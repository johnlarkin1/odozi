import Foundation

/// Drops answers the transcript doesn't support, so a hallucinated "sleep: 7" or an invented
/// gratitude never reaches the entry.
///
/// - Numbers must be in range and come with an evidence quote that actually appears in the
///   transcript (allowing for small wording differences). Drinks additionally need the quote to
///   contain a count, since a count can't be inferred from tone.
/// - Gratitude, win and tension must mostly use words that were actually said.
/// - Empty strings become nil.
enum ExtractionValidator {
    static func validate(_ extraction: VoiceExtraction, transcript: String) -> VoiceExtraction {
        let said = TranscriptText(transcript)
        var result = VoiceExtraction()

        if let mood = extraction.mood, (1 ... 10).contains(mood),
           let evidence = nonEmpty(extraction.moodEvidence), said.contains(quote: evidence) {
            result.mood = mood
            result.moodEvidence = evidence
        }
        if let sleep = extraction.sleepQuality, (1 ... 10).contains(sleep),
           let evidence = nonEmpty(extraction.sleepEvidence), said.contains(quote: evidence),
           Topic.sleep.isMentioned(in: evidence) {
            result.sleepQuality = sleep
            result.sleepEvidence = evidence
        }
        if let drinks = extraction.drinks, (0 ... 30).contains(drinks),
           let evidence = nonEmpty(extraction.drinksEvidence), said.contains(quote: evidence),
           mentionsCount(evidence) {
            result.drinks = drinks
            result.drinksEvidence = evidence
        }

        // A feeling word is a label for the day, so it may be the model's own word ("drained").
        // Cap it at a short phrase like the typed card does.
        if let word = nonEmpty(extraction.feelingWord), word.split(separator: " ").count <= 4 {
            result.feelingWord = word
            result.feelingColor = extraction.feelingColor
        }

        // Gratitude and tension need the speaker to have actually talked about them; a win is
        // anything that went well, so it needs no cue word. One sentence can answer only one of
        // the three: the model tends to copy the same line into all of them.
        var used: Set<String> = []
        func claim(_ text: String?, topic: Topic?) -> String? {
            guard let text = grounded(text, in: said) else { return nil }
            if let topic, !topic.isMentioned(in: transcript) { return nil }
            let key = TranscriptText.words(in: text).joined(separator: " ")
            guard used.insert(key).inserted else { return nil }
            return text
        }
        result.gratitude = claim(extraction.gratitude, topic: .gratitude)
        result.tension = claim(extraction.tension, topic: .tension)
        result.win = claim(extraction.win, topic: nil)
        result.journal = nonEmpty(extraction.journal)
        return result
    }

    /// True when the evidence states a count: "two beers", "had 3 glasses", "didn't drink".
    static func mentionsCount(_ evidence: String) -> Bool {
        let words = TranscriptText.words(in: evidence)
        if words.contains(where: { $0.first?.isNumber == true }) { return true }
        let countWords: Set<String> = [
            "zero", "no", "none", "one", "a", "two", "couple", "three", "four", "five", "six", "seven",
            "eight", "nine", "ten", "didnt", "didn", "sober", "dry", "nothing", "single"
        ]
        return words.contains(where: countWords.contains)
    }

    private static func grounded(_ text: String?, in said: TranscriptText) -> String? {
        guard let text = nonEmpty(text) else { return nil }
        return said.overlap(with: text) >= 0.6 ? text : nil
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// Cue words showing the speaker talked about a topic.
enum Topic {
    case sleep, gratitude, tension

    func isMentioned(in text: String) -> Bool {
        TranscriptText.words(in: text).contains { word in cues.contains { word.hasPrefix($0) } }
    }

    private var cues: [String] {
        switch self {
        case .sleep:
            return [
                "sleep", "slept", "bed", "nap", "rested", "resting", "restless", "insomnia", "woke", "wake", "awake",
                "tired", "exhausted"
            ]
        case .gratitude:
            return ["grateful", "gratitude", "thankful", "thank", "appreciat", "blessed", "lucky", "glad"]
        case .tension:
            return [
                "stress", "anxi", "worr", "tense", "tension", "frustrat", "annoy", "upset", "angry", "overwhelm",
                "hard", "tough", "rough", "difficult", "struggl", "nervous", "dread", "argu", "fight", "fought"
            ]
        }
    }
}

/// A normalized transcript for loose matching: lowercase words, punctuation and filler removed.
struct TranscriptText {
    let words: [String]
    private let joined: String
    private let wordSet: Set<String>
    private let stemIndex: [String: [String]]

    init(_ text: String) {
        words = Self.words(in: text)
        joined = " " + words.joined(separator: " ") + " "
        wordSet = Set(words)
        stemIndex = Dictionary(grouping: Set(words), by: Self.stem)
    }

    static func words(in text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !fillers.contains($0) }
    }

    /// The evidence appears in the transcript, verbatim or with at least 70% of its words.
    func contains(quote: String) -> Bool {
        let quoteWords = Self.words(in: quote)
        guard !quoteWords.isEmpty else { return false }
        if joined.contains(" " + quoteWords.joined(separator: " ") + " ") { return true }
        let hits = quoteWords.filter(wasSaid).count
        return Double(hits) / Double(quoteWords.count) >= 0.7
    }

    /// The share of `text`'s meaningful words that were said, matched loosely ("walked"/"walking").
    func overlap(with text: String) -> Double {
        let content = Self.words(in: text).filter { $0.count > 2 && !Self.stopwords.contains($0) }
        guard !content.isEmpty else { return 0 }
        let hits = content.filter(wasSaid).count
        return Double(hits) / Double(content.count)
    }

    /// The word, or a close form of it, was said: "walked" matches "walking", but "present"
    /// doesn't match "presentation".
    func wasSaid(_ word: String) -> Bool {
        if wordSet.contains(word) { return true }
        guard word.count >= 4 else { return false }
        return (stemIndex[Self.stem(word)] ?? []).contains { said in
            abs(said.count - word.count) <= 3 && (said.hasPrefix(word.dropLast(2)) || word.hasPrefix(said.dropLast(2)))
        }
    }

    private static func stem(_ word: String) -> String {
        String(word.prefix(4))
    }

    private static let fillers: Set<String> = ["um", "uh", "uhm", "erm", "hmm", "mm"]
    private static let stopwords: Set<String> = [
        "the", "and", "for", "that", "this", "with", "was", "were", "had", "have", "has", "but", "really",
        "just", "about", "today", "very", "being", "felt", "feel", "feeling", "got", "get", "its", "able",
        "finally", "grateful", "thankful", "stressed", "stress", "win", "tension"
    ]
}

/// Tidies a raw transcript into journal text without changing what was said: drops filler
/// words, collapses whitespace, and capitalizes the first letter.
enum TranscriptCleaner {
    static func clean(_ transcript: String) -> String {
        let fillerPattern = #"(?i)(?<![\w'])(um+|uh+|uhm+|erm+|hmm+)(?![\w'])[,.]?\s*"#
        var text = transcript.replacingOccurrences(of: fillerPattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" +([,.!?])"#, with: "$1", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return "" }
        return first.uppercased() + text.dropFirst()
    }
}
