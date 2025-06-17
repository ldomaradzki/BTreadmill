import Foundation

extension Double {
    func clamped(to min: Double, and max: Double) -> Double {
        return Swift.max(min, Swift.min(max, self))
    }
}