import SwiftUI
import SwiftData
import DeviceActivity

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")
    @State private var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(of: .day, for: .now)!
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )

    var body: some View {
        NavigationStack {
            List {
                Section("Screen Time") {
                    DeviceActivityReport(context, filter: filter)
                        .frame(height: 60)

                    NavigationLink("Select Apps to Monitor") {
                        ScreenTimeSelectAppsContentView(model: ScreenTimeSelectAppsModel())
                    }
                }

                Section("Data") {
                    Button("Export to CSV") {
                        exportData()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func exportData() {
        let descriptor = FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)])
        guard let entries = try? modelContext.fetch(descriptor) else { return }

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

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            let ac = UIActivityViewController(activityItems: [path], applicationActivities: nil)
            rootVC.present(ac, animated: true)
        }
    }
}
