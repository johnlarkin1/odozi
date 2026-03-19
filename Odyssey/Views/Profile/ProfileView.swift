import SwiftUI
import SwiftData
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

                        SyncStatusBanner()

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

                #if os(iOS)
                Section("Screen Time") {
                    DeviceActivityReport(context, filter: filter)
                        .frame(height: 60)
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

        var csv = "Date,Feeling,Sleep Quality,Single Word Feeling,Journal Entry,Drinks,Win,Tension,Gratitude,Steps,Screen Time,City\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        for entry in entries {
            let escapedJournal = entry.journalEntry.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedGratitude = entry.gratitude.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedWin = entry.win.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedTension = entry.tension.replacingOccurrences(of: "\"", with: "\"\"")

            let line = "\(dateFormatter.string(from: entry.date)),\(entry.feeling),\(entry.sleepQuality),\(entry.singleWordFeeling),\"\(escapedJournal)\",\(entry.drinks),\"\(escapedWin)\",\"\(escapedTension)\",\"\(escapedGratitude)\",\(entry.stepCount ?? 0),\(entry.screenTimeFormatted),\(entry.city ?? "")"
            csv.append(line + "\n")
        }

        let path = FileManager.default.temporaryDirectory.appendingPathComponent("odyssey_export.csv")
        try? csv.write(to: path, atomically: true, encoding: .utf8)
        return path
    }
}
