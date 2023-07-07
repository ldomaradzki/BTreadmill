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
                        let viewContext = persistence.container.viewContext
                        let newRun = Run(context: viewContext)
                        newRun.startTimestamp = Date()
                        newRun.endTimestamp = Date()
                        newRun.completed = false
                        
                        runSession = RunSession(run: newRun)
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
    
    @MainActor
    func shareOnStrava(run: Run) async -> Int? {
        await stravaService.sendPost(
            startDate: run.startTimestamp!,
            elapsedTimeSeconds: Int(run.duration.converted(to: .seconds).value),
            distanceMeters: run.distance.converted(to: .meters).value)
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
        let viewContext = persistence.container.viewContext
        
        runSession?.run.endTimestamp = .now
        runSession?.run.completed = true
        do {
            try viewContext.save()
            self.runSession = nil
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
