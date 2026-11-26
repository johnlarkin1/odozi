import Foundation
import os

private let processorLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "VoiceNoteProcessor")

/// The result of processing one voice note, ready to show and submit.
struct ProcessedVoiceNote: Equatable {
    let transcript: String
    /// Validated answers, or nil when extraction wasn't possible and the note fell back to
    /// transcript-only.
    let extraction: VoiceExtraction?
    let plan: VoiceEntryPlan
    /// Why extraction didn't run, when it didn't.
    let fallbackReason: VoiceExtractionError?
}

/// Transcript → answers → merge plan. Extraction failures never lose the note: they fall back
/// to putting the transcript in the journal.
struct VoiceNoteProcessor {
    /// Nil when no extractor can run on this device.
    let extractor: JournalExtractor?

    /// The on-device extractor when this device supports it, else transcript-only.
    static func makeDefault() -> VoiceNoteProcessor {
        VoiceNoteProcessor(extractor: OnDeviceJournalExtractor.isAvailable ? OnDeviceJournalExtractor() : nil)
    }

    func process(transcript: String, existing: DailyEntry?) async -> ProcessedVoiceNote {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        var extraction: VoiceExtraction?
        var fallbackReason: VoiceExtractionError?

        if trimmed.isEmpty {
            // Nothing was said: nothing to extract or write.
        } else if let extractor {
            do {
                let raw = try await extractor.extract(from: trimmed)
                extraction = ExtractionValidator.validate(raw, transcript: trimmed)
            } catch let error as VoiceExtractionError {
                processorLogger.info("Voice extraction fell back to transcript-only: \(String(describing: error))")
                fallbackReason = error
            } catch {
                processorLogger.error("Voice extraction failed: \(error)")
                fallbackReason = .failed(String(describing: error))
            }
        } else {
            fallbackReason = .modelUnavailable
        }

        let plan = VoiceEntryPlan(extraction: extraction, transcript: trimmed, existing: existing)
        return ProcessedVoiceNote(transcript: trimmed, extraction: extraction, plan: plan, fallbackReason: fallbackReason)
    }
}
