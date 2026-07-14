import UIKit

protocol RequestHeaderProviding {
    func headers(requiresAuthentication: Bool) -> [String: String]
}

final class DefaultRequestHeaderProvider: RequestHeaderProviding {
    private let sessionProvider: SessionProviding
    private let deviceIdentifier: DeviceIdentifying
    private let environment: APIEnvironment

    init(
        sessionProvider: SessionProviding,
        deviceIdentifier: DeviceIdentifying,
        environment: APIEnvironment
    ) {
        self.sessionProvider = sessionProvider
        self.deviceIdentifier = deviceIdentifier
        self.environment = environment
    }

    func headers(requiresAuthentication: Bool) -> [String: String] {
        let timezoneMinutes = -(TimeZone.current.secondsFromGMT() / 60)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let language = Locale.preferredLanguages.first ?? "en"
        let userAgent = [
            environment.gatewayAppName,
            version,
            "iOS",
            UIDevice.current.systemVersion,
            UIDevice.current.model,
            environment.distributionChannel,
            "\(timezoneMinutes)",
            language
        ].map(sanitizeUserAgentSegment).joined(separator: ";")

        var headers = [
            "X-Client-Id": environment.gatewayClientID,
            "timezone": "\(timezoneMinutes)",
            "User-Agent": userAgent,
            "Device-Id": deviceIdentifier.deviceID,
            "Content-Type": "application/json"
        ]

        if requiresAuthentication, let credential = sessionProvider.currentCredential {
            headers["Authorization"] = "Bearer \(credential.accessToken)"
            headers["tokenId"] = credential.accessToken
            headers["uid"] = credential.userID
        }

        return headers
    }

    private func sanitizeUserAgentSegment(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed
            .replacingOccurrences(of: ";", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return sanitized.isEmpty ? "unknown" : sanitized
    }
}
