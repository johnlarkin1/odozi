import Foundation

enum LocationCaptureMode: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case randomized
    case fixedTime // Legacy: kept for backward compatibility with existing UserDefaults

    var id: String { rawValue }

    /// Cases to show in the UI (excludes legacy fixedTime)
    static var displayCases: [LocationCaptureMode] {
        [.morning, .afternoon, .evening, .randomized]
    }

    var hour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 14
        case .evening, .fixedTime: 20
        case .randomized: 0 // Not used directly
        }
    }

    var label: String {
        switch self {
        case .morning: return "Morning (9:00 AM)"
        case .afternoon: return "Afternoon (2:00 PM)"
        case .evening: return "Evening (8:00 PM)"
        case .randomized: return "Randomized"
        case .fixedTime: return "Evening (8:00 PM)"
        }
    }

    var description: String {
        switch self {
        case .morning: return "Capture your location in the morning"
        case .afternoon: return "Capture your location in the afternoon"
        case .evening: return "Capture your location in the evening"
        case .randomized: return "Random time between 8 AM and 10 PM"
        case .fixedTime: return "Capture your location in the evening"
        }
    }
}
