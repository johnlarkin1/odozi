import XCTest
@testable import Odyssey

final class PromptModelsTests: XCTestCase {

    // MARK: - PromptStep

    func testPromptStepAllCasesCount() {
        XCTAssertEqual(PromptStep.allCases.count, 8)
    }

    func testPromptStepOrderMatchesRawValues() {
        let expectedOrder: [PromptStep] = [.mood, .feeling, .sleep, .gratitude, .win, .tension, .journal, .drinks]
        XCTAssertEqual(PromptStep.allCases, expectedOrder)
    }

    func testPromptStepRawValues() {
        XCTAssertEqual(PromptStep.mood.rawValue, 0)
        XCTAssertEqual(PromptStep.drinks.rawValue, 7)
    }

    func testPromptStepTitlesAreNonEmpty() {
        for step in PromptStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "Title for \(step) should not be empty")
        }
    }

    func testPromptStepSubtitlesAreNonEmpty() {
        for step in PromptStep.allCases {
            XCTAssertFalse(step.subtitle.isEmpty, "Subtitle for \(step) should not be empty")
        }
    }

    func testPromptStepIdMatchesRawValue() {
        for step in PromptStep.allCases {
            XCTAssertEqual(step.id, step.rawValue)
        }
    }

    func testPromptStepSpecificTitles() {
        XCTAssertEqual(PromptStep.mood.title, "How are you feeling?")
        XCTAssertEqual(PromptStep.sleep.title, "How did you sleep?")
        XCTAssertEqual(PromptStep.drinks.title, "How many drinks?")
    }

    // MARK: - PromptResponses

    func testPromptResponsesDefaults() {
        let responses = PromptResponses()
        XCTAssertEqual(responses.feeling, 5)
        XCTAssertEqual(responses.singleWordFeeling, "")
        XCTAssertEqual(responses.feelingColorHex, "#FFFFFF")
        XCTAssertEqual(responses.sleepQuality, 5)
        XCTAssertEqual(responses.gratitude, "")
        XCTAssertEqual(responses.win, "")
        XCTAssertEqual(responses.tension, "")
        XCTAssertEqual(responses.journalEntry, "")
        XCTAssertEqual(responses.drinks, 0)
    }

    func testPromptResponsesMutation() {
        var responses = PromptResponses()
        responses.feeling = 8
        responses.singleWordFeeling = "happy"
        responses.gratitude = "sunshine"
        XCTAssertEqual(responses.feeling, 8)
        XCTAssertEqual(responses.singleWordFeeling, "happy")
        XCTAssertEqual(responses.gratitude, "sunshine")
    }
}
