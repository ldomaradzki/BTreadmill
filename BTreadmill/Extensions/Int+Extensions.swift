//
//  Int+Extensions.swift
//  BTreadmill
//
//  Created by Lukasz Domaradzki on 05/07/2023.
//

import Foundation

extension Int {
    func toHex() -> String {
        var decimalValue = self
        var hexString = ""

        while decimalValue > 0 {
            let remainder = decimalValue % 16
            let hexDigit: String

            if remainder < 10 {
                hexDigit = String(remainder)
            } else {
                let asciiOffset = 55
                let unicodeScalar = UnicodeScalar(remainder + asciiOffset)
                hexDigit = String(Character(unicodeScalar!))
            }

            hexString = hexDigit + hexString
            decimalValue /= 16
        }

        if hexString.count == 1 {
            return "0\(hexString)"
        }
        
        return hexString
    }
}
