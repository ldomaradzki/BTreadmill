//
//  TreadmillCommand.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 05/07/2023.
//

import Foundation

enum TreadmillCommand {
    case start
    case speed(Double)
    case stop
    
    func toData() -> Data {
        switch self {
            
        case .start:
            return Data(hexString: "FB07A201010500B0FC")!
        case let .speed(value):
            let speed = Int(value.clamped(to: 1.0, and: 6.0) * 10)
            let hexString = "FB07A10201\(speed.toHex())00\((171+speed).toHex())FC"
            return Data(hexString: hexString)!
        case .stop:
            return Data(hexString: "FB07A204010000AEFC")!
        }
    }
}
