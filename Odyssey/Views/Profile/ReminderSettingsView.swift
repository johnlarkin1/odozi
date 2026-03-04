import SwiftUI
import SwiftData

struct ReminderSettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = true
    @AppStorage("reminderTimeOfDay") private var reminderTimeOfDayRaw = ReminderTimeOfDay.evening.rawValue

    @Environment(\.modelContext) private var modelContext

    private var selectedTimeOfDay: ReminderTimeOfDay {
        ReminderTimeOfDay(rawValue: reminderTimeOfDayRaw) ?? .evening
    }

    var body: some View {
        List {
            Section {
                Toggle("Daily Reminder", isOn: $reminderEnabled)
                    .onChange(of: reminderEnabled) { _, enabled in
                        if enabled {
                            NotificationService.scheduleReminder(timeOfDay: selectedTimeOfDay)
                        } else {
                            NotificationService.cancelReminder()
                        }
                        updateSwiftData()
                    }
            }
            .listRowBackground(Color.cardSurface)

            if reminderEnabled {
                Section("Reminder Time") {
                    ForEach(ReminderTimeOfDay.allCases) { time in
                        Button {
                            reminderTimeOfDayRaw = time.rawValue
                            NotificationService.scheduleReminder(timeOfDay: time)
                            updateSwiftData()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(time.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Text(time.notificationBody)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if time == selectedTimeOfDay {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.cosmicPurple)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Reminders")
        .cosmicBackground()
    }

    private func updateSwiftData() {
        let descriptor = FetchDescriptor<UserPreferences>()
        let existing = try? modelContext.fetch(descriptor).first
        let prefs = existing ?? UserPreferences()
        if existing == nil {
            modelContext.insert(prefs)
        }
        prefs.reminderEnabled = reminderEnabled
        prefs.reminderTimeOfDay = reminderTimeOfDayRaw
        prefs.updatedAt = Date()
        try? modelContext.save()
    }
}
