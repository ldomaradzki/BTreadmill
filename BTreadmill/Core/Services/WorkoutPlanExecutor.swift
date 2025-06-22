import Foundation
import Combine

class WorkoutPlanExecutor: ObservableObject {
    // MARK: - Published Properties
    @Published var currentPlan: WorkoutPlan?
    @Published var isExecuting: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentSegmentIndex: Int = 0
    @Published var segmentProgress: Double = 0.0
    @Published var overallProgress: Double = 0.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var segmentElapsedTime: TimeInterval = 0
    @Published var estimatedRemainingTime: TimeInterval?
    @Published var currentSegmentName: String?
    @Published var currentTargetSpeed: Double = 1.0
    @Published var nextTransition: TimeInterval?
    
    // MARK: - Private Properties
    private var executionTimer: Timer?
    private var planStartTime: Date?
    private var segmentStartTime: Date?
    private var totalPauseTime: TimeInterval = 0
    private var pauseStartTime: Date?
    
    // MARK: - Dependencies
    private let workoutManager: WorkoutManager
    
    // MARK: - Simulation
    private var timeAccelerationFactor: Double {
        // In simulator mode, accelerate time to match simulation (60x speed)
        return SettingsManager.shared.userProfile.simulatorMode ? 60.0 : 1.0
    }
    
    init(workoutManager: WorkoutManager) {
        self.workoutManager = workoutManager
    }
    
    // MARK: - Public Methods
    
    func startExecution(plan: WorkoutPlan) {
        guard !isExecuting else { return }
        
        currentPlan = plan
        isExecuting = true
        isPaused = false
        currentSegmentIndex = 0
        segmentProgress = 0.0
        overallProgress = 0.0
        elapsedTime = 0
        segmentElapsedTime = 0
        totalPauseTime = 0
        
        planStartTime = Date()
        segmentStartTime = Date()
        
        print("🎯 Starting plan execution: \(plan.name)")
        if timeAccelerationFactor > 1.0 {
            print("⚡ Simulator mode: \(timeAccelerationFactor)x time acceleration")
        }
        
        // Start the first segment
        startCurrentSegment()
        
        // Start execution timer
        startExecutionTimer()
    }
    
    func pauseExecution() {
        guard isExecuting && !isPaused else { return }
        
        isPaused = true
        pauseStartTime = Date()
        stopExecutionTimer()
        
        print("⏸️ Plan execution paused")
    }
    
    func resumeExecution() {
        guard isExecuting && isPaused else { return }
        
        isPaused = false
        
        // Add pause time to total (accelerated in simulator mode)
        if let pauseStart = pauseStartTime {
            totalPauseTime += Date().timeIntervalSince(pauseStart) * timeAccelerationFactor
            pauseStartTime = nil
        }
        
        startExecutionTimer()
        
        print("▶️ Plan execution resumed")
    }
    
    func stopExecution() {
        guard isExecuting else { return }
        
        isExecuting = false
        isPaused = false
        stopExecutionTimer()
        
        currentPlan = nil
        currentSegmentIndex = 0
        segmentProgress = 0.0
        overallProgress = 0.0
        elapsedTime = 0
        segmentElapsedTime = 0
        
        print("⏹️ Plan execution stopped")
    }
    
    func skipCurrentSegment() {
        guard isExecuting && !isPaused else { return }
        guard let plan = currentPlan else { return }
        guard currentSegmentIndex < plan.segments.count else { return }
        
        print("⏭️ Skipping segment \(currentSegmentIndex + 1)")
        
        // Move to next segment
        currentSegmentIndex += 1
        
        if currentSegmentIndex >= plan.segments.count {
            completePlan()
        } else {
            startCurrentSegment()
        }
    }
    
    // MARK: - Private Methods
    
    private func startExecutionTimer() {
        stopExecutionTimer()
        
        executionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateExecution()
        }
    }
    
    private func stopExecutionTimer() {
        executionTimer?.invalidate()
        executionTimer = nil
    }
    
    private func startCurrentSegment() {
        guard let plan = currentPlan else { return }
        guard currentSegmentIndex < plan.segments.count else { return }
        
        let segment = plan.segments[currentSegmentIndex]
        segmentStartTime = Date()
        segmentElapsedTime = 0
        segmentProgress = 0.0
        
        currentSegmentName = segment.segment.name ?? "Segment \(currentSegmentIndex + 1)"
        
        // Execute the segment to get initial state
        let context = createExecutionContext()
        let execution = segment.segment.execute(at: 0, context: context)
        
        nextTransition = execution.nextTransition
        
        // Update treadmill speed (this will update currentTargetSpeed)
        updateTreadmillSpeed(execution.currentSpeed)
        
        print("🏃 Started segment \(currentSegmentIndex + 1)/\(plan.segments.count): \(currentSegmentName ?? "Unknown")")
        print("   Target speed: \(execution.currentSpeed) km/h")
    }
    
    private func updateExecution() {
        guard let plan = currentPlan else { return }
        guard let planStart = planStartTime else { return }
        guard let segmentStart = segmentStartTime else { return }
        guard currentSegmentIndex < plan.segments.count else { return }
        
        let now = Date()
        
        // Calculate elapsed times (accelerated in simulator mode)
        let rawElapsedTime = now.timeIntervalSince(planStart) - totalPauseTime
        let rawSegmentElapsedTime = now.timeIntervalSince(segmentStart)
        
        elapsedTime = rawElapsedTime * timeAccelerationFactor
        segmentElapsedTime = rawSegmentElapsedTime * timeAccelerationFactor
        
        let segment = plan.segments[currentSegmentIndex]
        
        // Execute current segment
        let context = createExecutionContext()
        let execution = segment.segment.execute(at: segmentElapsedTime, context: context)
        
        // Update segment progress
        segmentProgress = execution.progress
        nextTransition = execution.nextTransition
        
        // Update treadmill speed if changed
        updateTreadmillSpeed(execution.currentSpeed)
        
        // Update overall progress
        updateOverallProgress()
        
        // Check if segment is complete
        if execution.isComplete {
            completeCurrentSegment()
        }
        
        // Update estimated remaining time
        updateEstimatedRemainingTime()
    }
    
    private func completeCurrentSegment() {
        guard let plan = currentPlan else { return }
        
        print("✅ Completed segment \(currentSegmentIndex + 1)/\(plan.segments.count)")
        
        currentSegmentIndex += 1
        
        if currentSegmentIndex >= plan.segments.count {
            completePlan()
        } else {
            startCurrentSegment()
        }
    }
    
    private func completePlan() {
        guard let plan = currentPlan else { return }
        
        print("🎉 Plan completed: \(plan.name)")
        
        // Check if auto-stop is enabled
        if plan.globalSettings.autoStopOnCompletion {
            // Stop the workout entirely
            workoutManager.endCurrentWorkout()
        }
        
        stopExecution()
    }
    
    private func createExecutionContext() -> ExecutionContext {
        return ExecutionContext(
            planStartTime: planStartTime ?? Date(),
            currentTime: Date(),
            elapsedTime: elapsedTime,
            totalPauseTime: totalPauseTime,
            currentSegmentIndex: currentSegmentIndex,
            userOverrides: [], // TODO: Implement overrides
            treadmillState: .running(RunningState(
                timestamp: Date(),
                speed: currentTargetSpeed,
                distance: 0,
                steps: 0
            ))
        )
    }
    
    private func updateTreadmillSpeed(_ targetSpeed: Double) {
        // Only update if speed has changed significantly
        let speedDifference = abs(targetSpeed - currentTargetSpeed)
        print("📊 Speed check: target=\(targetSpeed), current=\(currentTargetSpeed), diff=\(speedDifference)")
        
        if speedDifference >= 0.1 {
            currentTargetSpeed = targetSpeed
            workoutManager.setTreadmillSpeed(targetSpeed)
            print("🎛️ Updated speed to \(targetSpeed) km/h")
        } else {
            print("⏸️ Speed unchanged (diff < 0.1)")
        }
    }
    
    private func updateOverallProgress() {
        guard let plan = currentPlan else { return }
        guard let totalDuration = plan.estimatedDuration else { return }
        
        // Calculate progress based on elapsed time
        overallProgress = min(elapsedTime / totalDuration, 1.0)
    }
    
    private func updateEstimatedRemainingTime() {
        guard let plan = currentPlan else { return }
        guard let totalDuration = plan.estimatedDuration else { return }
        
        let remaining = totalDuration - elapsedTime
        estimatedRemainingTime = max(remaining, 0)
    }
    
    // MARK: - Public Computed Properties
    
    var currentSegmentDisplayText: String {
        guard let plan = currentPlan else { return "" }
        guard currentSegmentIndex < plan.segments.count else { return "" }
        
        let segmentNumber = currentSegmentIndex + 1
        let totalSegments = plan.segments.count
        let segmentName = currentSegmentName ?? "Segment \(segmentNumber)"
        
        return "\(segmentNumber)/\(totalSegments): \(segmentName)"
    }
    
    var progressDisplayText: String {
        let progressPercent = Int(segmentProgress * 100)
        return "\(progressPercent)%"
    }
    
    var remainingTimeDisplayText: String {
        guard let remaining = estimatedRemainingTime else { return "" }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s remaining"
        } else {
            return "\(seconds)s remaining"
        }
    }
}

