import SwiftUI
import SwiftData

struct MacSettingsView: View {
    var body: some View {
        TabView {
            AccountSettingsTab()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }

            NotificationsSettingsTab()
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }

            LocationSettingsTab()
                .tabItem {
                    Label("Location", systemImage: "location.fill")
                }

            DataSettingsTab()
                .tabItem {
                    Label("Data", systemImage: "square.and.arrow.up")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - Account Tab

private struct AccountSettingsTab: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Form {
            if authManager.hasAccount {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentTeal)
                    VStack(alignment: .leading) {
                        Text(authManager.user?.displayName ?? "Account")
                            .font(.headline)
                        if let email = authManager.user?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                SyncStatusBanner()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundStyle(Color.accentAmber)
                        Text("No backup")
                            .font(.headline)
                    }
                    Text("Your journal entries aren't backed up yet. Sign in to enable cloud sync.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications Tab

private struct NotificationsSettingsTab: View {
    var body: some View {
        Form {
            Section("Daily Reminder") {
                ReminderSettingsView()
            }

            Section("Weekly Digest") {
                WeeklyDigestSettingsView()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Location Tab

private struct LocationSettingsTab: View {
    var body: some View {
        Form {
            Section("Capture Timing") {
                LocationTimingSettingsView()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data Tab

private struct DataSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var csvExportURL: URL?

    var body: some View {
        Form {
            Section("Export") {
                if let url = csvExportURL {
                    HStack {
                        Text("Export ready")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                } else {
                    Button("Export Journal to CSV") {
                        csvExportURL = generateCSV()
                    }
                }
            }
        }
        .formStyle(.grouped)
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

// MARK: - About Tab

private struct AboutSettingsTab: View {
    var body: some View {
        Form {
            Section {
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

                if let siteURL = URL(string: "https://odozi.app") {
                    Link(destination: siteURL) {
                        Label("Website", systemImage: "globe")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
