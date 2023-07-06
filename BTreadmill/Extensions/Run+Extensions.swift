//
//  Run+Extensions.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 03/07/2023.
//

import Foundation

extension Run {
    var duration: Measurement<UnitDuration> {
        .init(value: endTimestamp!.timeIntervalSince(startTimestamp!), unit: .seconds)
    }
    
    var distance: Measurement<UnitLength> {
        .init(value: distanceMeters, unit: .meters)
    }
    
    var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.allowsFractionalUnits = true
        
        return formatter.string(from: duration.value)!
    }
    
    var hours: Int {
        Int(duration.converted(to: .hours).value)
    }
    
    var minutesReminder: Int {
        Int(duration.converted(to: .minutes).value) % 60
    }
    
    var speedsArray: [Double]? {
        speeds as? [Double]
    }
    
    var paceString: String {
        let pace = duration.converted(to: .minutes).value / distance.converted(to: .kilometers).value
        if pace == .infinity {
            return ""
        }
        let reminder = pace - Double(Int(pace))
        return "\(Int(pace)):\(Int(reminder * 60.0)) / km"
    }
}
