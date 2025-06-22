import Foundation

// MARK: - Interval Segment (Repeating Pattern)

struct IntervalSegment: WorkoutSegment {
    let id: String
    let type = SegmentType.interval
    var name: String?
    
    let pattern: [IntervalStep]              // The repeating pattern
    let repeatCount: RepeatCount             // How many times to repeat
    let restBetweenSets: TimeInterval?       // Optional rest between full cycles
    
    init(
        id: String = UUID().uuidString,
        name: String? = nil,
        pattern: [IntervalStep],
        repeatCount: RepeatCount,
        restBetweenSets: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.repeatCount = repeatCount
        self.restBetweenSets = restBetweenSets
    }
    
    // MARK: - WorkoutSegment Implementation
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution {
        let cycleInfo = calculateCurrentCycle(at: time)
        
        // Handle rest periods
        if cycleInfo.isInRest {
            let displayText = formatIntervalDisplay(cycleInfo: cycleInfo)
            return SegmentExecution(
                targetSpeed: 0.0,
                currentSpeed: 0.0,
                progress: cycleInfo.overallProgress,
                isComplete: cycleInfo.isComplete,
                nextTransition: cycleInfo.timeToNextTransition,
                displayText: displayText,
                metadata: [
                    "type": "interval",
                    "currentCycle": String(cycleInfo.currentCycle + 1),
                    "totalCycles": cycleInfo.totalCycles > 0 ? String(cycleInfo.totalCycles) : "∞",
                    "phase": "rest",
                    "remaining": String(Int(cycleInfo.timeToNextTransition ?? 0))
                ]
            )
        }
        
        let currentStep = pattern[cycleInfo.stepIndex]
        let displayText = formatIntervalDisplay(cycleInfo: cycleInfo)
        
        // Handle transitions for interval steps
        let actualSpeed: Double
        if currentStep.transitionType == .gradual && cycleInfo.stepProgress < 0.1 {
            // Gradual transition over first 10% of step
            let transitionProgress = cycleInfo.stepProgress / 0.1
            actualSpeed = currentStep.speed * transitionProgress
        } else {
            actualSpeed = currentStep.speed
        }
        
        return SegmentExecution(
            targetSpeed: currentStep.speed,
            currentSpeed: actualSpeed,
            progress: cycleInfo.overallProgress,
            isComplete: cycleInfo.isComplete,
            nextTransition: cycleInfo.timeToNextTransition,
            displayText: displayText,
            metadata: [
                "type": "interval",
                "currentCycle": String(cycleInfo.currentCycle + 1),
                "totalCycles": cycleInfo.totalCycles > 0 ? String(cycleInfo.totalCycles) : "∞",
                "currentStep": currentStep.name ?? "Step \(cycleInfo.stepIndex + 1)",
                "stepProgress": String(format: "%.1f", cycleInfo.stepProgress * 100),
                "targetSpeed": String(currentStep.speed),
                "stepRemaining": String(Int(cycleInfo.timeToNextTransition ?? 0))
            ]
        )
    }
    
    func estimatedDuration() -> TimeInterval? {
        switch repeatCount {
        case .count(let n):
            let cycleTime = pattern.reduce(0) { $0 + $1.duration }
            let restTime = (restBetweenSets ?? 0) * Double(max(n - 1, 0))
            return cycleTime * Double(n) + restTime
        case .duration(let totalTime):
            return totalTime
        case .indefinite:
            return nil
        }
    }
    
    func speedRange() -> [Double] {
        return pattern.map { $0.speed }
    }
    
    func validate() -> [String] {
        var errors: [String] = []
        
        if pattern.isEmpty {
            errors.append("Interval pattern cannot be empty")
        }
        
        for (index, step) in pattern.enumerated() {
            if step.speed < 1.0 || step.speed > 6.0 {
                errors.append("Step \(index + 1) speed \(step.speed) km/h is outside valid range")
            }
            if step.duration < 5 {
                errors.append("Step \(index + 1) duration is too short")
            }
        }
        
        return errors
    }
    
    // MARK: - Helper Methods
    
    private func calculateCurrentCycle(at time: TimeInterval) -> CycleInfo {
        let cycleTime = pattern.reduce(0) { $0 + $1.duration }
        let restTime = restBetweenSets ?? 0
        let totalCycleTime = cycleTime + restTime
        
        switch repeatCount {
        case .count(let totalCycles):
            let currentCycle = min(Int(time / totalCycleTime), totalCycles - 1)
            let timeInCurrentCycle = time - (Double(currentCycle) * totalCycleTime)
            
            // Check if we're in rest period
            if timeInCurrentCycle >= cycleTime && restTime > 0 {
                let restProgress = (timeInCurrentCycle - cycleTime) / restTime
                return CycleInfo(
                    currentCycle: currentCycle,
                    totalCycles: totalCycles,
                    stepIndex: 0,
                    stepProgress: 0,
                    overallProgress: (Double(currentCycle) + restProgress) / Double(totalCycles),
                    isComplete: false,
                    timeToNextTransition: restTime - (timeInCurrentCycle - cycleTime),
                    isInRest: true
                )
            }
            
            // Find current step within cycle
            var stepTime: TimeInterval = 0
            for (index, step) in pattern.enumerated() {
                if timeInCurrentCycle < stepTime + step.duration {
                    let stepProgress = (timeInCurrentCycle - stepTime) / step.duration
                    let overallProgress = (Double(currentCycle) + (timeInCurrentCycle / cycleTime)) / Double(totalCycles)
                    
                    return CycleInfo(
                        currentCycle: currentCycle,
                        totalCycles: totalCycles,
                        stepIndex: index,
                        stepProgress: stepProgress,
                        overallProgress: overallProgress,
                        isComplete: currentCycle >= totalCycles - 1 && timeInCurrentCycle >= cycleTime,
                        timeToNextTransition: step.duration - (timeInCurrentCycle - stepTime),
                        isInRest: false
                    )
                }
                stepTime += step.duration
            }
            
            // Should not reach here, but fallback
            return CycleInfo(
                currentCycle: currentCycle,
                totalCycles: totalCycles,
                stepIndex: pattern.count - 1,
                stepProgress: 1.0,
                overallProgress: 1.0,
                isComplete: true,
                timeToNextTransition: nil,
                isInRest: false
            )
            
        case .duration(let totalTime):
            let progress = min(time / totalTime, 1.0)
            let adjustedTime = time.truncatingRemainder(dividingBy: totalCycleTime)
            
            var stepTime: TimeInterval = 0
            for (index, step) in pattern.enumerated() {
                if adjustedTime < stepTime + step.duration {
                    let stepProgress = (adjustedTime - stepTime) / step.duration
                    
                    return CycleInfo(
                        currentCycle: Int(time / totalCycleTime),
                        totalCycles: Int(totalTime / totalCycleTime) + 1,
                        stepIndex: index,
                        stepProgress: stepProgress,
                        overallProgress: progress,
                        isComplete: progress >= 1.0,
                        timeToNextTransition: step.duration - (adjustedTime - stepTime),
                        isInRest: false
                    )
                }
                stepTime += step.duration
            }
            
            // In rest period
            return CycleInfo(
                currentCycle: Int(time / totalCycleTime),
                totalCycles: Int(totalTime / totalCycleTime) + 1,
                stepIndex: 0,
                stepProgress: 0,
                overallProgress: progress,
                isComplete: progress >= 1.0,
                timeToNextTransition: restTime - (adjustedTime - cycleTime),
                isInRest: true
            )
            
        case .indefinite:
            let adjustedTime = time.truncatingRemainder(dividingBy: totalCycleTime)
            
            var stepTime: TimeInterval = 0
            for (index, step) in pattern.enumerated() {
                if adjustedTime < stepTime + step.duration {
                    let stepProgress = (adjustedTime - stepTime) / step.duration
                    
                    return CycleInfo(
                        currentCycle: Int(time / totalCycleTime),
                        totalCycles: -1, // Indefinite
                        stepIndex: index,
                        stepProgress: stepProgress,
                        overallProgress: 0, // No overall progress for indefinite
                        isComplete: false,
                        timeToNextTransition: step.duration - (adjustedTime - stepTime),
                        isInRest: false
                    )
                }
                stepTime += step.duration
            }
            
            // In rest period
            return CycleInfo(
                currentCycle: Int(time / totalCycleTime),
                totalCycles: -1,
                stepIndex: 0,
                stepProgress: 0,
                overallProgress: 0,
                isComplete: false,
                timeToNextTransition: restTime - (adjustedTime - cycleTime),
                isInRest: true
            )
        }
    }
    
    private func formatIntervalDisplay(cycleInfo: CycleInfo) -> String {
        if cycleInfo.isInRest {
            let restTime = Int(cycleInfo.timeToNextTransition ?? 0)
            return "Rest - \(restTime)s remaining"
        }
        
        let currentStep = pattern[cycleInfo.stepIndex]
        let stepName = currentStep.name ?? "Step \(cycleInfo.stepIndex + 1)"
        let remainingTime = Int(cycleInfo.timeToNextTransition ?? 0)
        
        if cycleInfo.totalCycles > 0 {
            return "\(stepName): \(String(format: "%.1f", currentStep.speed)) km/h - \(remainingTime)s (Cycle \(cycleInfo.currentCycle + 1)/\(cycleInfo.totalCycles))"
        } else {
            return "\(stepName): \(String(format: "%.1f", currentStep.speed)) km/h - \(remainingTime)s"
        }
    }
}

// MARK: - Supporting Types

struct IntervalStep: Codable, Hashable {
    let speed: Double                        // km/h
    let duration: TimeInterval               // seconds
    let transitionType: TransitionType
    let name: String?                        // e.g., "Sprint", "Recovery"
    
    init(
        speed: Double,
        duration: TimeInterval,
        transitionType: TransitionType = .immediate,
        name: String? = nil
    ) {
        self.speed = speed
        self.duration = duration
        self.transitionType = transitionType
        self.name = name
    }
}

enum RepeatCount: Codable, Hashable {
    case count(Int)                          // Repeat N times
    case duration(TimeInterval)              // Repeat for total time
    case indefinite                          // Repeat until plan ends/stopped
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "count":
            let count = try container.decode(Int.self, forKey: .value)
            self = .count(count)
        case "duration":
            let duration = try container.decode(TimeInterval.self, forKey: .value)
            self = .duration(duration)
        case "indefinite":
            self = .indefinite
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown repeat count type: \(type)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .count(let count):
            try container.encode("count", forKey: .type)
            try container.encode(count, forKey: .value)
        case .duration(let duration):
            try container.encode("duration", forKey: .type)
            try container.encode(duration, forKey: .value)
        case .indefinite:
            try container.encode("indefinite", forKey: .type)
        }
    }
}

struct CycleInfo {
    let currentCycle: Int
    let totalCycles: Int
    let stepIndex: Int
    let stepProgress: Double
    let overallProgress: Double
    let isComplete: Bool
    let timeToNextTransition: TimeInterval?
    let isInRest: Bool
}