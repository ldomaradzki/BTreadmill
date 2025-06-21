import Foundation
import Combine
import OSLog

class TreadmillSimulatorService: TreadmillServiceProtocol {
    private let logger = Logger(subsystem: "BTreadmill", category: "simulator")
    private var cancellables = Set<AnyCancellable>()
    
    // Published state
    private let isConnectedSubject = CurrentValueSubject<Bool, Never>(true)
    private let stateSubject = CurrentValueSubject<TreadmillState, Never>(.idling)
    
    // Simulation state
    private var currentSpeed: Double = 0.0
    private var currentDistance: Double = 0.0
    private var isRunning = false
    private var simulationTimer: Timer?
    private let simulationUpdateInterval: TimeInterval = 0.5 // Update every 0.5 seconds for smoother demo
    private let demoAccelerationFactor: Double = 60.0 // Make demo 60x faster (1 minute = 1 hour)
    
    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        isConnectedSubject.eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<TreadmillState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    init() {
        // Start in connected state
        isConnectedSubject.send(true)
    }
    
    deinit {
        stopSimulation()
    }
    
    func sendCommand(_ command: TreadmillCommand) {
        
        switch command {
        case .start:
            startSimulation()
        case .speed(let speed):
            updateSpeed(speed)
        case .stop:
            stopSimulation()
        }
    }
    
    private func startSimulation() {
        guard !isRunning else { return }
        
        isRunning = true
        currentSpeed = SettingsManager.shared.userProfile.defaultSpeed
        
        // Transition through states: starting -> running
        stateSubject.send(.starting)
        
        // After a brief delay, transition to running
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.beginRunningSimulation()
        }
    }
    
    private func beginRunningSimulation() {
        guard isRunning else { return }
        
        
        // Start the simulation timer on the main run loop
        simulationTimer = Timer.scheduledTimer(withTimeInterval: simulationUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
        RunLoop.main.add(simulationTimer!, forMode: .common)
        
        
        // Send initial running state
        updateSimulation()
    }
    
    private func updateSpeed(_ newSpeed: Double) {
        guard isRunning else { return }
        
        currentSpeed = newSpeed
        
        // Update state immediately
        updateSimulation()
    }
    
    private func updateSimulation() {
        guard isRunning else { 
            logger.warning("updateSimulation called but isRunning is false")
            return 
        }
        
        
        // Simulate distance progression with acceleration for demo purposes
        // Normal: Distance increment = (speed in km/h) * (time interval in hours)
        // Demo: Accelerate by demoAccelerationFactor to show progress faster
        let baseDistanceIncrement = currentSpeed * (simulationUpdateInterval / 3600.0) // Convert seconds to hours
        let acceleratedDistanceIncrement = baseDistanceIncrement * demoAccelerationFactor
        currentDistance += acceleratedDistanceIncrement
        
        // Add some realistic variation to speed (±0.2 km/h for more visible changes)
        let speedVariation = Double.random(in: -0.2...0.2)
        let simulatedSpeed = max(0, currentSpeed + speedVariation)
        
        let runningState = RunningState(
            timestamp: .now,
            speed: simulatedSpeed,
            distance: currentDistance,
            strideLength: SettingsManager.shared.userProfile.strideLength.converted(to: .meters).value
        )
        
        stateSubject.send(.running(runningState))
        
    }
    
    private func stopSimulation() {
        guard isRunning else { return }
        
        
        // Send stopping state with final metrics
        if currentDistance > 0 {
            let finalState = RunningState(
                timestamp: .now,
                speed: 0,
                distance: currentDistance,
                strideLength: SettingsManager.shared.userProfile.strideLength.converted(to: .meters).value
            )
            stateSubject.send(.stopping(finalState))
        }
        
        // Clean up
        simulationTimer?.invalidate()
        simulationTimer = nil
        isRunning = false
        currentSpeed = 0.0
        
        // After a brief delay, transition to idling
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.stateSubject.send(.idling)
            // Reset distance for next session
            self?.currentDistance = 0.0
        }
    }
}