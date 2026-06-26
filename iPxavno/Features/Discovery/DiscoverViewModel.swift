import UIKit

enum HomeSectionKind {
    case mosaic
    case horizontal(HomeCardStyle)
    case doubleLine(HomeCardStyle)
}

enum HomeCardStyle {
    case bigRow
    case littleRow
    case videoHorizontal
    case oneBigWithFourSmall
    case doubleLineSmall
    case videoSmallVertical
    case videoBigVertical

    init(homeStyle: Int) {
        switch homeStyle {
        case 1:
            self = .bigRow
        case 2:
            self = .littleRow
        case 3:
            self = .videoHorizontal
        case 4:
            self = .oneBigWithFourSmall
        case 5:
            self = .doubleLineSmall
        case 6:
            self = .videoSmallVertical
        case 7:
            self = .videoBigVertical
        default:
            self = .bigRow
        }
    }

    var sectionKind: HomeSectionKind {
        switch self {
        case .oneBigWithFourSmall:
            return .mosaic
        case .doubleLineSmall:
            return .doubleLine(self)
        default:
            return .horizontal(self)
        }
    }

    var sectionHeight: CGFloat {
        switch self {
        case .bigRow:
            return 210
        case .littleRow:
            return 133
        case .videoHorizontal:
            return 154
        case .oneBigWithFourSmall:
            return 201
        case .doubleLineSmall:
            return 201
        case .videoSmallVertical:
            return 180
        case .videoBigVertical:
            return 226
        }
    }

    var itemSize: CGSize {
        let ratio = 157.0 / 210.0
        switch self {
        case .bigRow:
            return CGSize(width: 210 * ratio, height: 210)
        case .littleRow:
            return CGSize(width: 133 * ratio, height: 133)
        case .videoHorizontal:
            return CGSize(width: 206, height: 154)
        case .oneBigWithFourSmall:
            return CGSize(width: 201 * ratio, height: 201)
        case .doubleLineSmall:
            return CGSize(width: 96 * ratio, height: 96)
        case .videoSmallVertical:
            return CGSize(width: 135, height: 180)
        case .videoBigVertical:
            return CGSize(width: 226 * ratio, height: 226)
        }
    }
}

struct HomeMembershipState {
    let isVIP: Bool
    let diamonds: Int

    static let empty = HomeMembershipState(isVIP: false, diamonds: 0)
}

struct HomeContentSection {
    let source: ContentSection
    let title: String
    let kind: HomeSectionKind
    let templates: [CreativeTemplate]
}

struct DiscoverViewState {
    var isLoading: Bool
    var membership: HomeMembershipState
    var sections: [HomeContentSection]
    var errorMessage: String?

    static let initial = DiscoverViewState(
        isLoading: false,
        membership: .empty,
        sections: [],
        errorMessage: nil
    )
}

@MainActor
final class DiscoverViewModel {
    let state = Observable(DiscoverViewState.initial)

    let tab: HomePageTab
    var currentMembershipState: HomeMembershipState {
        membershipState(from: membershipHandler.cachedMembership)
    }

    private let contentRepository: ContentRepository
    private let membershipHandler: MembershipHandling
    private let generationRepository: GenerationRepository
    private let analytics: AnalyticsTracking
    private var accountObserver: NSObjectProtocol?

    init(
        tab: HomePageTab = .home,
        contentRepository: ContentRepository,
        membershipHandler: MembershipHandling,
        generationRepository: GenerationRepository,
        analytics: AnalyticsTracking
    ) {
        self.tab = tab
        self.contentRepository = contentRepository
        self.membershipHandler = membershipHandler
        self.generationRepository = generationRepository
        self.analytics = analytics
        observeAccountChanges()

        let cachedSections = contentRepository.cachedHomePage(tab: tab).map(makeHomeSections(from:)) ?? []
        let cachedMembership = membershipHandler.cachedMembership

        if !cachedMembership.account.userID.isEmpty {
            state.value = DiscoverViewState(
                isLoading: false,
                membership: membershipState(from: cachedMembership),
                sections: cachedSections,
                errorMessage: nil
            )
        } else if !cachedSections.isEmpty {
            state.value = DiscoverViewState(
                isLoading: false,
                membership: .empty,
                sections: cachedSections,
                errorMessage: nil
            )
        }
    }

    deinit {
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
    }

    func load() {
        state.value = DiscoverViewState(
            isLoading: true,
            membership: currentMembershipState,
            sections: state.value.sections,
            errorMessage: nil
        )

        Task {
            do {
                _ = try await membershipHandler.membershipStatus(forceRefresh: false)
                let snapshot = try await contentRepository.fetchHomePage(tab: tab)
                Task {
                    _ = try? await membershipHandler.membershipStatus(forceRefresh: true)
                }
                let resolvedMembership = currentMembershipState

                analytics.record(
                    AnalyticsEvent(
                        name: "home_loaded",
                        properties: ["tab": tab.rawValue, "sections": "\(snapshot.sections.count)"]
                    )
                )
                state.value = DiscoverViewState(
                    isLoading: false,
                    membership: resolvedMembership,
                    sections: makeHomeSections(from: snapshot),
                    errorMessage: nil
                )
            } catch {
                state.value = DiscoverViewState(
                    isLoading: false,
                    membership: currentMembershipState,
                    sections: state.value.sections,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    func didSelectTemplate(_ template: CreativeTemplate) {
        analytics.record(
            AnalyticsEvent(
                name: "template_selected",
                properties: ["template_id": "\(template.id)", "title": template.title]
            )
        )
    }

    func makeCategoryTemplateListViewModel(for section: ContentSection) -> CategoryTemplateListViewModel {
        analytics.record(
            AnalyticsEvent(
                name: "home_section_all_selected",
                properties: ["card_id": "\(section.id)", "category": "\(section.category.rawValue)", "title": section.title]
            )
        )
        return CategoryTemplateListViewModel(
            sourceSection: section,
            contentRepository: contentRepository,
            membershipHandler: membershipHandler,
            generationRepository: generationRepository,
            analytics: analytics
        )
    }

    func makeFilterGenerationViewController(
        for template: CreativeTemplate,
        sourceSection: ContentSection
    ) -> FilterGenerationViewController {
        FilterGenerationViewController(
            initialTemplate: template,
            sourceSection: sourceSection,
            contentRepository: contentRepository,
            membershipHandler: membershipHandler,
            generationRepository: generationRepository,
            analytics: analytics
        )
    }

    private func observeAccountChanges() {
        accountObserver = membershipHandler.observeMembershipChanges { [weak self] membership in
            guard let self else { return }
            Task { @MainActor in
                self.state.value = DiscoverViewState(
                    isLoading: self.state.value.isLoading,
                    membership: self.membershipState(from: membership),
                    sections: self.state.value.sections,
                    errorMessage: self.state.value.errorMessage
                )
            }
        }
    }

    private func membershipState(from membership: MembershipSnapshot) -> HomeMembershipState {
        HomeMembershipState(isVIP: membership.isVIP, diamonds: membership.diamonds)
    }

    private func makeHomeSections(from snapshot: DiscoverySnapshot) -> [HomeContentSection] {
        snapshot.sections
            .filter { !$0.templates.isEmpty }
            .map { section in
                let style = HomeCardStyle(homeStyle: section.homeStyle)
                return HomeContentSection(
                    source: section,
                    title: section.title,
                    kind: style.sectionKind,
                    templates: section.templates
                )
            }
    }
}
