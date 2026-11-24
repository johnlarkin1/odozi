import AVFoundation
import Foundation
import os
import Speech

private let speechLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "SpeechTranscription")

/// A finished recording: the full transcript and the audio file (in a temporary location;
/// hand it to `VoiceRecordingStore.importRecording` to keep it).
struct VoiceRecording: Equatable {
    let transcript: String
    let audioURL: URL
    let duration: TimeInterval
}

enum SpeechTranscriptionError: Error, Equatable {
    case microphoneDenied
    case transcriberUnavailable
    case unsupportedLocale
    case notRecording
}

/// Records from the microphone while transcribing live with `SpeechAnalyzer` (iOS 26), fully
/// on-device. Audio is written to an AAC file alongside, so the note can be kept and re-transcribed
/// later.
///
/// Usage: `start(onTranscript:onLevel:)`, then `stop()` for the result or `cancel()` to discard.
/// One recording at a time.
@MainActor
final class SpeechTranscriptionService {
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Error>?
    private var tapWriter: TapWriter?
    private var startedAt: Date?
    private var finalizedText = ""
    private var volatileText = ""

    var isRecording: Bool { startedAt != nil }

    static func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Starts recording and transcribing. The first run for a language downloads its speech
    /// model, which needs a network connection once.
    ///
    /// - Parameters:
    ///   - onTranscript: Called with the full transcript so far, including words still being
    ///     recognized, as it updates.
    ///   - onLevel: Called with the input level (0...1) for a meter.
    func start(
        locale: Locale = .current,
        onTranscript: @escaping @MainActor (String) -> Void,
        onLevel: @escaping @MainActor (Float) -> Void = { _ in }
    ) async throws {
        guard !isRecording else { return }
        guard await Self.requestMicrophonePermission() else { throw SpeechTranscriptionError.microphoneDenied }
        guard SpeechTranscriber.isAvailable else { throw SpeechTranscriptionError.transcriberUnavailable }
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechTranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()

        finalizedText = ""
        volatileText = ""
        resultsTask = Task { [weak self] in
            for try await result in transcriber.results {
                guard let self else { return }
                let text = String(result.text.characters)
                if result.isFinal {
                    self.finalizedText += text
                    self.volatileText = ""
                } else {
                    self.volatileText = text
                }
                onTranscript(self.currentTranscript)
            }
        }
        try await analyzer.start(inputSequence: inputSequence)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let writer = try TapWriter(
            fileURL: fileURL,
            inputFormat: inputFormat,
            analyzerFormat: analyzerFormat,
            continuation: continuation,
            onLevel: onLevel
        )
        // The tap runs on the audio thread, so its block must not be main-actor isolated.
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: writer.makeTapBlock())
        engine.prepare()
        try engine.start()

        self.analyzer = analyzer
        inputContinuation = continuation
        tapWriter = writer
        startedAt = Date()
    }

    /// Stops recording, waits for the last words to be recognized, and returns the result.
    func stop() async throws -> VoiceRecording {
        guard let startedAt, let tapWriter else { throw SpeechTranscriptionError.notRecording }
        stopAudio()
        inputContinuation?.finish()
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
            try await resultsTask?.value
        } catch {
            speechLogger.error("Finishing transcription failed: \(error)")
        }
        tapWriter.close()
        let recording = VoiceRecording(
            transcript: currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines),
            audioURL: tapWriter.fileURL,
            duration: Date().timeIntervalSince(startedAt)
        )
        reset()
        return recording
    }

    /// Stops and throws everything away, including the audio file.
    func cancel() async {
        guard isRecording else { return }
        stopAudio()
        inputContinuation?.finish()
        resultsTask?.cancel()
        await analyzer?.cancelAndFinishNow()
        if let tapWriter {
            tapWriter.close()
            try? FileManager.default.removeItem(at: tapWriter.fileURL)
        }
        reset()
    }

    private var currentTranscript: String {
        finalizedText + volatileText
    }

    private func stopAudio() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func reset() {
        analyzer = nil
        inputContinuation = nil
        resultsTask = nil
        tapWriter = nil
        startedAt = nil
    }
}

/// Runs on the audio thread: writes each mic buffer to the AAC file, converts it for the
/// analyzer, and reports the level.
private final class TapWriter: @unchecked Sendable {
    let fileURL: URL
    private var file: AVAudioFile?
    private let analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let onLevel: @MainActor (Float) -> Void
    private let lock = NSLock()

    init(
        fileURL: URL,
        inputFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat?,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        onLevel: @escaping @MainActor (Float) -> Void
    ) throws {
        self.fileURL = fileURL
        self.analyzerFormat = analyzerFormat
        self.continuation = continuation
        self.onLevel = onLevel
        // Speech-quality AAC: ~32 kbps per channel, about 0.25 MB a minute for the mono iPhone mic.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
            AVEncoderBitRateKey: 32000 * Int(inputFormat.channelCount)
        ]
        file = try AVAudioFile(
            forWriting: fileURL,
            settings: settings,
            commonFormat: inputFormat.commonFormat,
            interleaved: inputFormat.isInterleaved
        )
    }

    func makeTapBlock() -> AVAudioNodeTapBlock {
        { [self] buffer, _ in handle(buffer) }
    }

    func handle(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try file?.write(from: buffer)
        } catch {
            speechLogger.error("Writing voice audio failed: \(error)")
        }
        if let converted = convertForAnalyzer(buffer) {
            continuation.yield(AnalyzerInput(buffer: converted))
        }
        let level = Self.level(of: buffer)
        let onLevel = onLevel
        Task { @MainActor in onLevel(level) }
    }

    /// Closes the file so it's finalized on disk.
    func close() {
        lock.lock()
        file = nil
        lock.unlock()
    }

    private func convertForAnalyzer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let analyzerFormat else { return buffer }
        if buffer.format == analyzerFormat { return buffer }
        if converter == nil {
            converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
            converter?.primeMethod = .none
        }
        guard let converter else { return nil }

        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return nil }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let error {
            speechLogger.error("Converting voice audio failed: \(error)")
            return nil
        }
        return output
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0 ..< Int(buffer.frameLength) {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        // Speech RMS sits around 0.01-0.3; map to 0...1 on a rough log scale.
        let decibels = 20 * log10(max(rms, 0.000_01))
        return min(max((decibels + 50) / 50, 0), 1)
    }
}
