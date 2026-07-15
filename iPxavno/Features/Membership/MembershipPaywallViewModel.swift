import Foundation

struct MembershipPaywallState {
    var plans: [MembershipPurchasePlan]
    var selectedPlanID: String?
    var isLoading: Bool
    var errorMessage: String?
    var completedMessage: String?

    static let empty = MembershipPaywallState(
        plans: [],
        selectedPlanID: nil,
        isLoading: false,
        errorMessage: nil,
        completedMessage: nil
    )
}

@MainActor
final class MembershipPaywallViewModel {
    let state = Observable(MembershipPaywallState.empty)

    private let membershipHandler: MembershipHandling
    private let purchaseHandler: MembershipPurchaseHandling
    private let analytics: AnalyticsTracking

    init(
        membershipHandler: MembershipHandling,
        purchaseHandler: MembershipPurchaseHandling,
        analytics: AnalyticsTracking
    ) {
        self.membershipHandler = membershipHandler
        self.purchaseHandler = purchaseHandler
        self.analytics = analytics
    }

    var selectedPlan: MembershipPurchasePlan? {
        guard let selectedPlanID = state.value.selectedPlanID else { return nil }
        return state.value.plans.first { $0.id == selectedPlanID }
    }

    func load() {
        guard !state.value.isLoading else { return }

        state.value.isLoading = true
        state.value.errorMessage = nil

        Task {
            do {
                let catalog = membershipHandler.cachedMembership.productCatalog
                let plans = try await purchaseHandler.loadPlans(catalog: catalog)
                state.value = MembershipPaywallState(
                    plans: plans,
                    selectedPlanID: preferredSelectedPlanID(from: plans),
                    isLoading: false,
                    errorMessage: nil,
                    completedMessage: nil
                )
            } catch {
                let fallbackPlans = fallbackPlans()
                state.value = MembershipPaywallState(
                    plans: fallbackPlans,
                    selectedPlanID: preferredSelectedPlanID(from: fallbackPlans),
                    isLoading: false,
                    errorMessage: error.localizedDescription,
                    completedMessage: nil
                )
            }
        }
    }

    func select(planID: String) {
        guard state.value.plans.contains(where: { $0.id == planID }) else { return }
        state.value.selectedPlanID = planID
    }

    func purchaseSelectedPlan() {
        guard let selectedPlan else {
            state.value.errorMessage = MembershipPurchaseError.productUnavailable.localizedDescription
            return
        }

        state.value.isLoading = true
        state.value.errorMessage = nil
        analytics.record(
            AnalyticsEvent(
                name: "membership_paywall_purchase_tapped",
                properties: ["product_id": selectedPlan.id]
            )
        )

        Task {
            do {
                try await purchaseHandler.purchase(planID: selectedPlan.id)
                state.value.isLoading = false
                state.value.completedMessage = "You're all set. PRO is active."
            } catch MembershipPurchaseError.purchaseCancelled {
                state.value.isLoading = false
            } catch {
                state.value.isLoading = false
                state.value.errorMessage = error.localizedDescription
            }
        }
    }

    func restorePurchases() {
        guard !state.value.isLoading else { return }

        state.value.isLoading = true
        state.value.errorMessage = nil
        analytics.record(AnalyticsEvent(name: "membership_paywall_restore_tapped", properties: [:]))

        Task {
            do {
                try await purchaseHandler.restorePurchases()
                state.value.isLoading = false
                state.value.completedMessage = "Restore successful. PRO is active."
            } catch {
                state.value.isLoading = false
                state.value.errorMessage = error.localizedDescription
            }
        }
    }

    private func preferredSelectedPlanID(from plans: [MembershipPurchasePlan]) -> String? {
        plans.first(where: { $0.kind == .yearly })?.id ?? plans.first?.id
    }

    private func fallbackPlans() -> [MembershipPurchasePlan] {
        let catalog = membershipHandler.cachedMembership.productCatalog
        let weeklyID = catalog.allProductIDs.first { $0.lowercased().contains("week") }
            ?? catalog.allProductIDs.first
            ?? "membership.weekly"
        let yearlyID = catalog.allProductIDs.first { $0.lowercased().contains("year") || $0.lowercased().contains("annual") }
            ?? catalog.allProductIDs.dropFirst().first
            ?? "membership.yearly"

        return [
            MembershipPurchasePlan(
                id: weeklyID,
                kind: .weekly,
                title: "Weekly",
                price: "$4.99",
                subtitle: "+30 diamonds / week",
                callToAction: "Continue",
                renewalText: "auto-renews weekly",
                hasIntroOffer: false,
                isBestValue: false
            ),
            MembershipPurchasePlan(
                id: yearlyID,
                kind: .yearly,
                title: "Yearly",
                price: "$39.99",
                subtitle: "up to 1840 diamonds/year",
                callToAction: "Start 3-Day Free Trial",
                renewalText: "then $39.99/year",
                hasIntroOffer: true,
                isBestValue: true
            )
        ]
    }
}
