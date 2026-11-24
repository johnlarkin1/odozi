@testable import Odyssey
import SwiftData
import XCTest

@MainActor
final class EntrySubmitterTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var submitter: EntrySubmitter!
    private let today = Calendar.current.startOfDay(for: Date())

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        submitter = EntrySubmitter(context: context)
    }

    override func tearDown() async throws {
        submitter = nil
        container = nil
        context = nil
    }

    private func fetchToday() throws -> DailyEntry? {
        try DailyEntryRepository(context: context).fetchEntry(for: today)
    }

    // MARK: - Answered steps

    func testWritesOnlyAnsweredSteps() throws {
        var responses = PromptResponses()
        responses.feeling = 8
        responses.sleepQuality = 3
        responses.gratitude = "coffee with Sam"
        responses.win = "shipped it"

        try submitter.submit(responses, answered: [.mood, .gratitude], for: today)

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertEqual(entry.feeling, 8)
        XCTAssertEqual(entry.gratitude, "coffee with Sam")
        XCTAssertEqual(entry.sleepQuality, 0, "Unanswered sleep must not get the response default")
        XCTAssertEqual(entry.win, "", "Unanswered win must not be written")
    }

    func testUnansweredStepsKeepExistingValues() throws {
        let existing = DailyEntry(date: today, sleepQuality: 7, tension: "deadline")
        context.insert(existing)
        try context.save()

        var responses = PromptResponses()
        responses.feeling = 4
        try submitter.submit(responses, answered: [.mood], for: today)

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertEqual(entry.feeling, 4)
        XCTAssertEqual(entry.sleepQuality, 7)
        XCTAssertEqual(entry.tension, "deadline")
        let all = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(all.count, 1, "Submitting must reuse the day's entry")
    }

    func testFeelingStepWritesWordAndColorTogether() throws {
        var responses = PromptResponses()
        responses.singleWordFeeling = "calm"
        responses.feelingColorHex = "#3366FF"
        try submitter.submit(responses, answered: [.feeling], for: today)

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertEqual(entry.singleWordFeeling, "calm")
        XCTAssertEqual(entry.feelingColorHex, "#3366FF")
    }

    // MARK: - Submission flag

    func testMarksSubmittedWhenThereIsContent() throws {
        var responses = PromptResponses()
        responses.win = "ran 5k"
        try submitter.submit(responses, answered: [.win], for: today)

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertTrue(entry.hasUserSubmitted)
        XCTAssertNotNil(entry.firstSubmittedAt)
    }

    func testDoesNotMarkSubmittedWithoutContent() throws {
        try submitter.submit(PromptResponses(), answered: [], for: today)

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertFalse(entry.hasUserSubmitted)
        XCTAssertNil(entry.firstSubmittedAt)
    }

    func testKeepsOriginalFirstSubmittedAt() throws {
        var responses = PromptResponses()
        responses.win = "first"
        try submitter.submit(responses, answered: [.win], for: today)
        let firstSubmittedAt = try XCTUnwrap(fetchToday()?.firstSubmittedAt)

        responses.win = "second"
        try submitter.submit(responses, answered: [.win], for: today)

        XCTAssertEqual(try fetchToday()?.firstSubmittedAt, firstSubmittedAt)
    }

    // MARK: - Voice notes

    func testVoiceNoteStoresTranscriptAndRecording() throws {
        var responses = PromptResponses()
        responses.journalEntry = "Good day overall."
        let voice = VoiceCapture(transcript: "  um good day overall  ", audioFilename: "a.m4a")

        try submitter.submit(responses, answered: [.journal], for: today, voice: voice)

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertEqual(entry.journalEntry, "Good day overall.")
        XCTAssertEqual(entry.voiceTranscript, "um good day overall")
        XCTAssertEqual(entry.voiceAudioFilenames, ["a.m4a"])
        XCTAssertTrue(entry.hasUserSubmitted)
    }

    func testSecondVoiceNoteAppends() throws {
        try submitter.submit(
            PromptResponses(), answered: [], for: today,
            voice: VoiceCapture(transcript: "morning note", audioFilename: "a.m4a")
        )
        try submitter.submit(
            PromptResponses(), answered: [], for: today,
            voice: VoiceCapture(transcript: "evening note", audioFilename: "b.m4a")
        )

        let entry = try XCTUnwrap(fetchToday())
        XCTAssertEqual(entry.voiceTranscript, "morning note\n\nevening note")
        XCTAssertEqual(entry.voiceAudioFilenames, ["a.m4a", "b.m4a"])
    }

    func testVoiceNoteWithoutAudioKeepsFilenamesNil() throws {
        try submitter.submit(
            PromptResponses(), answered: [], for: today,
            voice: VoiceCapture(transcript: "no audio kept", audioFilename: nil)
        )
        XCTAssertNil(try fetchToday()?.voiceAudioFilenames)
    }

    func testSameRecordingIsNotListedTwice() {
        let entry = DailyEntry(date: today)
        EntrySubmitter.apply(VoiceCapture(transcript: "", audioFilename: "a.m4a"), to: entry)
        EntrySubmitter.apply(VoiceCapture(transcript: "", audioFilename: "a.m4a"), to: entry)
        XCTAssertEqual(entry.voiceAudioFilenames, ["a.m4a"])
        XCTAssertEqual(entry.voiceTranscript, "")
    }
}
