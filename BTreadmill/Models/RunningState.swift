//
//  RunningState.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 05/07/2023.
//

import Foundation

struct RunningState: Equatable {
    let speed: Measurement<UnitSpeed>
    let distance: Measurement<UnitLength>
}
