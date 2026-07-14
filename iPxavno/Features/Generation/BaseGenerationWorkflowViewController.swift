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
    let inputRequirement: GenerationWorkflowInputRequirement
    let requiredDiamonds: Int
    let canRunInBackground: Bool
    let pollInterval: TimeInterval
    let timeout: TimeInterval

    init(
        kind: GenerationWorkflowKind,
        template: CreativeTemplate,
        draft: CreationDraft,
        inputRequirement: GenerationWorkflowInputRequirement? = nil,
        requiredDiamonds: Int? = nil,
        canRunInBackground: Bool = true,
        pollInterval: TimeInterval = 0.5,
        timeout: TimeInterval? = nil
    ) {
        self.kind = kind
        self.template = template
        self.draft = draft
        self.inputRequirement = inputRequirement ?? GenerationWorkflowInputRequirement.default(for: template, kind: kind)
        self.requiredDiamonds = max(0, requiredDiamonds ?? template.diamondCost)
        self.canRunInBackground = canRunInBackground
        self.pollInterval = pollInterval
        self.timeout = timeout ?? TimeInterval(max(template.waitSeconds, 120))
    }
}

struct GenerationWorkflowInputRequirement {
    let mediaKind: GenerationWorkflowMediaKind
    let requiredMediaCount: Int
    let requiresPrompt: Bool

    init(
        mediaKind: GenerationWorkflowMediaKind = .image,
        requiredMediaCount: Int = 0,
        requiresPrompt: Bool = false
    ) {
        self.mediaKind = mediaKind
        self.requiredMediaCount = max(0, requiredMediaCount)
        self.requiresPrompt = requiresPrompt
    }

    static func `default`(
        for template: CreativeTemplate,
        kind: GenerationWorkflowKind
    ) -> GenerationWorkflowInputRequirement {
        let imageCount = template.inputRequirement?.imageCount ?? {
            switch kind {
            case .filter:
                return 1
            case .customImage, .customVideo:
                switch template.kind {
                case .imageToVideo, .imageToImage:
                    return 1
                case .multiImageToVideo:
                    return 2
                default:
                    return 0
                }
            }
        }()

        return GenerationWorkflowInputRequirement(
            mediaKind: .image,
            requiredMediaCount: imageCount,
            requiresPrompt: template.kind == .textToVideo || template.kind == .textToImage
        )
    }
}

class BaseGenerationWorkflowViewController: BaseViewController {
    let membershipHandler: MembershipHandling
    let generationRepository: GenerationRepository
    let generationWorkflowRunner: GenerationWorkflowRunning
    let analytics: AnalyticsTracking

    private var workflowTask: Task<Void, Never>?
    private var activeTaskID: String?
    private var activeRequest: GenerationWorkflowRequest?
    private var latestCompletedResult: (task: CreationTask, request: GenerationWorkflowRequest)?
    private weak var progressViewController: GenerationProgressViewController?

    init(
        membershipHandler: MembershipHandling,
        generationRepository: GenerationRepository,
        generationWorkflowRunner: GenerationWorkflowRunning,
        analytics: AnalyticsTracking
    ) {
        self.membershipHandler = membershipHandler
        self.generationRepository = generationRepository
        self.generationWorkflowRunner = generationWorkflowRunner
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
        Task { [generationWorkflowRunner] in
            await generationWorkflowRunner.cancel(taskID: activeTaskID)
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
        cancelGenerationWorkflow(deleteRemoteTask: false)
        progressViewController?.showBackgroundAccepted()
        navigationController?.popViewController(animated: true)
    }

    func makeGenerationWorkflowRequest() async throws -> GenerationWorkflowRequest {
        throw AppError.unsupported
    }

    func presentGenerationMediaPicker(kind: GenerationWorkflowMediaKind, index: Int) -> Bool {
        false
    }

    func presentMembershipPaywall(reason: MembershipBlockReason) {
        let paywall = MembershipPaywallViewController(
            viewModel: MembershipPaywallViewModel(
                membershipHandler: membershipHandler,
                purchaseHandler: AppRuntime.shared.container.membershipPurchaseHandler,
                analytics: analytics
            )
        )
        let navigationController = UINavigationController(rootViewController: paywall)
        navigationController.modalPresentationStyle = .fullScreen
        (progressViewController ?? self).present(navigationController, animated: true)
    }

    func presentDiamondPurchase(required: Int, available: Int) {
        let sheet = InsufficientDiamondsSheetViewController(required: required, available: available)
        sheet.onGetDiamonds = { [weak self] in
            self?.presentDiamondStore()
        }
        sheet.onGoPro = { [weak self] in
            self?.presentMembershipPaywall(reason: .insufficientDiamonds(required: required, available: available))
        }
        present(sheet, animated: false)
    }

    func generationDidStart(task: CreationTask, request: GenerationWorkflowRequest) {}

    func generationDidUpdate(task: CreationTask, request: GenerationWorkflowRequest) {}

    func generationDidFinish(task: CreationTask, request: GenerationWorkflowRequest) {}

    func generationDidMoveToBackground(taskID: String, request: GenerationWorkflowRequest) {}

    func generationDidCancel() {}

    func generationDidFail(error: Error) {
        guard progressViewController == nil else { return }
        showError(error.localizedDescription)
    }

    func presentDiamondStore() {
        let viewController = DiamondPurchaseViewController(
            viewModel: DiamondPurchaseViewModel(
                catalog: .configured,
                membershipHandler: membershipHandler,
                purchaseHandler: AppRuntime.shared.container.diamondPurchaseHandler,
                analytics: analytics
            )
        )
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    private func runGenerationWorkflow() async {
        var didShowLoading = false
        latestCompletedResult = nil
        defer {
            if didShowLoading {
                setLoading(false)
            }
            activeTaskID = nil
            activeRequest = nil
            progressViewController = nil
        }

        do {
            let request = try await makeGenerationWorkflowRequest()
            activeRequest = request
            try validateGenerationWorkflowRequest(request)

            setLoading(true)
            didShowLoading = true
            try await runEntitlementChecks(for: request)
            setLoading(false)
            didShowLoading = false
            presentProgressPage(for: request)

            let completedTask = try await generationWorkflowRunner.run(
                request: request,
                events: GenerationWorkflowEvents(
                    didResolveDraft: { [weak self] _ in
                        self?.progressViewController?.update(
                            progress: 0.15,
                            title: "Uploading media",
                            detail: "Your photo is ready."
                        )
                    },
                    didStart: { [weak self] task in
                        self?.activeTaskID = task.id
                        self?.progressViewController?.update(
                            progress: 0.20,
                            title: "Creating task",
                            detail: "Pixnova is preparing your video."
                        )
                        self?.progressViewController?.setSkipActionEnabled(true)
                        self?.generationDidStart(task: task, request: request)
                    },
                    didPoll: { [weak self] count in
                        self?.progressViewController?.update(
                            progress: Self.pollingProgress(for: count),
                            title: "Generating",
                            detail: "Rendering frame details..."
                        )
                    },
                    didUpdate: { [weak self] task in
                        self?.generationDidUpdate(task: task, request: request)
                    }
                )
            )
            latestCompletedResult = (completedTask, request)
            progressViewController?.finish(resultURL: completedTask.resultURL)
            generationDidFinish(task: completedTask, request: request)
            presentResultPageIfPossible(task: completedTask, request: request)
        } catch is CancellationError {
            generationDidCancel()
        } catch let error as GenerationWorkflowPreflightError {
            handleGenerationPreflightError(error)
        } catch let GenerationWorkflowBlockError.membership(reason) {
            presentMembershipPaywall(reason: reason)
        } catch let GenerationWorkflowBlockError.insufficientDiamonds(required, available) {
            presentDiamondPurchase(required: required, available: available)
        } catch {
            progressViewController?.showFailure(message: error.localizedDescription)
            generationDidFail(error: error)
        }
    }

    private func presentProgressPage(for request: GenerationWorkflowRequest) {
        let progressController = GenerationProgressViewController(
            template: request.template,
            requiredDiamonds: request.requiredDiamonds,
            isMember: membershipHandler.cachedMembership.isVIP
        )
        progressController.onCancel = { [weak self] in
            self?.cancelGenerationWorkflow(deleteRemoteTask: true)
            self?.navigationController?.popViewController(animated: true)
        }
        progressController.onSkipWait = { [weak self] in
            guard let self else { return }
            if self.membershipHandler.cachedMembership.isVIP {
                self.requestBackgroundGeneration()
            } else {
                self.presentMembershipPaywall(reason: .membershipRequired)
            }
        }
        progressController.onViewResult = { [weak self] in
            guard let self,
                  let result = self.latestCompletedResult else {
                self?.navigationController?.popViewController(animated: true)
                return
            }
            self.presentResultPageIfPossible(task: result.task, request: result.request, delay: 0)
        }
        progressController.onRetry = { [weak self] in
            guard let self else { return }
            self.navigationController?.popViewController(animated: false)
            self.beginGenerationWorkflow()
        }
        progressController.onBack = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        progressViewController = progressController
        navigationController?.pushViewController(progressController, animated: true)
    }

    private func presentResultPageIfPossible(
        task: CreationTask,
        request: GenerationWorkflowRequest,
        delay: TimeInterval = 0.55
    ) {
        guard let resultURL = task.resultURL else { return }
        let activeProgressController = progressViewController

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let navigationController = self.navigationController
            guard let navigationController,
                  !(navigationController.topViewController is GenerationResultViewController) else {
                return
            }

            let resultController = GenerationResultViewController(
                template: request.template,
                resultURL: resultURL
            )
            resultController.onUseTemplateAgain = { [weak self] in
                guard let self,
                      let navigationController = self.navigationController,
                      navigationController.viewControllers.contains(self) else {
                    return
                }
                navigationController.popToViewController(self, animated: true)
            }

            var viewControllers = navigationController.viewControllers.filter { viewController in
                guard !(viewController is GenerationProgressViewController) else { return false }
                return viewController !== activeProgressController
            }
            viewControllers.append(resultController)
            navigationController.setViewControllers(viewControllers, animated: true)
        }
    }

    private static func pollingProgress(for pollCount: Int) -> Double {
        let curvedProgress = 0.20 + 0.77 * (1 - pow(0.86, Double(max(0, pollCount))))
        return min(0.97, curvedProgress)
    }

    private func validateGenerationWorkflowRequest(_ request: GenerationWorkflowRequest) throws {
        guard request.template.id > 0, request.draft.templateID > 0 else {
            throw GenerationWorkflowPreflightError.invalidTemplate
        }

        let requirement = request.inputRequirement
        if requirement.requiredMediaCount > 0 {
            let selectedCount = request.draft.selectedMediaCount
            guard selectedCount >= requirement.requiredMediaCount else {
                throw GenerationWorkflowPreflightError.missingMedia(
                    kind: requirement.mediaKind,
                    expected: requirement.requiredMediaCount,
                    actual: selectedCount,
                    firstMissingIndex: request.draft.firstEmptyMediaIndex ?? selectedCount
                )
            }
        }

        if requirement.requiresPrompt,
           request.draft.prompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            throw GenerationWorkflowPreflightError.missingPrompt
        }
    }

    private func runEntitlementChecks(for request: GenerationWorkflowRequest) async throws {
        let membership = try await membershipHandler.membershipStatus(forceRefresh: false)

        switch membership.access(to: request.template) {
        case .allowed:
            break
        case let .blocked(reason):
            throw GenerationWorkflowBlockError.membership(reason)
        }

        switch membership.accessToDiamonds(required: request.requiredDiamonds) {
        case .allowed:
            break
        case let .blocked(.insufficientDiamonds(required, available)):
            throw GenerationWorkflowBlockError.insufficientDiamonds(required: required, available: available)
        case let .blocked(reason):
            throw GenerationWorkflowBlockError.membership(reason)
        }
    }

    private func handleGenerationPreflightError(_ error: GenerationWorkflowPreflightError) {
        switch error {
        case let .missingMedia(kind, _, _, firstMissingIndex):
            if !presentGenerationMediaPicker(kind: kind, index: firstMissingIndex) {
                generationDidFail(error: error)
            }
        case .missingPrompt, .invalidTemplate:
            generationDidFail(error: error)
        }
    }
}
