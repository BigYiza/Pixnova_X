import Foundation

enum MembershipCloseButtonStrategy: String, Codable {
    case normal
    case delayed3Seconds
    case hidden
}

enum MembershipFreeBenefitPresentation: Equatable {
    case styleOne
    case styleTwo
    case paywall
}

enum MembershipBlockReason: Equatable {
    case membershipRequired
    case cutoutRequiresMembership
    case insufficientDiamonds(required: Int, available: Int)
}

enum MembershipAccessDecision: Equatable {
    case allowed
    case blocked(MembershipBlockReason)

    var isAllowed: Bool {
        if case .allowed = self {
            return true
        }
        return false
    }
}

struct MembershipProductCatalog: Equatable {
    let primaryProductIDs: [String]
    let additionalProductIDs: [String]

    var allProductIDs: [String] {
        var seen = Set<String>()
        return (primaryProductIDs + additionalProductIDs).filter { seen.insert($0).inserted }
    }

    static var configured: MembershipProductCatalog {
        let primary = Bundle.main.stringArray(forInfoDictionaryKey: "MembershipPrimaryProductIDs")
        let additional = Bundle.main.stringArray(forInfoDictionaryKey: "MembershipAdditionalProductIDs")

        if !primary.isEmpty || !additional.isEmpty {
            return MembershipProductCatalog(primaryProductIDs: primary, additionalProductIDs: additional)
        }

        let fallbackPrefix = Bundle.main.bundleIdentifier ?? "app"
        return MembershipProductCatalog(
            primaryProductIDs: [
                "\(fallbackPrefix).pro.weekly",
                "\(fallbackPrefix).pro.yearly"
            ],
            additionalProductIDs: []
        )
    }
}

struct DiamondProductCatalog: Equatable {
    let consumableProductIDs: [String]

    var allProductIDs: [String] {
        var seen = Set<String>()
        return consumableProductIDs.filter { seen.insert($0).inserted }
    }

    static var configured: DiamondProductCatalog {
        let productIDs = Bundle.main.stringArray(forInfoDictionaryKey: "DiamondConsumableProductIDs")

        if !productIDs.isEmpty {
            return DiamondProductCatalog(consumableProductIDs: productIDs)
        }

        let fallbackPrefix = Bundle.main.bundleIdentifier ?? "app"
        return DiamondProductCatalog(
            consumableProductIDs: [
                "\(fallbackPrefix).diamonds.small",
                "\(fallbackPrefix).diamonds.medium",
                "\(fallbackPrefix).diamonds.large"
            ]
        )
    }
}

struct MembershipSnapshot {
    let account: AccountSnapshot
    let isVIP: Bool
    let expirationTime: TimeInterval?
    let videoTimes: Int
    let giveAIVideosTimes: Int
    let freeVIPTimes: Int
    let diamonds: Int
    let closeButtonStrategy: MembershipCloseButtonStrategy
    let paywallGroup: String?
    let productCatalog: MembershipProductCatalog

    static let empty = MembershipSnapshot(account: .empty)

    init(account: AccountSnapshot) {
        self.account = account
        isVIP = account.isVIP
        expirationTime = account.vipExpirationTime
        videoTimes = account.videoTimes
        giveAIVideosTimes = account.giveAIVideosTimes
        freeVIPTimes = account.freeVIPTimes
        diamonds = account.diamonds
        closeButtonStrategy = MembershipSnapshot.closeButtonStrategy(from: account)
        paywallGroup = account.userGroupMap[AccountUserGroupPosition.membershipPaywall]?.stringValue
        productCatalog = .configured
    }

    var expirationDate: Date? {
        guard let expirationTime, expirationTime > 0 else { return nil }
        return Date(timeIntervalSince1970: expirationTime)
    }

    var freeBenefitPresentation: MembershipFreeBenefitPresentation {
        if freeVIPTimes > 1 {
            return .styleOne
        }
        if freeVIPTimes == 1 {
            return .styleTwo
        }
        return .paywall
    }

    var shouldApplyWatermark: Bool {
        !isVIP
    }

    var canSkipWaiting: Bool {
        isVIP
    }

    func access(to template: CreativeTemplate) -> MembershipAccessDecision {
        if template.kind == .cutout {
            return accessToCutout()
        }
        if template.requiresMembership && !isVIP {
            return .blocked(.membershipRequired)
        }
        return .allowed
    }

    func accessToCutout() -> MembershipAccessDecision {
        isVIP ? .allowed : .blocked(.cutoutRequiresMembership)
    }

    func accessToDiamonds(required: Int) -> MembershipAccessDecision {
        diamonds >= required ? .allowed : .blocked(.insufficientDiamonds(required: required, available: diamonds))
    }

    private static func closeButtonStrategy(from account: AccountSnapshot) -> MembershipCloseButtonStrategy {
        let value = account.userGroupMap[AccountUserGroupPosition.membershipCloseButton]?.stringValue

        switch value {
        case "MemberShipCloseBtn_Close_3s":
            return .delayed3Seconds
        case "MemberShipCloseBtn_Close_None":
            return .hidden
        default:
            return .normal
        }
    }

}

private extension Bundle {
    func stringArray(forInfoDictionaryKey key: String) -> [String] {
        object(forInfoDictionaryKey: key) as? [String] ?? []
    }
}

protocol MembershipHandling: AnyObject {
    var cachedMembership: MembershipSnapshot { get }

    @discardableResult
    func refreshStatus() async throws -> MembershipSnapshot

    @discardableResult
    func maintainStatusAfterSessionPrepared() async throws -> MembershipSnapshot

    @discardableResult
    func membershipStatus(forceRefresh: Bool) async throws -> MembershipSnapshot

    func access(to template: CreativeTemplate) -> MembershipAccessDecision
    func accessToCutout() -> MembershipAccessDecision
    func accessToDiamonds(required: Int) -> MembershipAccessDecision
    func shouldApplyWatermark() -> Bool
    func canSkipWaiting() -> Bool
    func freeBenefitPresentation() -> MembershipFreeBenefitPresentation
    func observeMembershipChanges(_ handler: @escaping (MembershipSnapshot) -> Void) -> NSObjectProtocol
}
