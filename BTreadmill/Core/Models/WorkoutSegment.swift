import Foundation

// MARK: - WorkoutSegment Protocol

protocol WorkoutSegment: Codable, Identifiable, Hashable {
    var id: String { get }
    var type: SegmentType { get }
    var name: String? { get set }
    
    func execute(at time: TimeInterval, context: ExecutionContext) -> SegmentExecution
    func estimatedDuration() -> TimeInterval?
    func speedRange() -> [Double]
    func validate() -> [String]
}

// MARK: - Segment Types

enum SegmentType: String, Codable, CaseIterable, Hashable {
    case fixed          // Fixed speed for duration
    case interval       // Repeating pattern
    case ramp           // Gradual speed change
    
    var displayName: String {
        switch self {
        case .fixed: return "Fixed Speed"
        case .interval: return "Interval"
        case .ramp: return "Speed Ramp"
        }
    }
}

// MARK: - Type-Erased Wrapper

struct AnyWorkoutSegment: Codable, Identifiable, Hashable {
    let id: String
    let segment: any WorkoutSegment
    
    init<T: WorkoutSegment>(_ segment: T) {
        self.id = segment.id
        self.segment = segment
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SegmentType.self, forKey: .type)
        
        switch type {
        case .fixed:
            let segment = try container.decode(FixedSpeedSegment.self, forKey: .data)
            self.init(segment)
        case .interval:
            let segment = try container.decode(IntervalSegment.self, forKey: .data)
            self.init(segment)
        case .ramp:
            let segment = try container.decode(RampSegment.self, forKey: .data)
            self.init(segment)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(segment.type, forKey: .type)
        
        switch segment {
        case let fixedSegment as FixedSpeedSegment:
            try container.encode(fixedSegment, forKey: .data)
        case let intervalSegment as IntervalSegment:
            try container.encode(intervalSegment, forKey: .data)
        case let rampSegment as RampSegment:
            try container.encode(rampSegment, forKey: .data)
        default:
            throw EncodingError.invalidValue(
                segment,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unknown segment type")
            )
        }
    }
    
    // MARK: - Hashable Implementation
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AnyWorkoutSegment, rhs: AnyWorkoutSegment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Segment Execution Models

struct SegmentExecution {
    let targetSpeed: Double                  // Target speed for treadmill
    let currentSpeed: Double                 // Current actual speed (may be different during transitions)
    let progress: Double                     // 0.0 to 1.0
    let isComplete: Bool
    let nextTransition: TimeInterval?        // Seconds until next change
    let displayText: String                  // User-friendly description
    let metadata: [String: String]           // Additional context
    
    init(
        targetSpeed: Double,
        currentSpeed: Double? = nil,
        progress: Double,
        isComplete: Bool,
        nextTransition: TimeInterval? = nil,
        displayText: String,
        metadata: [String: String] = [:]
    ) {
        self.targetSpeed = targetSpeed
        self.currentSpeed = currentSpeed ?? targetSpeed
        self.progress = progress
        self.isComplete = isComplete
        self.nextTransition = nextTransition
        self.displayText = displayText
        self.metadata = metadata
    }
}

struct ExecutionContext {
    let planStartTime: Date
    let currentTime: Date
    let elapsedTime: TimeInterval
    let totalPauseTime: TimeInterval
    let currentSegmentIndex: Int
    let userOverrides: [Override]
    let treadmillState: TreadmillState?
    
    init(
        planStartTime: Date = Date(),
        currentTime: Date = Date(),
        elapsedTime: TimeInterval = 0,
        totalPauseTime: TimeInterval = 0,
        currentSegmentIndex: Int = 0,
        userOverrides: [Override] = [],
        treadmillState: TreadmillState? = nil
    ) {
        self.planStartTime = planStartTime
        self.currentTime = currentTime
        self.elapsedTime = elapsedTime
        self.totalPauseTime = totalPauseTime
        self.currentSegmentIndex = currentSegmentIndex
        self.userOverrides = userOverrides
        self.treadmillState = treadmillState
    }
}

// MARK: - Override System

struct Override: Codable, Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let type: OverrideType
    let value: Double?
    let duration: TimeInterval?
    
    init(type: OverrideType, value: Double? = nil, duration: TimeInterval? = nil) {
        self.timestamp = Date()
        self.type = type
        self.value = value
        self.duration = duration
    }
}

enum OverrideType: Codable, Hashable {
    case speedChange(Double)
    case pauseSegment
    case skipSegment
    case extendSegment(TimeInterval)
    case emergencyStop
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "speedChange":
            let speed = try container.decode(Double.self, forKey: .value)
            self = .speedChange(speed)
        case "pauseSegment":
            self = .pauseSegment
        case "skipSegment":
            self = .skipSegment
        case "extendSegment":
            let duration = try container.decode(TimeInterval.self, forKey: .value)
            self = .extendSegment(duration)
        case "emergencyStop":
            self = .emergencyStop
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown override type: \(type)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .speedChange(let speed):
            try container.encode("speedChange", forKey: .type)
            try container.encode(speed, forKey: .value)
        case .pauseSegment:
            try container.encode("pauseSegment", forKey: .type)
        case .skipSegment:
            try container.encode("skipSegment", forKey: .type)
        case .extendSegment(let duration):
            try container.encode("extendSegment", forKey: .type)
            try container.encode(duration, forKey: .value)
        case .emergencyStop:
            try container.encode("emergencyStop", forKey: .type)
        }
    }
}

// MARK: - Validation System

struct ValidationError: Identifiable, Hashable {
    let id = UUID()
    let type: ValidationErrorType
    let message: String
    let segmentId: UUID?
    let suggestion: String?
    
    init(type: ValidationErrorType, message: String, segmentId: UUID? = nil, suggestion: String? = nil) {
        self.type = type
        self.message = message
        self.segmentId = segmentId
        self.suggestion = suggestion
    }
}

enum ValidationErrorType: String, Codable, CaseIterable, Hashable {
    case speedOutOfRange
    case durationTooShort
    case durationTooLong
    case conflictingSettings
    case emptyPlan
    case invalidTransition
    case invalidInput
    case missingRequired
    case invalidRange
    case planOptimization
    
    var displayName: String {
        switch self {
        case .speedOutOfRange: return "Speed Out of Range"
        case .durationTooShort: return "Duration Too Short"
        case .durationTooLong: return "Duration Too Long"
        case .conflictingSettings: return "Conflicting Settings"
        case .emptyPlan: return "Empty Plan"
        case .invalidTransition: return "Invalid Transition"
        case .invalidInput: return "Invalid Input"
        case .missingRequired: return "Missing Required"
        case .invalidRange: return "Invalid Range"
        case .planOptimization: return "Plan Optimization"
        }
    }
}