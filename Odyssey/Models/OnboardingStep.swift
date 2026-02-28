import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case location
    case health
    case screenTime
    case completion

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome to Odyssey"
        case .location: "Your Daily Map"
        case .health: "Health Insights"
        case .screenTime: "Screen Time"
        case .completion: "You're All Set"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "Track your mental wellness journey with daily reflections, health data, and beautiful visualizations."
        case .location:
            "Odyssey captures your location once daily to build a personal map of your journey. Your data stays on your device."
        case .health:
            "Connect Apple Health to automatically track your steps, walking distance, and sleep alongside your journal entries."
        case .screenTime:
            "See how your screen time relates to your mood and wellness patterns."
        case .completion:
            "Your odyssey begins now"
        }
    }

    var iconName: String {
        switch self {
        case .welcome: "sail.boat.fill"
        case .location: "location.fill"
        case .health: "heart.fill"
        case .screenTime: "hourglass"
        case .completion: "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: .accentAmber
        case .location: .accentTeal
        case .health: .coralRed
        case .screenTime: .accentAmber
        case .completion: .successGreen
        }
    }

    var isPermissionStep: Bool {
        switch self {
        case .location, .health, .screenTime: true
        default: false
        }
    }
}
