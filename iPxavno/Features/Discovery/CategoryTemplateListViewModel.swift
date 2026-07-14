import Foundation

struct CategoryTemplateListState {
    var isLoading: Bool
    var title: String
    var cards: [ContentSection]
    var selectedIndex: Int
    var errorMessage: String?

    static func initial(sourceSection: ContentSection) -> CategoryTemplateListState {
        CategoryTemplateListState(
            isLoading: false,
            title: sourceSection.category.displayTitle(fallback: sourceSection.title),
            cards: [sourceSection],
            selectedIndex: 0,
            errorMessage: nil
        )
    }
}

@MainActor
final class CategoryTemplateListViewModel {
    let state: Observable<CategoryTemplateListState>

    private let sourceSection: ContentSection
    private let contentRepository: ContentRepository
    private let membershipHandler: MembershipHandling
    private let generationRepository: GenerationRepository
    private let generationWorkflowRunner: GenerationWorkflowRunning
    private let analytics: AnalyticsTracking
    private var contentObserver: NSObjectProtocol?

    init(
        sourceSection: ContentSection,
        contentRepository: ContentRepository,
        membershipHandler: MembershipHandling,
        generationRepository: GenerationRepository,
        generationWorkflowRunner: GenerationWorkflowRunning,
        analytics: AnalyticsTracking
    ) {
        self.sourceSection = sourceSection
        self.contentRepository = contentRepository
        self.membershipHandler = membershipHandler
        self.generationRepository = generationRepository
        self.generationWorkflowRunner = generationWorkflowRunner
        self.analytics = analytics
        state = Observable(CategoryTemplateListState.initial(sourceSection: sourceSection))
        observeContentCatalogChanges()
    }

    deinit {
        if let contentObserver {
            NotificationCenter.default.removeObserver(contentObserver)
        }
    }

    func load() {
        applyAllCards(contentRepository.cachedAllCards, recordsEvent: true)
    }

    func selectCard(at index: Int) {
        guard state.value.cards.indices.contains(index), state.value.selectedIndex != index else { return }
        let selectedCard = state.value.cards[index]
        analytics.record(
            AnalyticsEvent(
                name: "category_template_card_selected",
                properties: ["card_id": "\(selectedCard.id)", "title": selectedCard.title]
            )
        )
        state.value = CategoryTemplateListState(
            isLoading: state.value.isLoading,
            title: state.value.title,
            cards: state.value.cards,
            selectedIndex: index,
            errorMessage: nil
        )
    }

    func makeFilterGenerationViewController(for template: CreativeTemplate) -> FilterGenerationViewController {
        FilterGenerationViewController(
            initialTemplate: template,
            sourceSection: sourceSection,
            contentRepository: contentRepository,
            membershipHandler: membershipHandler,
            generationRepository: generationRepository,
            generationWorkflowRunner: generationWorkflowRunner,
            analytics: analytics
        )
    }

    func makeTemplateVideoGenerationViewController(for template: CreativeTemplate) -> TemplateVideoGenerationViewController {
        TemplateVideoGenerationViewController(
            template: template,
            membershipHandler: membershipHandler,
            generationRepository: generationRepository,
            generationWorkflowRunner: generationWorkflowRunner,
            analytics: analytics
        )
    }

    func didSelectTemplate(_ template: CreativeTemplate) {
        let membershipAccess = membershipHandler.access(to: template)
        analytics.record(
            AnalyticsEvent(
                name: "category_template_selected",
                properties: [
                    "template_id": "\(template.id)",
                    "title": template.title,
                    "membership_access": membershipAccess.isAllowed ? "allowed" : "blocked"
                ]
            )
        )
    }

    private func filteredCards(from allCards: [ContentSection]) -> [ContentSection] {
        var cards = allCards
            .filter { $0.category == sourceSection.category && !$0.templates.isEmpty }

        if !cards.contains(where: { $0.id == sourceSection.id }) {
            cards.insert(sourceSection, at: 0)
        }

        return cards
    }

    private func applyAllCards(_ allCards: [ContentSection], recordsEvent: Bool) {
        let resolvedCards = filteredCards(from: allCards)
        let currentCardID = state.value.cards.indices.contains(state.value.selectedIndex)
            ? state.value.cards[state.value.selectedIndex].id
            : sourceSection.id
        let selectedIndex = resolvedCards.firstIndex { $0.id == currentCardID }
            ?? resolvedCards.firstIndex { $0.id == sourceSection.id }
            ?? 0

        if recordsEvent {
            analytics.record(
                AnalyticsEvent(
                    name: "category_template_list_loaded",
                    properties: [
                        "category": "\(sourceSection.category.rawValue)",
                        "cards": "\(resolvedCards.count)",
                        "source": allCards.isEmpty ? "source_card" : "cached_all_data"
                    ]
                )
            )
        }

        state.value = CategoryTemplateListState(
            isLoading: false,
            title: sourceSection.category.displayTitle(fallback: sourceSection.title),
            cards: resolvedCards,
            selectedIndex: selectedIndex,
            errorMessage: nil
        )
    }

    private func observeContentCatalogChanges() {
        contentObserver = NotificationCenter.default.addObserver(
            forName: ContentNotifications.allCardsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let cards = notification.userInfo?[ContentNotificationUserInfoKey.cards] as? [ContentSection] else {
                return
            }

            Task { @MainActor in
                self.applyAllCards(cards, recordsEvent: false)
            }
        }
    }
}

private extension CreativeKind {
    func displayTitle(fallback: String) -> String {
        switch self {
        case .filter:
            return "Filters"
        case .hair:
            return "Hairstyle"
        case .cutout:
            return "Cutout"
        case .photo, .textToImage, .imageToImage:
            return "Photo"
        case .avatar:
            return "Avatar"
        case .video, .textToVideo, .imageToVideo, .multiImageToVideo, .videoEnhance:
            return "Video"
        case .outfit:
            return "Outfit"
        case .baby:
            return "Baby"
        case .makeup:
            return "Makeup"
        case .collection, .unknown:
            return fallback
        }
    }
}
