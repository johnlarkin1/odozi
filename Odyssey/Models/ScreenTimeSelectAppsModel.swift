//
//  ScreenTimeSelectAppsModel.swift
//  Odyssey
//
//  Created by John Larkin on 1/8/24.
//

import FamilyControls
import Foundation
import Observation

@Observable
class ScreenTimeSelectAppsModel {
    var activitySelection = FamilyActivitySelection()

    private static let defaultsKey = "selectedAppsToMonitor"

    init() {
        loadSelection()
    }

    func saveSelection() {
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        if let encoded = try? JSONEncoder().encode(activitySelection) {
            defaults?.set(encoded, forKey: Self.defaultsKey)
        }
        #if os(iOS) && !targetEnvironment(simulator)
            ScreenTimeMonitoringManager.register()
        #endif
    }

    private func loadSelection() {
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        if let data = defaults?.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            activitySelection = decoded
        }
    }
}
