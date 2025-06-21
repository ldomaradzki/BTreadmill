import Foundation

struct RunningState: Equatable {
    let timestamp: Date
    let speed: Measurement<UnitSpeed>
    let distance: Measurement<UnitLength>
    let steps: Int
    
    // Default stride length for an average adult in meters (approximately 0.7m)
    // This can be made user-configurable through settings
    static let defaultStrideLength: Double = 0.7
    
    init(timestamp: Date, speed: Measurement<UnitSpeed>, distance: Measurement<UnitLength>, steps: Int? = nil, strideLength: Measurement<UnitLength>? = nil) {
        self.timestamp = timestamp
        self.speed = speed
        self.distance = distance
        
        // If steps are provided, use them; otherwise calculate based on stride length
        if let steps = steps {
            self.steps = steps
        } else {
            // Use provided stride length or fall back to default
            let strideInMeters = strideLength?.converted(to: .meters).value ?? RunningState.defaultStrideLength
            
            // Calculate steps based on distance and stride length
            // Convert distance to meters first
            let distanceInMeters = distance.converted(to: .meters).value
            self.steps = Int(distanceInMeters / strideInMeters)
        }
    }
}