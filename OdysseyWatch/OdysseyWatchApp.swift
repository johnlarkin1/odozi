import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WatchApp")

@main
struct OdysseyWatchApp: App {
    @State private var watchAuth = WatchAuthManager()
    @State private var watchSync = WatchSyncService()
    @State private var sessionReceiver = WatchSessionReceiver()

    let container: ModelContainer?

    init() {
        do {
            container = try DataContainer.create()
        } catch {
            logger.error("Failed to create ModelContainer: \(error)")
            container = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                WatchTabView()
                    .environment(watchAuth)
                    .environment(watchSync)
                    .modelContainer(container)
                    .task {
                        sessionReceiver.activate(authManager: watchAuth)
                    }
            } else {
                Text("Unable to load data")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WatchTabView: View {
    var body: some View {
        TabView {
            TodayGlanceView()

            QuickCheckInView()

            WeekSummaryView()
        }
        .tabViewStyle(.verticalPage)
    }
}
