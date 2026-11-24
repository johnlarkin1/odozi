import Foundation
import FoundationModels
import os

private let extractorLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "OnDeviceJournalExtractor")

/// Extracts journal answers with Apple's on-device language model (Foundation Models). Nothing
/// leaves the device. Requires an Apple Intelligence iPhone with Apple Intelligence turned on;
/// check `isAvailable` first and fall back to transcript-only when it's false.
struct OnDeviceJournalExtractor: JournalExtractor {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func extract(from transcript: String) async throws -> VoiceExtraction {
        guard Self.isAvailable else { throw VoiceExtractionError.modelUnavailable }

        let session = LanguageModelSession(instructions: Self.instructions)
        do {
            let response = try await session.respond(
                to: "Transcript:\n\(transcript)",
                generating: GeneratedVoiceEntry.self,
                options: GenerationOptions(sampling: .greedy)
            )
            return response.content.extraction
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation, .refusal:
                extractorLogger.info("On-device model declined the transcript")
                throw VoiceExtractionError.refused
            case .exceededContextWindowSize:
                throw VoiceExtractionError.transcriptTooLong
            case .assetsUnavailable:
                throw VoiceExtractionError.modelUnavailable
            default:
                extractorLogger.error("On-device extraction failed: \(error)")
                throw VoiceExtractionError.failed(String(describing: error))
            }
        }
    }

    static let instructions = """
    You turn a spoken daily journal note into answers for a journaling app. The speaker is the \
    app's user, talking about their own day. Use only what they said.

    Rules:
    - Leave an answer empty when they didn't talk about it. Never invent details.
    - mood: their overall mood today from 1 (awful) to 10 (amazing). Infer it from how they \
    describe the day if they don't give a number. moodEvidence: the exact words you based it on.
    - sleepQuality: how well they slept last night from 1 to 10, inferred if needed. Only when \
    they talk about sleep. sleepEvidence: the exact words.
    - drinks: alcoholic drinks last night, only when they say a count or say they didn't drink \
    (then 0). drinksEvidence: the exact words.
    - feelingWord: one word or a very short phrase that captures the day. feelingColor: the \
    color that best matches that feeling.
    - gratitude, win, tension: something they're grateful for, something that went well, \
    something stressful. Keep their own words and first person; just remove filler like "um".
    - journal: everything they said, lightly cleaned up into first-person prose. Keep all the \
    content and their voice; don't summarize or add anything.
    """
}

@Generable
struct GeneratedVoiceEntry {
    @Guide(description: "Overall mood today, 1 (awful) to 10 (amazing). Empty if there's nothing to go on.")
    var mood: Int?
    @Guide(description: "Exact words from the transcript the mood is based on")
    var moodEvidence: String?
    @Guide(description: "One word or very short phrase capturing the day")
    var feelingWord: String?
    @Guide(description: "Color that matches the feeling word")
    var feelingColor: GeneratedFeelingColor?
    @Guide(description: "Last night's sleep, 1 (terrible) to 10 (great). Empty unless sleep was mentioned.")
    var sleepQuality: Int?
    @Guide(description: "Exact words about sleep")
    var sleepEvidence: String?
    @Guide(description: "Something they're grateful for, in their words. Empty if not mentioned.")
    var gratitude: String?
    @Guide(description: "A win or accomplishment, in their words. Empty if not mentioned.")
    var win: String?
    @Guide(description: "A source of tension or stress, in their words. Empty if not mentioned.")
    var tension: String?
    @Guide(description: "Alcoholic drinks last night. Empty unless a count was said; 0 if they didn't drink.")
    var drinks: Int?
    @Guide(description: "Exact words about drinking")
    var drinksEvidence: String?
    @Guide(description: "Everything they said as lightly cleaned-up first-person prose")
    var journal: String

    var extraction: VoiceExtraction {
        VoiceExtraction(
            mood: mood,
            moodEvidence: moodEvidence,
            feelingWord: feelingWord,
            feelingColor: feelingColor.flatMap { FeelingColor(rawValue: $0.rawValue) },
            sleepQuality: sleepQuality,
            sleepEvidence: sleepEvidence,
            gratitude: gratitude,
            win: win,
            tension: tension,
            drinks: drinks,
            drinksEvidence: drinksEvidence,
            journal: journal
        )
    }
}

@Generable
enum GeneratedFeelingColor: String {
    case red, orange, amber, yellow, green, teal, sky, blue, indigo, purple, pink, gray
}
