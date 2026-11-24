import Foundation

/// An answer voice wanted to change on an entry that already had one. Shown on the results
/// screen so the user decides; never applied automatically.
struct VoiceConflict: Equatable, Identifiable {
    let step: PromptStep
    let existing: String
    let proposed: String

    var id: PromptStep { step }
}

/// What a voice note will write to the day's entry, after merging with what's already there.
///
/// Merge rules: voice only fills questions that are still unanswered. Different answers to
/// already-answered questions become `conflicts`. The journal is the exception: a voice note's
/// journal text is appended, since free-writing accumulates over a day.
struct VoiceEntryPlan: Equatable {
    var responses = PromptResponses()
    /// Steps `EntrySubmitter` should write.
    var answered: Set<PromptStep> = []
    /// Answered numbers the model inferred from tone rather than heard as a number.
    var estimated: Set<PromptStep> = []
    var conflicts: [VoiceConflict] = []
    /// Questions still unanswered after this note, in prompt order, for the quick inputs.
    var missing: [PromptStep] = []

    /// The steps voice can answer. Photo and location come from elsewhere.
    static let voiceSteps: [PromptStep] = [.mood, .feeling, .sleep, .gratitude, .win, .tension, .journal, .drinks]

    init() {}

    /// - Parameters:
    ///   - extraction: Already validated answers. Nil when no extractor ran (fallback): the
    ///     transcript then becomes the journal and everything else is left for quick inputs.
    ///   - existing: The day's entry, if there is one.
    init(extraction: VoiceExtraction?, transcript: String, existing: DailyEntry?) {
        let current = Answers(entry: existing)
        let journalText = extraction?.journal ?? transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = extraction ?? VoiceExtraction(journal: journalText.isEmpty ? nil : journalText)

        consider(.mood, voice.mood.map(String.init), current: current.mood) {
            $0.feeling = voice.mood ?? 0
        }
        if voice.mood != nil, !Self.saysNumber(voice.moodEvidence) { estimated.insert(.mood) }

        consider(.feeling, voice.feelingWord, current: current.feelingWord) {
            $0.singleWordFeeling = voice.feelingWord ?? ""
            $0.feelingColorHex = voice.feelingColor?.hex ?? existing?.feelingColorHex ?? "#FFFFFF"
        }
        consider(.sleep, voice.sleepQuality.map(String.init), current: current.sleep) {
            $0.sleepQuality = voice.sleepQuality ?? 0
        }
        if voice.sleepQuality != nil, !Self.saysNumber(voice.sleepEvidence) { estimated.insert(.sleep) }

        consider(.gratitude, voice.gratitude, current: current.gratitude) { $0.gratitude = voice.gratitude ?? "" }
        consider(.win, voice.win, current: current.win) { $0.win = voice.win ?? "" }
        consider(.tension, voice.tension, current: current.tension) { $0.tension = voice.tension ?? "" }
        consider(.drinks, voice.drinks.map(String.init), current: current.drinks) { $0.drinks = voice.drinks ?? 0 }

        if let journal = voice.journal {
            responses.journalEntry = current.journal.map { $0 + "\n\n" + journal } ?? journal
            answered.insert(.journal)
        }

        estimated.formIntersection(answered)
        missing = Self.voiceSteps.filter { step in
            !answered.contains(step) && !current.isAnswered(step) && !conflicts.contains { $0.step == step }
        }
    }

    /// Accepts a conflicting answer: it will overwrite the existing one when submitted.
    mutating func accept(_ conflict: VoiceConflict, from extraction: VoiceExtraction) {
        conflicts.removeAll { $0.step == conflict.step }
        switch conflict.step {
        case .mood: responses.feeling = extraction.mood ?? responses.feeling
        case .feeling:
            responses.singleWordFeeling = extraction.feelingWord ?? responses.singleWordFeeling
            if let color = extraction.feelingColor { responses.feelingColorHex = color.hex }
        case .sleep: responses.sleepQuality = extraction.sleepQuality ?? responses.sleepQuality
        case .gratitude: responses.gratitude = extraction.gratitude ?? responses.gratitude
        case .win: responses.win = extraction.win ?? responses.win
        case .tension: responses.tension = extraction.tension ?? responses.tension
        case .drinks: responses.drinks = extraction.drinks ?? responses.drinks
        case .journal, .photo, .location: return
        }
        answered.insert(conflict.step)
    }

    private mutating func consider(
        _ step: PromptStep,
        _ proposed: String?,
        current: String?,
        write: (inout PromptResponses) -> Void
    ) {
        guard let proposed else { return }
        if let current {
            if current.caseInsensitiveCompare(proposed) != .orderedSame {
                conflicts.append(VoiceConflict(step: step, existing: current, proposed: proposed))
            }
            return
        }
        write(&responses)
        answered.insert(step)
    }

    /// The evidence says a number outright ("like a seven", "8 out of 10"), so it isn't an estimate.
    static func saysNumber(_ evidence: String?) -> Bool {
        guard let evidence else { return false }
        let numberWords: Set<String> = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return TranscriptText.words(in: evidence).contains { $0.first?.isNumber == true || numberWords.contains($0) }
    }
}

/// The day's existing answers, as display strings; nil means unanswered (0 / "" sentinels).
private struct Answers {
    var mood: String?
    var feelingWord: String?
    var sleep: String?
    var gratitude: String?
    var win: String?
    var tension: String?
    var journal: String?
    var drinks: String?

    init(entry: DailyEntry?) {
        guard let entry else { return }
        mood = entry.feeling > 0 ? String(entry.feeling) : nil
        feelingWord = entry.singleWordFeeling.isEmpty ? nil : entry.singleWordFeeling
        sleep = entry.sleepQuality > 0 ? String(entry.sleepQuality) : nil
        gratitude = entry.gratitude.isEmpty ? nil : entry.gratitude
        win = entry.win.isEmpty ? nil : entry.win
        tension = entry.tension.isEmpty ? nil : entry.tension
        journal = entry.journalEntry.isEmpty ? nil : entry.journalEntry
        // 0 drinks is indistinguishable from "not answered" in the model, so only counts > 0
        // count as an existing answer.
        drinks = entry.drinks > 0 ? String(entry.drinks) : nil
    }

    func isAnswered(_ step: PromptStep) -> Bool {
        switch step {
        case .mood: return mood != nil
        case .feeling: return feelingWord != nil
        case .sleep: return sleep != nil
        case .gratitude: return gratitude != nil
        case .win: return win != nil
        case .tension: return tension != nil
        case .journal: return journal != nil
        case .drinks: return drinks != nil
        case .photo, .location: return true
        }
    }
}
