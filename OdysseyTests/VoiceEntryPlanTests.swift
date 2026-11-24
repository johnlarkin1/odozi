@testable import Odyssey
import XCTest

@MainActor
final class VoiceEntryPlanTests: XCTestCase {
    private let full = VoiceExtraction(
        mood: 3, moodEvidence: "pretty rough",
        feelingWord: "drained", feelingColor: .indigo,
        sleepQuality: 2, sleepEvidence: "barely slept",
        gratitude: "Sam", win: "fixed the bug", tension: "launch slipped",
        drinks: 2, drinksEvidence: "two beers",
        journal: "Today was rough."
    )

    func testNewDayAnswersEverythingVoiceCovered() {
        let plan = VoiceEntryPlan(extraction: full, transcript: "...", existing: nil)

        XCTAssertEqual(plan.answered, Set(VoiceEntryPlan.voiceSteps))
        XCTAssertEqual(plan.responses.feeling, 3)
        XCTAssertEqual(plan.responses.singleWordFeeling, "drained")
        XCTAssertEqual(plan.responses.feelingColorHex, FeelingColor.indigo.hex)
        XCTAssertEqual(plan.responses.sleepQuality, 2)
        XCTAssertEqual(plan.responses.drinks, 2)
        XCTAssertEqual(plan.responses.journalEntry, "Today was rough.")
        XCTAssertTrue(plan.conflicts.isEmpty)
        XCTAssertTrue(plan.missing.isEmpty)
    }

    func testUnmentionedQuestionsAreMissingNotAnswered() {
        let partial = VoiceExtraction(win: "fixed the bug", journal: "Fixed the bug.")
        let plan = VoiceEntryPlan(extraction: partial, transcript: "...", existing: nil)

        XCTAssertEqual(plan.answered, [.win, .journal])
        XCTAssertEqual(plan.missing, [.mood, .feeling, .sleep, .gratitude, .tension, .drinks])
    }

    func testInferredNumbersAreEstimated() {
        let plan = VoiceEntryPlan(extraction: full, transcript: "...", existing: nil)
        XCTAssertEqual(plan.estimated, [.mood, .sleep])
    }

    func testStatedNumbersAreNotEstimated() {
        let stated = VoiceExtraction(mood: 7, moodEvidence: "I'd call it a seven", sleepQuality: 8, sleepEvidence: "slept like an 8")
        let plan = VoiceEntryPlan(extraction: stated, transcript: "...", existing: nil)
        XCTAssertTrue(plan.estimated.isEmpty)
    }

    func testFillsOnlyEmptyAnswersAndReportsConflicts() {
        let existing = DailyEntry(feeling: 6, gratitude: "coffee", win: "fixed the bug", journalEntry: "Morning notes.")

        let plan = VoiceEntryPlan(extraction: full, transcript: "...", existing: existing)

        XCTAssertFalse(plan.answered.contains(.mood))
        XCTAssertFalse(plan.answered.contains(.gratitude))
        XCTAssertFalse(plan.answered.contains(.win), "Same answer: nothing to write")
        XCTAssertTrue(plan.answered.contains(.sleep))
        XCTAssertEqual(
            plan.conflicts,
            [
                VoiceConflict(step: .mood, existing: "6", proposed: "3"),
                VoiceConflict(step: .gratitude, existing: "coffee", proposed: "Sam"),
            ]
        )
        XCTAssertFalse(plan.estimated.contains(.mood), "Unwritten answers aren't flagged")
    }

    func testJournalAppendsToExisting() {
        let existing = DailyEntry(journalEntry: "Morning notes.")
        let plan = VoiceEntryPlan(extraction: full, transcript: "...", existing: existing)
        XCTAssertEqual(plan.responses.journalEntry, "Morning notes.\n\nToday was rough.")
        XCTAssertTrue(plan.answered.contains(.journal))
    }

    func testAcceptingAConflictWritesIt() throws {
        let existing = DailyEntry(feeling: 6)
        var plan = VoiceEntryPlan(extraction: full, transcript: "...", existing: existing)
        let conflict = try XCTUnwrap(plan.conflicts.first { $0.step == .mood })

        plan.accept(conflict, from: full)

        XCTAssertTrue(plan.answered.contains(.mood))
        XCTAssertEqual(plan.responses.feeling, 3)
        XCTAssertFalse(plan.conflicts.contains { $0.step == .mood })
    }

    func testFallbackPutsTranscriptInJournal() {
        let plan = VoiceEntryPlan(extraction: nil, transcript: "  Long day at work.  ", existing: nil)

        XCTAssertEqual(plan.answered, [.journal])
        XCTAssertEqual(plan.responses.journalEntry, "Long day at work.")
        XCTAssertEqual(plan.missing, [.mood, .feeling, .sleep, .gratitude, .win, .tension, .drinks])
    }

    func testEmptyTranscriptFallbackWritesNothing() {
        let plan = VoiceEntryPlan(extraction: nil, transcript: "   ", existing: nil)
        XCTAssertTrue(plan.answered.isEmpty)
    }

    func testFeelingKeepsExistingColorWhenModelPicksNone() {
        let existing = DailyEntry(feelingColorHex: "#123456")
        let plan = VoiceEntryPlan(
            extraction: VoiceExtraction(feelingWord: "calm"),
            transcript: "...", existing: existing
        )
        XCTAssertEqual(plan.responses.feelingColorHex, "#123456")
    }
}
