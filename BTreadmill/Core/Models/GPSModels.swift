import Foundation
import CoreLocation

struct GPSCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    
    init(latitude: Double, longitude: Double, altitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
    
    var clLocation: CLLocation {
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude ?? 0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 5.0,
            timestamp: Date()
        )
    }
    
    func distance(to other: GPSCoordinate) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
    
    func bearing(to other: GPSCoordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    func coordinate(at distance: Double, bearing: Double) -> GPSCoordinate {
        let earthRadius = 6371000.0 // Earth's radius in meters
        let bearingRad = bearing * .pi / 180
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                       cos(lat1) * sin(distance / earthRadius) * cos(bearingRad))
        
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / earthRadius) * cos(lat1),
                               cos(distance / earthRadius) - sin(lat1) * sin(lat2))
        
        return GPSCoordinate(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi,
            altitude: altitude
        )
    }
}

extension Double {
    /// Converts degrees to semicircles (FIT file format)
    var semicircles: Int32 {
        return Int32(self * (2147483648.0 / 180.0))
    }
}

enum GPSTrackPattern: String, CaseIterable, Codable {
    case straightLine = "straight_line"
    case figure8 = "figure_8"
    case loop = "loop"
    case swirl = "swirl"
    case zigzag = "zigzag"
    case oval = "oval"
    
    var displayName: String {
        switch self {
        case .straightLine:
            return "Straight Line"
        case .figure8:
            return "Figure 8"
        case .loop:
            return "Loop"
        case .swirl:
            return "Swirl"
        case .zigzag:
            return "Zigzag"
        case .oval:
            return "Oval"
        }
    }
    
    var description: String {
        switch self {
        case .straightLine:
            return "Simple back-and-forth straight line pattern"
        case .figure8:
            return "Classic figure-8 or infinity symbol pattern"
        case .loop:
            return "Circular loop pattern"
        case .swirl:
            return "Spiral inward/outward pattern"
        case .zigzag:
            return "Sharp zigzag pattern with directional changes"
        case .oval:
            return "Elliptical oval track pattern"
        }
    }
    
    var estimatedTrackSize: Double {
        switch self {
        case .straightLine:
            return 200.0 // 200m straight line
        case .figure8:
            return 400.0 // ~400m figure-8
        case .loop:
            return 314.0 // ~314m circle (100m diameter)
        case .swirl:
            return 500.0 // ~500m spiral
        case .zigzag:
            return 300.0 // ~300m zigzag
        case .oval:
            return 400.0 // ~400m oval
        }
    }
}

struct GPSTrackSettings: Codable {
    var enabled: Bool
    var startingCoordinate: GPSCoordinate
    var preferredPattern: GPSTrackPattern
    var trackScale: Double // Scale factor for pattern size (0.5 = half size, 2.0 = double size)
    
    init() {
        self.enabled = false
        // Default to a generic location (San Francisco)
        self.startingCoordinate = GPSCoordinate(latitude: 37.7749, longitude: -122.4194)
        self.preferredPattern = .loop
        self.trackScale = 1.0
    }
}