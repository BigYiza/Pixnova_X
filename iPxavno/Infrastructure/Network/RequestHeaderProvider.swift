import Darwin
import UIKit

protocol RequestHeaderProviding {
    func headers(
        forPath path: String,
        requiresAuthentication: Bool,
        baseURL: URL
    ) -> [String: String]
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

    func headers(
        forPath path: String,
        requiresAuthentication: Bool,
        baseURL: URL
    ) -> [String: String] {
        if baseURL == environment.paymentBaseURL {
            return paymentHeaders(requiresAuthentication: requiresAuthentication)
        }

        return gatewayHeaders(requiresAuthentication: requiresAuthentication)
    }

    private func gatewayHeaders(requiresAuthentication: Bool) -> [String: String] {
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

        addAuthenticationHeaders(to: &headers, requiresAuthentication: requiresAuthentication)
        return headers
    }

    private func paymentHeaders(requiresAuthentication: Bool) -> [String: String] {
        let timezoneMinutes = TimeZone.current.secondsFromGMT() / 60
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let languageCode = shortLanguageCode()
        let userAgent = [
            "pixnova",
            version,
            "iOS",
            UIDevice.current.systemVersion,
            deviceCode,
            "Apple Store",
            "\(timezoneMinutes)",
            languageCode
        ].map(sanitizeUserAgentSegment).joined(separator: ";")

        var headers = [
            "timezone": "\(timezoneMinutes)",
            "User-Agent": userAgent,
            "device-id": deviceIdentifier.deviceID,
            "Content-Type": "application/json"
        ]

        addAuthenticationHeaders(to: &headers, requiresAuthentication: requiresAuthentication)
        return headers
    }

    private func addAuthenticationHeaders(to headers: inout [String: String], requiresAuthentication: Bool) {
        if requiresAuthentication, let credential = sessionProvider.currentCredential {
            headers["Authorization"] = "Bearer \(credential.accessToken)"
            headers["tokenId"] = credential.accessToken
            headers["uid"] = credential.userID
        }
    }

    private var deviceCode: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let capacity = MemoryLayout.size(ofValue: systemInfo.machine)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
                String(cString: $0)
            }
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    private func shortLanguageCode() -> String {
        let identifier = Locale.preferredLanguages.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        let separators = CharacterSet(charactersIn: "-_")
        return identifier
            .components(separatedBy: separators)
            .first?
            .lowercased()
            .nilIfEmpty ?? "en"
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
