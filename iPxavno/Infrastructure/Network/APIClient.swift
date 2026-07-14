import Foundation

final class APIClient {
    var tokenRefreshHandler: (() async throws -> Void)?

    private let environment: APIEnvironment
    private let headerProvider: RequestHeaderProviding
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        environment: APIEnvironment,
        headerProvider: RequestHeaderProviding,
        session: URLSession = .shared
    ) {
        self.environment = environment
        self.headerProvider = headerProvider
        self.session = session
        decoder = JSONDecoder()
    }

    func send<Response: Decodable>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
        let request = try makeRequest(endpoint)
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError.underlying(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.invalidResponse
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.decodingFailed
        }
    }

    func sendService<Payload: Decodable>(_ endpoint: APIEndpoint<ServiceEnvelope<Payload>>) async throws -> Payload {
        do {
            return try await send(endpoint).requirePayload()
        } catch AppError.tokenExpired {
            guard let tokenRefreshHandler else {
                throw AppError.tokenExpired
            }
            try await tokenRefreshHandler()
            return try await send(endpoint).requirePayload()
        }
    }

    func sendServiceEnvelope<Payload: Decodable>(
        _ endpoint: APIEndpoint<ServiceEnvelope<Payload>>
    ) async throws -> ServiceEnvelope<Payload> {
        let envelope = try await send(endpoint)
        guard envelope.requiresTokenRefresh else { return envelope }

        guard let tokenRefreshHandler else {
            throw AppError.tokenExpired
        }

        try await tokenRefreshHandler()
        return try await send(endpoint)
    }

    private func makeRequest<Response: Decodable>(_ endpoint: APIEndpoint<Response>) throws -> URLRequest {
        let baseURL: URL

        switch endpoint.host {
        case .service:
            baseURL = environment.serviceBaseURL
        case .payment:
            baseURL = environment.paymentBaseURL
        case let .absolute(url):
            baseURL = url
        }

        let url: URL

        if case .absolute = endpoint.host {
            url = baseURL
        } else {
            let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard var components = URLComponents(
                url: baseURL.appendingPathComponent(normalizedPath),
                resolvingAgainstBaseURL: false
            ) else {
                throw AppError.invalidURL
            }
            components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
            guard let composedURL = components.url else { throw AppError.invalidURL }
            url = composedURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        headerProvider.headers(requiresAuthentication: endpoint.requiresAuthentication).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        return request
    }
}
