import Foundation

struct APIEnvironment {
    let serviceBaseURL: URL
    let paymentBaseURL: URL
    let gatewayClientID: String
    let gatewayAppName: String
    let distributionChannel: String

    static var current: APIEnvironment {
        // #if DEBUG
        // return APIEnvironment(
        //     serviceBaseURL: URL(string: "https://gateway-test-836083013935.asia-southeast1.run.app")!,
        //     paymentBaseURL: URL(string: "https://pay-vmddzvrudq-df.a.run.app")!,
        //     gatewayClientID: "52d3e39b-294e-4645-893e-dbf1cb692c5f",
        //     gatewayAppName: "pixnova-plus",
        //     distributionChannel: "appstore"
        // )
        // #else
        return APIEnvironment(
            serviceBaseURL: URL(string: "https://gateway-636960850285.us-west2.run.app")!,
            paymentBaseURL: URL(string: "https://pay-mhsaciltta-wl.a.run.app")!,
            gatewayClientID: "52d3e39b-294e-4645-893e-dbf1cb692c5f",
            gatewayAppName: "picvidai",
            distributionChannel: "appstore"
        )
        // #endif
    }
}
