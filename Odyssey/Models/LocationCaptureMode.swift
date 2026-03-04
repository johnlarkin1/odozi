import Foundation

enum LocationCaptureMode: String, CaseIterable, Identifiable {
    case fixedTime
    case randomized

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixedTime: return "Fixed Time"
        case .randomized: return "Randomized"
        }
    }

    var description: String {
        switch self {
        case .fixedTime: return "Capture at a specific time each day"
        case .randomized: return "Random time between 8 AM and 10 PM"
        }
    }
}
