import Foundation

enum CreationState: String, Decodable {
    case queued
    case uploading
    case processing
    case completed
    case failed
    case cancelled
}

enum GenerationMediaInput: Equatable {
    case empty
    case localImage(URL)
    case remote(URL)
}

enum GenerationWorkflowMediaKind: Equatable {
    case image
    case video

    var displayName: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        }
    }
}

enum GenerationWorkflowPreflightError: Error, LocalizedError {
    case missingMedia(kind: GenerationWorkflowMediaKind, expected: Int, actual: Int, firstMissingIndex: Int)
    case missingPrompt
    case invalidTemplate

    var errorDescription: String? {
        switch self {
        case let .missingMedia(kind, expected, actual, _):
            if expected <= 1 {
                return "Please choose a \(kind.displayName) first."
            }
            return "Please choose \(expected) \(kind.displayName)s. Selected: \(actual)."
        case .missingPrompt:
            return "Please enter a prompt first."
        case .invalidTemplate:
            return "This template is not available."
        }
    }
}

enum GenerationTaskPollingError: Error {
    case pending(message: String?, code: Int?)
}

struct GenerationDraft {
    let templateID: Int
    let mediaInputs: [GenerationMediaInput]
    let prompt: String?
    let negativePrompt: String?
    let externalArguments: [String: JSONValue]
    let combineConfigs: JSONValue?
}

typealias CreationDraft = GenerationDraft

extension GenerationDraft {
    init(
        templateID: Int,
        mediaURLs: [URL],
        prompt: String?,
        externalArguments: [String: JSONValue]
    ) {
        self.init(
            templateID: templateID,
            mediaInputs: mediaURLs.map { .remote($0) },
            prompt: prompt,
            negativePrompt: nil,
            externalArguments: externalArguments,
            combineConfigs: nil
        )
    }
}

struct CreationTask: Decodable {
    let id: String
    let state: CreationState
    let message: String?
    let resultURL: URL?

    init(
        id: String,
        state: CreationState,
        message: String? = nil,
        resultURL: URL? = nil
    ) {
        self.id = id
        self.state = state
        self.message = message
        self.resultURL = resultURL
    }

    enum CodingKeys: String, CodingKey {
        case id = "task_id"
        case state
        case message = "msg"
        case resultURL = "aigc_url"
    }
}

extension GenerationDraft {
    var selectedMediaInputs: [GenerationMediaInput] {
        mediaInputs.filter { !$0.isEmpty }
    }

    var selectedMediaCount: Int {
        selectedMediaInputs.count
    }

    var firstEmptyMediaIndex: Int? {
        mediaInputs.firstIndex(where: \.isEmpty)
    }
}

extension GenerationMediaInput {
    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }
}
