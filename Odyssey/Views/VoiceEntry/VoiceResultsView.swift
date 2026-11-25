import SwiftUI

/// "Here's what I saved": every answer from the voice note, quick inputs for questions it didn't
/// cover, and conflicts with answers already on the entry. The entry is already saved when this
/// shows; Undo puts it back the way it was.
struct VoiceResultsView: View {
    let viewModel: VoiceEntryViewModel
    let onDone: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if viewModel.didUndo {
                    Text("Undone. Your entry is back to how it was, and the recording was deleted.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if viewModel.isFallback {
                        fallbackBanner
                    }
                    if !viewModel.conflicts.isEmpty {
                        conflictsSection
                    }
                    answersSection
                    if !viewModel.missingSteps.isEmpty {
                        missingSection
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) { buttons }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.didUndo ? "Nothing saved" : "Here's what I saved")
                .font(.title2.bold())
                .fontDesign(.rounded)
                .accessibilityIdentifier("voiceResultsTitle")
            if !viewModel.didUndo {
                Text("Tap Edit to change anything.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fallbackBanner: some View {
        Label {
            Text(fallbackText)
                .font(.subheadline)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.accentTeal)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardSurface))
    }

    private var fallbackText: String {
        switch viewModel.note?.fallbackReason {
        case .modelUnavailable:
            return "Your note is saved to your journal. Sorting it into answers needs Apple Intelligence, so fill in the rest below."
        default:
            return "Your note is saved to your journal. I couldn't sort it into answers this time, so fill in the rest below."
        }
    }

    // MARK: Answers

    private var answersSection: some View {
        VStack(spacing: 10) {
            ForEach(VoiceEntryPlan.voiceSteps.filter { viewModel.answeredSteps.contains($0) }) { step in
                if let value = viewModel.currentValue(for: step) {
                    AnswerRow(
                        step: step,
                        value: value,
                        isEstimated: viewModel.estimatedSteps.contains(step),
                        accent: step == .feeling ? viewModel.feelingColorHex().map { Color(hex: $0) } : nil
                    )
                }
            }
        }
    }

    // MARK: Conflicts

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You already answered these today")
                .font(.headline)
            ForEach(viewModel.conflicts) { conflict in
                VStack(alignment: .leading, spacing: 8) {
                    Label(conflict.step.title, systemImage: conflict.step.iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(conflict.step.iconColor)
                    Text("Saved: \(conflict.existing)")
                        .font(.subheadline)
                    Text("From this note: \(conflict.proposed)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Use new answer") { viewModel.accept(conflict) }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentAmber)
                        Button("Keep saved") { viewModel.keepExisting(conflict) }
                            .buttonStyle(.bordered)
                    }
                    .font(.subheadline)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardSurface))
            }
        }
    }

    // MARK: Missing

    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Not mentioned")
                .font(.headline)
            ForEach(viewModel.missingSteps) { step in
                QuickAnswerRow(step: step, viewModel: viewModel)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            if !viewModel.didUndo {
                Button("Undo") { viewModel.undo() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("voiceUndoButton")
                Button("Edit") { onEdit() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("voiceEditButton")
            }
            Spacer()
            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .tint(.accentAmber)
                .accessibilityIdentifier("voiceDoneButton")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black)
    }
}

private struct AnswerRow: View {
    let step: PromptStep
    let value: String
    let isEstimated: Bool
    let accent: Color?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.iconName)
                .foregroundStyle(accent ?? step.iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(step.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isEstimated {
                        Text("estimated")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(value)
                    .font(.body)
                    .lineLimit(step == .journal ? 6 : 3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardSurface))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voiceAnswer_\(step)")
    }
}

/// Quick inputs for the numeric questions; text questions point to Edit.
private struct QuickAnswerRow: View {
    let step: PromptStep
    let viewModel: VoiceEntryViewModel
    @State private var drinks = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(step.title, systemImage: step.iconName)
                .font(.subheadline)
                .foregroundStyle(step.iconColor)
            switch step {
            case .mood, .sleep:
                HStack(spacing: 4) {
                    ForEach(1 ... 10, id: \.self) { value in
                        Button("\(value)") {
                            viewModel.answer(step) { responses in
                                if step == .mood { responses.feeling = value } else { responses.sleepQuality = value }
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                        .accessibilityLabel("\(step == .mood ? "Mood" : "Sleep") \(value) out of 10")
                    }
                }
                .buttonStyle(.plain)
            case .drinks:
                HStack {
                    Stepper("\(drinks) \(drinks == 1 ? "drink" : "drinks")", value: $drinks, in: 0 ... 30)
                    Button("Save") {
                        viewModel.answer(.drinks) { $0.drinks = drinks }
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline)
            default:
                Text("Tap Edit to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardSurface))
    }
}
