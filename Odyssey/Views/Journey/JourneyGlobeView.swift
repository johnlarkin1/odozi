import MapKit
import os
import SwiftUI

private let globeLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "JourneyGlobe")

struct JourneyGlobeView: View {
    let entries: [DailyEntry]
    /// The day currently highlighted by the timeline slider / detail card.
    var selectedDate: Date?
    @Binding var cameraPosition: MapCameraPosition
    var onEntryTapped: ((DailyEntry) -> Void)?

    @State private var thumbnailCache: [Date: UIImage] = [:]

    var body: some View {
        Map(position: $cameraPosition) {
            // Every other day, dimmed so the selected day stands out.
            ForEach(backgroundEntries, id: \.date) { entry in
                if let coordinate = coordinate(for: entry) {
                    Annotation(entry.date.shortFormatted, coordinate: coordinate, anchor: .center) {
                        Button {
                            onEntryTapped?(entry)
                        } label: {
                            pinContent(for: entry)
                                .scaleEffect(0.85)
                                .opacity(0.45)
                        }
                        .accessibilityLabel(entry.date.shortFormatted)
                    }
                    .annotationTitles(.hidden)
                }
            }

            // Selected day, added last so it draws above the other pins.
            if let entry = selectedEntry, let coordinate = coordinate(for: entry) {
                Annotation(entry.date.shortFormatted, coordinate: coordinate, anchor: .center) {
                    SelectedDayPin(
                        date: entry.date,
                        moodColor: entry.moodGradientColor
                    ) {
                        pinContent(for: entry)
                    }
                    .accessibilityLabel("Selected day, \(entry.date.shortFormatted)")
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .onAppear { buildThumbnailCache() }
        .onChange(of: entries.count) { buildThumbnailCache() }
        .onChange(of: photoPinDates) { buildThumbnailCache() }
    }

    @ViewBuilder
    private func pinContent(for entry: DailyEntry) -> some View {
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

    private func coordinate(for entry: DailyEntry) -> CLLocationCoordinate2D? {
        guard let lat = entry.latitude, let lon = entry.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var locatedEntries: [DailyEntry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Days currently pinned with a photo. Rebuilding the cache when this
    /// changes makes a pin appear (or disappear) as soon as it's toggled,
    /// not only when the number of entries changes.
    private var photoPinDates: [Date] {
        locatedEntries.filter(\.hasMapPhoto).map(\.date)
    }

    private var selectedEntry: DailyEntry? {
        guard let selectedDate else { return nil }
        return locatedEntries.first { $0.date == selectedDate }
    }

    private var backgroundEntries: [DailyEntry] {
        locatedEntries.filter { $0.date != selectedDate }
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

/// Emphasized marker for the day the timeline is on: enlarged pin, amber ring,
/// a soft pulsing halo, and a date callout above it.
private struct SelectedDayPin<Content: View>: View {
    let date: Date
    let moodColor: Color
    @ViewBuilder let content: () -> Content

    @State private var isPulsing = false

    var body: some View {
        content()
            .scaleEffect(1.25)
            .padding(6)
            .background(
                Circle()
                    .stroke(Color.accentAmber, lineWidth: 3)
                    .shadow(color: Color.accentAmber.opacity(0.8), radius: 6)
            )
            .background(
                // Declarative repeatForever (not withAnimation in onAppear) so the
                // pulse can't leak into sibling views.
                Circle()
                    .fill(Color.accentAmber.opacity(0.35))
                    .scaleEffect(isPulsing ? 1.9 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .overlay(alignment: .top) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(moodColor)
                        .frame(width: 7, height: 7)
                    Text(date.shortFormatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.75)))
                .overlay(Capsule().stroke(Color.accentAmber, lineWidth: 1))
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + 8 }
            }
            .onAppear { isPulsing = true }
    }
}
