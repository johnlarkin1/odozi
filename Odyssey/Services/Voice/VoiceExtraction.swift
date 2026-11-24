import Foundation

/// What an extractor pulled out of a voice note's transcript. Every answer is optional: nil
/// means "not talked about", and nil answers are never written to the entry.
struct VoiceExtraction: Equatable, Sendable {
    /// Overall mood, 1-10. May be inferred from tone ("rough day" → 3).
    var mood: Int?
    /// A short quote from the transcript the mood is based on.
    var moodEvidence: String?
    /// One word or a short phrase for how the day felt.
    var feelingWord: String?
    var feelingColor: FeelingColor?
    /// Last night's sleep, 1-10. May be inferred ("barely slept" → 2).
    var sleepQuality: Int?
    var sleepEvidence: String?
    var gratitude: String?
    var win: String?
    var tension: String?
    /// Alcoholic drinks last night. Only filled when a count is actually said.
    var drinks: Int?
    var drinksEvidence: String?
    /// Everything said, cleaned up into a first-person journal entry.
    var journal: String?
}

/// A fixed palette for the "Capture your vibe" color, so the model picks a named color instead
/// of inventing hex codes.
enum FeelingColor: String, CaseIterable, Sendable {
    case red, orange, amber, yellow, green, teal, sky, blue, indigo, purple, pink, gray

    var hex: String {
        switch self {
        case .red: return "#E53935"
        case .orange: return "#FB8C00"
        case .amber: return "#F5A623"
        case .yellow: return "#FDD835"
        case .green: return "#4CAF50"
        case .teal: return "#2EC4B6"
        case .sky: return "#4FC3F7"
        case .blue: return "#1E88E5"
        case .indigo: return "#3949AB"
        case .purple: return "#8C5CF5"
        case .pink: return "#E86BAD"
        case .gray: return "#9E9E9E"
        }
    }
}

/// Turns a transcript into structured answers.
protocol JournalExtractor: Sendable {
    func extract(from transcript: String) async throws -> VoiceExtraction
}

enum VoiceExtractionError: Error, Equatable {
    /// The on-device model isn't available (device not eligible, Apple Intelligence off,
    /// model still downloading).
    case modelUnavailable
    /// The model's safety guardrails declined the content. Common for a wellness journal on a
    /// hard day, so callers must fall back, never drop the note.
    case refused
    /// The transcript didn't fit the model's context window.
    case transcriptTooLong
    case failed(String)
}
