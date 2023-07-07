//
//  RunSession.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 06/07/2023.
//

import Foundation

class RunSession {
    let run: Run
    
    let startDate = Date()
    var endDate: Date? = nil {
        didSet {
            run.endTimestamp = endDate
        }
    }
    var lastRunningState: RunningState? { allRunningStates.last }
    var allRunningStates: [RunningState] = [] {
        didSet {
            guard let lastRunningState else { return }
            
            run.endTimestamp = Date()
            run.distanceMeters = lastRunningState.distance.converted(to: .meters).value
            run.speeds = allRunningStates.map { $0.speed.converted(to: .kilometersPerHour).value } as NSObject
        }
    }
    
    init(run: Run) {
        self.run = run
    }
}
