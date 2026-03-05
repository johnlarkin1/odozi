import SwiftUI

struct NotificationPermissionCard: View {
    @AppStorage("reminderTimeOfDay") private var reminderTimeOfDayRaw = ReminderTimeOfDay.evening.rawValue
    @AppStorage("reminderCustomHour") private var reminderCustomHour = 20
    @AppStorage("reminderCustomMinute") private var reminderCustomMinute = 0

    private var selectedTimeOfDay: ReminderTimeOfDay {
        ReminderTimeOfDay(rawValue: reminderTimeOfDayRaw) ?? .evening
    }

    private var customTimeDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderCustomHour, minute: reminderCustomMinute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderCustomHour = comps.hour ?? 20
                reminderCustomMinute = comps.minute ?? 0
            }
        )
    }

    var body: some View {
        PromptCardContainer(
            iconName: OnboardingStep.notifications.iconName,
            iconColor: OnboardingStep.notifications.iconColor,
            title: OnboardingStep.notifications.title,
            subtitle: OnboardingStep.notifications.subtitle
        ) {
            VStack(spacing: 16) {
                featureRow(icon: "bell.badge.fill", text: "Daily reminders to reflect on your day")
                featureRow(icon: "clock.fill", text: "Choose morning, afternoon, evening, or custom")
                featureRow(icon: "xmark.circle", text: "Cancel anytime in Settings")

                Divider()
                    .background(.white.opacity(0.2))

                VStack(spacing: 12) {
                    Text("When should we remind you?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    ForEach(ReminderTimeOfDay.allCases) { time in
                        Button {
                            reminderTimeOfDayRaw = time.rawValue
                        } label: {
                            HStack {
                                Image(systemName: selectedTimeOfDay == time ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTimeOfDay == time ? Color.cosmicPurple : .white.opacity(0.4))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(time.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Text(time.notificationBody)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    if selectedTimeOfDay == .custom {
                        DatePicker("Time", selection: customTimeDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .tint(Color.cosmicPurple)
                    }
                }
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
