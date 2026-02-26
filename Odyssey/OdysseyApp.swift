import SwiftUI
import SwiftData
import CoreLocation
import FamilyControls
import DeviceActivity

@main
struct OdysseyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let locationManager = CLLocationManager()
    let container: ModelContainer

    init() {
        do {
            container = try DataContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.colorScheme, .dark)
                .onAppear {
                    requestPermissions()
                }
                .overlay {
                    // Hidden Screen Time data extractor
                    ScreenTimeDataExtractor()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Foreground catch-up: capture snapshot if today's doesn't exist
                Task {
                    await foregroundCatchUp()
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
        locationManager.requestAlwaysAuthorization()
    }

    func requestScreenTimeAccess() {
        let authorizationCenter = AuthorizationCenter.shared

        Task {
            do {
                try await authorizationCenter.requestAuthorization(for: .individual)
                print("Screen Time API access granted.")
                setupDeviceActivityMonitoring()
            } catch {
                print("Error requesting Screen Time API access: \(error)")
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
            print("Error setting up device activity monitoring: \(error)")
        }
    }

    @MainActor
    private func foregroundCatchUp() async {
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
