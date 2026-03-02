import SwiftUI
import DeviceActivity

struct ScreenTimeDataExtractor: View {
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
    }
}
