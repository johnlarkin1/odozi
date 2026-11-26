@testable import Odyssey
import XCTest

private struct StubExtractor: JournalExtractor {
    let result: Result<VoiceExtraction, VoiceExtractionError>

    func extract(from _: String) async throws -> VoiceExtraction {
        try result.get()
    }
}

@MainActor
final class VoiceNoteProcessorTests: XCTestCase {
    private let transcript = "Pretty good day. I finally fixed the login bug."

    func testValidatesExtraction() async {
        let raw = VoiceExtraction(
            mood: 7, moodEvidence: "Pretty good day",
            win: "I finally fixed the login bug",
            tension: "Arguing with my landlord", // never said
            journal: "Pretty good day. I finally fixed the login bug."
        )
        let processor = VoiceNoteProcessor(extractor: StubExtractor(result: .success(raw)))

        let note = await processor.process(transcript: transcript, existing: nil)

        XCTAssertNil(note.fallbackReason)
        XCTAssertEqual(note.extraction?.mood, 7)
        XCTAssertNil(note.extraction?.tension, "Ungrounded answer must be dropped")
        XCTAssertEqual(note.plan.answered, [.mood, .win, .journal])
    }

    func testRefusalFallsBackToTranscript() async {
        let processor = VoiceNoteProcessor(extractor: StubExtractor(result: .failure(.refused)))

        let note = await processor.process(transcript: transcript, existing: nil)

        XCTAssertEqual(note.fallbackReason, .refused)
        XCTAssertNil(note.extraction)
        XCTAssertEqual(note.plan.answered, [.journal])
        XCTAssertEqual(note.plan.responses.journalEntry, transcript)
    }

    func testNoExtractorFallsBack() async {
        let note = await VoiceNoteProcessor(extractor: nil).process(transcript: transcript, existing: nil)
        XCTAssertEqual(note.fallbackReason, .modelUnavailable)
        XCTAssertEqual(note.plan.responses.journalEntry, transcript)
    }

    func testEmptyTranscriptSkipsExtraction() async {
        let processor = VoiceNoteProcessor(extractor: StubExtractor(result: .failure(.failed("should not run"))))
        let note = await processor.process(transcript: "  ", existing: nil)
        XCTAssertNil(note.fallbackReason)
        XCTAssertTrue(note.plan.answered.isEmpty)
    }
}

/// Runs the real on-device model when the test machine has it (Apple Intelligence enabled);
/// skipped otherwise. A light check that extraction plus validation behaves on realistic notes.
final class OnDeviceJournalExtractorTests: XCTestCase {
    func testExtractsARealisticNote() async throws {
        try XCTSkipUnless(OnDeviceJournalExtractor.isAvailable, "On-device model not available here")
        let transcript = """
        Today was a really good day. I slept great, probably like an eight out of ten. I'm grateful \
        for my sister calling me this morning. My win is that I finished the presentation for work. \
        The only stressful thing was traffic on the way home. I didn't have anything to drink last night.
        """

        let raw = try await OnDeviceJournalExtractor().extract(from: transcript)
        let result = ExtractionValidator.validate(raw, transcript: transcript)

        XCTAssertNotNil(result.mood)
        XCTAssertEqual(result.sleepQuality, 8)
        XCTAssertNotNil(result.gratitude)
        XCTAssertNotNil(result.win)
        XCTAssertNotNil(result.tension)
        XCTAssertEqual(result.drinks, 0)
        XCTAssertFalse(result.journal?.isEmpty ?? true)
    }

    func testLeavesUnmentionedQuestionsEmpty() async throws {
        try XCTSkipUnless(OnDeviceJournalExtractor.isAvailable, "On-device model not available here")
        let transcript = "I finished the presentation for work today and I'm relieved it's done."

        let raw = try await OnDeviceJournalExtractor().extract(from: transcript)
        let result = ExtractionValidator.validate(raw, transcript: transcript)

        XCTAssertNil(result.sleepQuality, "Sleep wasn't mentioned")
        XCTAssertNil(result.drinks, "Drinks weren't mentioned")
        XCTAssertNil(result.gratitude)
    }
}
