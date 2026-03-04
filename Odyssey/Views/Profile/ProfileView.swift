import SwiftUI
import SwiftData
import DeviceActivity

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectAppsModel = ScreenTimeSelectAppsModel()
    @Query private var allEntries: [DailyEntry]

    private var localEntryCount: Int { allEntries.count }

    @State private var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")
    @State private var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )

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

                Section("Screen Time") {
                    DeviceActivityReport(context, filter: filter)
                        .frame(height: 60)

                    NavigationLink("Select Apps to Monitor") {
                        ScreenTimeSelectAppsContentView(model: selectAppsModel)
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
