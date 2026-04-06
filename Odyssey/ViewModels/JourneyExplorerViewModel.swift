import MapKit
import SwiftData
import SwiftUI
#if os(iOS)
    import Photos
#endif

@MainActor
@Observable
final class JourneyExplorerViewModel {
    var entries: [DailyEntry] = []
    var dateRange: DateRange = .allTime
    var selectedEntry: DailyEntry?
    var selectedIndex: Double = 0
    var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: .init(latitude: 20, longitude: 0), distance: 40_000_000)
    )

    #if os(iOS)
        var autoPhotoThumbnails: [UIImage] = []
        var autoPhotoAssets: [PHAsset] = []
    #endif
    var isLoadingPhotos = false

    private let modelContext: ModelContext
    #if os(iOS)
        private let photoService = PhotoLibraryService.shared
    #endif

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var filteredEntries: [DailyEntry] {
        let start = Calendar.current.startOfDay(for: dateRange.startDate)
        return entries.filter { $0.date >= start }.sorted { $0.date < $1.date }
    }

    var locatedEntries: [DailyEntry] {
        filteredEntries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var sliderRange: ClosedRange<Double> {
        let count = locatedEntries.count
        guard count > 1 else { return 0 ... 0 }
        return 0 ... Double(count - 1)
    }

    var entryCount: Int {
        locatedEntries.count
    }

    func loadEntries() {
        let descriptor = FetchDescriptor<DailyEntry>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []

        if let first = locatedEntries.first {
            selectEntry(first, animated: false)
        }
    }

    func selectEntry(_ entry: DailyEntry, animated: Bool = true) {
        selectedEntry = entry

        if let index = locatedEntries.firstIndex(where: { $0.date == entry.date }) {
            selectedIndex = Double(index)
        }

        if let lat = entry.latitude, let lon = entry.longitude {
            let camera = MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                distance: 100_000,
                heading: 0,
                pitch: 0
            )
            if animated {
                withAnimation(.easeInOut(duration: 0.8)) {
                    cameraPosition = .camera(camera)
                }
            } else {
                cameraPosition = .camera(camera)
            }
        }

        #if os(iOS)
            Task { await loadAutoPhotos(for: entry) }
        #endif
    }

    func selectBySliderIndex(_ index: Double) {
        let clamped = Int(index.rounded())
        let entries = locatedEntries
        guard clamped >= 0, clamped < entries.count else { return }
        selectEntry(entries[clamped])
    }

    #if os(iOS)
        func loadAutoPhotos(for entry: DailyEntry) async {
            isLoadingPhotos = true
            defer { isLoadingPhotos = false }

            let status = await photoService.requestAuthorization()
            guard status == .authorized || status == .limited else {
                autoPhotoThumbnails = []
                autoPhotoAssets = []
                return
            }

            let assets = await photoService.fetchAssets(for: entry.date)
            let prefixedAssets = Array(assets.prefix(6))
            autoPhotoAssets = prefixedAssets
            var thumbnails: [UIImage] = []
            for asset in prefixedAssets {
                if let thumb = await photoService.loadThumbnail(for: asset) {
                    thumbnails.append(thumb)
                }
            }
            autoPhotoThumbnails = thumbnails
        }
    #endif

    func attachPhoto(jpegData: Data, to entry: DailyEntry) {
        var existing = entry.attachedPhotoData ?? []
        existing.append(jpegData)
        entry.attachedPhotoData = existing
        if entry.mapThumbnailData == nil {
            if let thumbnail = PhotoLibraryService.generateMapThumbnail(from: jpegData) {
                entry.mapThumbnailData = thumbnail
                entry.showOnPhotoMap = true
            }
        } else {
            entry.showOnPhotoMap = true
        }
        entry.updatedAt = Date()
    }

    func removeAttachedPhoto(at index: Int, from entry: DailyEntry) {
        guard var existing = entry.attachedPhotoData, index < existing.count else { return }
        existing.remove(at: index)
        entry.attachedPhotoData = existing.isEmpty ? nil : existing
        entry.updatedAt = Date()
    }
}
