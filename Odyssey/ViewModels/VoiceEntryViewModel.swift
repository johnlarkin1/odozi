import AVFoundation
import Foundation
import os
import SwiftData

private let voiceEntryLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "VoiceEntry")

/// Records audio and streams a transcript. `SpeechTranscriptionService` in the app; a scripted
/// fake for tests and demos.
@MainActor
protocol VoiceRecorder: AnyObject {
    func start(
        onTranscript: @escaping @MainActor (String) -> Void,
        onLevel: @escaping @MainActor (Float) -> Void
    ) async throws
    func stop() async throws -> VoiceRecording
    func cancel() async
}

extension SpeechTranscriptionService: VoiceRecorder {
    func start(
        onTranscript: @escaping @MainActor (String) -> Void,
        onLevel: @escaping @MainActor (Float) -> Void
    ) async throws {
        try await start(locale: .current, onTranscript: onTranscript, onLevel: onLevel)
    }
}

/// Drives a voice entry: record → transcribe → extract → save automatically → show what was
/// saved, with undo, quick inputs for what wasn't covered, and accepting conflicting answers.
@MainActor
@Observable
final class VoiceEntryViewModel {
    enum Phase: Equatable {
        case idle
        case preparing
        case recording
        case processing
        case saved
        case failed(String)
    }

    /// Recordings stop on their own at this length (keeps the transcript inside the model's
    /// context window).
    static let maxDuration: TimeInterval = 10 * 60

    private(set) var phase: Phase = .idle
    private(set) var liveTranscript = ""
    private(set) var level: Float = 0
    private(set) var elapsed: TimeInterval = 0
    /// What was processed and saved; set once `phase == .saved`.
    private(set) var note: ProcessedVoiceNote?
    /// Questions answered by this note (including quick inputs and accepted conflicts).
    private(set) var answeredSteps: Set<PromptStep> = []
    private(set) var conflicts: [VoiceConflict] = []
    private(set) var didUndo = false

    let targetDate: Date
    private let modelContext: ModelContext
    private let recorder: VoiceRecorder
    private let processor: VoiceNoteProcessor
    private let store: VoiceRecordingStore
    private var timerTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?
    private var undoSnapshot: EntrySnapshot?

    init(
        modelContext: ModelContext,
        date: Date = Date(),
        recorder: VoiceRecorder,
        processor: VoiceNoteProcessor,
        store: VoiceRecordingStore = .shared
    ) {
        self.modelContext = modelContext
        targetDate = Calendar.current.startOfDay(for: date)
        self.recorder = recorder
        self.processor = processor
        self.store = store
    }

    var isFallback: Bool {
        note?.fallbackReason != nil && !(note?.transcript.isEmpty ?? true)
    }

    /// Unanswered questions after this note, in prompt order.
    var missingSteps: [PromptStep] {
        guard let entry = fetchEntry() else { return VoiceEntryPlan.voiceSteps }
        return VoiceEntryPlan.voiceSteps.filter { !Self.isAnswered($0, on: entry) }
    }

    var estimatedSteps: Set<PromptStep> {
        (note?.plan.estimated ?? []).intersection(answeredSteps)
    }

    // MARK: - Recording

    func startRecording() async {
        guard phase == .idle || phase.isFailure else { return }
        phase = .preparing
        liveTranscript = ""
        elapsed = 0
        do {
            try await recorder.start(
                onTranscript: { [weak self] text in self?.liveTranscript = text },
                onLevel: { [weak self] level in self?.level = level }
            )
            phase = .recording
            startTimer()
            observeInterruptions()
        } catch {
            voiceEntryLogger.error("Couldn't start voice recording: \(error)")
            phase = .failed(Self.message(for: error))
        }
    }

    /// Stops recording, then extracts and saves.
    func finishRecording() async {
        guard phase == .recording else { return }
        stopObserving()
        phase = .processing
        do {
            let recording = try await recorder.stop()
            await process(recording)
        } catch {
            voiceEntryLogger.error("Couldn't finish voice recording: \(error)")
            phase = .failed("Something went wrong finishing the recording. Please try again.")
        }
    }

    /// Throws the recording away without saving anything.
    func cancelRecording() async {
        stopObserving()
        await recorder.cancel()
        phase = .idle
        liveTranscript = ""
    }

    private func process(_ recording: VoiceRecording) async {
        let transcript = recording.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            try? FileManager.default.removeItem(at: recording.audioURL)
            phase = .failed("I didn't catch anything. Try again a little closer to the mic.")
            return
        }

        let existing = fetchEntry()
        undoSnapshot = EntrySnapshot(entry: existing)
        let processed = await processor.process(transcript: transcript, existing: existing)

        var audioFilename: String?
        do {
            audioFilename = try store.importRecording(from: recording.audioURL)
        } catch {
            // Keep the entry even if the audio couldn't be kept.
            voiceEntryLogger.error("Couldn't keep voice audio: \(error)")
        }

        do {
            try EntrySubmitter(context: modelContext).submit(
                processed.plan.responses,
                answered: processed.plan.answered,
                for: targetDate,
                voice: VoiceCapture(transcript: transcript, audioFilename: audioFilename)
            )
            note = processed
            answeredSteps = processed.plan.answered
            conflicts = processed.plan.conflicts
            undoSnapshot?.addedAudio = audioFilename
            phase = .saved
        } catch {
            voiceEntryLogger.error("Couldn't save voice entry: \(error)")
            if let audioFilename { store.delete(audioFilename) }
            phase = .failed("Couldn't save your entry. Your note wasn't lost: please try again.")
        }
    }

    // MARK: - After saving

    /// Answers a question the note didn't cover (mood, sleep or drinks quick inputs).
    func answer(_ step: PromptStep, with update: (inout PromptResponses) -> Void) {
        var responses = PromptResponses()
        update(&responses)
        save(responses, answered: [step])
    }

    /// Uses the voice note's answer instead of the one already on the entry.
    func accept(_ conflict: VoiceConflict) {
        guard var plan = note?.plan, let extraction = note?.extraction else { return }
        plan.accept(conflict, from: extraction)
        conflicts.removeAll { $0.step == conflict.step }
        save(plan.responses, answered: [conflict.step])
    }

    func keepExisting(_ conflict: VoiceConflict) {
        conflicts.removeAll { $0.step == conflict.step }
    }

    /// Puts the entry back exactly as it was before this voice note, and deletes its audio.
    func undo() {
        guard let snapshot = undoSnapshot else { return }
        do {
            if let audio = snapshot.addedAudio { store.delete(audio) }
            if snapshot.existed {
                if let entry = fetchEntry() { snapshot.restore(entry) }
            } else if let entry = fetchEntry() {
                modelContext.delete(entry)
            }
            try modelContext.save()
            didUndo = true
            undoSnapshot = nil
        } catch {
            voiceEntryLogger.error("Couldn't undo voice entry: \(error)")
        }
    }

    func currentValue(for step: PromptStep) -> String? {
        guard let entry = fetchEntry(), Self.isAnswered(step, on: entry) else { return nil }
        switch step {
        case .mood: return "\(entry.feeling)/10"
        case .feeling: return entry.singleWordFeeling
        case .sleep: return "\(entry.sleepQuality)/10"
        case .gratitude: return entry.gratitude
        case .win: return entry.win
        case .tension: return entry.tension
        case .journal: return entry.journalEntry
        case .drinks: return entry.drinks == 1 ? "1 drink" : "\(entry.drinks) drinks"
        case .photo, .location: return nil
        }
    }

    func feelingColorHex() -> String? {
        fetchEntry()?.feelingColorHex
    }

    private func save(_ responses: PromptResponses, answered: Set<PromptStep>) {
        do {
            try EntrySubmitter(context: modelContext).submit(responses, answered: answered, for: targetDate)
            answeredSteps.formUnion(answered)
        } catch {
            voiceEntryLogger.error("Couldn't save voice follow-up answer: \(error)")
        }
    }

    private func fetchEntry() -> DailyEntry? {
        try? DailyEntryRepository(context: modelContext).fetchEntry(for: targetDate)
    }

    private static func isAnswered(_ step: PromptStep, on entry: DailyEntry) -> Bool {
        switch step {
        case .mood: return entry.feeling > 0
        case .feeling: return !entry.singleWordFeeling.isEmpty
        case .sleep: return entry.sleepQuality > 0
        case .gratitude: return !entry.gratitude.isEmpty
        case .win: return !entry.win.isEmpty
        case .tension: return !entry.tension.isEmpty
        case .journal: return !entry.journalEntry.isEmpty
        // 0 drinks can't be told apart from "not answered" in the model.
        case .drinks: return entry.drinks > 0
        case .photo, .location: return true
        }
    }

    // MARK: - Timer and interruptions

    private func startTimer() {
        timerTask?.cancel()
        let started = Date()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.phase == .recording else { return }
                self.elapsed = Date().timeIntervalSince(started)
                if self.elapsed >= Self.maxDuration {
                    await self.finishRecording()
                    return
                }
            }
        }
    }

    /// A phone call or Siri takes the mic away: keep what was said so far.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in await self?.finishRecording() }
        }
    }

    private func stopObserving() {
        timerTask?.cancel()
        timerTask = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
    }

    private static func message(for error: Error) -> String {
        switch error as? SpeechTranscriptionError {
        case .microphoneDenied:
            return "Odozi needs microphone access to record. You can turn it on in Settings."
        case .transcriberUnavailable, .unsupportedLocale:
            return "On-device speech recognition isn't available for your language on this device yet."
        case .notRecording, .none:
            return "Couldn't start recording. If this is the first time, the speech model may need a network connection to download."
        }
    }
}

extension VoiceEntryViewModel.Phase {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// The prompt and voice fields of an entry before a voice note, for undo.
private struct EntrySnapshot {
    let existed: Bool
    var addedAudio: String?
    private var feeling = 0
    private var singleWordFeeling = ""
    private var feelingColorHex = "#FFFFFF"
    private var sleepQuality = 0
    private var gratitude = ""
    private var win = ""
    private var tension = ""
    private var journalEntry = ""
    private var drinks = 0
    private var voiceTranscript = ""
    private var voiceAudioFilenames: [String]?
    private var hasUserSubmitted = false
    private var firstSubmittedAt: Date?

    init(entry: DailyEntry?) {
        existed = entry != nil
        guard let entry else { return }
        feeling = entry.feeling
        singleWordFeeling = entry.singleWordFeeling
        feelingColorHex = entry.feelingColorHex
        sleepQuality = entry.sleepQuality
        gratitude = entry.gratitude
        win = entry.win
        tension = entry.tension
        journalEntry = entry.journalEntry
        drinks = entry.drinks
        voiceTranscript = entry.voiceTranscript
        voiceAudioFilenames = entry.voiceAudioFilenames
        hasUserSubmitted = entry.hasUserSubmitted
        firstSubmittedAt = entry.firstSubmittedAt
    }

    func restore(_ entry: DailyEntry) {
        entry.feeling = feeling
        entry.singleWordFeeling = singleWordFeeling
        entry.feelingColorHex = feelingColorHex
        entry.sleepQuality = sleepQuality
        entry.gratitude = gratitude
        entry.win = win
        entry.tension = tension
        entry.journalEntry = journalEntry
        entry.drinks = drinks
        entry.voiceTranscript = voiceTranscript
        entry.voiceAudioFilenames = voiceAudioFilenames
        entry.hasUserSubmitted = hasUserSubmitted
        entry.firstSubmittedAt = firstSubmittedAt
        entry.updatedAt = Date()
    }
}
