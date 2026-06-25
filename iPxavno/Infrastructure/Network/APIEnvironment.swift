import Foundation

struct APIEnvironment {
    let serviceBaseURL: URL
    let paymentBaseURL: URL

    static var current: APIEnvironment {
        #if DEBUG
        return APIEnvironment(
            serviceBaseURL: URL(string: "https://api.pixnova.app")!,
            paymentBaseURL: URL(string: "https://pay-vmddzvrudq-df.a.run.app")!
        )
        #else
        return APIEnvironment(
            serviceBaseURL: URL(string: "https://api.pixnova.app")!,
            paymentBaseURL: URL(string: "https://pay-mhsaciltta-wl.a.run.app")!
        )
        #endif
    }
}
