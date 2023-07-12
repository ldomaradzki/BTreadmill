//
//  ContentViewModel.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 01/07/2023.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    private var bag = Set<AnyCancellable>()
    private let stravaService = StravaService()
    private let treadmillService = TreadmillService()
    private let appDatabase: AppDatabase
    
    private var runSession: RunSession?

    @Published var bluetoothState: Bool = false
    @Published var showAlert = false
    @Published var runningSpeed: Measurement<UnitSpeed>?
    @Published var distance: Measurement<UnitLength>?
    @Published var treadmillState: TreadmillState = .unknown
    
    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
        
        treadmillService.isConnectedPublisher
            .sink { [weak self] in
                self?.bluetoothState = $0
            }.store(in: &bag)
        
        treadmillService.statePublisher
            .scan((.unknown, .unknown), { state1, state2 -> (TreadmillState, TreadmillState) in
                return (state1.1, state2)
            })
            .sink { [weak self] previousState, state in
                guard let self else { return }
                
                self.treadmillState = state
                
                switch state {
                case .starting:
                    if runSession == nil {
                        let newRunData = RunData(startTimestamp: .now)
                        
                        runSession = RunSession(runData: newRunData, viewModel: self)
                    }
                case .running(let runningState):
                    if let runSession {
                        if runSession.runData.paused, previousState == .starting {
                            runSession.runData.paused = false
                            await self.update(runData: runSession.runData)
                        }
                        runSession.allRunningStates.append(runningState)
                    }
                    
                    runningSpeed = runningState.speed
                    distance = runningState.distance
                case .stopping(let runningState):
                    runSession?.allRunningStates.append(runningState)
                    
                    runningSpeed = runningState.speed
                    distance = runningState.distance
                case .idling:
                    if let runSession {
                        if !runSession.runData.paused {
                            runSession.endDate = Date()
                            await self.save(runSession: runSession)
                        } else if case .stopping(_) = previousState {
                            runSession.runData.distanceMetersOffset += runSession.runData.distanceMeters
                            runSession.runData.distanceMeters = 0
                            await self.update(runData: runSession.runData)
                        }
                    }
                    
                    runningSpeed = nil
                    distance = nil
                case .hibernated, .unknown: break
                }
            }.store(in: &bag)
    }
    
    func sendCommand(_ command: TreadmillCommand) {
        treadmillService.sendCommand(command)
    }
    
    func pauseRun() async {
        guard let runSession else { return }
        runSession.runData.paused = true
        await update(runData: runSession.runData)
    }
    
    func closePausedRun(_ runData: RunData) async {
        await save(runData: runData)
    }
    
    func shareOnStrava(runData: RunData) async -> Int? {
        await stravaService.sendPost(
            startDate: runData.startTimestamp,
            elapsedTimeSeconds: Int(runData.duration.converted(to: .seconds).value),
            distanceMeters: runData.distance.converted(to: .meters).value)
    }
    
    func updateUploadedId(runData: RunData, id: Int) async {
        runData.uploadedId = "\(id)"
        await update(runData: runData)
    }
    
    func update(runData: RunData) async {
        await appDatabase.updateRunData(runData)
    }
    
    func remove(runData: RunData) async {
        await appDatabase.removeRunData(runData)
    }
    
    private func save(runSession: RunSession?) async {
        guard let runSession else { return }

        await save(runData: runSession.runData)
        self.runSession = nil
    }
    
    private func save(runData: RunData) async {
        runData.completed = true
        runData.paused = false
        await appDatabase.updateRunData(runData)
    }
}
