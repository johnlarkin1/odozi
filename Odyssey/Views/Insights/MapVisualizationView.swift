import MapKit
import SwiftData
import SwiftUI

struct MapVisualizationView: View {
    let entries: [DailyEntry]

    @Environment(\.modelContext) private var modelContext
    @State private var position: MapCameraPosition = .automatic
    @State private var isUpdatingLocation = false
    @State private var locationViewModel: DailyEntryViewModel?

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                ForEach(locatedEntries, id: \.date) { entry in
                    if let lat = entry.latitude, let lng = entry.longitude {
                        Annotation(entry.date.shortFormatted, coordinate: CLLocationCoordinate2D(
                            latitude: lat,
                            longitude: lng
                        )) {
                            if entry.hasMapPhoto,
                               let thumbData = entry.mapThumbnailData,
                               let uiImage = UIImage(data: thumbData)
                            {
                                PhotoMapPin(image: uiImage, moodColor: entry.moodGradientColor)
                                    .accessibilityLabel(
                                        "Photo entry on \(entry.date.shortFormatted), mood \(entry.feeling) out of 10\(entry.city.map { ", \($0)" } ?? "")"
                                    )
                            } else {
                                Circle()
                                    .fill(entry.moodGradientColor)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                    .accessibilityLabel(
                                        "Entry on \(entry.date.shortFormatted), mood \(entry.feeling) out of 10\(entry.city.map { ", \($0)" } ?? "")"
                                    )
                            }
                        }
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
            .background(
                LinearGradient(
                    colors: [Color.deepSpaceBlue, Color.cardSurface],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationTitle("My Map")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .onAppear {
                if locationViewModel == nil {
                    locationViewModel = DailyEntryViewModel(modelContext: modelContext)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            isUpdatingLocation = true
                            defer { isUpdatingLocation = false }
                            try? await locationViewModel?.updateLocation()
                        }
                    } label: {
                        if isUpdatingLocation {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "location.fill")
                        }
                    }
                    .disabled(isUpdatingLocation)
                }
            }
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
