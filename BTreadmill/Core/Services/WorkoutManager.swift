import Foundation
import Combine
import OSLog

extension Notification.Name {
    static let treadmillServiceReset = Notification.Name("treadmillServiceReset")
}

class WorkoutManager: ObservableObject {
    private let logger = Logger(subsystem: "BTreadmill", category: "workout")
    private var bag = Set<AnyCancellable>()
    
    @Published var currentWorkout: WorkoutSession?
    @Published var isWorkoutActive: Bool = false
    @Published var workoutHistory: [WorkoutSession] = []
    
    // Plan execution
    @Published var planExecutor: WorkoutPlanExecutor?
    @Published var currentExecutingPlan: WorkoutPlan?
    
    // Workout statistics
    private let currentWorkoutSubject = CurrentValueSubject<WorkoutSession?, Never>(nil)
    var currentWorkoutPublisher: AnyPublisher<WorkoutSession?, Never> {
        currentWorkoutSubject.eraseToAnyPublisher()
    }
    
    private var treadmillService: TreadmillServiceProtocol {
        return TreadmillService.shared
    }
    
    init() {
        // Initialize plan executor
        planExecutor = WorkoutPlanExecutor(workoutManager: self)
        
        setupSubscriptions()
        
        // Load existing workout history from persistent storage after services are set up
        loadWorkoutHistory()
        
        // Listen for service changes
        NotificationCenter.default.publisher(for: .treadmillServiceReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupSubscriptions()
            }
            .store(in: &bag)
    }
    
    private func setupSubscriptions() {
        // Clear existing subscriptions except for the service reset notification
        bag.removeAll()
        
        // Subscribe to treadmill state changes
        treadmillService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleTreadmillStateChange(state)
            }
            .store(in: &bag)
        
        // Subscribe to current workout changes to publish updates
        $currentWorkout
            .sink { [weak self] workout in
                self?.currentWorkoutSubject.send(workout)
            }
            .store(in: &bag)
        
        // Re-add the service reset notification
        NotificationCenter.default.publisher(for: .treadmillServiceReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupSubscriptions()
            }
            .store(in: &bag)
    }
    
    // MARK: - Workout Control
    
    func startWorkout() {
        guard currentWorkout == nil else {
            logger.warning("Attempted to start workout while one is already active")
            return
        }
        
        // Determine if this is a demo workout based on simulator mode
        let isDemo = SettingsManager.shared.userProfile.simulatorMode
        currentWorkout = WorkoutSession(isDemo: isDemo)
        isWorkoutActive = true
        
        
        // Send start command to treadmill
        treadmillService.sendCommand(.start)
    }
    
    func startWorkoutWithPlan(_ plan: WorkoutPlan) {
        guard currentWorkout == nil else {
            logger.warning("Attempted to start workout with plan while one is already active")
            return
        }
        
        // Start regular workout first
        startWorkout()
        
        // Then start plan execution
        currentExecutingPlan = plan
        planExecutor?.startExecution(plan: plan)
        
        logger.info("Started workout with plan: \(plan.name)")
    }
    
    func pauseWorkout() {
        guard var workout = currentWorkout, !workout.isPaused else {
            logger.warning("Attempted to pause workout that is not active or already paused")
            return
        }
        
        workout.pause()
        currentWorkout = workout
        
        // Pause plan execution if active
        planExecutor?.pauseExecution()
        
        // Stop the treadmill
        treadmillService.sendCommand(.stop)
    }
    
    func resumeWorkout() {
        guard var workout = currentWorkout, workout.isPaused else {
            logger.warning("Attempted to resume workout that is not paused")
            return
        }
        
        let speedToRestore = workout.speedBeforePause
        workout.resume()
        currentWorkout = workout
        
        // Resume plan execution if active
        planExecutor?.resumeExecution()
        
        // Start the treadmill again
        treadmillService.sendCommand(.start)
        
        // For plan workouts, the plan executor will handle speed control
        // For free workouts, restore the previous speed
        if currentExecutingPlan == nil && speedToRestore > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.treadmillService.sendCommand(.speed(speedToRestore))
            }
        }
    }
    
    func endCurrentWorkout() {
        guard var workout = currentWorkout else {
            logger.warning("Attempted to end workout when none is active")
            return
        }
        
        workout.end()
        isWorkoutActive = false
        
        // Stop plan execution if active
        planExecutor?.stopExecution()
        currentExecutingPlan = nil
        
        // Save the completed workout
        saveWorkout(workout)
        
        // Clear current workout
        currentWorkout = nil
        
        // Stop the treadmill
        treadmillService.sendCommand(.stop)
    }
    
    func setTreadmillSpeed(_ speed: Double) {
        guard isWorkoutActive else {
            logger.warning("Attempted to set speed without active workout")
            return
        }
        
        let clampedSpeed = speed.clamped(to: 1.0, and: 6.0)
        treadmillService.sendCommand(.speed(clampedSpeed))
        
    }
    
    func skipCurrentSegment() {
        guard currentExecutingPlan != nil else {
            logger.warning("Attempted to skip segment but no plan is executing")
            return
        }
        
        planExecutor?.skipCurrentSegment()
    }
    
    // MARK: - Private Methods
    
    private func handleTreadmillStateChange(_ state: TreadmillState) {
        guard var workout = currentWorkout else { return }
        
        switch state {
        case .running(let runningState):
            // Track speed data for chart (only when not paused)
            if !workout.isPaused {
                workout.speedHistory.append(runningState.speed)
            }
            
            // Update workout with current treadmill data
            workout.updateWith(runningState: runningState)
            
            // If workout was paused but treadmill is running, resume it
            if workout.isPaused && isWorkoutActive {
                workout.resume()
            }
            
            currentWorkout = workout
            
        case .stopping(let runningState):
            // Track final speed data if not paused
            if !workout.isPaused {
                workout.speedHistory.append(runningState.speed)
            }
            
            // Update workout with final state but don't auto-pause
            workout.updateWith(runningState: runningState)
            currentWorkout = workout
            
        case .idling, .hibernated:
            // Only auto-pause if the user didn't manually pause
            // and the treadmill has been idle for a significant time
            // This prevents premature pausing during startup
            break
            
        default:
            break
        }
    }
    
    private func saveWorkout(_ workout: WorkoutSession) {
        // Save to SettingsManager which handles JSON persistence
        SettingsManager.shared.addWorkout(workout)
        
        // Update local in-memory copy to stay in sync
        workoutHistory.insert(workout, at: 0)
        
    }
    
    // MARK: - Workout History
    
    private func loadWorkoutHistory() {
        // Ensure SettingsManager is fully initialized before accessing workout history
        DispatchQueue.main.async { [weak self] in
            self?.workoutHistory = SettingsManager.shared.workoutHistory
        }
    }
    
    func getWorkoutHistory() -> [WorkoutSession] {
        // Get the latest data from SettingsManager
        return SettingsManager.shared.workoutHistory
    }
    
    func deleteWorkout(id: UUID) {
        SettingsManager.shared.deleteWorkout(id: id)
        workoutHistory.removeAll { $0.id == id }
    }
    
    func updateWorkout(_ workout: WorkoutSession) {
        SettingsManager.shared.updateWorkout(workout)
        
        // Update local in-memory copy
        if let index = workoutHistory.firstIndex(where: { $0.id == workout.id }) {
            workoutHistory[index] = workout
        }
    }
}