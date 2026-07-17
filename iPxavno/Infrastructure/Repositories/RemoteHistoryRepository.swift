import Foundation

final class RemoteHistoryRepository: HistoryRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchHistory(page: Int, pageSize: Int) async throws -> HistoryTaskPage {
        let endpoint = APIEndpoint<ServiceEnvelope<HistoryTaskPage>>(
            method: .get,
            path: "/api/query_my_tasks",
            queryItems: [
                URLQueryItem(name: "page_num", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize))
            ]
        )
        return try await apiClient.sendService(endpoint)
    }
}
