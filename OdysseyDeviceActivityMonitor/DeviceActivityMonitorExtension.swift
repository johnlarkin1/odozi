//
//  DeviceActivityMonitorExtension.swift
//  OdysseyDeviceActivityMonitor
//
//  Created by John Larkin on 1/8/24.
//

import DeviceActivity

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
//        // Fetch the day's activity data
//        fetchDataForDay()
//
//        // Save data to CoreData
//        saveDataToCoreData()
    }
    
}
