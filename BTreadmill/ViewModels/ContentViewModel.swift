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
    class RunSession {
        let startDate = Date()
        var endDate: Date? = nil
        var lastRunningState: RunningState? { allRunningStates.last }
        var allRunningStates: [RunningState] = []
    }
    
    private var bag = Set<AnyCancellable>()
    private let persistence = PersistenceController.shared
    private let stravaService = StravaService()
    private let treadmillService = TreadmillService()
    
    private var runSession: RunSession?
    
    @Published var bluetoothState: Bool = false
    @Published var showAlert = false
    @Published var runningSpeed: Measurement<UnitSpeed>?
    @Published var distance: Measurement<UnitLength>?
    @Published var treadmillState: TreadmillState = .unknown
    
    init() {
        treadmillService.isConnectedPublisher
            .sink { [weak self] in
                self?.bluetoothState = $0
            }.store(in: &bag)
        
        treadmillService.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                
                self.treadmillState = state
                
                switch state {
                case .starting:
                    if runSession == nil {
                        runSession = RunSession()
                    }
                case .running(let runningState):
                    runSession?.allRunningStates.append(runningState)
                    
                    runningSpeed = runningState.speed
                    distance = runningState.distance
                case .stopping(let runningState):
                    runSession?.allRunningStates.append(runningState)
                    
                    runningSpeed = runningState.speed
                    distance = runningState.distance
                case .idling:
                    if runSession != nil {
                        runSession?.endDate = Date()
                        self.save(runSession: runSession)
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
    
    func shareOnStrava(run: Run) async -> Int? {
        await stravaService.sendPost(
            startDate: run.startTimestamp!,
            elapsedTime: run.duration,
            distance: run.distance)
    }
    
    func updateUploadedId(run: Run, id: Int) {
        let viewContext = persistence.container.viewContext
        
        run.uploadedId = Int64(id)
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func remove(run: Run) {
        let viewContext = persistence.container.viewContext
        
        viewContext.delete(run)
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func save(runSession: RunSession?) {
        guard let runSession, let lastRunningState = runSession.lastRunningState else {
            return
        }
        
        let viewContext = persistence.container.viewContext
        
        let newRun = Run(context: viewContext)
        newRun.startTimestamp = runSession.startDate
        newRun.endTimestamp = runSession.endDate
        newRun.distanceMeters = lastRunningState.distance.converted(to: .meters).value
        newRun.speeds = runSession.allRunningStates.map { $0.speed.converted(to: .kilometersPerHour).value } as NSObject

        do {
            try viewContext.save()
            self.runSession = nil
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
