import SwiftUI

struct NotificationPermissionCard: View {
    var body: some View {
        PromptCardContainer(
            iconName: OnboardingStep.notifications.iconName,
            iconColor: OnboardingStep.notifications.iconColor,
            title: OnboardingStep.notifications.title,
            subtitle: OnboardingStep.notifications.subtitle
        ) {
            VStack(spacing: 16) {
                featureRow(icon: "bell.badge.fill", text: "Daily reminders to reflect on your day")
                featureRow(icon: "clock.fill", text: "Choose morning, afternoon, or evening")
                featureRow(icon: "xmark.circle", text: "Cancel anytime in Settings")
            }
            .padding(.horizontal, 8)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.cosmicPurple)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}
