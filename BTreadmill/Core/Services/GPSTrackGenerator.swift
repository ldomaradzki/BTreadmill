import Foundation
import OSLog

class GPSTrackGenerator {
    private let logger = Logger(subsystem: "BTreadmill", category: "gps")
    
    private let settings: GPSTrackSettings
    private let pattern: GPSTrackPattern
    private let startCoordinate: GPSCoordinate
    private let trackScale: Double
    
    private var totalDistance: Double = 0
    private var currentPatternPosition: Double = 0
    private var isReversed: Bool = false
    
    init(settings: GPSTrackSettings) {
        self.settings = settings
        self.pattern = settings.preferredPattern
        self.startCoordinate = settings.startingCoordinate
        self.trackScale = settings.trackScale
        
        logger.info("GPS Track Generator initialized with pattern: \(self.pattern.displayName), scale: \(self.trackScale)")
    }
    
    func generateCoordinate(for distance: Double, speed: Double, timestamp: Date) -> GPSCoordinate {
        totalDistance = distance * 1000 // Convert km to meters
        
        switch pattern {
        case .straightLine:
            return generateStraightLineCoordinate()
        case .figure8:
            return generateFigure8Coordinate()
        case .loop:
            return generateLoopCoordinate()
        case .swirl:
            return generateSwirlCoordinate()
        case .zigzag:
            return generateZigzagCoordinate()
        case .oval:
            return generateOvalCoordinate()
        }
    }
    
    func reset() {
        totalDistance = 0
        currentPatternPosition = 0
        isReversed = false
        logger.debug("GPS Track Generator reset")
    }
    
    // MARK: - Pattern Generation Methods
    
    private func generateStraightLineCoordinate() -> GPSCoordinate {
        let trackLength = 200.0 * trackScale
        let progress = totalDistance.truncatingRemainder(dividingBy: trackLength * 2)
        
        let distance: Double
        let bearing: Double = 0 // North
        
        if progress <= trackLength {
            // Going north
            distance = progress
        } else {
            // Coming back south
            distance = trackLength - (progress - trackLength)
        }
        
        return startCoordinate.coordinate(at: distance, bearing: bearing)
    }
    
    private func generateFigure8Coordinate() -> GPSCoordinate {
        let radius = 100.0 * trackScale
        let circumference = 2 * .pi * radius
        let totalTrack = circumference * 2 // Two loops for figure-8
        
        let progress = totalDistance.truncatingRemainder(dividingBy: totalTrack)
        let angle: Double
        let centerOffset: Double
        
        if progress <= circumference {
            // First loop (bottom)
            angle = (progress / radius) * 180 / .pi
            centerOffset = -radius / 2
        } else {
            // Second loop (top)
            let secondLoopProgress = progress - circumference
            angle = (secondLoopProgress / radius) * 180 / .pi
            centerOffset = radius / 2
        }
        
        let x = radius * cos(angle * .pi / 180)
        let y = radius * sin(angle * .pi / 180) + centerOffset
        
        // Convert x,y to lat/lon offset
        let latOffset = y / 111320.0 // Approximate meters per degree latitude
        let lonOffset = x / (111320.0 * cos(startCoordinate.latitude * .pi / 180))
        
        return GPSCoordinate(
            latitude: startCoordinate.latitude + latOffset,
            longitude: startCoordinate.longitude + lonOffset,
            altitude: startCoordinate.altitude
        )
    }
    
    private func generateLoopCoordinate() -> GPSCoordinate {
        let radius = 50.0 * trackScale
        let circumference = 2 * .pi * radius
        
        let progress = totalDistance.truncatingRemainder(dividingBy: circumference)
        let angle = (progress / radius) * 180 / .pi
        
        let x = radius * cos(angle * .pi / 180)
        let y = radius * sin(angle * .pi / 180)
        
        // Convert x,y to lat/lon offset
        let latOffset = y / 111320.0
        let lonOffset = x / (111320.0 * cos(startCoordinate.latitude * .pi / 180))
        
        return GPSCoordinate(
            latitude: startCoordinate.latitude + latOffset,
            longitude: startCoordinate.longitude + lonOffset,
            altitude: startCoordinate.altitude
        )
    }
    
    private func generateSwirlCoordinate() -> GPSCoordinate {
        let maxRadius = 75.0 * trackScale
        let spiralLength = 500.0 * trackScale
        
        let progress = totalDistance.truncatingRemainder(dividingBy: spiralLength)
        let radiusProgress = progress / spiralLength
        let radius = maxRadius * radiusProgress
        
        // Multiple revolutions as we spiral outward
        let angle = (progress / 10.0) * 180 / .pi
        
        let x = radius * cos(angle * .pi / 180)
        let y = radius * sin(angle * .pi / 180)
        
        // Convert x,y to lat/lon offset
        let latOffset = y / 111320.0
        let lonOffset = x / (111320.0 * cos(startCoordinate.latitude * .pi / 180))
        
        return GPSCoordinate(
            latitude: startCoordinate.latitude + latOffset,
            longitude: startCoordinate.longitude + lonOffset,
            altitude: startCoordinate.altitude
        )
    }
    
    private func generateZigzagCoordinate() -> GPSCoordinate {
        let segmentLength = 50.0 * trackScale
        let amplitude = 30.0 * trackScale
        let totalPattern = segmentLength * 6 // 6 segments for full zigzag
        
        let progress = totalDistance.truncatingRemainder(dividingBy: totalPattern)
        let segmentIndex = Int(progress / segmentLength)
        let segmentProgress = progress.truncatingRemainder(dividingBy: segmentLength)
        
        let x: Double
        let y = segmentProgress
        
        // Alternate between left and right
        switch segmentIndex % 4 {
        case 0: x = 0 // Straight
        case 1: x = amplitude // Right
        case 2: x = 0 // Straight back
        case 3: x = -amplitude // Left
        default: x = 0
        }
        
        // Convert x,y to lat/lon offset
        let latOffset = y / 111320.0
        let lonOffset = x / (111320.0 * cos(startCoordinate.latitude * .pi / 180))
        
        return GPSCoordinate(
            latitude: startCoordinate.latitude + latOffset,
            longitude: startCoordinate.longitude + lonOffset,
            altitude: startCoordinate.altitude
        )
    }
    
    private func generateOvalCoordinate() -> GPSCoordinate {
        let majorAxis = 100.0 * trackScale // Width
        let minorAxis = 60.0 * trackScale  // Height
        let circumference = .pi * (3 * (majorAxis + minorAxis) - sqrt((3 * majorAxis + minorAxis) * (majorAxis + 3 * minorAxis)))
        
        let progress = totalDistance.truncatingRemainder(dividingBy: circumference)
        let angle = (progress / circumference) * 2 * .pi
        
        let x = (majorAxis / 2) * cos(angle)
        let y = (minorAxis / 2) * sin(angle)
        
        // Convert x,y to lat/lon offset
        let latOffset = y / 111320.0
        let lonOffset = x / (111320.0 * cos(startCoordinate.latitude * .pi / 180))
        
        return GPSCoordinate(
            latitude: startCoordinate.latitude + latOffset,
            longitude: startCoordinate.longitude + lonOffset,
            altitude: startCoordinate.altitude
        )
    }
}