//
//  RunData.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 09/07/2023.
//

import Foundation
import GRDB

class RunData: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var startTimestamp: Date
    var endTimestamp: Date?
    var distanceMeters: Double
    var distanceMetersOffset: Double
    var speeds: String
    var completed: Bool
    var uploadedId: String?
    var paused: Bool
    
    init(id: Int64? = nil, startTimestamp: Date, endTimestamp: Date? = .now, distanceMeters: Double = 0, distanceMetersOffset: Double = 0, speeds: String = "", completed: Bool = false, uploadedId: String? = nil, paused: Bool = false) {
        self.id = id
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.distanceMeters = distanceMeters
        self.distanceMetersOffset = distanceMetersOffset
        self.speeds = speeds
        self.completed = completed
        self.uploadedId = uploadedId
        self.paused = paused
    }

    
    func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension RunData {
    static func prepareSchema(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("createRunData") { db in
            try db.create(table: "rundata") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("startTimestamp", .datetime).notNull()
                t.column("endTimestamp", .datetime)
                t.column("distanceMeters", .double).notNull()
                t.column("distanceMetersOffset", .double).notNull().defaults(to: 0.0)
                t.column("speeds", .text).notNull()
                t.column("completed", .boolean).notNull().defaults(to: false)
                t.column("uploadedId", .text)
                t.column("paused", .boolean).notNull().defaults(to: false)
            }
        }
    }
}

extension RunData {
    var duration: Measurement<UnitDuration> {
        .init(value: endTimestamp?.timeIntervalSince(startTimestamp) ?? .init(), unit: .seconds)
    }
    
    var distance: Measurement<UnitLength> {
        .init(value: distanceMeters + distanceMetersOffset, unit: .meters)
    }
}

extension RunData {
    // Used for graph display or calculating max/avg speeds for a run
    var speedsArray: [Double] {
        speeds.split(separator: "|").compactMap { Double($0) }
    }
    
    // Used in details screen
    var paceString: String {
        guard duration.value > 0 else { return "" }
        let pace = duration.converted(to: .minutes).value / distance.converted(to: .kilometers).value
        if pace == .infinity || pace == .signalingNaN {
            return ""
        }
        let reminder = pace - Double(Int(pace))
        return "\(Int(pace)):\(Int(reminder * 60.0)) / km"
    }
    
    // Used in details and list screen
    var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.allowsFractionalUnits = true
        
        return formatter.string(from: duration.value)!
    }
    
    // Used in the list screen
    var hours: Int {
        Int(duration.converted(to: .hours).value)
    }
    
    // Used in the list screen
    var minutesReminder: Int {
        Int(duration.converted(to: .minutes).value) % 60
    }
}
