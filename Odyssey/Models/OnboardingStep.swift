import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case location
    case health
    case screenTime
    case notifications
    case account
    case completion

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Your odyssey begins"
        case .location: "Location"
        case .health: "Health Insights"
        case .screenTime: "Screen Time"
        case .notifications: "Daily Reminders"
        case .account: "Back Up Your Journal?"
        case .completion: "You're All Set"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "A space for daily reflection. Track how you feel, where you've been, and where you're going."
        case .location:
            "Capture where you are as you move through your day to build a personal map of your "
                + "journey. Background access lets it fill in on its own, without opening the app."
        case .health:
            "Connect Apple Health to automatically track your steps, walking distance, and sleep alongside your journal entries."
        case .screenTime:
            "See how your screen time relates to your mood and wellness patterns."
        case .notifications:
            "A gentle nudge to reflect on your day. Choose when works best for you."
        case .account:
            "Your entries are always stored on this device. Enable iCloud backup to keep them safe across devices."
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
        case .notifications: "bell.fill"
        case .account: "icloud.fill"
        case .completion: "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: .accentAmber
        case .location: .accentTeal
        case .health: .coralRed
        case .screenTime: .accentAmber
        case .notifications: .cosmicPurple
        case .account: .accentTeal
        case .completion: .successGreen
        }
    }

    var isPermissionStep: Bool {
        switch self {
        case .location, .health, .screenTime, .notifications: true
        default: false
        }
    }

    var hasEmbeddedButtons: Bool {
        switch self {
        case .account, .completion: true
        default: false
        }
    }
}
