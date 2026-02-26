import SwiftUI
import MapKit

struct MapVisualizationView: View {
    let entries: [DailyEntry]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                ForEach(locatedEntries, id: \.date) { entry in
                    Annotation(entry.date.shortFormatted, coordinate: CLLocationCoordinate2D(
                        latitude: entry.latitude!,
                        longitude: entry.longitude!
                    )) {
                        Circle()
                            .fill(entry.moodGradientColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))

            // Summary bar
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(locatedEntries.count)")
                        .font(.title3.bold())
                    Text("Pins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(uniqueCities.count)")
                        .font(.title3.bold())
                    Text("Cities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(uniqueCountries.count)")
                        .font(.title3.bold())
                    Text("Countries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.cardSurface)
        }
        .navigationTitle("My Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var locatedEntries: [DailyEntry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var uniqueCities: Set<String> {
        Set(locatedEntries.compactMap(\.city))
    }

    private var uniqueCountries: Set<String> {
        Set(locatedEntries.compactMap(\.country))
    }
}
