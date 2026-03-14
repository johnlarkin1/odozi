import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct JournalInsightResult {
    let followUpQuestion: String
    let detectedEmotion: String
    let encouragement: String
    let suggestion: String
}

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct JournalInsight {
    @Guide(description: "A compassionate follow-up question based on the journal entry, one sentence")
    var followUpQuestion: String

    @Guide(description: "A single word capturing the dominant emotion in the entry")
    var detectedEmotion: String

    @Guide(description: "One sentence of warm, genuine encouragement based on the entry")
    var encouragement: String

    @Guide(description: "A brief, practical self-care suggestion inspired by the entry")
    var suggestion: String
}
#endif

enum JournalInsightService {
    static func generateInsight(from responses: PromptResponses) async -> JournalInsightResult? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *),
              FoundationModelsAvailability.isAvailable else {
            return nil
        }

        let prompt = buildPrompt(from: responses)

        do {
            let session = LanguageModelSession(
                instructions: """
                You are a compassionate journaling coach. \
                Reflect on the user's daily journal entry with warmth and empathy. \
                Be genuine but not saccharine. Never diagnose or offer medical advice. \
                Keep each field to one sentence.
                """
            )
            let response = try await session.respond(to: prompt, generating: JournalInsight.self)
            let insight = response
            return JournalInsightResult(
                followUpQuestion: insight.followUpQuestion,
                detectedEmotion: insight.detectedEmotion,
                encouragement: insight.encouragement,
                suggestion: insight.suggestion
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    static func buildPrompt(from responses: PromptResponses) -> String {
        var parts: [String] = []

        parts.append("Mood rating: \(responses.feeling)/10")

        if !responses.singleWordFeeling.isEmpty {
            parts.append("Feeling: \(responses.singleWordFeeling)")
        }

        if responses.sleepQuality != 5 {
            parts.append("Sleep quality: \(responses.sleepQuality)/10")
        }

        if !responses.gratitude.isEmpty {
            parts.append("Gratitude: \(responses.gratitude)")
        }

        if !responses.win.isEmpty {
            parts.append("Today's win: \(responses.win)")
        }

        if !responses.tension.isEmpty {
            parts.append("Tension: \(responses.tension)")
        }

        if !responses.journalEntry.isEmpty {
            parts.append("Journal: \(responses.journalEntry)")
        }

        if responses.drinks > 0 {
            parts.append("Drinks: \(responses.drinks)")
        }

        return parts.joined(separator: "\n")
    }
}
