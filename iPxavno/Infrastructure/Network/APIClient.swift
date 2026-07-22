import Foundation

final class APIClient {
    var tokenRefreshHandler: (() async throws -> Void)?

    private let environment: APIEnvironment
    private let headerProvider: RequestHeaderProviding
    private let session: URLSession
    private let decoder: JSONDecoder
    private let analytics: AnalyticsTracking?

    init(
        environment: APIEnvironment,
        headerProvider: RequestHeaderProviding,
        session: URLSession = .shared,
        analytics: AnalyticsTracking? = nil
    ) {
        self.environment = environment
        self.headerProvider = headerProvider
        self.session = session
        self.analytics = analytics
        decoder = JSONDecoder()
    }

    func send<Response: Decodable>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
        let request = try makeRequest(endpoint)
        let startedAt = ProcessInfo.processInfo.systemUptime
        #if DEBUG
            let requestID = Self.requestLogID()
            Self.logRequest(request, requestID: requestID, responseType: Response.self)
        #endif
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            trackResponse(
                endpoint: endpoint,
                request: request,
                startedAt: startedAt,
                result: "transport_error",
                error: error
            )
            #if DEBUG
                Self.logNetworkError(error, request: request, requestID: requestID)
            #endif
            throw AppError.underlying(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            trackResponse(
                endpoint: endpoint,
                request: request,
                startedAt: startedAt,
                result: "http_error",
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                responseBytes: data.count
            )
            #if DEBUG
                Self.logInvalidResponse(
                    response, data: data, request: request, requestID: requestID)
            #endif
            throw AppError.invalidResponse
        }

        do {
            let decoded = try decoder.decode(Response.self, from: data)
            #if DEBUG
                Self.logSuccess(httpResponse, data: data, request: request, requestID: requestID)
            #endif
            trackResponse(
                endpoint: endpoint,
                request: request,
                startedAt: startedAt,
                result: "success",
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            return decoded
        } catch {
            trackResponse(
                endpoint: endpoint,
                request: request,
                startedAt: startedAt,
                result: "decoding_error",
                statusCode: httpResponse.statusCode,
                responseBytes: data.count,
                error: error
            )
            #if DEBUG
                Self.logDecodingError(
                    error, response: httpResponse, data: data, request: request,
                    requestID: requestID,
                    responseType: Response.self)
            #endif
            throw AppError.decodingFailed
        }
    }

    func sendService<Payload: Decodable>(_ endpoint: APIEndpoint<ServiceEnvelope<Payload>>)
        async throws -> Payload
    {
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

    private func makeRequest<Response: Decodable>(_ endpoint: APIEndpoint<Response>) throws
        -> URLRequest
    {
        let baseURL: URL

        switch endpoint.host {
        case .service:
            baseURL = environment.serviceBaseURL
        case .payment:
            baseURL = environment.paymentBaseURL
        case .absolute(let url):
            baseURL = url
        }

        let url: URL

        if case .absolute = endpoint.host {
            url = baseURL
        } else {
            let normalizedPath = endpoint.path.trimmingCharacters(
                in: CharacterSet(charactersIn: "/"))
            guard
                var components = URLComponents(
                    url: baseURL.appendingPathComponent(normalizedPath),
                    resolvingAgainstBaseURL: false
                )
            else {
                throw AppError.invalidURL
            }
            components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
            guard let composedURL = components.url else { throw AppError.invalidURL }
            url = composedURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        headerProvider.headers(
            forPath: endpoint.path,
            requiresAuthentication: endpoint.requiresAuthentication,
            baseURL: baseURL
        ).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        return request
    }

    private func trackResponse<Response: Decodable>(
        endpoint: APIEndpoint<Response>,
        request: URLRequest,
        startedAt: TimeInterval,
        result: String,
        statusCode: Int? = nil,
        responseBytes: Int? = nil,
        error: Error? = nil
    ) {
        var properties = [
            "path": endpoint.path,
            "method": endpoint.method.rawValue,
            "host": request.url?.host ?? "unknown",
            "result": result,
            "duration_ms": String(Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)),
        ]
        properties["status_code"] = statusCode.map(String.init)
        properties["response_bytes"] = responseBytes.map(String.init)
        if let error {
            let nsError = error as NSError
            properties["error_domain"] = nsError.domain
            properties["error_code"] = String(nsError.code)
        }
        analytics?.record(
            AnalyticsEvent(name: "network_response", properties: properties, category: .network)
        )
    }
}

#if DEBUG
    extension APIClient {
        fileprivate static func requestLogID() -> String {
            String(UUID().uuidString.prefix(8))
        }

        fileprivate static func logRequest<Response: Decodable>(
            _ request: URLRequest, requestID: String, responseType: Response.Type
        ) {
            print(
                "[API][\(requestID)] ->",
                request.httpMethod ?? "GET",
                request.url?.absoluteString ?? "<nil-url>",
                "responseType=\(responseType)"
            )
        }

        fileprivate static func logSuccess(
            _ response: HTTPURLResponse, data: Data, request: URLRequest, requestID: String
        ) {
            print(
                "[API][\(requestID)] <-",
                response.statusCode,
                request.httpMethod ?? "GET",
                request.url?.absoluteString ?? "<nil-url>",
                "bytes=\(data.count)"
            )
        }

        fileprivate static func logNetworkError(
            _ error: Error, request: URLRequest, requestID: String
        ) {
            print(
                "[API][\(requestID)][NetworkError]",
                request.httpMethod ?? "GET",
                request.url?.absoluteString ?? "<nil-url>",
                errorDiagnostic(error)
            )
        }

        fileprivate static func logInvalidResponse(
            _ response: URLResponse, data: Data, request: URLRequest, requestID: String
        ) {
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

        fileprivate static func logDecodingError<Response: Decodable>(
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

        fileprivate static func responseBodyPreview(_ data: Data, limit: Int = 4_000) -> String {
            guard !data.isEmpty else { return "<empty>" }
            let text = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
            guard text.count > limit else { return text }
            return "\(text.prefix(limit))...<truncated \(text.count - limit) chars>"
        }

        fileprivate static func errorDiagnostic(_ error: Error) -> String {
            let nsError = error as NSError
            var parts = [
                "type=\(type(of: error))",
                "domain=\(nsError.domain)",
                "code=\(nsError.code)",
                "description=\(error.localizedDescription)",
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
