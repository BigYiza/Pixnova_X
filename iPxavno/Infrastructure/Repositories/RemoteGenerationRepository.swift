import Foundation

final class RemoteGenerationRepository: GenerationRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func createTask(from draft: CreationDraft) async throws -> CreationTask {
        let urls = try draft.mediaInputs.map { input -> String in
            switch input {
            case let .remote(url):
                return url.absoluteString
            case .empty, .localImage:
                throw AppError.unsupported
            }
        }
        let payload = ImageGenerationRequest(
            urls: urls,
            filterID: draft.templateID,
            prompt: draft.prompt,
            negativePrompt: draft.negativePrompt,
            externalArguments: draft.externalArguments
                .nilIfEmpty,
            combineConfigs: draft.combineConfigs?.isEmptyObject == true ? nil : draft.combineConfigs
        )
        let body = try JSONEncoder().encode(payload)
        let endpoint = APIEndpoint<ServiceEnvelope<ImageGenerationResponse>>(
            method: .post,
            path: "/api/image_generation",
            body: body
        )
        let response = try await apiClient.sendService(endpoint)
        return CreationTask(id: response.id, state: .queued)
    }

    func fetchTask(id: String) async throws -> CreationTask {
        let endpoint = APIEndpoint<ServiceEnvelope<QueryResultResponse>>(
            method: .get,
            path: "/api/query_result",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
        let envelope = try await apiClient.sendServiceEnvelope(endpoint)

        guard envelope.code == 0 else {
            throw GenerationTaskPollingError.pending(message: envelope.resolvedMessage, code: envelope.resolvedCode)
        }

        guard let payload = envelope.data else {
            throw GenerationTaskPollingError.pending(message: envelope.resolvedMessage, code: envelope.resolvedCode)
        }

        return try payload.creationTask(fallbackID: id)
    }

    func cancelTask(id: String) async throws {
        let body = try JSONEncoder().encode(DeleteTaskRequest(taskID: id))
        let endpoint = APIEndpoint<ServiceEnvelope<EmptyResponse>>(
            method: .post,
            path: "/api/del_task_by_id",
            body: body
        )
        _ = try await apiClient.sendService(endpoint)
    }
}

private struct ImageGenerationRequest: Encodable {
    let urls: [String]
    let filterID: Int
    let prompt: String?
    let negativePrompt: String?
    let externalArguments: [String: JSONValue]?
    let combineConfigs: JSONValue?

    enum CodingKeys: String, CodingKey {
        case urls
        case filterID = "filter_id"
        case prompt
        case negativePrompt = "negative_prompt"
        case externalArguments = "external_args"
        case combineConfigs = "combine_configs"
    }
}

private struct ImageGenerationResponse: Decodable {
    let id: String
}

private struct QueryResultResponse: Decodable {
    let taskID: String?
    let id: String?
    let state: CreationState?
    let message: String?
    let resultURL: URL?
    let resultURLs: [URL]?

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case id
        case state
        case message = "msg"
        case resultURL = "aigc_url"
        case resultURLs = "aigc_urls"
    }

    func creationTask(fallbackID: String) throws -> CreationTask {
        if let completedURL = validResultURL {
            return CreationTask(
                id: taskID ?? id ?? fallbackID,
                state: .completed,
                message: message,
                resultURL: completedURL
            )
        }

        guard let state else {
            throw GenerationTaskPollingError.pending(message: message, code: nil)
        }

        return CreationTask(
            id: taskID ?? id ?? fallbackID,
            state: state,
            message: message,
            resultURL: resultURL
        )
    }

    private var validResultURL: URL? {
        if let resultURL, resultURL.isHTTPURL {
            return resultURL
        }
        return resultURLs?.first(where: \.isHTTPURL)
    }
}

private struct DeleteTaskRequest: Encodable {
    let taskID: String

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
    }
}

private extension Dictionary {
    var nilIfEmpty: Dictionary? {
        isEmpty ? nil : self
    }
}

private extension URL {
    var isHTTPURL: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
