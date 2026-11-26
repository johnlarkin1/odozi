import Foundation
import SwiftData

extension VoiceEntryViewModel {
    /// Launch-environment key: when set (UI tests and demo recordings), the voice flow "hears" a
    /// scripted note instead of using the microphone, since the simulator has no real speech.
    static let scriptedNoteEnvironmentKey = "VOICE_DEMO_NOTE"

    /// The real microphone and on-device model, or the scripted note when the launch environment
    /// asks for it.
    static func makeDefault(modelContext: ModelContext) -> VoiceEntryViewModel {
        #if DEBUG
            if ProcessInfo.processInfo.environment[scriptedNoteEnvironmentKey] != nil {
                return VoiceEntryViewModel(
                    modelContext: modelContext,
                    recorder: ScriptedVoiceRecorder(transcript: ScriptedVoiceNote.transcript),
                    processor: VoiceNoteProcessor(extractor: ScriptedJournalExtractor())
                )
            }
        #endif
        return VoiceEntryViewModel(
            modelContext: modelContext,
            recorder: SpeechTranscriptionService(),
            processor: .makeDefault()
        )
    }
}

#if DEBUG
    enum ScriptedVoiceNote {
        static let transcript = """
        Today was pretty good honestly. I slept okay, maybe a six. I'm grateful my sister called \
        this morning. My win is that I finally shipped the voice journaling feature. The only \
        stressful thing was traffic on the way home. And I had two glasses of wine last night.
        """

        /// What the on-device model typically returns for `transcript`.
        static let extraction = VoiceExtraction(
            mood: 7, moodEvidence: "Today was pretty good honestly",
            feelingWord: "content", feelingColor: .teal,
            sleepQuality: 6, sleepEvidence: "I slept okay, maybe a six",
            gratitude: "My sister called this morning",
            win: "I finally shipped the voice journaling feature",
            tension: "Traffic on the way home",
            drinks: 2, drinksEvidence: "I had two glasses of wine last night"
        )
    }

    /// "Speaks" a fixed transcript a few words at a time, with a moving level meter.
    @MainActor
    final class ScriptedVoiceRecorder: VoiceRecorder {
        private let transcript: String
        private var task: Task<Void, Never>?
        private var spoken = ""

        init(transcript: String) {
            self.transcript = transcript
        }

        func start(
            onTranscript: @escaping @MainActor (String) -> Void,
            onLevel: @escaping @MainActor (Float) -> Void
        ) async throws {
            let words = transcript.split(separator: " ")
            task = Task { [weak self] in
                for (index, word) in words.enumerated() {
                    try? await Task.sleep(for: .milliseconds(180))
                    guard !Task.isCancelled, let self else { return }
                    self.spoken += (index == 0 ? "" : " ") + word
                    onTranscript(self.spoken)
                    onLevel(Float.random(in: 0.3 ... 0.9))
                }
                onLevel(0)
            }
        }

        func stop() async throws -> VoiceRecording {
            task?.cancel()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("scripted-\(UUID().uuidString).m4a")
            try Data().write(to: url)
            // Demo recordings show the whole note even if stopped early.
            return VoiceRecording(transcript: transcript, audioURL: url, duration: 30)
        }

        func cancel() async {
            task?.cancel()
        }
    }

    struct ScriptedJournalExtractor: JournalExtractor {
        func extract(from transcript: String) async throws -> VoiceExtraction {
            try? await Task.sleep(for: .seconds(1))
            var extraction = ScriptedVoiceNote.extraction
            extraction.journal = TranscriptCleaner.clean(transcript)
            return extraction
        }
    }
#endif
