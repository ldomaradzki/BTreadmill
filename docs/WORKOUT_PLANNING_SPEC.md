# Workout Planning System - Technical Specification

## Overview

The Workout Planning System extends BTreadmill with workout automation, allowing users to create JSON-based workout plans and execute them with timed intervals, speed variations, and repeatable patterns. This simplified approach focuses on JSON file management rather than complex UI creation tools.

## Data Architecture

### Core Data Models

```swift
// MARK: - Plan Definition Models

struct WorkoutPlan: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String?
    var createdAt: Date
    var lastModified: Date
    var segments: [WorkoutSegment]
    var globalSettings: GlobalPlanSettings
    var tags: [String]
    
    // Computed properties
    var estimatedDuration: TimeInterval { /* calculated from segments */ }
    var totalDistance: Measurement<UnitLength>? { /* if deterministic */ }
    var speedRange: ClosedRange<Double> { /* min/max speeds */ }
}

struct GlobalPlanSettings: Codable {
    var maxDuration: TimeInterval?           // Optional time limit
    var autoStopOnCompletion: Bool           // Stop treadmill when plan ends
    var allowManualOverride: Bool            // Allow speed changes during execution
    var pauseBehavior: PauseBehavior         // How pausing affects plan timing
    var warmupSpeed: Double?                 // Optional warmup before plan starts
    var cooldownSpeed: Double?               // Optional cooldown after plan ends
    var emergencyStopEnabled: Bool           // Emergency stop behavior
}

enum PauseBehavior: String, Codable, CaseIterable {
    case holdPosition      // Pause both timer and segment progression
    case continueTimer     // Keep timer running, hold segment
    case resetSegment      // Reset current segment when resumed
}

// MARK: - Segment Types

protocol WorkoutSegment: Codable, Identifiable {
    var id: UUID { get }
    var type: SegmentType { get }
    var name: String? { get set }
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution
    func estimatedDuration() -> TimeInterval?
    func validate() -> [ValidationError]
}

enum SegmentType: String, Codable {
    case fixed          // Fixed speed for duration
    case interval       // Repeating pattern
    case ramp           // Gradual speed change
    case custom         // User-defined logic
}

// MARK: - Fixed Speed Segment

struct FixedSpeedSegment: WorkoutSegment {
    let id = UUID()
    let type = SegmentType.fixed
    var name: String?
    
    let speed: Double                        // km/h (1.0-6.0)
    let duration: TimeInterval               // seconds
    let transitionType: TransitionType       // How to change to this speed
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution {
        let progress = min(time / duration, 1.0)
        let isComplete = progress >= 1.0
        
        return SegmentExecution(
            currentSpeed: speed,
            progress: progress,
            isComplete: isComplete,
            nextTransition: isComplete ? nil : (duration - time),
            displayText: formatDisplayText(progress: progress)
        )
    }
    
    func estimatedDuration() -> TimeInterval? { duration }
}

enum TransitionType: String, Codable {
    case immediate      // Instant speed change
    case gradual        // Smooth transition over 5-10 seconds
    case userPaced      // Wait for user confirmation
}

// MARK: - Interval Segment (Repeating Pattern)

struct IntervalSegment: WorkoutSegment {
    let id = UUID()
    let type = SegmentType.interval
    var name: String?
    
    let pattern: [IntervalStep]              // The repeating pattern
    let repeatCount: RepeatCount             // How many times to repeat
    let restBetweenSets: TimeInterval?       // Optional rest between full cycles
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution {
        // Complex logic to determine current step, repetition, and progress
        let cycleInfo = calculateCurrentCycle(at: time)
        let currentStep = pattern[cycleInfo.stepIndex]
        
        return SegmentExecution(
            currentSpeed: currentStep.speed,
            progress: cycleInfo.overallProgress,
            isComplete: cycleInfo.isComplete,
            nextTransition: cycleInfo.timeToNextTransition,
            displayText: formatIntervalDisplay(cycleInfo: cycleInfo)
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
}

struct IntervalStep: Codable {
    let speed: Double                        // km/h
    let duration: TimeInterval               // seconds
    let transitionType: TransitionType
    let name: String?                        // e.g., "Sprint", "Recovery"
}

enum RepeatCount: Codable {
    case count(Int)                          // Repeat N times
    case duration(TimeInterval)              // Repeat for total time
    case indefinite                          // Repeat until plan ends/stopped
    
    enum CodingKeys: String, CodingKey {
        case type, value
    }
}

// MARK: - Ramp Segment (Gradual Speed Changes)

struct RampSegment: WorkoutSegment {
    let id = UUID()
    let type = SegmentType.ramp
    var name: String?
    
    let startSpeed: Double                   // Starting speed
    let endSpeed: Double                     // Ending speed
    let duration: TimeInterval               // Time for the ramp
    let rampType: RampType                   // Linear, exponential, etc.
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution {
        let progress = min(time / duration, 1.0)
        let currentSpeed = calculateRampSpeed(progress: progress)
        
        return SegmentExecution(
            currentSpeed: currentSpeed,
            progress: progress,
            isComplete: progress >= 1.0,
            nextTransition: progress >= 1.0 ? nil : (duration - time),
            displayText: formatRampDisplay(currentSpeed: currentSpeed, progress: progress)
        )
    }
    
    private func calculateRampSpeed(progress: Double) -> Double {
        switch rampType {
        case .linear:
            return startSpeed + (endSpeed - startSpeed) * progress
        case .exponential:
            let factor = pow(progress, 2.0)
            return startSpeed + (endSpeed - startSpeed) * factor
        case .logarithmic:
            let factor = log(1 + progress * (exp(1) - 1))
            return startSpeed + (endSpeed - startSpeed) * factor
        }
    }
}

enum RampType: String, Codable {
    case linear
    case exponential        // Slow start, fast finish
    case logarithmic        // Fast start, slow finish
}

// MARK: - Execution Engine Models

struct SegmentExecution {
    let currentSpeed: Double
    let progress: Double                     // 0.0 to 1.0
    let isComplete: Bool
    let nextTransition: TimeInterval?        // Seconds until next change
    let displayText: String                  // User-friendly description
    let metadata: [String: Any]?             // Additional context
}

struct ExecutionContext {
    let planStartTime: Date
    let currentTime: Date
    let elapsedTime: TimeInterval
    let totalPauseTime: TimeInterval
    let currentSegmentIndex: Int
    let userOverrides: [Override]
    let treadmillState: TreadmillState
}

struct Override {
    let timestamp: Date
    let type: OverrideType
    let value: Double?
    let duration: TimeInterval?
}

enum OverrideType {
    case speedChange(Double)
    case pauseSegment
    case skipSegment
    case extendSegment(TimeInterval)
    case emergencyStop
}

// MARK: - Plan Execution State

class PlanExecutionState: ObservableObject {
    @Published var currentPlan: WorkoutPlan?
    @Published var isExecuting: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentSegmentIndex: Int = 0
    @Published var segmentProgress: Double = 0.0
    @Published var overallProgress: Double = 0.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var estimatedRemainingTime: TimeInterval?
    @Published var currentExecution: SegmentExecution?
    @Published var activeOverrides: [Override] = []
    
    // Execution control
    func startPlan(_ plan: WorkoutPlan) { /* ... */ }
    func pausePlan() { /* ... */ }
    func resumePlan() { /* ... */ }
    func stopPlan() { /* ... */ }
    func skipCurrentSegment() { /* ... */ }
    func overrideSpeed(_ speed: Double, duration: TimeInterval?) { /* ... */ }
}

// MARK: - Plan Builder System

class WorkoutPlanBuilder: ObservableObject {
    @Published var currentPlan: WorkoutPlan
    @Published var selectedSegment: WorkoutSegment?
    @Published var validationErrors: [ValidationError] = []
    
    init() {
        currentPlan = WorkoutPlan(
            id: UUID(),
            name: "New Plan",
            description: nil,
            createdAt: Date(),
            lastModified: Date(),
            segments: [],
            globalSettings: GlobalPlanSettings.default,
            tags: []
        )
    }
    
    // Building methods
    func addFixedSpeedSegment(speed: Double, duration: TimeInterval) -> UUID
    func addIntervalSegment(pattern: [IntervalStep], repeatCount: RepeatCount) -> UUID
    func addRampSegment(from: Double, to: Double, duration: TimeInterval, type: RampType) -> UUID
    func insertSegment(_ segment: WorkoutSegment, at index: Int)
    func removeSegment(id: UUID)
    func moveSegment(from: Int, to: Int)
    func duplicateSegment(id: UUID) -> UUID
    
    // Validation and preview
    func validatePlan() -> [ValidationError]
    func previewPlan() -> PlanPreview
    func estimateTotalTime() -> TimeInterval?
    func calculateSpeedProfile() -> [(time: TimeInterval, speed: Double)]
}

struct ValidationError: Identifiable {
    let id = UUID()
    let type: ValidationErrorType
    let message: String
    let segmentId: UUID?
    let suggestion: String?
}

enum ValidationErrorType {
    case speedOutOfRange
    case durationTooShort
    case durationTooLong
    case conflictingSettings
    case emptyPlan
    case invalidTransition
}

struct PlanPreview {
    let totalDuration: TimeInterval?
    let segmentCount: Int
    let speedChanges: Int
    let estimatedDistance: Measurement<UnitLength>?
    let estimatedCalories: Int?
    let complexityRating: ComplexityRating
    let visualTimeline: [TimelinePoint]
}

struct TimelinePoint {
    let time: TimeInterval
    let speed: Double
    let segmentName: String?
    let isTransition: Bool
}

enum ComplexityRating {
    case simple         // 1-3 segments, no intervals
    case moderate       // 4-10 segments, basic intervals
    case complex        // 10+ segments, complex intervals
    case advanced       // Nested intervals, custom logic
}
```

## JSON Plan Storage

Plans are stored as JSON files in the application's Documents folder under `WorkoutPlans/`. Each plan is a standalone JSON file that can be easily shared, backed up, or manually created.

### Plan Loading

The system automatically loads all JSON files from the WorkoutPlans directory on startup. Plans are validated on load and invalid plans are logged but not loaded.

### File Structure

```
~/Documents/BTreadmill/
├── WorkoutPlans/
│   ├── beginner-easy-walk.json
│   ├── intermediate-intervals.json
│   ├── advanced-hiit.json
│   └── custom-plan.json
└── WorkoutHistory/
    └── (existing workout data)
```

## Implementation Plan

### Phase 1: Core Data Models & Storage (COMPLETED)
**Priority: High**

**Status: ✅ COMPLETED**
- Core data models defined (`WorkoutPlan`, `WorkoutSegment` protocols, concrete segment types)
- JSON serialization/deserialization implemented
- Data models support all required segment types

### Phase 2: JSON Plan Management (CURRENT)
**Priority: High**

**Tasks:**
1. Create sample JSON workout plans for different difficulty levels
2. Implement simple plan loading from JSON files
3. Add plan selection to main menu interface
4. Create basic plan execution engine

**Deliverables:**
- Sample JSON plans (beginner, intermediate, advanced)
- Plan loading functionality
- Simple plan selection UI
- Basic execution engine

### Phase 3: Execution Integration (NEXT)
**Priority: High**

**Tasks:**
1. Integrate plan execution with existing workout system
2. Add execution progress display to main interface
3. Implement pause/resume with plan context
4. Add plan-specific statistics tracking

**Deliverables:**
- Working plan execution
- Progress visualization
- Plan-aware workout tracking

## Built-in Plan Templates

### Beginner Templates
1. **Easy Walk**: 30 min at 2.5 km/h with 2-minute breaks every 10 minutes
2. **First Steps**: Alternating 3 min at 2 km/h, 2 min at 3 km/h for 20 minutes
3. **Gentle Introduction**: 5 min warmup at 1.5 km/h, 15 min at 2.5 km/h, 5 min cooldown

### Intermediate Templates
1. **Steady Progress**: 5 min warmup, 20 min at 3.5 km/h, 10 min at 4 km/h, 5 min cooldown
2. **Hill Simulation**: Gradual ramps from 2-5 km/h over 3-minute intervals
3. **Interval Training**: 2 min at 3 km/h, 1 min at 5 km/h, repeat 10 times

### Advanced Templates
1. **HIIT Challenge**: 30 sec at 6 km/h, 90 sec at 2 km/h, repeat 20 times
2. **Endurance Builder**: 60 minutes with speed increasing every 10 minutes
3. **Speed Pyramid**: Increasing speed every 2 minutes, then decreasing back down

### Recovery Templates
1. **Active Recovery**: 20 min at 1.5-2 km/h with gentle speed variations
2. **Post-Workout**: 10 min at 1.5 km/h with 1-minute pauses every 3 minutes
3. **Mobility Walk**: 15 min at 2 km/h with 30-second stops for stretching

## Technical Considerations

### Performance Optimization
- **Memory Management**: Efficient segment caching and cleanup
- **Timer Precision**: Use high-resolution timers for accurate execution
- **UI Responsiveness**: Async operations for plan loading/saving
- **Data Structures**: Optimized for large plans with many segments

### Error Handling
- **Treadmill Disconnection**: Pause plan, attempt reconnection
- **Invalid Speed**: Clamp to safe ranges, log warnings
- **Timer Drift**: Self-correcting execution timing
- **Data Corruption**: Graceful degradation and recovery

### Extensibility
- **Plugin Architecture**: Allow custom segment types
- **Script Integration**: Support for user-defined logic
- **API Endpoints**: External plan sharing and synchronization
- **Theme System**: Customizable UI for different user preferences

### Security & Privacy
- **Local Storage**: All plans stored locally by default
- **Encryption**: Optional encryption for sensitive plans
- **Sharing Controls**: User controls what gets shared
- **Data Validation**: Strict validation to prevent malicious plans

## Success Metrics

### User Experience Goals
- **Plan Creation Time**: < 5 minutes for simple plans
- **Execution Accuracy**: ± 2 seconds timing precision
- **UI Responsiveness**: < 100ms for all interactions
- **Learning Curve**: New users create first plan in < 10 minutes

### Technical Goals
- **Memory Usage**: < 50MB additional overhead
- **Battery Impact**: < 5% additional drain during execution
- **File Size**: Plans average < 10KB storage
- **Startup Time**: Plan system adds < 500ms to app launch

### Feature Adoption
- **Plan Usage**: 60% of users create at least one plan
- **Template Usage**: 80% of plans start from templates
- **Execution Completion**: 70% of started plans complete successfully
- **Repeat Usage**: 40% of users create multiple plans

This comprehensive specification provides a robust foundation for implementing advanced workout planning while maintaining the simplicity and reliability that makes BTreadmill effective.