import DeviceActivity
import SwiftUI

struct ScreenTimeDataExtractor: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )
    @State private var refreshID = UUID()

    var body: some View {
        DeviceActivityReport(.init(rawValue: "Total Activity"), filter: filter)
            .id(refreshID)
            .frame(width: 1, height: 1)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    filter = DeviceActivityFilter(
                        segment: .daily(
                            during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
                        ),
                        users: .all,
                        devices: .init([.iPhone, .iPad])
                    )
                    refreshID = UUID()
                }
            }
    }
}
