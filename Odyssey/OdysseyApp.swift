import SwiftUI
import SwiftData
import ClerkKit
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "App")

@main
struct OdysseyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var onboardingViewModel = OnboardingViewModel()
    @State private var authManager = AuthManager()
    @State private var syncService = SyncService()
    @State private var showBackupPrompt = false
    @State private var showRetentionAlert = false
    @State private var oldEntryCount = 0

    let container: ModelContainer?
    let containerError: Error?

    init() {
        if let key = ClerkConfiguration.publishableKey,
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Clerk.configure(publishableKey: key)
            AuthManager.clerkConfigured = true
        }

        do {
            let c = try DataContainer.create()
            container = c
            containerError = nil

            // Skip onboarding for returning users (existing entries = already using the app)
            if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                let context = ModelContext(c)
                var descriptor = FetchDescriptor<DailyEntry>()
                descriptor.fetchLimit = 1
                if let count = try? context.fetchCount(descriptor), count > 0 {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            }
        } catch {
            container = nil
            containerError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    if hasCompletedOnboarding {
                        ContentView()
                            .environment(\.colorScheme, .dark)
                            .environment(authManager)
                            .environment(syncService)
                            .overlay {
                                ScreenTimeDataExtractor()
                            }
                            .modelContainer(container)
                            .task {
                                await authManager.initialize()
                            }
                            .fullScreenCover(isPresented: $showBackupPrompt) {
                                BackupPromptModal()
                                    .environment(authManager)
                                    .environment(\.colorScheme, .dark)
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .didSaveFirstEntry)) { _ in
                                let hasSeenPrompt = UserDefaults.standard.bool(forKey: "hasSeenBackupPrompt")
                                if !hasSeenPrompt && !authManager.hasAccount {
                                    showBackupPrompt = true
                                    UserDefaults.standard.set(true, forKey: "hasSeenBackupPrompt")
                                }
                            }
                            .alert("Clean Up Old Entries", isPresented: $showRetentionAlert) {
                                Button("Delete \(oldEntryCount) Entries", role: .destructive) {
                                    DataRetentionService.performCleanup(context: container.mainContext)
                                }
                                Button("Remind Me Later", role: .cancel) {
                                    DataRetentionService.recordDismissal()
                                }
                                Button("Create Account") {
                                    showBackupPrompt = true
                                }
                            } message: {
                                Text("You have \(oldEntryCount) entries older than 1 year. Would you like to delete them?")
                            }
                    } else {
                        OnboardingFlowView(
                            viewModel: onboardingViewModel,
                            onComplete: {
                                hasCompletedOnboarding = true
                            }
                        )
                        .environment(\.colorScheme, .dark)
                        .environment(authManager)
                    }
                } else {
                    DataStoreErrorView(error: containerError)
                        .environment(\.colorScheme, .dark)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, container != nil, hasCompletedOnboarding {
                    Task {
                        await foregroundCatchUp()
                    }
                }
            }
        }
    }

    @MainActor
    private func foregroundCatchUp() async {
        guard let container else { return }
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<DailyEntry> { $0.date == today }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        // Check if any background data exists — not just latitude (which stays nil if location denied)
        let entry = try? context.fetch(descriptor).first
        let hasSnapshot = entry != nil && (
            entry?.latitude != nil ||
            entry?.stepCount != nil ||
            entry?.screenTimeSeconds != nil ||
            entry?.sleepHours != nil
        )

        if !hasSnapshot {
            let service = BackgroundSnapshotService()
            let data = await service.captureSnapshot()
            applySnapshotData(data, to: context)
        }

        // Sync pending entries if signed in
        if authManager.hasAccount {
            await syncService.syncPendingEntries(modelContext: context, authManager: authManager)
        }

        // Data retention: count old entries and prompt user for confirmation
        let count = DataRetentionService.countOldEntries(
            context: context,
            hasAccount: authManager.hasAccount
        )
        if count > 0 {
            oldEntryCount = count
            showRetentionAlert = true
        }
    }
}

private struct DataStoreErrorView: View {
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
    }
}
