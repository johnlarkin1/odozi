import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "App")

@main
struct OdysseyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var onboardingViewModel = OnboardingViewModel()

    let container: ModelContainer?
    let containerError: Error?

    init() {
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
                            .overlay {
                                ScreenTimeDataExtractor()
                            }
                            .modelContainer(container)
                    } else {
                        OnboardingFlowView(
                            viewModel: onboardingViewModel,
                            onComplete: {
                                hasCompletedOnboarding = true
                            }
                        )
                        .environment(\.colorScheme, .dark)
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

        let hasSnapshot = (try? context.fetch(descriptor).first?.latitude) != nil

        if !hasSnapshot {
            let service = BackgroundSnapshotService()
            await service.captureSnapshot(modelContext: context)
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
