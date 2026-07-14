import Foundation

enum MembershipPlanKind: Equatable {
    case weekly
    case yearly
    case other
}

struct MembershipPurchasePlan: Equatable {
    let id: String
    let kind: MembershipPlanKind
    let title: String
    let price: String
    let subtitle: String
    let callToAction: String
    let renewalText: String
    let hasIntroOffer: Bool
    let isBestValue: Bool
}

enum MembershipPurchaseError: Error, LocalizedError {
    case productUnavailable
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case receiptUnavailable
    case restoreUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This subscription is not available right now."
        case .purchaseCancelled:
            return "Purchase cancelled."
        case .purchasePending:
            return "Purchase is pending approval."
        case .verificationFailed:
            return "Purchase could not be verified."
        case .receiptUnavailable:
            return "Purchase receipt is unavailable."
        case .restoreUnavailable:
            return "No purchase was found to restore."
        }
    }
}

protocol MembershipPurchaseHandling: AnyObject {
    func loadPlans(catalog: MembershipProductCatalog) async throws -> [MembershipPurchasePlan]
    func purchase(planID: String) async throws
    func restorePurchases() async throws
}

struct DiamondPurchasePack: Equatable {
    let id: String
    let title: String
    let price: String
    let subtitle: String
    let diamondAmount: Int?
    let isPurchasable: Bool
}

enum DiamondPurchaseError: Error, LocalizedError {
    case productUnavailable
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case receiptUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "Diamond products are not available right now."
        case .purchaseCancelled:
            return "Purchase cancelled."
        case .purchasePending:
            return "Purchase is pending approval."
        case .verificationFailed:
            return "Purchase could not be verified."
        case .receiptUnavailable:
            return "Purchase receipt is unavailable."
        }
    }
}

protocol DiamondPurchaseHandling: AnyObject {
    func loadPacks(catalog: DiamondProductCatalog) async throws -> [DiamondPurchasePack]
    func purchase(packID: String) async throws
}
