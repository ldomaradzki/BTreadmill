import Foundation
import Combine
import OSLog

class WorkoutManager: ObservableObject {
    private let logger = Logger(subsystem: "BTreadmill", category: "workout")
    private let treadmillService: TreadmillServiceProtocol
    private var bag = Set<AnyCancellable>()
    
    @Published var currentWorkout: WorkoutSession?
    @Published var isWorkoutActive: Bool = false
    
    // Workout statistics
    private let currentWorkoutSubject = CurrentValueSubject<WorkoutSession?, Never>(nil)
    var currentWorkoutPublisher: AnyPublisher<WorkoutSession?, Never> {
        currentWorkoutSubject.eraseToAnyPublisher()
    }
    
    init(treadmillService: TreadmillServiceProtocol) {
        self.treadmillService = treadmillService
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
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
    }
    
    // MARK: - Workout Control
    
    func startWorkout() {
        guard currentWorkout == nil else {
            logger.warning("Attempted to start workout while one is already active")
            return
        }
        
        currentWorkout = WorkoutSession()
        isWorkoutActive = true
        
        logger.info("Started new workout session: \(self.currentWorkout?.id.uuidString ?? "unknown")")
        
        // Send start command to treadmill
        treadmillService.sendCommand(.start)
    }
    
    func pauseWorkout() {
        guard var workout = currentWorkout, !workout.isPaused else {
            logger.warning("Attempted to pause workout that is not active or already paused")
            return
        }
        
        workout.pause()
        currentWorkout = workout
        
        logger.info("Paused workout session")
        
        // Stop the treadmill
        treadmillService.sendCommand(.stop)
    }
    
    func resumeWorkout() {
        guard var workout = currentWorkout, workout.isPaused else {
            logger.warning("Attempted to resume workout that is not paused")
            return
        }
        
        workout.resume()
        currentWorkout = workout
        
        logger.info("Resumed workout session")
        
        // Start the treadmill again (it will resume from speed 0)
        treadmillService.sendCommand(.start)
    }
    
    func endCurrentWorkout() {
        guard var workout = currentWorkout else {
            logger.warning("Attempted to end workout when none is active")
            return
        }
        
        workout.end()
        isWorkoutActive = false
        
        logger.info("Ended workout session - Distance: \(workout.totalDistance.value) km, Time: \(workout.activeTime) seconds")
        
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
        
        logger.info("Set treadmill speed to \(clampedSpeed) km/h")
    }
    
    // MARK: - Private Methods
    
    private func handleTreadmillStateChange(_ state: TreadmillState) {
        guard var workout = currentWorkout else { return }
        
        switch state {
        case .running(let runningState), .stopping(let runningState):
            // Update workout with current treadmill data
            workout.updateWith(runningState: runningState)
            currentWorkout = workout
            
        case .idling, .hibernated:
            // Treadmill stopped - if we have an active workout, pause it
            if isWorkoutActive && !workout.isPaused {
                pauseWorkout()
            }
            
        default:
            break
        }
    }
    
    private func saveWorkout(_ workout: WorkoutSession) {
        // For now, just log the workout. Later this will save to Core Data
        logger.info("Saving workout: \(workout.id) - \(workout.totalDistance.value) km in \(workout.activeTime) seconds")
        
        // TODO: Implement Core Data persistence
        // DataStore.shared.saveWorkout(workout)
    }
    
    // MARK: - Workout History (placeholder)
    
    func getWorkoutHistory() -> [WorkoutSession] {
        // TODO: Implement Core Data fetch
        // return DataStore.shared.fetchWorkouts()
        return []
    }
    
    func deleteWorkout(id: UUID) {
        // TODO: Implement Core Data deletion
        // DataStore.shared.deleteWorkout(with: id)
        logger.info("Delete workout requested for: \(id)")
    }
}