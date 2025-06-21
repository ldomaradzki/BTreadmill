import Foundation

struct UserProfile: Codable {
    var weight: Measurement<UnitMass>
    var strideLength: Measurement<UnitLength>
    var preferredUnits: UnitSystem
    var defaultSpeed: Double // km/h
    var simulatorMode: Bool
    
    init() {
        self.weight = Measurement(value: 70, unit: .kilograms)
        self.strideLength = Measurement(value: 0.7, unit: .meters)
        self.preferredUnits = .metric
        self.defaultSpeed = 3.0
        self.simulatorMode = false
    }
}

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"
    
    var displayName: String {
        switch self {
        case .metric:
            return "Metric (km/h, kg, km)"
        case .imperial:
            return "Imperial (mph, lb, mi)"
        }
    }
    
    var speedUnit: UnitSpeed {
        switch self {
        case .metric:
            return .kilometersPerHour
        case .imperial:
            return .milesPerHour
        }
    }
    
    var distanceUnit: UnitLength {
        switch self {
        case .metric:
            return .kilometers
        case .imperial:
            return .miles
        }
    }
    
    var massUnit: UnitMass {
        switch self {
        case .metric:
            return .kilograms
        case .imperial:
            return .pounds
        }
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