import Foundation

struct CreationHubViewState {
    var isLoading: Bool
    var sections: [ContentSection]
    var errorMessage: String?

    static let initial = CreationHubViewState(isLoading: false, sections: [], errorMessage: nil)
}

@MainActor
final class CreationHubViewModel {
    let state = Observable(CreationHubViewState.initial)

    private let mode: CreationHubMode
    private let contentRepository: ContentRepository
    private let accountRepository: AccountRepository
    private let analytics: AnalyticsTracking

    init(
        mode: CreationHubMode,
        contentRepository: ContentRepository,
        accountRepository: AccountRepository,
        analytics: AnalyticsTracking
    ) {
        self.mode = mode
        self.contentRepository = contentRepository
        self.accountRepository = accountRepository
        self.analytics = analytics
    }

    func load() {
        state.value = CreationHubViewState(isLoading: true, sections: state.value.sections, errorMessage: nil)

        Task {
            do {
                _ = try await accountRepository.refreshSessionIfNeeded(force: false)
                let snapshot = try await contentRepository.fetchHomePage(tab: mode.homePageTab)
                analytics.record(
                    AnalyticsEvent(
                        name: "home_tab_loaded",
                        properties: ["tab": mode.title, "sections": "\(snapshot.sections.count)"]
                    )
                )
                state.value = CreationHubViewState(
                    isLoading: false,
                    sections: normalizedSections(from: snapshot),
                    errorMessage: nil
                )
            } catch {
                state.value = CreationHubViewState(
                    isLoading: false,
                    sections: [],
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    func didSelectTemplate(_ template: CreativeTemplate) {
        analytics.record(
            AnalyticsEvent(
                name: "home_tab_template_selected",
                properties: ["tab": mode.title, "template_id": "\(template.id)", "title": template.title]
            )
        )
    }

    private func normalizedSections(from snapshot: DiscoverySnapshot) -> [ContentSection] {
        return snapshot.sections
    }
}

extension CreationHubMode {
    var homePageTab: HomePageTab {
        switch self {
        case .video:
            return .video
        case .filters:
            return .filters
        case .photo:
            return .photo
        }
    }
}
