import Foundation

struct ProfileMembershipState {
    let isVIP: Bool
    let diamonds: Int
    let renewalText: String?

    static let empty = ProfileMembershipState(isVIP: false, diamonds: 0, renewalText: nil)
}

struct ProfileViewState {
    var membership: ProfileMembershipState
    var tasks: [HistoryTask]
    var totalTasks: Int
    var isInitialLoading: Bool
    var isRefreshing: Bool
    var isLoadingMore: Bool
    var errorMessage: String?

    static let initial = ProfileViewState(
        membership: .empty,
        tasks: [],
        totalTasks: 0,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: nil
    )

    var canLoadMore: Bool {
        tasks.count < totalTasks
    }
}

@MainActor
final class ProfileViewModel {
    let state: Observable<ProfileViewState>

    private let membershipHandler: MembershipHandling
    private let historyRepository: HistoryRepository
    private let analytics: AnalyticsTracking
    private var accountObserver: NSObjectProtocol?
    private var currentPage = 0
    private var isFetchingHistory = false
    private var hasLoaded = false

    init(
        membershipHandler: MembershipHandling,
        historyRepository: HistoryRepository,
        analytics: AnalyticsTracking
    ) {
        self.membershipHandler = membershipHandler
        self.historyRepository = historyRepository
        self.analytics = analytics
        state = Observable(
            ProfileViewState(
                membership: Self.membershipState(from: membershipHandler.cachedMembership),
                tasks: [],
                totalTasks: 0,
                isInitialLoading: false,
                isRefreshing: false,
                isLoadingMore: false,
                errorMessage: nil
            )
        )
        observeAccountChanges()
    }

    deinit {
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        refreshMembership()
        fetchHistory(mode: .initial)
    }

    func refresh() {
        refreshMembership()
        fetchHistory(mode: .refresh)
    }

    func loadMore() {
        guard state.value.canLoadMore else { return }
        fetchHistory(mode: .more)
    }

    private func refreshMembership() {
        Task {
            do {
                let membership = try await membershipHandler.membershipStatus(forceRefresh: true)
                applyMembership(membership)
            } catch {
                applyMembership(membershipHandler.cachedMembership)
            }
        }
    }

    private func fetchHistory(mode: HistoryLoadMode) {
        guard !isFetchingHistory else { return }
        isFetchingHistory = true

        var loadingState = state.value
        loadingState.errorMessage = nil
        switch mode {
        case .initial:
            loadingState.isInitialLoading = loadingState.tasks.isEmpty
        case .refresh:
            loadingState.isRefreshing = true
        case .more:
            loadingState.isLoadingMore = true
        }
        state.value = loadingState

        let requestedPage = mode == .more ? currentPage + 1 : 1
        Task {
            do {
                let page = try await historyRepository.fetchHistory(page: requestedPage, pageSize: 20)
                applyHistoryPage(page, mode: mode, requestedPage: requestedPage)
            } catch {
                finishHistoryLoading(with: error)
            }
        }
    }

    private func applyHistoryPage(_ page: HistoryTaskPage, mode: HistoryLoadMode, requestedPage: Int) {
        isFetchingHistory = false
        currentPage = requestedPage

        var updatedState = state.value
        switch mode {
        case .initial, .refresh:
            updatedState.tasks = page.items
        case .more:
            let existingIDs = Set(updatedState.tasks.map(\.id))
            updatedState.tasks += page.items.filter { !existingIDs.contains($0.id) }
        }
        updatedState.totalTasks = max(page.total, updatedState.tasks.count)
        updatedState.isInitialLoading = false
        updatedState.isRefreshing = false
        updatedState.isLoadingMore = false
        updatedState.errorMessage = nil
        state.value = updatedState

        analytics.record(
            AnalyticsEvent(
                name: "profile_history_loaded",
                properties: ["count": "\(updatedState.tasks.count)", "total": "\(page.total)"]
            )
        )
    }

    private func finishHistoryLoading(with error: Error) {
        isFetchingHistory = false
        var updatedState = state.value
        updatedState.isInitialLoading = false
        updatedState.isRefreshing = false
        updatedState.isLoadingMore = false
        updatedState.errorMessage = error.localizedDescription
        state.value = updatedState
    }

    private func observeAccountChanges() {
        accountObserver = membershipHandler.observeMembershipChanges { [weak self] membership in
            guard let self else { return }
            Task { @MainActor in
                self.applyMembership(membership)
            }
        }
    }

    private func applyMembership(_ membership: MembershipSnapshot) {
        var updatedState = state.value
        updatedState.membership = Self.membershipState(from: membership)
        state.value = updatedState
    }

    private static func membershipState(from membership: MembershipSnapshot) -> ProfileMembershipState {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        let renewalText = membership.expirationDate.map { "Renews \(formatter.string(from: $0))" }
        return ProfileMembershipState(
            isVIP: membership.isVIP,
            diamonds: membership.diamonds,
            renewalText: renewalText
        )
    }
}

private enum HistoryLoadMode {
    case initial
    case refresh
    case more
}
