import Foundation

enum TreadmillState: Equatable {
    case unknown
    case hibernated
    case idling
    case starting
    case running(RunningState)
    case stopping(RunningState)
    
    static func == (lhs: TreadmillState, rhs: TreadmillState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown): return true
        case (.hibernated, .hibernated): return true
        case (.idling, .idling): return true
        case (.starting, .starting): return true
        case (.running(let state1), .running(let state2)): return state1 == state2
        case (.stopping(let state1), .stopping(let state2)): return state1 == state2
        default: return false
        }
    }
}