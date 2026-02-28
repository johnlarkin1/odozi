import SwiftUI

struct OnboardingNavigationBar: View {
    let step: OnboardingStep
    let isFirstStep: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void
    let onEnable: () -> Void

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

            // Skip button (only on permission steps)
            if step.isPermissionStep {
                Button("Skip") {
                    onSkip()
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Enable / Continue button
            if step.isPermissionStep {
                Button(action: onEnable) {
                    HStack(spacing: 4) {
                        Text(enableButtonTitle)
                        Image(systemName: "chevron.right")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(step.iconColor)
                    .clipShape(Capsule())
                }
            } else if step != .completion {
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

    private var enableButtonTitle: String {
        #if targetEnvironment(simulator)
        if step == .screenTime {
            return "Continue"
        }
        #endif
        return "Enable"
    }
}
