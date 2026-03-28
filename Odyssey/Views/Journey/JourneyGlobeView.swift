import MapKit
import os
import SwiftUI

private let globeLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "JourneyGlobe")

struct JourneyGlobeView: View {
    let entries: [DailyEntry]
    @Binding var cameraPosition: MapCameraPosition
    var onEntryTapped: ((DailyEntry) -> Void)?

    @State private var thumbnailCache: [Date: UIImage] = [:]

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
                            if entry.hasMapPhoto, let uiImage = thumbnailCache[entry.date] {
                                PhotoMapPin(image: uiImage, moodColor: entry.moodGradientColor)
                            } else {
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
        }
        .mapStyle(.imagery(elevation: .realistic))
        .onAppear { buildThumbnailCache() }
        .onChange(of: entries.count) { buildThumbnailCache() }
    }

    private var locatedEntries: [DailyEntry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private func buildThumbnailCache() {
        var cache: [Date: UIImage] = [:]
        for entry in locatedEntries where entry.hasMapPhoto {
            if let data = entry.mapThumbnailData {
                if let image = UIImage(data: data) {
                    cache[entry.date] = image
                } else {
                    globeLogger.warning("Failed to decode map thumbnail for entry on \(entry.date.shortFormatted)")
                }
            }
        }
        thumbnailCache = cache
    }
}
