import SwiftData
import SwiftUI

/// Full-screen voice journaling: talk through your day, then see what was saved.
struct VoiceEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VoiceEntryViewModel?
    @State private var showingGuidedFlow = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let vm = viewModel {
                content(vm)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task {
                    if viewModel?.phase == .recording || viewModel?.phase == .preparing {
                        await viewModel?.cancelRecording()
                    }
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("voiceEntryClose")
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
        .fullScreenCover(isPresented: $showingGuidedFlow, onDismiss: { dismiss() }) {
            GuidedPromptFlowView()
        }
        .onAppear {
            if viewModel == nil {
                viewModel = VoiceEntryViewModel.makeDefault(modelContext: modelContext)
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: VoiceEntryViewModel) -> some View {
        switch vm.phase {
        case .idle, .preparing, .recording:
            VoiceRecordingPanel(viewModel: vm)
        case .processing:
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.accentAmber)
                Text("Pulling out your answers…")
                    .font(.headline)
                Text("This happens on your iPhone. Nothing leaves your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        case .saved:
            VoiceResultsView(
                viewModel: vm,
                onDone: { dismiss() },
                onEdit: { showingGuidedFlow = true }
            )
        case let .failed(message):
            VStack(spacing: 20) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.coralRed)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await vm.startRecording() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentAmber)
            }
            .padding(32)
        }
    }
}

// MARK: - Recording

private struct VoiceRecordingPanel: View {
    let viewModel: VoiceEntryViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Talk through your day")
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                Text("Cover whatever you like. I'll fill in your answers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 56)

            PromptCheatSheet()

            transcriptArea

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                if viewModel.phase == .recording {
                    LevelMeter(level: viewModel.level)
                    Text(Self.format(viewModel.elapsed))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                recordButton
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(transcriptText)
                    .font(.body)
                    .foregroundStyle(viewModel.liveTranscript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .id("transcript")
                    .accessibilityIdentifier("voiceLiveTranscript")
            }
            .frame(maxHeight: 260)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardSurface))
            .onChange(of: viewModel.liveTranscript) { _, _ in
                proxy.scrollTo("transcript", anchor: .bottom)
            }
        }
    }

    private var transcriptText: String {
        if !viewModel.liveTranscript.isEmpty { return viewModel.liveTranscript }
        switch viewModel.phase {
        case .preparing: return "Getting ready…"
        case .recording: return "Listening…"
        default: return "Your words will appear here as you talk."
        }
    }

    private var recordButton: some View {
        let isRecording = viewModel.phase == .recording
        return Button {
            Task {
                if isRecording {
                    await viewModel.finishRecording()
                } else {
                    await viewModel.startRecording()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.coralRed : Color.accentAmber)
                    .frame(width: 84, height: 84)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.black)
            }
        }
        .disabled(viewModel.phase == .preparing)
        .accessibilityLabel(isRecording ? "Stop and save" : "Start recording")
        .accessibilityIdentifier(isRecording ? "voiceStopButton" : "voiceRecordButton")
    }

    static func format(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// The questions, as a reminder of what to cover.
private struct PromptCheatSheet: View {
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(VoiceEntryPlan.voiceSteps) { step in
                Label(Self.shortTitle(step), systemImage: step.iconName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(step.iconColor)
            }
        }
    }

    static func shortTitle(_ step: PromptStep) -> String {
        switch step {
        case .mood: return "Mood"
        case .feeling: return "Vibe"
        case .sleep: return "Sleep"
        case .gratitude: return "Gratitude"
        case .win: return "Win"
        case .tension: return "Stress"
        case .journal: return "Anything else"
        case .drinks: return "Drinks"
        case .photo: return "Photo"
        case .location: return "Location"
        }
    }
}

private struct LevelMeter: View {
    let level: Float

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 12, id: \.self) { index in
                Capsule()
                    .fill(Float(index) / 12 < level ? Color.accentAmber : Color.white.opacity(0.15))
                    .frame(width: 6, height: 8 + CGFloat(index % 4) * 4)
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
        .accessibilityHidden(true)
    }
}
