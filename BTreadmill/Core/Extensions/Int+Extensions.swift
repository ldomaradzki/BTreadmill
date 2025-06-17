import Foundation

extension Int {
    func toHex() -> String {
        return String(format: "%02X", self)
    }
}