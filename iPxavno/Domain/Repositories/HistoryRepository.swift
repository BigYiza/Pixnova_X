import Foundation

protocol HistoryRepository {
    func fetchHistory(page: Int, pageSize: Int) async throws -> HistoryTaskPage
}
