import Foundation

enum ReminderTimeOfDay: String, CaseIterable, Identifiable {
    case morning, afternoon, evening, custom

    var id: String { rawValue }

    var hour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 14
        case .evening: 20
        case .custom: 0 // Not used directly; reads from UserDefaults
        }
    }

    var label: String {
        switch self {
        case .morning: "Morning (9:00 AM)"
        case .afternoon: "Afternoon (2:00 PM)"
        case .evening: "Evening (8:00 PM)"
        case .custom: "Custom"
        }
    }

    var notificationBody: String {
        switch self {
        case .morning: "Start your day with a moment of reflection."
        case .afternoon: "Take a break and check in with yourself."
        case .evening: "Wind down and reflect on your day."
        case .custom: "Time to check in with yourself."
        }
    }
}
