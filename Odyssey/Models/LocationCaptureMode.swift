import Foundation

enum LocationCaptureMode: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case randomized
    case custom

    var id: String { rawValue }

    static var displayCases: [LocationCaptureMode] {
        allCases
    }

    var hour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 14
        case .evening: 20
        case .randomized, .custom: 0 // Not used directly
        }
    }

    var label: String {
        switch self {
        case .morning: return "Morning (9:00 AM)"
        case .afternoon: return "Afternoon (2:00 PM)"
        case .evening: return "Evening (8:00 PM)"
        case .randomized: return "Randomized"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .morning: return "Capture your location in the morning"
        case .afternoon: return "Capture your location in the afternoon"
        case .evening: return "Capture your location in the evening"
        case .randomized: return "Random time between 8 AM and 10 PM"
        case .custom: return "Choose a specific time"
        }
    }
}
