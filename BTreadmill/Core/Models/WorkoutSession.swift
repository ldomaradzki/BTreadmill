import Foundation

struct WorkoutSession: Identifiable, Codable {
    
    private enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, totalDistance, totalTime, averageSpeed, maxSpeed
        case averagePace, totalSteps, estimatedCalories, isDemo, actualStartDate, actualEndDate
        case currentSpeed, speedHistory, stravaActivityId, stravaUploadDate, fitFilePath
        case hasGPSData, trackPattern, startingCoordinate
    }
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var totalDistance: Double // kilometers
    var totalTime: TimeInterval
    var averageSpeed: Double // km/h
    var maxSpeed: Double // km/h
    var averagePace: TimeInterval // minutes per kilometer
    var totalSteps: Int
    var estimatedCalories: Int
    // Non-serialized runtime state
    var isPaused: Bool = false
    var pausedDuration: TimeInterval = 0
    var isDemo: Bool
    
    // Grace period for calculated metrics (non-serialized)
    private var dataPointCount: Int = 0
    private let gracePeriodDataPoints: Int = 5
    
    // Actual session timing (wall-clock time including pauses)
    var actualStartDate: Date
    var actualEndDate: Date?
    
    // Non-serialized values before pause (for accumulation after resume)
    var distanceBeforePause: Double = 0 // kilometers
    var stepsBeforePause: Int = 0
    var caloriesBeforePause: Int = 0
    var speedBeforePause: Double = 0 // km/h - speed to restore when resuming
    var pauseStartTime: Date?
    
    // Current workout state (for active sessions)
    var currentSpeed: Double = 0 // km/h
    var lastUpdateTime: Date = Date()
    
    // Speed tracking for charts (speed values at each treadmill update)
    var speedHistory: [Double]
    
    // Strava integration
    var stravaActivityId: String?
    var stravaUploadDate: Date?
    
    // FIT file integration
    var fitFilePath: String?
    
    // GPS tracking integration
    var hasGPSData: Bool
    var trackPattern: GPSTrackPattern?
    var startingCoordinate: GPSCoordinate?
    
    init(id: UUID = UUID(), startTime: Date = Date(), isDemo: Bool = false) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.totalDistance = 0
        self.totalTime = 0
        self.averageSpeed = 0
        self.maxSpeed = 0
        self.averagePace = 0
        self.totalSteps = 0
        self.estimatedCalories = 0
        self.isDemo = isDemo
        self.actualStartDate = startTime
        self.actualEndDate = nil
        self.speedHistory = []
        self.stravaActivityId = nil
        self.stravaUploadDate = nil
        self.fitFilePath = nil
        self.hasGPSData = false
        self.trackPattern = nil
        self.startingCoordinate = nil
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var activeTime: TimeInterval {
        return totalTime - pausedDuration
    }
    
    var isInGracePeriod: Bool {
        return dataPointCount < gracePeriodDataPoints
    }
    
    var cadence: Double {
        guard activeTime > 0 && !isInGracePeriod else { return 0 }
        return Double(totalSteps) / (activeTime / 60.0) // steps per minute
    }
    
    var actualSessionDuration: TimeInterval {
        guard let endDate = actualEndDate else {
            return Date().timeIntervalSince(actualStartDate)
        }
        return endDate.timeIntervalSince(actualStartDate)
    }
    
    var isUploadedToStrava: Bool {
        return stravaActivityId != nil
    }
    
    var stravaActivityURL: URL? {
        guard let activityId = stravaActivityId else { return nil }
        return URL(string: "https://www.strava.com/activities/\(activityId)")
    }
    
    mutating func updateWith(runningState: RunningState) {
        let timeDelta = runningState.timestamp.timeIntervalSince(lastUpdateTime)
        
        if !isPaused {
            // Increment data point counter
            dataPointCount += 1
            
            // Apply simulation acceleration factor to time if this is a demo workout
            let adjustedTimeDelta = isDemo ? timeDelta * 60.0 : timeDelta
            totalTime += adjustedTimeDelta
            
            // Update distance (accumulate with pre-pause values)
            totalDistance = distanceBeforePause + runningState.distance
            
            // Update speed tracking
            currentSpeed = runningState.speed
            if currentSpeed > maxSpeed {
                maxSpeed = currentSpeed
            }
            
            // Update steps (accumulate with pre-pause values)
            totalSteps = stepsBeforePause + runningState.steps
            
            // Calculate average metrics only after grace period
            if activeTime > 0 && !isInGracePeriod {
                averageSpeed = totalDistance / (activeTime / 3600.0)
                
                // Calculate average pace (minutes per kilometer)
                if totalDistance > 0 {
                    averagePace = (activeTime / 60.0) / totalDistance
                }
                
                // Estimate calories (basic formula - can be improved with user weight)
                estimatedCalories = calculateEstimatedCalories()
            }
        }
        
        lastUpdateTime = runningState.timestamp
    }
    
    mutating func pause() {
        // Store current values before pausing
        distanceBeforePause = totalDistance
        stepsBeforePause = totalSteps
        caloriesBeforePause = estimatedCalories
        speedBeforePause = currentSpeed
        pauseStartTime = Date()
        isPaused = true
    }
    
    mutating func resume() {
        // Add the paused duration to the total paused time
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        
        // Values are already stored in distanceBeforePause, stepsBeforePause, caloriesBeforePause
        // The updateWith method will accumulate new treadmill values with these stored values
        // Note: dataPointCount is preserved across pause/resume to maintain grace period state
        isPaused = false
    }
    
    mutating func end() {
        let now = Date()
        
        // If we're ending while paused, add the final paused duration
        if isPaused, let pauseStart = pauseStartTime {
            pausedDuration += now.timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        endTime = now
        actualEndDate = now
        isPaused = false
    }
    
    mutating func markAsUploadedToStrava(activityId: String) {
        self.stravaActivityId = activityId
        self.stravaUploadDate = Date()
    }
    
    private func calculateEstimatedCalories() -> Int {
        // Basic calorie calculation: ~0.75 calories per kg per km
        // This will be improved when user weight is available from settings
        let defaultWeight: Double = 70 // kg - default weight
        let calories = totalDistance * defaultWeight * 0.75
        return Int(calories)
    }
}