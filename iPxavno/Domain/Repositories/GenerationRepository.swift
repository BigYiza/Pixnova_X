import Foundation

protocol GenerationRepository {
    func createTask(from draft: CreationDraft) async throws -> CreationTask
    func fetchTask(id: String) async throws -> CreationTask
    func cancelTask(id: String) async throws
}
