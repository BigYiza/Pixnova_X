import Foundation

protocol DeviceIdentifying {
    var deviceID: String { get }

    @discardableResult
    func regenerateDeviceID() -> String
}
