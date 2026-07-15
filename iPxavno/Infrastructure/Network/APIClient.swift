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
        #if DEBUG
        let requestID = Self.requestLogID()
        Self.logRequest(request, requestID: requestID, responseType: Response.self)
        #endif
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            Self.logNetworkError(error, request: request, requestID: requestID)
            #endif
            throw AppError.underlying(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            #if DEBUG
            Self.logInvalidResponse(response, data: data, request: request, requestID: requestID)
            #endif
            throw AppError.invalidResponse
        }

        do {
            let decoded = try decoder.decode(Response.self, from: data)
            #if DEBUG
            Self.logSuccess(httpResponse, data: data, request: request, requestID: requestID)
            #endif
            return decoded
        } catch {
            #if DEBUG
            Self.logDecodingError(error, response: httpResponse, data: data, request: request, requestID: requestID, responseType: Response.self)
            #endif
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

#if DEBUG
private extension APIClient {
    static func requestLogID() -> String {
        String(UUID().uuidString.prefix(8))
    }

    static func logRequest<Response: Decodable>(_ request: URLRequest, requestID: String, responseType: Response.Type) {
        print(
            "[API][\(requestID)] ->",
            request.httpMethod ?? "GET",
            request.url?.absoluteString ?? "<nil-url>",
            "responseType=\(responseType)"
        )
    }

    static func logSuccess(_ response: HTTPURLResponse, data: Data, request: URLRequest, requestID: String) {
        print(
            "[API][\(requestID)] <-",
            response.statusCode,
            request.httpMethod ?? "GET",
            request.url?.absoluteString ?? "<nil-url>",
            "bytes=\(data.count)"
        )
    }

    static func logNetworkError(_ error: Error, request: URLRequest, requestID: String) {
        print(
            "[API][\(requestID)][NetworkError]",
            request.httpMethod ?? "GET",
            request.url?.absoluteString ?? "<nil-url>",
            errorDiagnostic(error)
        )
    }

    static func logInvalidResponse(_ response: URLResponse, data: Data, request: URLRequest, requestID: String) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print(
            "[API][\(requestID)][InvalidResponse]",
            request.httpMethod ?? "GET",
            request.url?.absoluteString ?? "<nil-url>",
            "status=\(statusCode)",
            "bytes=\(data.count)",
            "body=\(responseBodyPreview(data))"
        )
    }

    static func logDecodingError<Response: Decodable>(
        _ error: Error,
        response: HTTPURLResponse,
        data: Data,
        request: URLRequest,
        requestID: String,
        responseType: Response.Type
    ) {
        print(
            "[API][\(requestID)][DecodingError]",
            request.httpMethod ?? "GET",
            request.url?.absoluteString ?? "<nil-url>",
            "status=\(response.statusCode)",
            "responseType=\(responseType)",
            "bytes=\(data.count)",
            "error=\(errorDiagnostic(error))",
            "body=\(responseBodyPreview(data))"
        )
    }

    static func responseBodyPreview(_ data: Data, limit: Int = 4_000) -> String {
        guard !data.isEmpty else { return "<empty>" }
        let text = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        guard text.count > limit else { return text }
        return "\(text.prefix(limit))...<truncated \(text.count - limit) chars>"
    }

    static func errorDiagnostic(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = [
            "type=\(type(of: error))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "description=\(error.localizedDescription)"
        ]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            let underlyingError = underlying as NSError
            parts.append(
                "underlying={type=\(type(of: underlying)) domain=\(underlyingError.domain) code=\(underlyingError.code) description=\(underlying.localizedDescription)}"
            )
        }
        return parts.joined(separator: " ")
    }
}
#endif
