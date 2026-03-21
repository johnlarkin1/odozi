import MapKit
import SwiftUI

struct JourneyGlobeView: View {
    let entries: [DailyEntry]
    @Binding var cameraPosition: MapCameraPosition
    var onEntryTapped: ((DailyEntry) -> Void)?

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(locatedEntries, id: \.date) { entry in
                if let lat = entry.latitude, let lon = entry.longitude {
                    Annotation(entry.date.shortFormatted, coordinate: CLLocationCoordinate2D(
                        latitude: lat,
                        longitude: lon
                    )) {
                        Button {
                            onEntryTapped?(entry)
                        } label: {
                            Circle()
                                .fill(entry.moodGradientColor)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                                )
                                .shadow(color: entry.moodGradientColor.opacity(0.5), radius: 4)
                        }
                    }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
    }

    private var locatedEntries: [DailyEntry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }
}
