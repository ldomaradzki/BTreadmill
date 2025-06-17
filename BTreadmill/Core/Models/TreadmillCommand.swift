import Foundation

enum TreadmillCommand: CustomDebugStringConvertible {
    case start
    case speed(Double)
    case stop
    
    func toData() -> Data {
        switch self {
        case .start:
            return Data(hexString: "FB07A201010500B0FC")!
        case let .speed(value):
            // Round to nearest 0.1 to avoid floating point precision issues
            let roundedValue = (value * 10).rounded() / 10
            let speed = Int(roundedValue.clamped(to: 1.0, and: 6.0) * 10)
            
            // For debugging
            print("Setting speed: requested=\(value), rounded=\(roundedValue), hex=\(speed.toHex())")
            
            let checksum = 171 + speed
            let hexString = "FB07A10201\(speed.toHex())00\(checksum.toHex())FC"
            return Data(hexString: hexString)!
        case .stop:
            return Data(hexString: "FB07A204010000AEFC")!
        }
    }
    
    var debugDescription: String {
        switch self {
        case .start:
            "start"
        case .speed(let double):
            "speed \(double)"
        case .stop:
            "stop"
        }
    }
}