//
//  RunSession.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 06/07/2023.
//

import Foundation

class RunSession {
    var runData: RunData
    weak var viewModel: ContentViewModel?
    
    let startDate = Date()
    var endDate: Date? = nil {
        didSet {
            runData.endTimestamp = endDate
            
            Task { @MainActor in
                await viewModel?.update(runData: runData)
            }
        }
    }
    var lastRunningState: RunningState? { allRunningStates.last }
    var allRunningStates: [RunningState] = [] {
        didSet {
            guard let lastRunningState else { return }

            runData.endTimestamp = Date()
            runData.distanceMeters = lastRunningState.distance.converted(to: .meters).value
            runData.speeds = allRunningStates.map { $0.speed.converted(to: .kilometersPerHour).value }.map { String($0) }.joined(separator: "|")
            
            Task { @MainActor in
                await viewModel?.update(runData: runData)
            }
        }
    }
    
    init(runData: RunData, viewModel: ContentViewModel) {
        self.runData = runData
        self.viewModel = viewModel
    }
}
