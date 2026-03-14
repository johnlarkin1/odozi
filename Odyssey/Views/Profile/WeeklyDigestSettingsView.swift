import SwiftUI
import SwiftData

struct WeeklyDigestSettingsView: View {
    @AppStorage("weeklyDigestEnabled") private var digestEnabled = false
    @AppStorage("weeklyDigestWeekday") private var digestWeekday = 1
    @AppStorage("weeklyDigestHour") private var digestHour = 18
    @AppStorage("weeklyDigestMinute") private var digestMinute = 0

    @Environment(\.modelContext) private var modelContext

    private static let weekdayNames = [
        1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday",
        5: "Thursday", 6: "Friday", 7: "Saturday"
    ]

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: digestHour, minute: digestMinute)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                digestHour = comps.hour ?? 18
                digestMinute = comps.minute ?? 0
                WeeklyDigestNotificationManager.schedule(
                    weekday: digestWeekday,
                    hour: digestHour,
                    minute: digestMinute
                )
                updateSwiftData()
            }
        )
    }

    var body: some View {
        List {
            Section {
                Toggle("Weekly Digest", isOn: $digestEnabled)
                    .onChange(of: digestEnabled) { _, enabled in
                        if enabled {
                            WeeklyDigestNotificationManager.schedule(
                                weekday: digestWeekday,
                                hour: digestHour,
                                minute: digestMinute
                            )
                        } else {
                            WeeklyDigestNotificationManager.cancel()
                        }
                        updateSwiftData()
                    }
            } footer: {
                Text("Get a summary of your week's journaling stats delivered as a notification.")
            }
            .listRowBackground(Color.cardSurface)

            if digestEnabled {
                Section("Day") {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            digestWeekday = weekday
                            WeeklyDigestNotificationManager.schedule(
                                weekday: digestWeekday,
                                hour: digestHour,
                                minute: digestMinute
                            )
                            updateSwiftData()
                        } label: {
                            HStack {
                                Text(Self.weekdayNames[weekday] ?? "")
                                    .foregroundStyle(.white)
                                Spacer()
                                if weekday == digestWeekday {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.cosmicPurple)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)

                Section("Time") {
                    DatePicker("Delivery Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .tint(Color.cosmicPurple)
                }
                .listRowBackground(Color.cardSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Weekly Digest")
        .cosmicBackground()
    }

    private func updateSwiftData() {
        let descriptor = FetchDescriptor<UserPreferences>()
        let existing = try? modelContext.fetch(descriptor).first
        let prefs = existing ?? UserPreferences()
        if existing == nil {
            modelContext.insert(prefs)
        }
        prefs.weeklyDigestEnabled = digestEnabled
        prefs.weeklyDigestWeekday = digestWeekday
        prefs.weeklyDigestHour = digestHour
        prefs.weeklyDigestMinute = digestMinute
        prefs.updatedAt = Date()
        try? modelContext.save()
    }
}
