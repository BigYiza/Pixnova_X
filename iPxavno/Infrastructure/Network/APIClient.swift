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
            let headers = formattedHeaders(request.allHTTPHeaderFields ?? [:])
            let body = formattedBody(request.httpBody)
            print("""
            [API][\(requestID)] REQUEST
            method: \(request.httpMethod ?? "GET")
            url: \(sanitizedURL(request.url))
            responseType: \(responseType)
            headers:
            \(headers)
            body:
            \(body)
            """)
        }

        fileprivate static func logSuccess(
            _ response: HTTPURLResponse, data: Data, request: URLRequest, requestID: String
        ) {
            logResponse(
                response,
                data: data,
                request: request,
                requestID: requestID,
                result: "SUCCESS"
            )
        }

        fileprivate static func logNetworkError(
            _ error: Error, request: URLRequest, requestID: String
        ) {
            print(
                "[API][\(requestID)][NetworkError]",
                request.httpMethod ?? "GET",
                sanitizedURL(request.url),
                errorDiagnostic(error)
            )
        }

        fileprivate static func logInvalidResponse(
            _ response: URLResponse, data: Data, request: URLRequest, requestID: String
        ) {
            guard let httpResponse = response as? HTTPURLResponse else {
                print("""
                [API][\(requestID)] RESPONSE INVALID
                method: \(request.httpMethod ?? "GET")
                url: \(sanitizedURL(request.url))
                response: <not an HTTP response>
                body:
                \(formattedBody(data))
                """)
                return
            }
            logResponse(
                httpResponse,
                data: data,
                request: request,
                requestID: requestID,
                result: "HTTP_ERROR"
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
            logResponse(
                response,
                data: data,
                request: request,
                requestID: requestID,
                result: "DECODING_ERROR"
            )
            print("""
            [API][\(requestID)] DECODING ERROR
            responseType: \(responseType)
            error: \(errorDiagnostic(error))
            """)
        }

        private static func logResponse(
            _ response: HTTPURLResponse,
            data: Data,
            request: URLRequest,
            requestID: String,
            result: String
        ) {
            print("""
            [API][\(requestID)] RESPONSE \(result)
            method: \(request.httpMethod ?? "GET")
            url: \(sanitizedURL(request.url))
            status: \(response.statusCode)
            bytes: \(data.count)
            headers:
            \(formattedHeaders(response.allHeaderFields))
            body:
            \(formattedBody(data))
            """)
        }

        private static func formattedBody(_ data: Data?) -> String {
            guard let data, !data.isEmpty else { return "<empty>" }

            if let object = try? JSONSerialization.jsonObject(with: data),
               JSONSerialization.isValidJSONObject(object),
               let sanitizedData = try? JSONSerialization.data(
                   withJSONObject: sanitizeJSONObject(object),
                   options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
               ),
               let text = String(data: sanitizedData, encoding: .utf8) {
                return text
            }

            return String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        }

        private static func formattedHeaders(_ headers: [String: String]) -> String {
            let values = headers.map { key, value in
                "  \(key): \(isSensitiveKey(key) ? "<redacted>" : value)"
            }
            return values.sorted().isEmpty ? "<empty>" : values.sorted().joined(separator: "\n")
        }

        private static func formattedHeaders(_ headers: [AnyHashable: Any]) -> String {
            let values = headers.map { key, value in
                let name = String(describing: key)
                let displayedValue = isSensitiveKey(name) ? "<redacted>" : String(describing: value)
                return "  \(name): \(displayedValue)"
            }
            return values.sorted().isEmpty ? "<empty>" : values.sorted().joined(separator: "\n")
        }

        private static func sanitizeJSONObject(_ object: Any) -> Any {
            if let dictionary = object as? [String: Any] {
                return dictionary.reduce(into: [String: Any]()) { result, element in
                    result[element.key] = isSensitiveKey(element.key)
                        ? "<redacted>"
                        : sanitizeJSONObject(element.value)
                }
            }
            if let array = object as? [Any] {
                return array.map(sanitizeJSONObject)
            }
            return object
        }

        private static func sanitizedURL(_ url: URL?) -> String {
            guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { return "<nil-url>" }
            components.queryItems = components.queryItems?.map { item in
                URLQueryItem(
                    name: item.name,
                    value: isSensitiveKey(item.name) ? "<redacted>" : item.value
                )
            }
            return components.url?.absoluteString ?? url.absoluteString
        }

        private static func isSensitiveKey(_ key: String) -> Bool {
            let normalized = key.lowercased().filter { $0.isLetter || $0.isNumber }
            let exactKeys: Set<String> = [
                "authorization",
                "accesstoken",
                "refreshtoken",
                "idtoken",
                "firebasetoken",
                "token",
                "tokenid",
                "receipt",
                "transactionreceipt",
                "signedtransactioninfo",
                "signedrenewalinfo",
                "clientsecret",
                "ephemeralkey",
                "password",
                "secret",
                "signature",
                "setcookie",
                "cookie"
            ]
            return exactKeys.contains(normalized)
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
