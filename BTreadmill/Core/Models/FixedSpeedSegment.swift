import Foundation

// MARK: - Fixed Speed Segment

struct FixedSpeedSegment: WorkoutSegment {
    let id: String
    let type = SegmentType.fixed
    var name: String?
    
    let speed: Double                        // km/h (1.0-6.0)
    let duration: TimeInterval               // seconds
    let transitionType: TransitionType       // How to change to this speed
    
    init(
        id: String = UUID().uuidString,
        name: String? = nil,
        speed: Double,
        duration: TimeInterval,
        transitionType: TransitionType = .immediate
    ) {
        self.id = id
        self.name = name
        self.speed = speed
        self.duration = duration
        self.transitionType = transitionType
    }
    
    // MARK: - WorkoutSegment Implementation
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution {
        let progress = duration > 0 ? min(time / duration, 1.0) : 1.0
        let isComplete = time >= duration
        let remaining = max(0, duration - time)
        
        // Since treadmill handles speed transitions automatically, always use target speed
        let actualSpeed = speed
        
        let displayText: String
        if isComplete {
            displayText = "Completed: \(String(format: "%.1f", speed)) km/h"
        } else if remaining < 60 {
            displayText = "Fixed \(String(format: "%.1f", speed)) km/h (\(Int(remaining))s left)"
        } else {
            let minutes = Int(remaining) / 60
            displayText = "Fixed \(String(format: "%.1f", speed)) km/h (\(minutes)m left)"
        }
        
        return SegmentExecution(
            targetSpeed: speed,
            currentSpeed: actualSpeed,
            progress: progress,
            isComplete: isComplete,
            nextTransition: isComplete ? nil : remaining,
            displayText: displayText,
            metadata: [
                "type": "fixed",
                "targetSpeed": "\(speed)",
                "duration": "\(duration)",
                "remaining": "\(remaining)",
                "transitionType": transitionType.rawValue
            ]
        )
    }
    
    func estimatedDuration() -> TimeInterval? {
        return duration
    }
    
    func speedRange() -> [Double] {
        return [speed]
    }
    
    func validate() -> [String] {
        var errors: [String] = []
        
        // Validate speed range
        if speed < 1.0 || speed > 6.0 {
            errors.append("Speed \(speed) km/h is outside the valid range (1.0-6.0 km/h)")
        }
        
        // Validate duration
        if duration < 10 {
            errors.append("Duration \(Int(duration)) seconds is too short")
        }
        
        if duration > 3600 {
            errors.append("Duration \(Int(duration/60)) minutes is very long")
        }
        
        return errors
    }
    
    // MARK: - Helper Methods
    
    private func formatDisplayText(progress: Double) -> String {
        let remainingMinutes = Int((duration * (1.0 - progress)) / 60)
        let remainingSeconds = Int((duration * (1.0 - progress)).truncatingRemainder(dividingBy: 60))
        
        if remainingMinutes > 0 {
            return "\(String(format: "%.1f", speed)) km/h for \(remainingMinutes)m \(remainingSeconds)s"
        } else {
            return "\(String(format: "%.1f", speed)) km/h for \(remainingSeconds)s"
        }
    }
}

// MARK: - Transition Type

enum TransitionType: String, Codable, CaseIterable, Hashable {
    case immediate      // Instant speed change
    case gradual        // Smooth transition over 5-10 seconds
    case userPaced      // Wait for user confirmation
    
    var displayName: String {
        switch self {
        case .immediate: return "Immediate"
        case .gradual: return "Gradual"
        case .userPaced: return "User Paced"
        }
    }
    
    var transitionDuration: TimeInterval {
        switch self {
        case .immediate: return 0
        case .gradual: return 5.0
        case .userPaced: return 0 // Handled by execution engine
        }
    }
}