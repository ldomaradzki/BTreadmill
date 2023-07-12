//
//  ContentViewModel.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 01/07/2023.
//

import Foundation
import Combine
import SwiftUI

class ContentViewModel: ObservableObject {
    private var bag = Set<AnyCancellable>()
    private let stravaService = StravaService()
    private let treadmillService = TreadmillService()
    private let appDatabase: AppDatabase
    
    private var runSession: RunSession?
    var paused: Bool = false

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
                    if paused, previousState == .starting {
                        paused = false
                    }
                    runSession?.allRunningStates.append(runningState)
                    
                    runningSpeed = runningState.speed
                    distance = runningState.distance
                case .stopping(let runningState):
                    runSession?.allRunningStates.append(runningState)
                    
                    runningSpeed = runningState.speed
                    distance = runningState.distance
                case .idling:
                    if let runSession {
                        if !paused {
                            runSession.endDate = Date()
                            Task { [weak self] in await self?.save(runSession: self?.runSession) }
                        } else {
                            runSession.runData.distanceMetersOffset += runSession.runData.distanceMeters
                            Task { [weak self] in await self?.update(runData: runSession.runData) }
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
    
    @MainActor
    func shareOnStrava(runData: RunData) async -> Int? {
        await stravaService.sendPost(
            startDate: runData.startTimestamp,
            elapsedTimeSeconds: Int(runData.duration.converted(to: .seconds).value),
            distanceMeters: runData.distance.converted(to: .meters).value)
    }
    
    @MainActor
    func updateUploadedId(runData: RunData, id: Int) async {
        runData.uploadedId = "\(id)"
        await update(runData: runData)
    }
    
    @MainActor
    func update(runData: RunData) async {
        await appDatabase.updateRunData(runData)
    }
    
    @MainActor
    func remove(runData: RunData) async {
        await appDatabase.removeRunData(runData)
    }
    
    @MainActor
    private func save(runSession: RunSession?) async {
        guard let runSession else { return }

        runSession.runData.endTimestamp = .now
        runSession.runData.completed = true
        await appDatabase.saveRunData(&runSession.runData)
        
        self.runSession = nil
    }
}
