import Foundation
import os
import SwiftData

private let submitterLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "EntrySubmitter")

/// A voice note to attach to the day's entry alongside its answers.
struct VoiceCapture: Equatable {
    /// The raw speech-to-text, before any cleanup.
    var transcript: String
    /// File name inside `VoiceRecordingStore`, or nil when no audio was kept.
    var audioFilename: String?
}

/// The one place prompt answers get written onto a `DailyEntry`. The guided flow and voice
/// journaling both submit through here, so they share the same rules: only answered steps are
/// written, `hasUserSubmitted` is set only when there's real content, and achievements are
/// evaluated once per save.
@MainActor
struct EntrySubmitter {
    let context: ModelContext

    struct Submission {
        let entry: DailyEntry
        let unlockedAchievements: [Achievement]
    }

    /// Saves `responses` to the entry for `date`, creating the entry if needed.
    ///
    /// - Parameters:
    ///   - answered: The steps whose answers should be written. A step that's missing here is
    ///     left exactly as it is on the entry, so defaults like `sleepQuality = 5` never become
    ///     phantom answers.
    ///   - voice: A voice note to append to the entry's transcript and recordings.
    @discardableResult
    func submit(
        _ responses: PromptResponses,
        answered: Set<PromptStep>,
        for date: Date,
        voice: VoiceCapture? = nil
    ) throws -> Submission {
        let repository = DailyEntryRepository(context: context)
        let entry = try repository.fetchOrCreate(for: date)

        Self.apply(responses, answered: answered, to: entry)
        if let voice {
            Self.apply(voice, to: entry)
        }
        if let photoData = responses.attachedPhotoData {
            Self.attachPhoto(photoData, to: entry)
        }

        // Only mark as submitted if the user actually provided content.
        if entry.hasPromptData {
            entry.hasUserSubmitted = true
            if entry.firstSubmittedAt == nil {
                entry.firstSubmittedAt = Date()
            }
        }
        entry.updatedAt = Date()

        try context.save()
        NotificationCenter.default.post(name: .didSaveFirstEntry, object: nil)

        let achievementService = AchievementService(modelContext: context)
        let allEntries = (try? context.fetch(FetchDescriptor<DailyEntry>())) ?? []
        let unlocked = achievementService.evaluateAll(entries: allEntries, latestEntry: entry)
        return Submission(entry: entry, unlockedAchievements: unlocked)
    }

    /// Writes the fields for each answered step onto `entry`.
    static func apply(_ responses: PromptResponses, answered: Set<PromptStep>, to entry: DailyEntry) {
        if answered.contains(.mood) {
            entry.feeling = responses.feeling
        }
        if answered.contains(.feeling) {
            entry.singleWordFeeling = responses.singleWordFeeling
            entry.feelingColorHex = responses.feelingColorHex
        }
        if answered.contains(.sleep) {
            entry.sleepQuality = responses.sleepQuality
        }
        if answered.contains(.gratitude) {
            entry.gratitude = responses.gratitude
        }
        if answered.contains(.win) {
            entry.win = responses.win
        }
        if answered.contains(.tension) {
            entry.tension = responses.tension
        }
        if answered.contains(.journal) {
            entry.journalEntry = responses.journalEntry
        }
        if answered.contains(.drinks) {
            entry.drinks = responses.drinks
        }
    }

    /// Appends a voice note: transcripts accumulate (one paragraph per note) and so do recordings.
    static func apply(_ voice: VoiceCapture, to entry: DailyEntry) {
        let transcript = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            entry.voiceTranscript = entry.voiceTranscript.isEmpty
                ? transcript
                : entry.voiceTranscript + "\n\n" + transcript
        }
        if let filename = voice.audioFilename {
            var filenames = entry.voiceAudioFilenames ?? []
            if !filenames.contains(filename) {
                filenames.append(filename)
            }
            entry.voiceAudioFilenames = filenames
        }
    }

    private static func attachPhoto(_ photoData: Data, to entry: DailyEntry) {
        var existing = entry.attachedPhotoData ?? []
        existing.append(photoData)
        entry.attachedPhotoData = existing
        #if os(iOS)
            if let thumbnail = PhotoLibraryService.generateMapThumbnail(from: photoData) {
                entry.mapThumbnailData = thumbnail
                entry.showOnPhotoMap = true
            } else {
                submitterLogger.error(
                    "Failed to generate map thumbnail from attached photo (\(photoData.count) bytes)"
                )
            }
        #endif
    }
}
