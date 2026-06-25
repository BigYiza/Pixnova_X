import Foundation

enum AppError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case tokenExpired
    case server(message: String, code: Int)
    case offline
    case unsupported
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server response could not be read."
        case .decodingFailed:
            return "The response format is not supported."
        case .tokenExpired:
            return "Your session has expired."
        case let .server(message, _):
            return message
        case .offline:
            return "The network connection appears to be offline."
        case .unsupported:
            return "This action is not available yet."
        case let .underlying(error):
            return error.localizedDescription
        }
    }
}
