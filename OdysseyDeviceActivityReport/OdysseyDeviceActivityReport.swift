//
//  OdysseyDeviceActivityReport.swift
//  OdysseyDeviceActivityReport
//
//  Created by John Larkin on 1/8/24.
//

import DeviceActivity
import SwiftUI

@main
struct OdysseyDeviceActivityReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        // Add more reports here...
    }
}
