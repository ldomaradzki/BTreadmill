import Foundation
import Combine
import OSLog

protocol TreadmillServiceProtocol {
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    var statePublisher: AnyPublisher<TreadmillState, Never> { get }
    func sendCommand(_ command: TreadmillCommand)
}

class TreadmillServiceMock: TreadmillServiceProtocol {
    var statePublisher: AnyPublisher<TreadmillState, Never> {
        Just(TreadmillState.unknown).eraseToAnyPublisher()
    }
    
    var isConnectedMock: Bool = false
    
    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        Just(isConnectedMock).eraseToAnyPublisher()
    }
    
    func sendCommand(_ command: TreadmillCommand) {
        // Command ignored in mock
    }
}

class TreadmillService: TreadmillServiceProtocol {
    private let logger = Logger(subsystem: "BTreadmill", category: "treadmill")
    private var bag = Set<AnyCancellable>()
    private let bluetoothService = BluetoothService()
    private let treadmillStateSubject = CurrentValueSubject<TreadmillState, Never>(.unknown)
    
    // MARK: - Public
    
    var statePublisher: AnyPublisher<TreadmillState, Never> { treadmillStateSubject.eraseToAnyPublisher() }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { bluetoothService.isConnectedPublisher }
    
    private static var _shared: TreadmillServiceProtocol?
    
    static var shared: TreadmillServiceProtocol {
        if let existing = _shared {
            return existing
        }
        
        // Check if simulator mode is enabled in settings
        if SettingsManager.shared.userProfile.simulatorMode {
            _shared = TreadmillSimulatorService()
            return _shared!
        }
        
        #if targetEnvironment(simulator)
        let treadmillService = TreadmillServiceMock()
        treadmillService.isConnectedMock = true
        _shared = treadmillService
        return _shared!
        #else
        _shared = TreadmillService()
        return _shared!
        #endif
    }
    
    static func resetShared() {
        _shared = nil
        NotificationCenter.default.post(name: .treadmillServiceReset, object: nil)
    }
    
    init() {
        bluetoothService.dataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rawStream in
                guard let self, !rawStream.isEmpty else { return }

                let state = self.parseState(rawStream)
                self.treadmillStateSubject.send(state)
            }.store(in: &bag)
    }
    
    func sendCommand(_ command: TreadmillCommand) {
        bluetoothService.sendCommand(data: command.toData()) { [weak self] result in
            if case .failure(let error) = result {
                self?.logger.error("Failed to send command: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        // Cancel all subscriptions
        bag.removeAll()
    }
    
    private func parseState(_ rawStream: [Int]) -> TreadmillState {
        if rawStream.count < 18 {
            if rawStream.count > 1 && rawStream[1] == 4 {
                return .hibernated
            }
            return .idling
        }
        
        guard rawStream.count > 3 else {
            logger.warning("Treadmill data too short: \(rawStream)")
            return .idling
        }
        
        switch rawStream[3] {
            case 1:
                return .starting
            case 2:
                let runningState = self.parseRunningState(rawStream)
                return .running(runningState)
            case 4, 5:
                let runningState = self.parseRunningState(rawStream)
                return .stopping(runningState)
            default:
                    return .idling
        }
    }
    
    private func parseRunningState(_ rawStream: [Int]) -> RunningState {
        guard rawStream.count >= 13 else {
            logger.warning("Data packet too small for running state: \(rawStream)")
            return .init(timestamp: .now, 
                        speed: 0, 
                        distance: 0,
                        strideLength: SettingsManager.shared.userProfile.strideLength.converted(to: .meters).value)
        }
        
        let doubleValues = rawStream.map { Double($0) }
        let currentSpeed = doubleValues[5] / 10.0
        let distance = doubleValues[12] / 100.0
        let distanceOffset = (rawStream.count > 11) ? doubleValues[11] / 100.0 : 0.0
        
        let totalDistance = distance + (distanceOffset * 256)
        
        // Step count is calculated in the RunningState initializer based on distance and user's stride length
        return .init(timestamp: .now, speed: currentSpeed, distance: totalDistance, strideLength: SettingsManager.shared.userProfile.strideLength.converted(to: .meters).value)
    }
}