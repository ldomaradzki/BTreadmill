import Foundation

struct UserProfile: Codable {
    var weight: Measurement<UnitMass>
    var strideLength: Measurement<UnitLength>
    var defaultSpeed: Double // km/h
    var simulatorMode: Bool
    
    init() {
        self.weight = Measurement(value: 70, unit: .kilograms)
        self.strideLength = Measurement(value: 0.7, unit: .meters)
        self.defaultSpeed = 3.0
        self.simulatorMode = false
    }
}

enum MenuBarDisplayOption: String, CaseIterable, Codable {
    case none = "none"
    case speed = "speed"
    case distance = "distance"
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .speed:
            return "Show current speed"
        case .distance:
            return "Show distance"
        }
    }
}