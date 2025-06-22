import Foundation

// MARK: - Ramp Segment (Gradual Speed Changes)

struct RampSegment: WorkoutSegment {
    let id: String
    let type = SegmentType.ramp
    var name: String?
    
    let startSpeed: Double                   // Starting speed
    let endSpeed: Double                     // Ending speed
    let duration: TimeInterval               // Time for the ramp
    let rampType: RampType                   // Linear, exponential, etc.
    
    init(
        id: String = UUID().uuidString,
        name: String? = nil,
        startSpeed: Double,
        endSpeed: Double,
        duration: TimeInterval,
        rampType: RampType = .linear
    ) {
        self.id = id
        self.name = name
        self.startSpeed = startSpeed
        self.endSpeed = endSpeed
        self.duration = duration
        self.rampType = rampType
    }
    
    // MARK: - WorkoutSegment Implementation
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution {
        let progress = duration > 0 ? min(time / duration, 1.0) : 1.0
        let targetSpeed = calculateRampSpeed(progress: progress)
        let isComplete = time >= duration
        let remaining = max(0, duration - time)
        
        let displayText = formatRampDisplay(currentSpeed: targetSpeed, progress: progress)
        
        return SegmentExecution(
            targetSpeed: targetSpeed,
            currentSpeed: targetSpeed, // For ramps, current follows target smoothly
            progress: progress,
            isComplete: isComplete,
            nextTransition: isComplete ? nil : remaining,
            displayText: displayText,
            metadata: [
                "type": "ramp",
                "startSpeed": String(format: "%.1f", startSpeed),
                "endSpeed": String(format: "%.1f", endSpeed),
                "currentSpeed": String(format: "%.1f", targetSpeed),
                "rampType": rampType.rawValue,
                "progress": String(format: "%.1f", progress * 100),
                "remaining": String(Int(remaining)),
                "direction": endSpeed > startSpeed ? "increasing" : "decreasing"
            ]
        )
    }
    
    func estimatedDuration() -> TimeInterval? {
        return duration
    }
    
    func speedRange() -> [Double] {
        return [min(startSpeed, endSpeed), max(startSpeed, endSpeed)]
    }
    
    func validate() -> [String] {
        var errors: [String] = []
        
        // Validate speed ranges
        if startSpeed < 1.0 || startSpeed > 6.0 {
            errors.append("Start speed \(startSpeed) km/h is outside valid range (1.0-6.0 km/h)")
        }
        
        if endSpeed < 1.0 || endSpeed > 6.0 {
            errors.append("End speed \(endSpeed) km/h is outside valid range (1.0-6.0 km/h)")
        }
        
        // Validate duration
        if duration < 30 {
            errors.append("Ramp duration \(Int(duration)) seconds is too short for smooth transition")
        }
        
        if duration > 1800 {
            errors.append("Ramp duration \(Int(duration/60)) minutes is very long")
        }
        
        return errors
    }
    
    // MARK: - Helper Methods
    
    private func calculateRampSpeed(progress: Double) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        switch rampType {
        case .linear:
            return startSpeed + (endSpeed - startSpeed) * clampedProgress
            
        case .exponential:
            // Slow start, fast finish
            let factor = pow(clampedProgress, 2.0)
            return startSpeed + (endSpeed - startSpeed) * factor
            
        case .logarithmic:
            // Fast start, slow finish
            let factor = clampedProgress == 0 ? 0 : log(1 + clampedProgress * (exp(1) - 1))
            return startSpeed + (endSpeed - startSpeed) * factor
            
        case .smoothStep:
            // S-curve for very smooth transitions
            let factor = clampedProgress * clampedProgress * (3.0 - 2.0 * clampedProgress)
            return startSpeed + (endSpeed - startSpeed) * factor
            
        case .easeInOut:
            // Slow start and end, fast middle
            let factor = clampedProgress < 0.5 
                ? 2.0 * clampedProgress * clampedProgress
                : 1.0 - pow(-2.0 * clampedProgress + 2.0, 2.0) / 2.0
            return startSpeed + (endSpeed - startSpeed) * factor
        }
    }
    
    private func formatRampDisplay(currentSpeed: Double, progress: Double) -> String {
        let remainingMinutes = Int((duration * (1.0 - progress)) / 60)
        let remainingSeconds = Int((duration * (1.0 - progress)).truncatingRemainder(dividingBy: 60))
        
        let direction = endSpeed > startSpeed ? "↗" : "↘"
        let progressPercent = Int(progress * 100)
        
        if remainingMinutes > 0 {
            return "\(direction) \(String(format: "%.1f", currentSpeed)) km/h (\(progressPercent)%) - \(remainingMinutes)m \(remainingSeconds)s"
        } else {
            return "\(direction) \(String(format: "%.1f", currentSpeed)) km/h (\(progressPercent)%) - \(remainingSeconds)s"
        }
    }
}

// MARK: - Ramp Type

enum RampType: String, Codable, CaseIterable, Hashable {
    case linear
    case exponential        // Slow start, fast finish
    case logarithmic        // Fast start, slow finish
    case smoothStep         // S-curve transition
    case easeInOut          // Slow start and end
    
    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .exponential: return "Exponential (Slow → Fast)"
        case .logarithmic: return "Logarithmic (Fast → Slow)"
        case .smoothStep: return "Smooth Step"
        case .easeInOut: return "Ease In-Out"
        }
    }
    
    var description: String {
        switch self {
        case .linear: return "Constant rate of speed change"
        case .exponential: return "Gradual acceleration, then rapid"
        case .logarithmic: return "Rapid change, then gradual"
        case .smoothStep: return "Very smooth S-curve transition"
        case .easeInOut: return "Slow start and end, fast middle"
        }
    }
}