@testable import Odyssey
import SwiftData
import XCTest

private struct FixedExtractor: JournalExtractor {
    let extraction: VoiceExtraction

    func extract(from transcript: String) async throws -> VoiceExtraction {
        var result = extraction
        result.journal = TranscriptCleaner.clean(transcript)
        return result
    }
}

@MainActor
final class VoiceEntryViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var storeDirectory: URL!
    private var store: VoiceRecordingStore!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceEntryViewModelTests-\(UUID().uuidString)", isDirectory: true)
        store = VoiceRecordingStore(directory: storeDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeDirectory)
        container = nil
        context = nil
    }

    private func makeViewModel(
        transcript: String = ScriptedVoiceNote.transcript,
        extractor: JournalExtractor? = ScriptedJournalExtractor()
    ) -> VoiceEntryViewModel {
        VoiceEntryViewModel(
            modelContext: context,
            recorder: ScriptedVoiceRecorder(transcript: transcript),
            processor: VoiceNoteProcessor(extractor: extractor),
            store: store
        )
    }

    private func record(_ vm: VoiceEntryViewModel) async {
        await vm.startRecording()
        XCTAssertEqual(vm.phase, .recording)
        await vm.finishRecording()
    }

    private func todayEntry() -> DailyEntry? {
        try? DailyEntryRepository(context: context).fetchEntry(for: Date())
    }

    func testRecordingSavesAnswersTranscriptAndAudio() async throws {
        let vm = makeViewModel()
        await record(vm)

        XCTAssertEqual(vm.phase, .saved)
        let entry = try XCTUnwrap(todayEntry())
        XCTAssertEqual(entry.feeling, 7)
        XCTAssertEqual(entry.sleepQuality, 6)
        XCTAssertEqual(entry.singleWordFeeling, "content")
        XCTAssertEqual(entry.drinks, 2)
        XCTAssertEqual(entry.win, "I finally shipped the voice journaling feature")
        XCTAssertFalse(entry.journalEntry.isEmpty)
        XCTAssertEqual(entry.voiceTranscript, ScriptedVoiceNote.transcript)
        XCTAssertTrue(entry.hasUserSubmitted)
        let audio = try XCTUnwrap(entry.voiceAudioFilenames?.first)
        XCTAssertTrue(store.exists(audio))
        XCTAssertTrue(vm.missingSteps.isEmpty)
    }

    func testStatedSleepIsNotEstimatedButToneMoodIs() async {
        let vm = makeViewModel()
        await record(vm)
        XCTAssertTrue(vm.estimatedSteps.contains(.mood))
        XCTAssertFalse(vm.estimatedSteps.contains(.sleep), "\"maybe a six\" states a number")
    }

    func testUndoOnNewDayRemovesEntryAndAudio() async throws {
        let vm = makeViewModel()
        await record(vm)
        let audio = try XCTUnwrap(todayEntry()?.voiceAudioFilenames?.first)

        vm.undo()

        XCTAssertTrue(vm.didUndo)
        XCTAssertNil(todayEntry())
        XCTAssertFalse(store.exists(audio))
    }

    func testUndoRestoresExistingEntry() async throws {
        let existing = DailyEntry(date: Calendar.current.startOfDay(for: Date()), feeling: 4, gratitude: "coffee")
        existing.hasUserSubmitted = true
        context.insert(existing)
        try context.save()

        let vm = makeViewModel()
        await record(vm)
        XCTAssertEqual(todayEntry()?.sleepQuality, 6)

        vm.undo()

        let entry = try XCTUnwrap(todayEntry())
        XCTAssertEqual(entry.feeling, 4)
        XCTAssertEqual(entry.gratitude, "coffee")
        XCTAssertEqual(entry.sleepQuality, 0)
        XCTAssertEqual(entry.voiceTranscript, "")
        XCTAssertNil(entry.voiceAudioFilenames)
    }

    func testExistingAnswersBecomeConflictsAndCanBeAccepted() async throws {
        context.insert(DailyEntry(date: Calendar.current.startOfDay(for: Date()), feeling: 4))
        try context.save()

        let vm = makeViewModel()
        await record(vm)

        XCTAssertEqual(todayEntry()?.feeling, 4, "Voice must not overwrite an existing answer")
        let conflict = try XCTUnwrap(vm.conflicts.first { $0.step == .mood })
        vm.accept(conflict)
        XCTAssertEqual(todayEntry()?.feeling, 7)
        XCTAssertTrue(vm.conflicts.isEmpty)
    }

    func testQuickAnswerFillsMissingQuestion() async {
        let vm = makeViewModel(
            transcript: "I finally fixed the login bug today.",
            extractor: FixedExtractor(extraction: VoiceExtraction(win: "I finally fixed the login bug"))
        )
        await record(vm)
        XCTAssertTrue(vm.missingSteps.contains(.sleep))

        vm.answer(.sleep) { $0.sleepQuality = 8 }

        XCTAssertEqual(todayEntry()?.sleepQuality, 8)
        XCTAssertFalse(vm.missingSteps.contains(.sleep))
        XCTAssertTrue(vm.answeredSteps.contains(.sleep))
    }

    func testWithoutModelTranscriptGoesToJournal() async throws {
        let vm = makeViewModel(transcript: "Long day. um Mostly meetings.", extractor: nil)
        await record(vm)

        XCTAssertEqual(vm.phase, .saved)
        XCTAssertTrue(vm.isFallback)
        let entry = try XCTUnwrap(todayEntry())
        XCTAssertEqual(entry.journalEntry, "Long day. Mostly meetings.")
        XCTAssertEqual(entry.feeling, 0)
    }

    func testEmptyTranscriptFailsWithoutSaving() async {
        let vm = makeViewModel(transcript: "   ")
        await record(vm)

        XCTAssertTrue(vm.phase.isFailure)
        XCTAssertNil(todayEntry())
    }

    func testCancelSavesNothing() async {
        let vm = makeViewModel()
        await vm.startRecording()
        await vm.cancelRecording()

        XCTAssertEqual(vm.phase, .idle)
        XCTAssertNil(todayEntry())
    }
}
