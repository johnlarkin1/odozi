import Foundation

enum PromptStep: Int, CaseIterable, Identifiable {
    case mood = 0
    case feeling
    case sleep
    case gratitude
    case win
    case tension
    case journal
    case drinks

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .mood: return "How are you feeling?"
        case .feeling: return "One word to describe today"
        case .sleep: return "How did you sleep?"
        case .gratitude: return "What are you grateful for?"
        case .win: return "What's your win today?"
        case .tension: return "Any tension or stress?"
        case .journal: return "Journal your thoughts"
        case .drinks: return "How many drinks?"
        }
    }

    var subtitle: String {
        switch self {
        case .mood: return "Rate your overall mood"
        case .feeling: return "Pick a word and a color"
        case .sleep: return "Rate last night's sleep"
        case .gratitude: return "Something big or small"
        case .win: return "Celebrate an accomplishment"
        case .tension: return "Name it to tame it"
        case .journal: return "Free-write whatever's on your mind"
        case .drinks: return "Alcoholic drinks last night"
        }
    }

    var emoji: String {
        switch self {
        case .mood: return "🌤️"
        case .feeling: return "🎨"
        case .sleep: return "🌙"
        case .gratitude: return "🙏"
        case .win: return "🏆"
        case .tension: return "💭"
        case .journal: return "📝"
        case .drinks: return "🍷"
        }
    }
}
