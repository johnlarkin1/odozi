import XCTest
@testable import Odyssey

final class JournalInsightServiceTests: XCTestCase {

    // MARK: - JournalInsightResult

    func testJournalInsightResultStoresAllFields() {
        let result = JournalInsightResult(
            followUpQuestion: "What made you smile today?",
            detectedEmotion: "Grateful",
            encouragement: "You're doing great recognizing the good things.",
            suggestion: "Try a 5-minute walk outside."
        )
        XCTAssertEqual(result.followUpQuestion, "What made you smile today?")
        XCTAssertEqual(result.detectedEmotion, "Grateful")
        XCTAssertEqual(result.encouragement, "You're doing great recognizing the good things.")
        XCTAssertEqual(result.suggestion, "Try a 5-minute walk outside.")
    }

    // MARK: - buildPrompt

    func testBuildPromptIncludesMoodRating() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Mood rating: 5/10"))
    }

    func testBuildPromptIncludesFeelingWhenNotEmpty() {
        var responses = PromptResponses()
        responses.singleWordFeeling = "grateful"
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Feeling: grateful"))
    }

    func testBuildPromptExcludesFeelingWhenEmpty() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Feeling:"))
    }

    func testBuildPromptIncludesSleepWhenNotDefault() {
        var responses = PromptResponses()
        responses.sleepQuality = 8
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Sleep quality: 8/10"))
    }

    func testBuildPromptExcludesSleepWhenDefault() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Sleep quality:"))
    }

    func testBuildPromptIncludesGratitudeWhenNotEmpty() {
        var responses = PromptResponses()
        responses.gratitude = "sunny weather"
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Gratitude: sunny weather"))
    }

    func testBuildPromptExcludesGratitudeWhenEmpty() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Gratitude:"))
    }

    func testBuildPromptIncludesWinWhenNotEmpty() {
        var responses = PromptResponses()
        responses.win = "finished the project"
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Today's win: finished the project"))
    }

    func testBuildPromptExcludesWinWhenEmpty() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Today's win:"))
    }

    func testBuildPromptIncludesTensionWhenNotEmpty() {
        var responses = PromptResponses()
        responses.tension = "deadline pressure"
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Tension: deadline pressure"))
    }

    func testBuildPromptExcludesTensionWhenEmpty() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Tension:"))
    }

    func testBuildPromptIncludesJournalWhenNotEmpty() {
        var responses = PromptResponses()
        responses.journalEntry = "Today was a great day."
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Journal: Today was a great day."))
    }

    func testBuildPromptExcludesJournalWhenEmpty() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Journal:"))
    }

    func testBuildPromptIncludesDrinksWhenPositive() {
        var responses = PromptResponses()
        responses.drinks = 3
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertTrue(prompt.contains("Drinks: 3"))
    }

    func testBuildPromptExcludesDrinksWhenZero() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertFalse(prompt.contains("Drinks:"))
    }

    func testBuildPromptWithAllFieldsPopulated() {
        var responses = PromptResponses()
        responses.feeling = 8
        responses.singleWordFeeling = "happy"
        responses.sleepQuality = 7
        responses.gratitude = "family"
        responses.win = "promotion"
        responses.tension = "commute"
        responses.journalEntry = "Long but good day"
        responses.drinks = 2

        let prompt = JournalInsightService.buildPrompt(from: responses)

        XCTAssertTrue(prompt.contains("Mood rating: 8/10"))
        XCTAssertTrue(prompt.contains("Feeling: happy"))
        XCTAssertTrue(prompt.contains("Sleep quality: 7/10"))
        XCTAssertTrue(prompt.contains("Gratitude: family"))
        XCTAssertTrue(prompt.contains("Today's win: promotion"))
        XCTAssertTrue(prompt.contains("Tension: commute"))
        XCTAssertTrue(prompt.contains("Journal: Long but good day"))
        XCTAssertTrue(prompt.contains("Drinks: 2"))
    }

    func testBuildPromptWithDefaultResponsesOnlyIncludesMood() {
        let responses = PromptResponses()
        let prompt = JournalInsightService.buildPrompt(from: responses)
        XCTAssertEqual(prompt, "Mood rating: 5/10")
    }

    func testBuildPromptFieldsSeparatedByNewlines() {
        var responses = PromptResponses()
        responses.singleWordFeeling = "calm"
        responses.gratitude = "peace"
        let prompt = JournalInsightService.buildPrompt(from: responses)
        let lines = prompt.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
    }

    // MARK: - generateInsight (unavailable environment)

    func testGenerateInsightReturnsNilWhenUnavailable() async {
        // On simulator / CI, FoundationModels is not available
        let responses = PromptResponses()
        let result = await JournalInsightService.generateInsight(from: responses)
        XCTAssertNil(result, "Should return nil when FoundationModels is unavailable")
    }
}
