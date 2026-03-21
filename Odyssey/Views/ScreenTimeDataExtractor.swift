import DeviceActivity
import SwiftUI

struct ScreenTimeDataExtractor: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")
    @State private var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )

    var body: some View {
        // Hidden zero-size view that triggers data extraction
        DeviceActivityReport(context, filter: filter)
            .frame(width: 0, height: 0)
            .opacity(0)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Refresh filter with today's date interval to avoid stale data after midnight
                    filter = DeviceActivityFilter(
                        segment: .daily(
                            during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
                        ),
                        users: .all,
                        devices: .init([.iPhone, .iPad])
                    )
                }
            }
    }
}
