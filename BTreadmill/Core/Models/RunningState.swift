import Foundation

struct RunningState: Equatable {
    let timestamp: Date
    let speed: Double // km/h
    let distance: Double // kilometers
    let steps: Int
    
    // Default stride length for an average adult in meters (approximately 0.7m)
    // This can be made user-configurable through settings
    static let defaultStrideLength: Double = 0.7
    
    init(timestamp: Date, speed: Double, distance: Double, steps: Int? = nil, strideLength: Double? = nil) {
        self.timestamp = timestamp
        self.speed = speed
        self.distance = distance
        
        // If steps are provided, use them; otherwise calculate based on stride length
        if let steps = steps {
            self.steps = steps
        } else {
            // Use provided stride length or fall back to default
            let strideInMeters = strideLength ?? RunningState.defaultStrideLength
            
            // Calculate steps based on distance and stride length
            // Convert distance to meters first (distance is in kilometers)
            let distanceInMeters = distance * 1000
            self.steps = Int(distanceInMeters / strideInMeters)
        }
    }
}