import SwiftUI

struct HealthPermissionCard: View {
    var body: some View {
        PromptCardContainer(
            iconName: OnboardingStep.health.iconName,
            iconColor: OnboardingStep.health.iconColor,
            title: OnboardingStep.health.title,
            subtitle: OnboardingStep.health.subtitle
        ) {
            VStack(spacing: 16) {
                featureRow(icon: "figure.walk", text: "Daily steps and walking distance")
                featureRow(icon: "bed.double.fill", text: "Sleep duration tracking")
                featureRow(icon: "figure.run", text: "Workout sessions and exercise data")
                featureRow(icon: "heart.fill", text: "Heart rate and resting heart rate")
                featureRow(icon: "eye.slash.fill", text: "Read-only access — Odozi never writes health data")
            }
            .padding(.horizontal, 8)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.coralRed)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
