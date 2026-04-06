import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "WatchApp")

@main
struct OdysseyWatchApp: App {
    @State private var watchAuth = WatchAuthManager()
    @State private var sessionReceiver = WatchSessionReceiver()

    static let isScreenshotMode = ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "1"

    let container: ModelContainer?

    init() {
        do {
            #if DEBUG
                if Self.isScreenshotMode {
                    container = try createWatchSeededContainer()
                } else {
                    container = try DataContainer.create()
                }
            #else
                container = try DataContainer.create()
            #endif
        } catch {
            logger.error("Failed to create ModelContainer: \(error)")
            container = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                #if DEBUG
                    if Self.isScreenshotMode {
                        WatchScreenshotView()
                            .modelContainer(container)
                    } else {
                        normalWatchView(container: container)
                    }
                #else
                    normalWatchView(container: container)
                #endif
            } else {
                Text("Unable to load data")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func normalWatchView(container: ModelContainer) -> some View {
        WatchTabView()
            .environment(watchAuth)
            .modelContainer(container)
            .task {
                sessionReceiver.activate(authManager: watchAuth)
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
