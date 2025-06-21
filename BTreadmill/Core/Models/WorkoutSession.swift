import Foundation

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var totalDistance: Measurement<UnitLength>
    var totalTime: TimeInterval
    var averageSpeed: Measurement<UnitSpeed>
    var maxSpeed: Measurement<UnitSpeed>
    var averagePace: TimeInterval // minutes per kilometer
    var totalSteps: Int
    var estimatedCalories: Int
    var isPaused: Bool
    var pausedDuration: TimeInterval
    var isDemo: Bool
    
    // Actual session timing (wall-clock time including pauses)
    var actualStartDate: Date
    var actualEndDate: Date?
    
    // Values before pause (for accumulation after resume)
    var distanceBeforePause: Measurement<UnitLength>
    var stepsBeforePause: Int
    var caloriesBeforePause: Int
    
    // Current workout state (for active sessions)
    var currentSpeed: Measurement<UnitSpeed>
    var lastUpdateTime: Date
    
    init(id: UUID = UUID(), startTime: Date = Date(), isDemo: Bool = false) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.totalDistance = Measurement(value: 0, unit: .kilometers)
        self.totalTime = 0
        self.averageSpeed = Measurement(value: 0, unit: .kilometersPerHour)
        self.maxSpeed = Measurement(value: 0, unit: .kilometersPerHour)
        self.averagePace = 0
        self.totalSteps = 0
        self.estimatedCalories = 0
        self.isPaused = false
        self.pausedDuration = 0
        self.isDemo = isDemo
        self.actualStartDate = startTime
        self.actualEndDate = nil
        self.distanceBeforePause = Measurement(value: 0, unit: .kilometers)
        self.stepsBeforePause = 0
        self.caloriesBeforePause = 0
        self.currentSpeed = Measurement(value: 0, unit: .kilometersPerHour)
        self.lastUpdateTime = startTime
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var activeTime: TimeInterval {
        return totalTime - pausedDuration
    }
    
    var actualSessionDuration: TimeInterval {
        guard let endDate = actualEndDate else {
            return Date().timeIntervalSince(actualStartDate)
        }
        return endDate.timeIntervalSince(actualStartDate)
    }
    
    mutating func updateWith(runningState: RunningState) {
        let timeDelta = runningState.timestamp.timeIntervalSince(lastUpdateTime)
        
        if !isPaused {
            // Apply simulation acceleration factor to time if this is a demo workout
            let adjustedTimeDelta = isDemo ? timeDelta * 60.0 : timeDelta
            totalTime += adjustedTimeDelta
            
            // Update distance (accumulate with pre-pause values)
            totalDistance = Measurement(value: distanceBeforePause.value + runningState.distance.converted(to: distanceBeforePause.unit).value, unit: distanceBeforePause.unit)
            
            // Update speed tracking
            currentSpeed = runningState.speed
            if runningState.speed.value > maxSpeed.value {
                maxSpeed = runningState.speed
            }
            
            // Update steps (accumulate with pre-pause values)
            totalSteps = stepsBeforePause + runningState.steps
            
            // Calculate average speed (excluding paused time)
            if activeTime > 0 {
                let avgSpeedValue = totalDistance.converted(to: .kilometers).value / (activeTime / 3600.0)
                averageSpeed = Measurement(value: avgSpeedValue, unit: .kilometersPerHour)
                
                // Calculate average pace (minutes per kilometer)
                if totalDistance.converted(to: .kilometers).value > 0 {
                    averagePace = (activeTime / 60.0) / totalDistance.converted(to: .kilometers).value
                }
            }
            
            // Estimate calories (basic formula - can be improved with user weight)
            estimatedCalories = calculateEstimatedCalories()
        }
        
        lastUpdateTime = runningState.timestamp
    }
    
    mutating func pause() {
        // Store current values before pausing
        distanceBeforePause = totalDistance
        stepsBeforePause = totalSteps
        caloriesBeforePause = estimatedCalories
        isPaused = true
    }
    
    mutating func resume() {
        // Values are already stored in distanceBeforePause, stepsBeforePause, caloriesBeforePause
        // The updateWith method will accumulate new treadmill values with these stored values
        isPaused = false
    }
    
    mutating func end() {
        let now = Date()
        endTime = now
        actualEndDate = now
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