import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

enum APIHost {
    case service
    case payment
    case absolute(URL)
}

struct APIEndpoint<Response: Decodable> {
    let host: APIHost
    let method: HTTPMethod
    let path: String
    let queryItems: [URLQueryItem]
    let body: Data?
    let requiresAuthentication: Bool

    init(
        host: APIHost = .service,
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuthentication: Bool = true
    ) {
        self.host = host
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.requiresAuthentication = requiresAuthentication
    }
}

struct EmptyResponse: Decodable {}

struct ServiceEnvelope<Payload: Decodable>: Decodable {
    let code: Int?
    let data: Payload?
    let descriptionText: String?
    let desc: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case data
        case descriptionText = "description"
        case desc
        case message = "msg"
    }

    func requirePayload() throws -> Payload {
        guard code == 0 else {
            let resolvedCode = code ?? -1
            let text = descriptionText ?? desc ?? message ?? "Request failed."
            let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if resolvedCode == -100 || (resolvedCode == -1 && normalizedText.contains("illegal request")) {
                throw AppError.tokenExpired
            }

            throw AppError.server(message: text, code: resolvedCode)
        }

        guard let data else {
            if Payload.self == EmptyResponse.self, let empty = EmptyResponse() as? Payload {
                return empty
            }
            throw AppError.invalidResponse
        }

        return data
    }
}
