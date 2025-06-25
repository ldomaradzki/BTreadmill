import Foundation

struct UserProfile: Codable {
    var weight: Measurement<UnitMass>
    var strideLength: Measurement<UnitLength>
    var defaultSpeed: Double // km/h
    var simulatorMode: Bool
    var gpsTrackSettings: GPSTrackSettings
    
    init() {
        self.weight = Measurement(value: 70, unit: .kilograms)
        self.strideLength = Measurement(value: 0.7, unit: .meters)
        self.defaultSpeed = 3.0
        self.simulatorMode = false
        self.gpsTrackSettings = GPSTrackSettings()
    }
    
    // Custom decoder to handle missing fields for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields with defaults if missing
        self.weight = try container.decodeIfPresent(Measurement<UnitMass>.self, forKey: .weight) ?? Measurement(value: 70, unit: .kilograms)
        self.strideLength = try container.decodeIfPresent(Measurement<UnitLength>.self, forKey: .strideLength) ?? Measurement(value: 0.7, unit: .meters)
        self.defaultSpeed = try container.decodeIfPresent(Double.self, forKey: .defaultSpeed) ?? 3.0
        self.simulatorMode = try container.decodeIfPresent(Bool.self, forKey: .simulatorMode) ?? false
        
        // GPS settings - new field that may not exist in old configs
        self.gpsTrackSettings = try container.decodeIfPresent(GPSTrackSettings.self, forKey: .gpsTrackSettings) ?? GPSTrackSettings()
    }
    
    private enum CodingKeys: String, CodingKey {
        case weight
        case strideLength
        case defaultSpeed
        case simulatorMode
        case gpsTrackSettings
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