import Foundation

struct UserProfile: Codable {
    var weight: Measurement<UnitMass>
    var strideLength: Measurement<UnitLength>
    var preferredUnits: UnitSystem
    var autoConnectEnabled: Bool
    var defaultSpeed: Double // km/h
    var maxSpeed: Double // km/h safety limit
    
    init() {
        self.weight = Measurement(value: 70, unit: .kilograms)
        self.strideLength = Measurement(value: 0.7, unit: .meters)
        self.preferredUnits = .metric
        self.autoConnectEnabled = true
        self.defaultSpeed = 3.0
        self.maxSpeed = 6.0
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