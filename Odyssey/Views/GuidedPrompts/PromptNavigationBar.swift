import SwiftUI

struct PromptNavigationBar: View {
    let isFirstStep: Bool
    let isLastStep: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.body.weight(.medium))
            }
            .opacity(isFirstStep ? 0 : 1)
            .disabled(isFirstStep)

            Spacer()

            // Skip button
            if !isLastStep {
                Button("Skip") {
                    onSkip()
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Next / Submit button
            if isLastStep {
                Button(action: onSubmit) {
                    Text("Submit")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.accentAmber)
                        .clipShape(Capsule())
                }
            } else {
                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentAmber)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 12)
    }
}
