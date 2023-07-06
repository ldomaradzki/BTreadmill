//
//  GroupedRuns.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 04/07/2023.
//

import Foundation

struct GroupedRuns: Identifiable {
    var id: TimeInterval
    let date: Date
    let runs: [Run]
    
    var title: String {
        "\(DateFormatter.mediumDateFormatter.string(from: date)) (total: \(totalDistance())km)"
    }
    
    private func totalDistance() -> String {
        let distance = runs.map { $0.distanceMeters }.reduce(0, +)
        let kmDistance = Measurement<UnitLength>(value: distance, unit: .meters).converted(to: .kilometers).value
        return String(format: "%.2f", kmDistance)
    }
}
