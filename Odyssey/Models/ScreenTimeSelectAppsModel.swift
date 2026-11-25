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

    init() {
        loadSelection()
    }

    func saveSelection() {
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        if let encoded = try? JSONEncoder().encode(activitySelection) {
            defaults?.set(encoded, forKey: ScreenTimeMonitoringManager.selectionKey)
        }
        #if os(iOS) && !targetEnvironment(simulator)
            ScreenTimeMonitoringManager.register(force: true)
        #endif
    }

    private func loadSelection() {
        let defaults = UserDefaults(suiteName: "group.com.johnlarkin.Odyssey")
        if let data = defaults?.data(forKey: ScreenTimeMonitoringManager.selectionKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            activitySelection = decoded
        }
    }
}
