//
//  Double+Extensions.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 05/07/2023.
//

import Foundation

extension Double {
    func clamped(to minValue: Double, and maxValue: Double) -> Double {
        return min(maxValue, max(minValue, self))
    }
}
