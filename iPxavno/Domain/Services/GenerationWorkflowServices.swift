import Foundation

protocol GenerationMediaUploading {
    func resolveMediaInputs(for draft: GenerationDraft) async throws -> GenerationDraft
}

protocol GenerationWorkflowRunning {
    func run(
        request: GenerationWorkflowRequest,
        events: GenerationWorkflowEvents
    ) async throws -> CreationTask

    func cancel(taskID: String) async
}

struct GenerationWorkflowEvents {
    var didResolveDraft: ((GenerationDraft) -> Void)?
    var didStart: ((CreationTask) -> Void)?
    var didPoll: ((Int) -> Void)?
    var didUpdate: ((CreationTask) -> Void)?
}

enum GenerationWorkflowBlockError: Error {
    case membership(MembershipBlockReason)
    case insufficientDiamonds(required: Int, available: Int)
}

final class DefaultGenerationWorkflowRunner: GenerationWorkflowRunning {
    private let membershipHandler: MembershipHandling
    private let mediaUploader: GenerationMediaUploading
    private let generationRepository: GenerationRepository
    private let analytics: AnalyticsTracking

    init(
        membershipHandler: MembershipHandling,
        mediaUploader: GenerationMediaUploading,
        generationRepository: GenerationRepository,
        analytics: AnalyticsTracking
    ) {
        self.membershipHandler = membershipHandler
        self.mediaUploader = mediaUploader
        self.generationRepository = generationRepository
        self.analytics = analytics
    }

    func run(
        request: GenerationWorkflowRequest,
        events: GenerationWorkflowEvents
    ) async throws -> CreationTask {
        try await runPreflightChecks(for: request)

        analytics.record(
            AnalyticsEvent(
                name: "generation_workflow_start",
                properties: ["kind": request.kind.rawValue, "template_id": "\(request.template.id)"]
            )
        )

        let resolvedDraft = try await mediaUploader.resolveMediaInputs(for: request.draft)
        events.didResolveDraft?(resolvedDraft)

        let task = try await generationRepository.createTask(from: resolvedDraft)
        events.didStart?(task)

        let completedTask = try await pollUntilFinished(task: task, request: request, events: events)
        _ = try? await membershipHandler.refreshStatus()

        analytics.record(
            AnalyticsEvent(
                name: "generation_workflow_finish",
                properties: ["kind": request.kind.rawValue, "template_id": "\(request.template.id)"]
            )
        )

        return completedTask
    }

    func cancel(taskID: String) async {
        try? await generationRepository.cancelTask(id: taskID)
    }

    private func runPreflightChecks(for request: GenerationWorkflowRequest) async throws {
        let membership = try await membershipHandler.membershipStatus(forceRefresh: false)

        switch membership.access(to: request.template) {
        case .allowed:
            break
        case let .blocked(reason):
            throw GenerationWorkflowBlockError.membership(reason)
        }

        switch membership.accessToDiamonds(required: request.requiredDiamonds) {
        case .allowed:
            return
        case let .blocked(.insufficientDiamonds(required, available)):
            throw GenerationWorkflowBlockError.insufficientDiamonds(required: required, available: available)
        case let .blocked(reason):
            throw GenerationWorkflowBlockError.membership(reason)
        }
    }

    private func pollUntilFinished(
        task initialTask: CreationTask,
        request: GenerationWorkflowRequest,
        events: GenerationWorkflowEvents
    ) async throws -> CreationTask {
        var task = initialTask
        let startedAt = Date()
        var pollCount = 0
        var consecutiveQueryFailureCount = 0

        while true {
            try Task.checkCancellation()

            switch task.state {
            case .completed:
                return task
            case .failed:
                throw AppError.server(message: task.message ?? "Generation failed.", code: -1)
            case .cancelled:
                throw CancellationError()
            case .queued, .uploading, .processing:
                break
            }

            guard Date().timeIntervalSince(startedAt) < request.timeout else {
                throw AppError.server(message: "Generate timeout.", code: -1)
            }

            let delay = UInt64(request.pollInterval * 1_000_000_000)
            try await Task.sleep(nanoseconds: delay)
            pollCount += 1
            events.didPoll?(pollCount)

            do {
                task = try await generationRepository.fetchTask(id: initialTask.id)
                consecutiveQueryFailureCount = 0
            } catch let error as GenerationTaskPollingError {
                switch error {
                case let .pending(message, code):
                    if Self.isTerminalQueryFailure(message: message, code: code) {
                        consecutiveQueryFailureCount += 1
                        if consecutiveQueryFailureCount >= Self.maximumConsecutiveQueryFailures {
                            throw AppError.server(
                                message: message ?? Self.terminalQueryFailureMessage,
                                code: code ?? -1
                            )
                        }
                    } else {
                        consecutiveQueryFailureCount = 0
                    }
                }
                continue
            }

            events.didUpdate?(task)
        }
    }

    private static let terminalQueryFailureMessage = "Oops, something went wrong. Just try again!"
    private static let maximumConsecutiveQueryFailures = 5

    private static func isTerminalQueryFailure(message: String?, code: Int?) -> Bool {
        let normalizedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        return code == -1 && normalizedMessage == terminalQueryFailureMessage
    }
}

final class PassthroughGenerationMediaUploader: GenerationMediaUploading {
    func resolveMediaInputs(for draft: GenerationDraft) async throws -> GenerationDraft {
        draft
    }
}
