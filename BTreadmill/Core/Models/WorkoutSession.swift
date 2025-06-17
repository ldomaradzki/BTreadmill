import Foundation

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var totalDistance: Measurement<UnitLength>
    var totalTime: TimeInterval
    var averageSpeed: Measurement<UnitSpeed>
    var maxSpeed: Measurement<UnitSpeed>
    var totalSteps: Int
    var estimatedCalories: Int
    var isPaused: Bool
    var pausedDuration: TimeInterval
    
    // Current workout state (for active sessions)
    var currentSpeed: Measurement<UnitSpeed>
    var lastUpdateTime: Date
    
    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.totalDistance = Measurement(value: 0, unit: .kilometers)
        self.totalTime = 0
        self.averageSpeed = Measurement(value: 0, unit: .kilometersPerHour)
        self.maxSpeed = Measurement(value: 0, unit: .kilometersPerHour)
        self.totalSteps = 0
        self.estimatedCalories = 0
        self.isPaused = false
        self.pausedDuration = 0
        self.currentSpeed = Measurement(value: 0, unit: .kilometersPerHour)
        self.lastUpdateTime = startTime
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var activeTime: TimeInterval {
        return totalTime - pausedDuration
    }
    
    mutating func updateWith(runningState: RunningState) {
        let timeDelta = runningState.timestamp.timeIntervalSince(lastUpdateTime)
        
        if !isPaused {
            totalTime += timeDelta
            
            // Update distance (treadmill provides cumulative distance)
            totalDistance = runningState.distance
            
            // Update speed tracking
            currentSpeed = runningState.speed
            if runningState.speed.value > maxSpeed.value {
                maxSpeed = runningState.speed
            }
            
            // Update steps
            totalSteps = runningState.steps
            
            // Calculate average speed (excluding paused time)
            if activeTime > 0 {
                let avgSpeedValue = totalDistance.converted(to: .kilometers).value / (activeTime / 3600.0)
                averageSpeed = Measurement(value: avgSpeedValue, unit: .kilometersPerHour)
            }
            
            // Estimate calories (basic formula - can be improved with user weight)
            estimatedCalories = calculateEstimatedCalories()
        }
        
        lastUpdateTime = runningState.timestamp
    }
    
    mutating func pause() {
        isPaused = true
    }
    
    mutating func resume() {
        isPaused = false
    }
    
    mutating func end() {
        endTime = Date()
        isPaused = false
    }
    
    private func calculateEstimatedCalories() -> Int {
        // Basic calorie calculation: ~0.75 calories per kg per km
        // This will be improved when user weight is available from settings
        let defaultWeight: Double = 70 // kg - default weight
        let distanceKm = totalDistance.converted(to: .kilometers).value
        let calories = distanceKm * defaultWeight * 0.75
        return Int(calories)
    }
}