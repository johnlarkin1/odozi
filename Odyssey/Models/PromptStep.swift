import SwiftUI

enum PromptStep: Int, CaseIterable, Identifiable {
    case mood = 0
    case feeling
    case sleep
    case gratitude
    case win
    case tension
    case journal
    case drinks
    case location

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .mood: return "How are you feeling?"
        case .feeling: return "Capture your vibe"
        case .sleep: return "How did you sleep?"
        case .gratitude: return "What are you grateful for?"
        case .win: return "What's your win today?"
        case .tension: return "Any tension or stress?"
        case .journal: return "Journal your thoughts"
        case .drinks: return "How many drinks?"
        case .location: return "Your Location"
        }
    }

    var subtitle: String {
        switch self {
        case .mood: return "Rate your overall mood"
        case .feeling: return "Pick a word to describe today"
        case .sleep: return "Rate last night's sleep"
        case .gratitude: return "Something big or small"
        case .win: return "Celebrate an accomplishment"
        case .tension: return "Name it to tame it"
        case .journal: return "Free-write whatever's on your mind"
        case .drinks: return "Alcoholic drinks last night"
        case .location: return "Confirm or update where you are"
        }
    }

    var iconName: String {
        switch self {
        case .mood: return "sun.max.fill"
        case .feeling: return "paintpalette.fill"
        case .sleep: return "moon.stars.fill"
        case .gratitude: return "heart.fill"
        case .win: return "trophy.fill"
        case .tension: return "cloud.fill"
        case .journal: return "note.text"
        case .drinks: return "wineglass.fill"
        case .location: return "location.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .mood: return .accentAmber
        case .feeling: return .purple
        case .sleep: return .accentTeal
        case .gratitude: return .accentAmber
        case .win: return .successGreen
        case .tension: return .coralRed
        case .journal: return .accentAmber
        case .drinks: return .accentTeal
        case .location: return .accentTeal
        }
    }
}
