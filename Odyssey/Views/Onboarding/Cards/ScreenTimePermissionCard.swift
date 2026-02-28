import SwiftUI

struct ScreenTimePermissionCard: View {
    var body: some View {
        PromptCardContainer(
            iconName: OnboardingStep.screenTime.iconName,
            iconColor: OnboardingStep.screenTime.iconColor,
            title: OnboardingStep.screenTime.title,
            subtitle: OnboardingStep.screenTime.subtitle
        ) {
            VStack(spacing: 16) {
                featureRow(icon: "chart.bar.fill", text: "Correlate screen time with your mood")
                featureRow(icon: "apps.iphone", text: "See which apps you use most")
                featureRow(icon: "hand.raised.fill", text: "Your data never leaves your device")
            }
            .padding(.horizontal, 8)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentAmber)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
