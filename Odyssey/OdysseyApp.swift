import SwiftUI
import SwiftData
import CoreLocation
import FamilyControls
import DeviceActivity
import os

private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Permissions")

@main
struct OdysseyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let locationManager = CLLocationManager()
    let container: ModelContainer?
    let containerError: Error?

    init() {
        do {
            container = try DataContainer.create()
            containerError = nil
        } catch {
            container = nil
            containerError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .environment(\.colorScheme, .dark)
                        .onAppear {
                            requestPermissions()
                        }
                        .overlay {
                            // Hidden Screen Time data extractor
                            ScreenTimeDataExtractor()
                        }
                        .modelContainer(container)
                } else {
                    DataStoreErrorView(error: containerError)
                        .environment(\.colorScheme, .dark)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, container != nil {
                    // Foreground catch-up: capture snapshot if today's doesn't exist
                    Task {
                        await foregroundCatchUp()
                    }
                }
            }
        }
    }

    func requestPermissions() {
        requestLocationAccess()
        requestScreenTimeAccess()
        requestHealthKitAccess()
    }

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestScreenTimeAccess() {
        let authorizationCenter = AuthorizationCenter.shared

        Task {
            do {
                try await authorizationCenter.requestAuthorization(for: .individual)
                logger.info("Screen Time API access granted.")
                setupDeviceActivityMonitoring()
            } catch {
                logger.error("Screen Time API access error: \(error)")
            }
        }
    }

    func requestHealthKitAccess() {
        guard HealthKitService.isAvailable else { return }
        Task {
            let service = HealthKitService()
            try? await service.requestAuthorization()
        }
    }

    private func setupDeviceActivityMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(
                DeviceActivityName("Odyssey"),
                during: schedule
            )
        } catch {
            logger.error("Device activity monitoring setup failed: \(error)")
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
