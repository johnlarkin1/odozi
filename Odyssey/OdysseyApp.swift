import CoreLocation
import os
import SwiftData
import SwiftUI
import WidgetKit

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "App")

@main
struct OdysseyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var onboardingViewModel = OnboardingViewModel()
    @State private var authManager = AuthManager()
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

            // Merge any cross-timezone duplicate entries (e.g. from a user
            // journaling across a zone change). Idempotent — no-op if clean.
            MainActor.assumeIsolated {
                let repo = DailyEntryRepository(context: seedContext)
                _ = try? repo.dedupeByCalendarDay()
            }

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
            logger.error("Failed to create ModelContainer: \(error)")
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
                                _ = DeepLinkRouter.handle(url)
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

        // Re-register screen time monitoring on every foreground (defensive best practice —
        // callbacks can silently break after app/OS updates or reboots)
        #if os(iOS) && !targetEnvironment(simulator)
            ScreenTimeMonitoringManager.register()
        #endif

        // Re-request HealthKit auth (idempotent) — covers users who denied then re-enabled in Settings
        if HealthKitService.isAvailable {
            let hk = HealthKitService()
            try? await hk.requestAuthorization()
        }

        // Request location auth if still undetermined. The automated snapshot path
        // never prompts on its own, so returning users who skipped onboarding (existing
        // entries → onboarding bypassed) would otherwise never be asked, and the daily
        // location grab would silently capture nothing.
        let locationManager = CLLocationManager()
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        // Always capture and apply snapshot — applySnapshotData only writes non-nil values
        // and uses fetchOrCreateToday(), so repeated calls are safe
        let service = BackgroundSnapshotService()
        let data = await service.captureSnapshot()
        applySnapshotData(data, to: context)
        NotificationCenter.default.post(name: .snapshotDidUpdate, object: nil)

        // Screen Time extension writes async to SharedDefaults — poll until available.
        // The DeviceActivity extension needs time to compute and write data,
        // so we use a longer window with increasing delays.
        Task {
            do {
                logger.info("Screen time polling started: \(SharedDefaults.getScreenTimeDebugInfo())")
                let delays: [Int] = [500, 500, 750, 750, 1000, 1000, 1000, 1500, 1500, 2000,
                                     2000, 2000, 2500, 2500, 3000]
                for (index, delay) in delays.enumerated() {
                    try await Task.sleep(for: .milliseconds(delay))
                    if let screenTime = SharedDefaults.getScreenTime() {
                        logger.info("Screen time found on poll \(index + 1): \(screenTime.seconds)s")
                        let repository = DailyEntryRepository(context: context)
                        let entry = try repository.fetchOrCreateToday()
                        entry.screenTimeSeconds = screenTime.seconds
                        entry.pickups = screenTime.pickups
                        try context.save()
                        NotificationCenter.default.post(name: .screenTimeDidUpdate, object: nil)
                        return
                    }
                }
                logger.warning("Screen time data not available after polling: \(SharedDefaults.getScreenTimeDebugInfo())")
            } catch is CancellationError {
                // Task cancelled (e.g. app backgrounded) — expected, no action needed
            } catch {
                logger.error("Failed to save screen time: \(error)")
            }
        }

        NotificationService.rescheduleIfNeeded()

        // Refresh weekly digest notification with latest stats
        await WeeklyDigestNotificationManager.refreshContent(context: context)

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
            Text("There was a problem loading your journal data. Please restart the app. If the problem persists, reinstall Odozi.")
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
