import Foundation

enum ContentNotifications {
    static let allCardsDidChange = Notification.Name("allCardsDidChange")
}

enum ContentNotificationUserInfoKey {
    static let cards = "cards"
}
