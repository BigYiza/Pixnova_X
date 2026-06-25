import Foundation

final class RemoteGenerationRepository: GenerationRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func createTask(from draft: CreationDraft) async throws -> CreationTask {
        let payload = ImageGenerationRequest(
            urls: draft.mediaURLs.map(\.absoluteString),
            filterID: draft.templateID,
            prompt: draft.prompt,
            externalArguments: draft.externalArguments
        )
        let body = try JSONEncoder().encode(payload)
        let endpoint = APIEndpoint<ServiceEnvelope<CreationTask>>(
            method: .post,
            path: "/api/image_generation",
            body: body
        )
        return try await apiClient.sendService(endpoint)
    }

    func fetchTask(id: String) async throws -> CreationTask {
        let endpoint = APIEndpoint<ServiceEnvelope<CreationTask>>(
            method: .get,
            path: "/api/query_result",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
        return try await apiClient.sendService(endpoint)
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
    let externalArguments: [String: String]

    enum CodingKeys: String, CodingKey {
        case urls
        case filterID = "filter_id"
        case prompt
        case externalArguments = "external_args"
    }
}

private struct DeleteTaskRequest: Encodable {
    let taskID: String

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
    }
}
