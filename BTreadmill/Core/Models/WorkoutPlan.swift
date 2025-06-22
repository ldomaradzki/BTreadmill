import Foundation

// MARK: - WorkoutPlan Core Model

struct WorkoutPlan: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var segments: [AnyWorkoutSegment]
    var globalSettings: GlobalPlanSettings
    var tags: [String]
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        segments: [AnyWorkoutSegment] = [],
        globalSettings: GlobalPlanSettings = GlobalPlanSettings(),
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.segments = segments
        self.globalSettings = globalSettings
        self.tags = tags
    }
    
    // MARK: - Computed Properties
    
    var estimatedDuration: TimeInterval? {
        let segmentDurations = segments.compactMap { $0.segment.estimatedDuration() }
        guard segmentDurations.count == segments.count else { return nil }
        return segmentDurations.reduce(0, +)
    }
    
    var totalDistance: Measurement<UnitLength>? {
        guard let duration = estimatedDuration else { return nil }
        let averageSpeed = speedRange.lowerBound + (speedRange.upperBound - speedRange.lowerBound) / 2
        let distanceKm = averageSpeed * (duration / 3600) // Convert to hours
        return Measurement(value: distanceKm, unit: UnitLength.kilometers)
    }
    
    var speedRange: ClosedRange<Double> {
        let speeds = segments.flatMap { $0.segment.speedRange() }
        guard !speeds.isEmpty else { return 1.0...6.0 }
        return speeds.min()!...speeds.max()!
    }
}

// MARK: - Global Plan Settings

struct GlobalPlanSettings: Codable, Hashable {
    var maxDuration: TimeInterval?           // Optional time limit
    var autoStopOnCompletion: Bool           // Stop treadmill when plan ends
    var allowManualOverride: Bool            // Allow speed changes during execution
    var pauseBehavior: PauseBehavior         // How pausing affects plan timing
    var warmupSpeed: Double?                 // Optional warmup before plan starts
    var cooldownSpeed: Double?               // Optional cooldown after plan ends
    var emergencyStopEnabled: Bool           // Emergency stop behavior
    
    init(
        maxDuration: TimeInterval? = nil,
        autoStopOnCompletion: Bool = true,
        allowManualOverride: Bool = true,
        pauseBehavior: PauseBehavior = .holdPosition,
        warmupSpeed: Double? = nil,
        cooldownSpeed: Double? = nil,
        emergencyStopEnabled: Bool = true
    ) {
        self.maxDuration = maxDuration
        self.autoStopOnCompletion = autoStopOnCompletion
        self.allowManualOverride = allowManualOverride
        self.pauseBehavior = pauseBehavior
        self.warmupSpeed = warmupSpeed
        self.cooldownSpeed = cooldownSpeed
        self.emergencyStopEnabled = emergencyStopEnabled
    }
}

enum PauseBehavior: String, Codable, CaseIterable, Hashable {
    case holdPosition      // Pause both timer and segment progression
    case continueTimer     // Keep timer running, hold segment
    case resetSegment      // Reset current segment when resumed
    
    var displayName: String {
        switch self {
        case .holdPosition: return "Hold Position"
        case .continueTimer: return "Continue Timer"
        case .resetSegment: return "Reset Segment"
        }
    }
}