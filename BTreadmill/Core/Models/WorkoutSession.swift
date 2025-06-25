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
    var speedBeforePause: Double = 0 // km/h - speed to restore when resuming
    var pauseStartTime: Date?
    var isManuallyPaused: Bool = false // Track if user manually paused vs auto-pause
    
    // Incremental distance/steps tracking (HealthKit style)
    var lastTreadmillDistance: Double = 0 // Last known treadmill cumulative distance
    var lastTreadmillSteps: Int = 0 // Last known treadmill cumulative steps
    
    // Timer-based time tracking
    var currentTimerStart: Date = Date() // When current timer segment started
    var isTimerRunning: Bool = false // Whether timer is currently running
    
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
    
    // Custom decoder to handle missing GPS fields for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startTime = try container.decode(Date.self, forKey: .startTime)
        self.endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        self.totalDistance = try container.decode(Double.self, forKey: .totalDistance)
        self.totalTime = try container.decode(TimeInterval.self, forKey: .totalTime)
        self.averageSpeed = try container.decode(Double.self, forKey: .averageSpeed)
        self.maxSpeed = try container.decode(Double.self, forKey: .maxSpeed)
        self.averagePace = try container.decode(TimeInterval.self, forKey: .averagePace)
        self.totalSteps = try container.decode(Int.self, forKey: .totalSteps)
        self.estimatedCalories = try container.decode(Int.self, forKey: .estimatedCalories)
        self.isDemo = try container.decode(Bool.self, forKey: .isDemo)
        self.actualStartDate = try container.decode(Date.self, forKey: .actualStartDate)
        self.actualEndDate = try container.decodeIfPresent(Date.self, forKey: .actualEndDate)
        
        // Optional fields that may not exist in old workout files
        self.currentSpeed = try container.decodeIfPresent(Double.self, forKey: .currentSpeed) ?? 0
        self.speedHistory = try container.decodeIfPresent([Double].self, forKey: .speedHistory) ?? []
        self.stravaActivityId = try container.decodeIfPresent(String.self, forKey: .stravaActivityId)
        self.stravaUploadDate = try container.decodeIfPresent(Date.self, forKey: .stravaUploadDate)
        self.fitFilePath = try container.decodeIfPresent(String.self, forKey: .fitFilePath)
        
        // GPS fields - new fields that may not exist in old workout files
        self.hasGPSData = try container.decodeIfPresent(Bool.self, forKey: .hasGPSData) ?? false
        self.trackPattern = try container.decodeIfPresent(GPSTrackPattern.self, forKey: .trackPattern)
        self.startingCoordinate = try container.decodeIfPresent(GPSCoordinate.self, forKey: .startingCoordinate)
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    var activeTime: TimeInterval {
        return getCurrentTotalTime()
    }
    
    var isInGracePeriod: Bool {
        return dataPointCount < gracePeriodDataPoints
    }
    
    var cadence: Double {
        let currentActiveTime = getCurrentTotalTime()
        guard currentActiveTime > 0 && !isInGracePeriod else { return 0 }
        return Double(totalSteps) / (currentActiveTime / 60.0) // steps per minute
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
    
    // MARK: - Timer Management
    
    mutating func startTimer() {
        guard !isTimerRunning else { return }
        currentTimerStart = Date()
        isTimerRunning = true
    }
    
    mutating func stopTimer() {
        guard isTimerRunning else { return }
        // Accumulate elapsed time to total
        let elapsed = Date().timeIntervalSince(currentTimerStart)
        let adjustedElapsed = isDemo ? elapsed * 60.0 : elapsed // Apply demo acceleration
        totalTime += adjustedElapsed
        isTimerRunning = false
    }
    
    func getCurrentTotalTime() -> TimeInterval {
        var total = totalTime
        if isTimerRunning {
            let currentElapsed = Date().timeIntervalSince(currentTimerStart)
            let adjustedElapsed = isDemo ? currentElapsed * 60.0 : currentElapsed
            total += adjustedElapsed
        }
        return total
    }
    
    mutating func updateWith(runningState: RunningState) {
        if !isPaused {
            // Increment data point counter  
            dataPointCount += 1
            
            // Start timer if not running (handles resume and initial start)
            if !isTimerRunning {
                startTimer()
            }
            
            // Calculate incremental distance change (HealthKit style)
            let distanceChange = runningState.distance - lastTreadmillDistance
            if distanceChange > 0 {
                // Only add positive distance changes
                totalDistance += distanceChange
            }
            // Always update baseline for next comparison (handles resets and normal progression)
            lastTreadmillDistance = runningState.distance
            
            // Calculate incremental steps change (HealthKit style)
            let stepsChange = runningState.steps - lastTreadmillSteps
            if stepsChange > 0 {
                // Only add positive step changes
                totalSteps += stepsChange
            }
            // Always update baseline for next comparison (handles resets and normal progression)
            lastTreadmillSteps = runningState.steps
            
            // Update speed tracking
            currentSpeed = runningState.speed
            if currentSpeed > maxSpeed {
                maxSpeed = currentSpeed
            }
            
            // Calculate average metrics only after grace period
            let currentActiveTime = getCurrentTotalTime()
            if currentActiveTime > 0 && !isInGracePeriod {
                // Calculate average speed from speed history for better accuracy
                if !speedHistory.isEmpty {
                    averageSpeed = speedHistory.reduce(0, +) / Double(speedHistory.count)
                } else {
                    // Fallback to distance/time calculation if no speed history
                    averageSpeed = totalDistance / (currentActiveTime / 3600.0)
                }
                
                // Calculate average pace (minutes per kilometer)
                if totalDistance > 0 {
                    averagePace = (currentActiveTime / 60.0) / totalDistance
                }
                
                // Estimate calories (basic formula - can be improved with user weight)
                estimatedCalories = calculateEstimatedCalories()
            }
        }
        
        lastUpdateTime = runningState.timestamp
    }
    
    mutating func pause() {
        // Stop the timer and accumulate time
        stopTimer()
        
        // Store current speed for resuming
        speedBeforePause = currentSpeed
        pauseStartTime = Date()
        isPaused = true
        isManuallyPaused = true // Mark as manually paused
    }
    
    mutating func resume() {
        // Track paused duration for wall-clock time calculations
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        
        // Timer will be started automatically when next update comes in
        // With incremental tracking, distance/steps will automatically handle treadmill resets
        // Note: dataPointCount is preserved across pause/resume to maintain grace period state
        isPaused = false
        isManuallyPaused = false // Clear manual pause flag
    }
    
    mutating func end() {
        let now = Date()
        
        // Stop the timer and accumulate final time
        stopTimer()
        
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