import SwiftUI

struct LocationPermissionCard: View {
    var body: some View {
        PromptCardContainer(
            iconName: OnboardingStep.location.iconName,
            iconColor: OnboardingStep.location.iconColor,
            title: OnboardingStep.location.title,
            subtitle: OnboardingStep.location.subtitle
        ) {
            VStack(spacing: 16) {
                featureRow(icon: "map.fill", text: "Build a personal map of your journey")
                featureRow(icon: "lock.shield.fill", text: "Sampled on movement, stays on device")
                featureRow(icon: "moon.zzz.fill", text: "Captures in the background with \"Always\" enabled")
            }
            .padding(.horizontal, 8)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentTeal)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
