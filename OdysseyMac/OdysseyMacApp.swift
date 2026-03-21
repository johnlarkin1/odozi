import ClerkKit
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "MacApp")

@main
struct OdysseyMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var authManager = AuthManager()
    @State private var syncService = SyncService()
    @State private var selectedSection: SidebarSection = .today
    @State private var showGuidedPrompt = false

    let container: ModelContainer?
    let containerError: Error?

    init() {
        if let key = ClerkConfiguration.publishableKey,
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        {
            Clerk.configure(publishableKey: key)
            AuthManager.clerkConfigured = true
        }

        do {
            let c = try DataContainer.create()
            container = c
            containerError = nil

            let seedContext = ModelContext(c)
            let achievementService = AchievementService(modelContext: seedContext)
            achievementService.seedIfNeeded()
        } catch {
            container = nil
            containerError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    MacMainView(selectedSection: $selectedSection, showGuidedPrompt: $showGuidedPrompt)
                        .frame(minWidth: 800, minHeight: 600)
                        .environment(\.colorScheme, .dark)
                        .environment(authManager)
                        .environment(syncService)
                        .modelContainer(container)
                        .task {
                            await authManager.initialize()
                        }
                } else {
                    MacDataStoreErrorView(error: containerError)
                        .environment(\.colorScheme, .dark)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, container != nil {
                    Task {
                        await foregroundSync()
                    }
                }
            }
        }
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    selectedSection = .today
                    showGuidedPrompt = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Navigate") {
                Button("Today") {
                    selectedSection = .today
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Journal") {
                    selectedSection = .journal
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Insights") {
                    selectedSection = .insights
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Link("Odyssey Help", destination: URL(string: "https://odozi.app")!)
            }
        }

        Settings {
            if let container {
                MacSettingsView()
                    .environment(\.colorScheme, .dark)
                    .environment(authManager)
                    .environment(syncService)
                    .modelContainer(container)
            }
        }
    }

    @MainActor
    private func foregroundSync() async {
        guard let container else { return }
        let context = container.mainContext

        // Sync pending entries if signed in
        if authManager.hasAccount {
            await syncService.syncPendingEntries(modelContext: context, authManager: authManager)
        }
    }
}

private struct MacDataStoreErrorView: View {
    let error: Error?
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.coralRed)
            Text("Unable to Load Data")
                .font(.title2.bold())
            Text("There was a problem loading your journal data. Please restart the app. If the problem persists, reinstall Odyssey.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            if let error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
