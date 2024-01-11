//
//  OdysseyApp.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI
import CoreLocation
import FamilyControls
import DeviceActivity

@main
struct OdysseyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    private let locationManager = CLLocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.colorScheme, .dark)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    requestPermissions()
                }
        }
    }
    
    func requestPermissions() {
        requestLocationAccess()
        requestScreenTimeAccess()
    }
    
    func requestLocationAccess() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func requestScreenTimeAccess() {
        // Initialize the AuthorizationCenter
        let authorizationCenter = AuthorizationCenter.shared

        // Perform the authorization request
        Task {
            do {
                // Request authorization for individual (current device) management
                try await authorizationCenter.requestAuthorization(for: .individual)
                print("Screen Time API access granted.")
                
                setupDeviceActivityMonitoring();
            } catch {
                // Handle any errors
                print("Error requesting Screen Time API access: \(error)")
            }
        }
    }
    
    private func setupDeviceActivityMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        let eventName = DeviceActivityEvent.Name("DailyActivityMonitor")
        let event = DeviceActivityEvent(
            threshold: DateComponents(hour: 24)
        )

        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(
                DeviceActivityName("Odyssey"),
                during: schedule,
                events: [eventName: event]
            )
        } catch {
            print("Error setting up device activity monitoring: \(error)")
        }
    }
}
