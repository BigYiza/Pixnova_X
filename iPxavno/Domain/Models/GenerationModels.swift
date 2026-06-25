import Foundation

enum CreationState: String, Decodable {
    case queued
    case uploading
    case processing
    case completed
    case failed
    case cancelled
}

struct CreationDraft {
    let templateID: Int
    let mediaURLs: [URL]
    let prompt: String?
    let externalArguments: [String: String]
}

struct CreationTask: Decodable {
    let id: String
    let state: CreationState
    let message: String?
    let resultURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "task_id"
        case state
        case message = "msg"
        case resultURL = "aigc_url"
    }
}
