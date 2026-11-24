@testable import Odyssey
import XCTest

final class ExtractionValidatorTests: XCTestCase {
    private let transcript = """
    Um, today was honestly pretty rough. I barely slept, maybe four hours. Work was stressful \
    because the launch slipped again. But I had two beers with Sam after work and I'm grateful \
    for that, he always cheers me up. Small win, I finally fixed the login bug.
    """

    func testKeepsGroundedAnswers() {
        let raw = VoiceExtraction(
            mood: 3, moodEvidence: "today was honestly pretty rough",
            feelingWord: "drained", feelingColor: .indigo,
            sleepQuality: 2, sleepEvidence: "I barely slept, maybe four hours",
            gratitude: "Grateful for Sam, he always cheers me up",
            win: "I finally fixed the login bug",
            tension: "Work was stressful because the launch slipped again",
            drinks: 2, drinksEvidence: "I had two beers with Sam",
            journal: "Today was pretty rough."
        )

        let result = ExtractionValidator.validate(raw, transcript: transcript)

        XCTAssertEqual(result, raw)
    }

    func testDropsNumbersWithoutEvidence() {
        let raw = VoiceExtraction(mood: 7, moodEvidence: nil, sleepQuality: 6, sleepEvidence: "  ")
        let result = ExtractionValidator.validate(raw, transcript: transcript)
        XCTAssertNil(result.mood)
        XCTAssertNil(result.sleepQuality)
    }

    func testDropsNumbersWhoseEvidenceWasNeverSaid() {
        let raw = VoiceExtraction(mood: 9, moodEvidence: "best day of my whole life")
        XCTAssertNil(ExtractionValidator.validate(raw, transcript: transcript).mood)
    }

    func testDropsOutOfRangeNumbers() {
        let raw = VoiceExtraction(
            mood: 11, moodEvidence: "pretty rough",
            sleepQuality: 0, sleepEvidence: "barely slept"
        )
        let result = ExtractionValidator.validate(raw, transcript: transcript)
        XCTAssertNil(result.mood)
        XCTAssertNil(result.sleepQuality)
    }

    func testEvidenceToleratesSmallWordingDifferences() {
        let raw = VoiceExtraction(mood: 3, moodEvidence: "Today was pretty rough.")
        XCTAssertEqual(ExtractionValidator.validate(raw, transcript: transcript).mood, 3)
    }

    func testDrinksNeedACountInTheEvidence() {
        let raw = VoiceExtraction(drinks: 1, drinksEvidence: "beers with Sam after work")
        XCTAssertNil(ExtractionValidator.validate(raw, transcript: transcript).drinks)
    }

    func testZeroDrinksFromSayingTheyDidntDrink() {
        let raw = VoiceExtraction(drinks: 0, drinksEvidence: "didn't drink at all")
        let result = ExtractionValidator.validate(raw, transcript: "Quiet night, I didn't drink at all.")
        XCTAssertEqual(result.drinks, 0)
    }

    func testDropsInventedText() {
        let raw = VoiceExtraction(
            gratitude: "Grateful for my family's beach vacation",
            win: "Ran a marathon personal record"
        )
        let result = ExtractionValidator.validate(raw, transcript: transcript)
        XCTAssertNil(result.gratitude)
        XCTAssertNil(result.win)
    }

    func testLongFeelingPhraseIsDropped() {
        let raw = VoiceExtraction(feelingWord: "tired but kind of hopeful about tomorrow", feelingColor: .blue)
        let result = ExtractionValidator.validate(raw, transcript: transcript)
        XCTAssertNil(result.feelingWord)
        XCTAssertNil(result.feelingColor, "Color goes with the word")
    }

    func testEmptyStringsBecomeNil() {
        let raw = VoiceExtraction(feelingWord: " ", gratitude: "", journal: "\n")
        let result = ExtractionValidator.validate(raw, transcript: transcript)
        XCTAssertEqual(result, VoiceExtraction())
    }

    func testFillerWordsAreIgnoredWhenMatching() {
        let said = TranscriptText("um I uh finally fixed the bug")
        XCTAssertTrue(said.contains(quote: "I finally fixed the bug"))
    }
}

final class TranscriptCleanerTests: XCTestCase {
    func testRemovesFillersAndTidiesSpacing() {
        XCTAssertEqual(
            TranscriptCleaner.clean("  um, today was uh   pretty good. Umm I fixed the bug  "),
            "Today was pretty good. I fixed the bug"
        )
    }

    func testKeepsWordsThatContainFillers() {
        XCTAssertEqual(TranscriptCleaner.clean("the umbrella was huge"), "The umbrella was huge")
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(TranscriptCleaner.clean("  uh  "), "")
    }
}
