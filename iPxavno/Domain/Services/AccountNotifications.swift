import Foundation

enum AccountNotifications {
    static let accountDidChange = Notification.Name("accountDidChange")
    static let membershipStateDidChange = Notification.Name("membershipStateDidChange")
    static let invitationInfoDidUpdateResetFlag = Notification.Name("invitationInfoDidUpdateResetFlag")
    static let invitationInfoDidUpdateNeedShowDialog = Notification.Name("invitationInfoDidUpdateNeedShowDialog")
}

enum AccountNotificationUserInfoKey {
    static let account = "account"
}
