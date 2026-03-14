import SwiftUI
import SwiftData
import ClerkKit
import WidgetKit
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
    @State private var showAchievementWelcome = false
    @State private var retroactiveUnlockCount = 0
    @State private var oldEntryCount = 0

    let container: ModelContainer?
    let containerError: Error?

    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] != nil
    }

    init() {
        if let key = ClerkConfiguration.publishableKey,
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
           !Self.isScreenshotMode {
            Clerk.configure(publishableKey: key)
            AuthManager.clerkConfigured = true
        }

        do {
            #if DEBUG
            let c = if Self.isScreenshotMode {
                try DataContainer.createSeededContainer()
            } else {
                try DataContainer.create()
            }
            #else
            let c = try DataContainer.create()
            #endif
            container = c
            containerError = nil

            // Seed achievements
            let seedContext = ModelContext(c)
            let achievementService = AchievementService(modelContext: seedContext)
            achievementService.seedIfNeeded()

            if Self.isScreenshotMode {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }

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
                                performRetroactiveAchievementEvaluation()
                            }
                            .fullScreenCover(isPresented: $showBackupPrompt) {
                                BackupPromptModal()
                                    .environment(authManager)
                                    .environment(\.colorScheme, .dark)
                            }
                            .onOpenURL { url in
                                guard url.scheme == "odyssey", url.host == "guided-prompt" else { return }
                                NotificationCenter.default.post(name: .openGuidedPrompt, object: nil)
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .didSaveFirstEntry)) { _ in
                                NotificationService.cancelTodaysPendingReminder()
                                WidgetCenter.shared.reloadAllTimelines()
                                let hasSeenPrompt = UserDefaults.standard.bool(forKey: "hasSeenBackupPrompt")
                                if !hasSeenPrompt && !authManager.hasAccount {
                                    showBackupPrompt = true
                                    UserDefaults.standard.set(true, forKey: "hasSeenBackupPrompt")
                                }
                            }
                            .sheet(isPresented: $showAchievementWelcome) {
                                AchievementWelcomeSheet(unlockCount: retroactiveUnlockCount) {
                                    showAchievementWelcome = false
                                }
                                .environment(\.colorScheme, .dark)
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
    private func performRetroactiveAchievementEvaluation() {
        guard let container else { return }
        let key = "hasRunInitialAchievementEvaluation"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let context = container.mainContext
        let service = AchievementService(modelContext: context)
        let entries = (try? context.fetch(FetchDescriptor<DailyEntry>())) ?? []

        guard !entries.isEmpty else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        let unlocked = service.evaluateAll(entries: entries, latestEntry: nil)
        UserDefaults.standard.set(true, forKey: key)

        if !unlocked.isEmpty {
            // Suppress "new" indicator for retroactively earned badges
            for achievement in unlocked {
                achievement.isNew = false
            }
            try? context.save()

            retroactiveUnlockCount = unlocked.count
            showAchievementWelcome = true
        }
    }

    @MainActor
    private func foregroundCatchUp() async {
        guard let container else { return }
        let context = container.mainContext

        // Always capture and apply snapshot — applySnapshotData only writes non-nil values
        // and uses fetchOrCreateToday(), so repeated calls are safe
        let service = BackgroundSnapshotService()
        let data = await service.captureSnapshot()
        applySnapshotData(data, to: context)

        // Screen Time extension writes async to SharedDefaults — re-read after a delay
        // to catch data that wasn't available on the initial read
        Task {
            try? await Task.sleep(for: .seconds(3))
            if let screenTime = SharedDefaults.getScreenTime() {
                let repository = DailyEntryRepository(context: context)
                if let entry = try? repository.fetchOrCreateToday() {
                    entry.screenTimeSeconds = screenTime.seconds
                    entry.pickups = screenTime.pickups
                    try? context.save()
                    NotificationCenter.default.post(name: .screenTimeDidUpdate, object: nil)
                }
            }
        }

        NotificationService.rescheduleIfNeeded()

        // Refresh weekly digest notification with latest stats
        await WeeklyDigestNotificationManager.refreshContent(context: context)

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

        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct AchievementWelcomeSheet: View {
    let unlockCount: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentAmber)

            Text("Welcome to Achievements!")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Based on your journaling history, you've already unlocked **\(unlockCount)** achievements. Check them out in Insights!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onDismiss) {
                Text("View Gallery")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
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
