import UIKit

enum GenerationWorkflowKind: String {
    case customVideo
    case customImage
    case filter
}

struct GenerationWorkflowRequest {
    let kind: GenerationWorkflowKind
    let template: CreativeTemplate
    let draft: CreationDraft
    let requiredDiamonds: Int
    let canRunInBackground: Bool
    let pollInterval: TimeInterval
    let timeout: TimeInterval

    init(
        kind: GenerationWorkflowKind,
        template: CreativeTemplate,
        draft: CreationDraft,
        requiredDiamonds: Int? = nil,
        canRunInBackground: Bool = true,
        pollInterval: TimeInterval = 0.5,
        timeout: TimeInterval? = nil
    ) {
        self.kind = kind
        self.template = template
        self.draft = draft
        self.requiredDiamonds = max(0, requiredDiamonds ?? template.diamondCost)
        self.canRunInBackground = canRunInBackground
        self.pollInterval = pollInterval
        self.timeout = timeout ?? TimeInterval(max(template.waitSeconds, 120))
    }
}

class BaseGenerationWorkflowViewController: BaseViewController {
    let membershipHandler: MembershipHandling
    let generationRepository: GenerationRepository
    let analytics: AnalyticsTracking

    private var workflowTask: Task<Void, Never>?
    private var activeTaskID: String?
    private var activeRequest: GenerationWorkflowRequest?

    init(
        membershipHandler: MembershipHandling,
        generationRepository: GenerationRepository,
        analytics: AnalyticsTracking
    ) {
        self.membershipHandler = membershipHandler
        self.generationRepository = generationRepository
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginGenerationWorkflow() {
        workflowTask?.cancel()
        workflowTask = Task { [weak self] in
            await self?.runGenerationWorkflow()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            cancelGenerationWorkflow(deleteRemoteTask: false)
        }
    }

    func cancelGenerationWorkflow(deleteRemoteTask: Bool = true) {
        workflowTask?.cancel()

        guard deleteRemoteTask, let activeTaskID else { return }
        Task { [generationRepository] in
            try? await generationRepository.cancelTask(id: activeTaskID)
        }
    }

    func requestBackgroundGeneration() {
        guard let activeTaskID, let activeRequest else {
            showError("No active generation task.")
            return
        }

        guard activeRequest.canRunInBackground else {
            showError("This generation task cannot run in the background.")
            return
        }

        guard membershipHandler.canSkipWaiting() else {
            presentMembershipPaywall(reason: .membershipRequired)
            return
        }

        generationDidMoveToBackground(taskID: activeTaskID, request: activeRequest)
    }

    func makeGenerationWorkflowRequest() async throws -> GenerationWorkflowRequest {
        throw AppError.unsupported
    }

    func presentMembershipPaywall(reason: MembershipBlockReason) {
        showError("Membership is required for this template.")
    }

    func presentDiamondPurchase(required: Int, available: Int) {
        showError("Not enough diamonds. Required: \(required), available: \(available).")
    }

    func generationDidStart(task: CreationTask, request: GenerationWorkflowRequest) {}

    func generationDidUpdate(task: CreationTask, request: GenerationWorkflowRequest) {}

    func generationDidFinish(task: CreationTask, request: GenerationWorkflowRequest) {}

    func generationDidMoveToBackground(taskID: String, request: GenerationWorkflowRequest) {}

    func generationDidCancel() {}

    func generationDidFail(error: Error) {
        showError(error.localizedDescription)
    }

    private func runGenerationWorkflow() async {
        setLoading(true)
        defer {
            setLoading(false)
            activeTaskID = nil
            activeRequest = nil
        }

        do {
            let request = try await makeGenerationWorkflowRequest()
            activeRequest = request

            guard try await runPreflightChecks(for: request) else { return }

            analytics.record(
                AnalyticsEvent(
                    name: "generation_workflow_start",
                    properties: ["kind": request.kind.rawValue, "template_id": "\(request.template.id)"]
                )
            )

            let task = try await generationRepository.createTask(from: request.draft)
            activeTaskID = task.id
            generationDidStart(task: task, request: request)

            let completedTask = try await pollUntilFinished(task: task, request: request)
            generationDidFinish(task: completedTask, request: request)
            _ = try? await membershipHandler.refreshStatus()

            analytics.record(
                AnalyticsEvent(
                    name: "generation_workflow_finish",
                    properties: ["kind": request.kind.rawValue, "template_id": "\(request.template.id)"]
                )
            )
        } catch is CancellationError {
            generationDidCancel()
        } catch {
            generationDidFail(error: error)
        }
    }

    private func runPreflightChecks(for request: GenerationWorkflowRequest) async throws -> Bool {
        let membership = try await membershipHandler.membershipStatus(forceRefresh: false)

        switch membership.access(to: request.template) {
        case .allowed:
            break
        case let .blocked(reason):
            presentMembershipPaywall(reason: reason)
            return false
        }

        switch membership.accessToDiamonds(required: request.requiredDiamonds) {
        case .allowed:
            return true
        case let .blocked(.insufficientDiamonds(required, available)):
            presentDiamondPurchase(required: required, available: available)
            return false
        case let .blocked(reason):
            presentMembershipPaywall(reason: reason)
            return false
        }
    }

    private func pollUntilFinished(
        task initialTask: CreationTask,
        request: GenerationWorkflowRequest
    ) async throws -> CreationTask {
        var task = initialTask
        let startedAt = Date()

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
            task = try await generationRepository.fetchTask(id: initialTask.id)
            generationDidUpdate(task: task, request: request)
        }
    }
}
