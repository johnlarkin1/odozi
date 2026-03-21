import SwiftData
import SwiftUI

struct ReminderSettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = true
    @AppStorage("reminderTimeOfDay") private var reminderTimeOfDayRaw = ReminderTimeOfDay.evening.rawValue
    @AppStorage("reminderCustomHour") private var reminderCustomHour = 20
    @AppStorage("reminderCustomMinute") private var reminderCustomMinute = 0

    @Environment(\.modelContext) private var modelContext

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
                NotificationService.scheduleReminder(timeOfDay: .custom, customHour: reminderCustomHour, customMinute: reminderCustomMinute)
                updateSwiftData()
            }
        )
    }

    var body: some View {
        List {
            Section {
                Toggle("Daily Reminder", isOn: $reminderEnabled)
                    .onChange(of: reminderEnabled) { _, enabled in
                        if enabled {
                            NotificationService.scheduleReminder(
                                timeOfDay: selectedTimeOfDay,
                                customHour: reminderCustomHour,
                                customMinute: reminderCustomMinute
                            )
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
                            NotificationService.scheduleReminder(
                                timeOfDay: time,
                                customHour: reminderCustomHour,
                                customMinute: reminderCustomMinute
                            )
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

                    if selectedTimeOfDay == .custom {
                        DatePicker("Time", selection: customTimeDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .tint(Color.cosmicPurple)
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
        prefs.reminderCustomHour = reminderCustomHour
        prefs.reminderCustomMinute = reminderCustomMinute
        prefs.updatedAt = Date()
        try? modelContext.save()
    }
}
