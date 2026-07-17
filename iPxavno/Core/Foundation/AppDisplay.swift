import Foundation

enum AppDisplay {
    static var name: String {
        return "Pixnova"
//        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
//        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
//        return [displayName, bundleName, "Pixnova"]
//            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
//            .first { !$0.isEmpty } ?? "Pixnova"
    }

    static var proName: String {
        "\(name) PRO"
    }
}
