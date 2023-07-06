//
//  TreadmillService.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 01/07/2023.
//

import Foundation
import Combine
import OSLog

class TreadmillService {
    private let logger = Logger(subsystem: "Treadmill", category: "state")
    private var bag = Set<AnyCancellable>()
    private let bluetoothService = BluetoothService()
    
    private let treadmillStateSubject = CurrentValueSubject<TreadmillState, Never>(.unknown)
    
    // MARK: - Public
    
    var statePublisher: AnyPublisher<TreadmillState, Never> { treadmillStateSubject.eraseToAnyPublisher() }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { bluetoothService.isConnectedPublisher }
    
    init() {
        bluetoothService.dataPublisher.sink { [weak self] rawStream in
            guard let self, !rawStream.isEmpty else { return }

            let state = self.parseState(rawStream)
            self.treadmillStateSubject.send(state)
        }.store(in: &bag)
    }
    
    func sendCommand(_ command: TreadmillCommand) {
        bluetoothService.sendCommand(data: command.toData())
    }
    
    private func parseState(_ rawStream: [Int]) -> TreadmillState {
        if rawStream.count < 18 {
            if rawStream[1] == 4 {
                logger.debug("Treadmill state: hibernated")
                return .hibernated
            }
            logger.debug("Treadmill state: idling")
            return .idling
        }
        
        switch rawStream[3] {
            case 1:
                logger.debug("Treadmill state: starting")
                return .starting
            case 2:
                let runningState = self.parseRunningState(rawStream)
                logger.debug("Treadmill state: running \(runningState.distance.debugDescription) \(runningState.speed.debugDescription)")
                return .running(runningState)
            case 4, 5:
                let runningState = self.parseRunningState(rawStream)
                logger.debug("Treadmill state: stopping \(runningState.distance.debugDescription) \(runningState.speed.debugDescription)")
                return .stopping(runningState)
            default:
                logger.debug("Treadmill state: idling")
                return .idling
        }
    }
    
    private func parseRunningState(_ rawStream: [Int]) -> RunningState {
        let doubleValues = rawStream.map { Double($0) }
        let currentSpeed = doubleValues[5] / 10.0
        let distance = doubleValues[12] / 100.0
        let distanceOffset = doubleValues[11] / 100.0
        
        let speedMeasurement = Measurement<UnitSpeed>(value: currentSpeed, unit: .kilometersPerHour)
        let distanceMeasurement = Measurement<UnitLength>(value: distance, unit: .kilometers) + Measurement<UnitLength>(value: distanceOffset * 256, unit: .kilometers)
        
        return .init(speed: speedMeasurement, distance: distanceMeasurement)
    }
}
