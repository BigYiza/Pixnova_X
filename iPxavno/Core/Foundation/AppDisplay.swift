import Foundation

enum AppDisplay {
    static var name: String {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        return [displayName, bundleName, "iPxavno"]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "iPxavno"
    }

    static var proName: String {
        "\(name) PRO"
    }
}
