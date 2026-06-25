import UIKit

protocol RequestHeaderProviding {
    func headers(requiresAuthentication: Bool) -> [String: String]
}

final class DefaultRequestHeaderProvider: RequestHeaderProviding {
    private let sessionProvider: SessionProviding
    private let deviceIdentifier: DeviceIdentifying

    init(sessionProvider: SessionProviding, deviceIdentifier: DeviceIdentifying) {
        self.sessionProvider = sessionProvider
        self.deviceIdentifier = deviceIdentifier
    }

    func headers(requiresAuthentication: Bool) -> [String: String] {
        let timezoneMinutes = TimeZone.current.secondsFromGMT() / 60
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let language = Locale.preferredLanguages.first ?? "en"
        let userAgent = [
            "pixnova",
            version,
            "iOS",
            UIDevice.current.systemVersion,
            UIDevice.current.model,
            "Apple Store",
            "\(timezoneMinutes)",
            language
        ].joined(separator: ";")

        var headers = [
            "timezone": "\(timezoneMinutes)",
            "User-Agent": userAgent,
            "device-id": deviceIdentifier.deviceID,
            "Content-Type": "application/json"
        ]

        if requiresAuthentication, let credential = sessionProvider.currentCredential {
            headers["Authorization"] = "Bearer \(credential.accessToken)"
            headers["tokenId"] = credential.accessToken
            headers["uid"] = credential.userID
        }

        return headers
    }
}
