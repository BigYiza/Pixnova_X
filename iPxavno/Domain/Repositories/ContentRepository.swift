import Foundation

enum HomePageTab: String {
    case home = "88"
    case video = "1"
    case filters = "2"
    case photo = "3"

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .video:
            return "Video"
        case .filters:
            return "Filters"
        case .photo:
            return "Photo"
        }
    }
}

protocol ContentRepository {
    var cachedAllCards: [ContentSection] { get }
    func cachedHomePage(tab: HomePageTab) -> DiscoverySnapshot?
    func fetchHomePage(tab: HomePageTab) async throws -> DiscoverySnapshot
    func refreshAllCards() async throws -> [ContentSection]
}
