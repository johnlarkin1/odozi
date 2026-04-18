import SwiftData
import SwiftUI
#if os(iOS)
    import DeviceActivity
#endif

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @State private var selectAppsModel = ScreenTimeSelectAppsModel()
    #endif
    @Query private var allEntries: [DailyEntry]

    private var localEntryCount: Int { allEntries.count }

    #if os(iOS)
        @State private var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")
        @State private var filter = DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
            ),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    #endif

    @AppStorage(DataContainer.iCloudSyncEnabledKey) private var iCloudSyncEnabled = false
    @State private var syncToggleChanged = false

    @AppStorage("reminderEnabled") private var reminderEnabled = true
    @AppStorage("reminderTimeOfDay") private var reminderTimeOfDayRaw = ReminderTimeOfDay.evening.rawValue
    @AppStorage("reminderCustomHour") private var reminderCustomHour = 20
    @AppStorage("reminderCustomMinute") private var reminderCustomMinute = 0
    @AppStorage("weeklyDigestEnabled") private var weeklyDigestEnabled = false
    @AppStorage("weeklyDigestWeekday") private var weeklyDigestWeekday = 1
    @AppStorage("locationCaptureMode") private var locationCaptureModeRaw = LocationCaptureMode.evening.rawValue
    @AppStorage("locationCaptureHour") private var locationCaptureHour = 20
    @AppStorage("locationCaptureMinute") private var locationCaptureMinute = 0

    @State private var csvExportURL: URL?

    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if authManager.hasAccount {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentTeal)
                            VStack(alignment: .leading) {
                                Text(authManager.user?.displayName ?? "Account")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let email = authManager.user?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        NavigationLink("Manage Account") {
                            AccountView()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.icloud")
                                    .foregroundStyle(Color.accentAmber)
                                Text("No backup")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            if localEntryCount > 0 {
                                Text("\(localEntryCount) \(localEntryCount == 1 ? "entry" : "entries") on this device only — not backed up")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Your journal entries aren't backed up yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        NavigationLink {
                            SignInView()
                        } label: {
                            HStack {
                                Text("Back Up Your Journal")
                                Text("Free")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.accentAmber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentAmber.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }

                Section("Sync") {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        Label("iCloud Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                    }
                    .onChange(of: iCloudSyncEnabled) { _, _ in
                        syncToggleChanged = true
                    }

                    Text("Sync your journal across iPhone, Apple Watch, and Mac via iCloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if syncToggleChanged {
                        Label("Restart Odozi to apply", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(Color.accentAmber)
                    }

                    if DataContainer.isQuotaDisabled {
                        Label("Sync paused — iCloud storage full", systemImage: "exclamationmark.icloud")
                            .font(.caption)
                            .foregroundStyle(Color.coralRed)
                    }
                }
                .listRowBackground(Color.cardSurface)

                #if os(iOS)
                    Section("Screen Time") {
                        DeviceActivityReport(context, filter: filter)
                        #if DEBUG
                            .frame(height: 120)
                        #else
                            .frame(height: 60)
                        #endif
                            .onChange(of: scenePhase) { _, newPhase in
                                if newPhase == .active {
                                    filter = DeviceActivityFilter(
                                        segment: .daily(
                                            during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
                                        ),
                                        users: .all,
                                        devices: .init([.iPhone, .iPad])
                                    )
                                }
                            }

                        NavigationLink("Select Apps to Monitor") {
                            ScreenTimeSelectAppsContentView(model: selectAppsModel)
                        }
                    }
                    .listRowBackground(Color.cardSurface)
                #endif

                Section("Reminders") {
                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        HStack {
                            Label("Daily Reminder", systemImage: "bell.fill")
                            Spacer()
                            Text(reminderStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        WeeklyDigestSettingsView()
                    } label: {
                        HStack {
                            Label("Weekly Digest", systemImage: "calendar.badge.clock")
                            Spacer()
                            Text(weeklyDigestStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)

                Section("Location") {
                    NavigationLink {
                        LocationTimingSettingsView()
                    } label: {
                        HStack {
                            Label("Capture Timing", systemImage: "location.fill")
                            Spacer()
                            Text(locationTimingStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)

                Section("Data") {
                    if let url = csvExportURL {
                        ShareLink(item: url) {
                            Label("Export to CSV", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Export to CSV") {
                            csvExportURL = generateCSV()
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)

                #if DEBUG
                    Section("Developer") {
                        NavigationLink {
                            DevToolsView()
                        } label: {
                            Label("Developer Tools", systemImage: "hammer.fill")
                        }
                    }
                    .listRowBackground(Color.cardSurface)
                #endif

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    if let privacyURL = URL(string: "https://odozi.app/privacy") {
                        Link(destination: privacyURL) {
                            Label("Privacy Policy", systemImage: "hand.raised")
                        }
                    }

                    if let termsURL = URL(string: "https://odozi.app/terms") {
                        Link(destination: termsURL) {
                            Label("Terms of Service", systemImage: "doc.text")
                        }
                    }
                }
                .listRowBackground(Color.cardSurface)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Profile")
            .cosmicBackground()
        }
    }

    private var locationTimingStatusText: String {
        let mode = LocationCaptureMode(rawValue: locationCaptureModeRaw) ?? .evening
        if mode == .custom {
            return formatTime(hour: locationCaptureHour, minute: locationCaptureMinute)
        }
        return mode.label
    }

    private static let weekdayShortNames = [
        1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed",
        5: "Thu", 6: "Fri", 7: "Sat"
    ]

    private var weeklyDigestStatusText: String {
        if weeklyDigestEnabled {
            return Self.weekdayShortNames[weeklyDigestWeekday] ?? "Sun"
        }
        return "Off"
    }

    private var reminderStatusText: String {
        if reminderEnabled {
            let timeOfDay = ReminderTimeOfDay(rawValue: reminderTimeOfDayRaw) ?? .evening
            if timeOfDay == .custom {
                return formatTime(hour: reminderCustomHour, minute: reminderCustomMinute)
            }
            return timeOfDay.label
        }
        return "Off"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let comps = DateComponents(hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: comps) else { return "Custom" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func generateCSV() -> URL? {
        let descriptor = FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)])
        guard let entries = try? modelContext.fetch(descriptor) else { return nil }

        let headers = [
            "Date", "Feeling", "Sleep Quality", "Single Word Feeling",
            "Journal Entry", "Drinks", "Win", "Tension", "Gratitude",
            "Steps", "Screen Time", "City", "Sleep Hours",
            "Sleep REM Hours", "Sleep Deep Hours", "Sleep Core Hours",
            "Sleep Awake Minutes", "Sleep Score"
        ]
        var csv = headers.joined(separator: ",") + "\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        for entry in entries {
            let escapedJournal = entry.journalEntry.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedGratitude = entry.gratitude.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedWin = entry.win.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedTension = entry.tension.replacingOccurrences(of: "\"", with: "\"\"")

            let sleepHoursStr = entry.sleepHours.map { String(format: "%.2f", $0) } ?? ""
            let remStr = entry.sleepREMHours.map { String(format: "%.2f", $0) } ?? ""
            let deepStr = entry.sleepDeepHours.map { String(format: "%.2f", $0) } ?? ""
            let coreStr = entry.sleepCoreHours.map { String(format: "%.2f", $0) } ?? ""
            let awakeStr = entry.sleepAwakeMinutes.map { String(format: "%.1f", $0) } ?? ""
            let scoreStr = entry.sleepScore.map { "\($0)" } ?? ""

            let line =
                "\(dateFormatter.string(from: entry.date)),\(entry.feeling),\(entry.sleepQuality),\(entry.singleWordFeeling),\"\(escapedJournal)\",\(entry.drinks),\"\(escapedWin)\",\"\(escapedTension)\",\"\(escapedGratitude)\",\(entry.stepCount ?? 0),\(entry.screenTimeFormatted),\(entry.city ?? ""),\(sleepHoursStr),\(remStr),\(deepStr),\(coreStr),\(awakeStr),\(scoreStr)"
            csv.append(line + "\n")
        }

        let path = FileManager.default.temporaryDirectory.appendingPathComponent("odyssey_export.csv")
        try? csv.write(to: path, atomically: true, encoding: .utf8)
        return path
    }
}
