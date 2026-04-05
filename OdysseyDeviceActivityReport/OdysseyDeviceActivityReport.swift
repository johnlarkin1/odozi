//
//  OdysseyDeviceActivityReport.swift
//  OdysseyDeviceActivityReport
//
//  Created by John Larkin on 1/8/24.
//

import DeviceActivity
import SwiftUI

#if DEBUG
    import Foundation
    import os

    private let initLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DARExtensionInit")

    // Drops a breadcrumb file in the App Group container the instant this extension's
    // bundle is loaded. Runs exactly once per process because it's a top-level let.
    private let _extensionDidLoad: Bool = {
        NSLog("[Odyssey DAR] extension bundle loaded pid=%d", getpid())
        initLogger.info("DAR extension bundle loaded pid=\(getpid())")
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.johnlarkin.Odyssey"
        ) {
            let url = container.appendingPathComponent("dar_loaded.json")
            let payload: [String: Any] = [
                "ts": Date().timeIntervalSince1970,
                "pid": getpid(),
                "bundle": Bundle.main.bundleIdentifier ?? "unknown"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload) {
                try? data.write(to: url, options: .atomic)
                NSLog("[Odyssey DAR] wrote dar_loaded.json path=%@", url.path)
                initLogger.info("Wrote dar_loaded.json at \(url.path, privacy: .public)")
            }
        } else {
            NSLog("[Odyssey DAR] containerURL is NIL at init")
            initLogger.error("containerURL nil at extension init")
        }
        return true
    }()
#endif

@main
struct OdysseyDeviceActivityReport: DeviceActivityReportExtension {
    #if DEBUG
        init() {
            _ = _extensionDidLoad
            NSLog("[Odyssey DAR] DeviceActivityReportExtension.init()")
            initLogger.info("DeviceActivityReportExtension.init()")
        }
    #endif

    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        // Add more reports here...
    }
}
