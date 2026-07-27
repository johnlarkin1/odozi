#if os(iOS)
    import CoreLocation
    import Foundation
    import os
    import Photos
    import SwiftData

    private let photoSyncLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "PhotoSync")

    /// Outcome of a photo-sync pass, surfaced to the UI as a human-readable
    /// summary and used by tests to assert behavior.
    struct PhotoSyncSummary: Equatable, Sendable {
        var daysScanned = 0
        var daysWithPhotos = 0
        var photosLinked = 0
        var locationsSet = 0
        var authorizationDenied = false

        var didAnything: Bool { photosLinked > 0 || locationsSet > 0 }
    }

    /// Links photos from the user's library to `DailyEntry` rows across a date
    /// range, and backfills each day's location from photo GPS metadata when the
    /// entry has none. Runs on demand (from the Profile sync button) and on a
    /// throttled cadence from the app's foreground catch-up.
    ///
    /// Rules (per the feature spec):
    ///   1. For every day in the range, link that day's photos to the entry.
    ///   2. If the entry has no location, derive it from the first geotagged
    ///      photo of the day (coordinates + reverse-geocoded place).
    ///   3. If the entry already has a location, leave it and just link photos.
    @MainActor
    final class PhotoSyncService {
        static let autoSyncEnabledKey = "photoAutoSyncEnabled"
        static let lastAutoSyncKey = "lastPhotoAutoSyncAt"

        /// How far back the automatic sync looks on each foreground pass.
        static let autoSyncWindowDays = 30
        /// Don't run the automatic sync more than once per this interval.
        static let autoSyncMinInterval: TimeInterval = 12 * 60 * 60
        /// Upper bound on identifiers stored per day so a burst of photos on one
        /// day can't bloat a single entry.
        static let maxPhotosPerDay = 30

        private let photoService: PhotoLibraryService
        private let geocoder = CLGeocoder()

        init(photoService: PhotoLibraryService = .shared) {
            self.photoService = photoService
        }

        // MARK: - Manual sync

        /// Scan `[startDate, endDate]` (inclusive of both calendar days), linking
        /// photos and backfilling locations. Prompts for photo access if needed.
        @discardableResult
        func sync(from startDate: Date, to endDate: Date, context: ModelContext) async -> PhotoSyncSummary {
            let status = await photoService.requestAuthorization()
            guard status == .authorized || status == .limited else {
                photoSyncLogger.info("Photo sync skipped — authorization status \(status.rawValue)")
                return PhotoSyncSummary(authorizationDenied: true)
            }
            return await run(from: startDate, to: endDate, context: context)
        }

        // MARK: - Automatic sync (cadence)

        /// Throttled automatic sync over a recent window. No-ops when disabled,
        /// when run too recently, or when photo access hasn't been granted (it
        /// never prompts — that's the manual button's job).
        func autoSyncIfNeeded(context: ModelContext) async {
            let defaults = UserDefaults.standard
            let enabled = defaults.object(forKey: Self.autoSyncEnabledKey) as? Bool ?? true
            guard enabled else { return }

            if let last = defaults.object(forKey: Self.lastAutoSyncKey) as? Date,
               Date().timeIntervalSince(last) < Self.autoSyncMinInterval {
                return
            }

            let status = photoService.currentAuthorizationStatus()
            guard status == .authorized || status == .limited else { return }

            let end = Date()
            let start = Calendar.current.date(byAdding: .day, value: -Self.autoSyncWindowDays, to: end) ?? end
            let summary = await run(from: start, to: end, context: context)
            defaults.set(Date(), forKey: Self.lastAutoSyncKey)
            photoSyncLogger.info(
                "Auto photo sync: linked \(summary.photosLinked) photos, set \(summary.locationsSet) locations across \(summary.daysWithPhotos) days"
            )
        }

        // MARK: - Core

        private func run(from startDate: Date, to endDate: Date, context: ModelContext) async -> PhotoSyncSummary {
            var summary = PhotoSyncSummary()
            let calendar = Calendar.current
            let lower = min(startDate, endDate)
            let upper = max(startDate, endDate)
            let rangeStart = calendar.startOfDay(for: lower)
            let lastDayStart = calendar.startOfDay(for: upper)
            guard let fetchEnd = calendar.date(byAdding: .day, value: 1, to: lastDayStart) else {
                return summary
            }

            let infos = await photoService.fetchAssetInfos(from: rangeStart, to: fetchEnd)
            let grouped = Self.groupByDay(infos, calendar: calendar)
            summary.daysScanned = grouped.count

            let repository = DailyEntryRepository(context: context)
            for group in grouped {
                summary.daysWithPhotos += 1
                do {
                    let entry = try repository.fetchOrCreate(for: group.day)

                    let linked = Self.linkPhotos(group.infos, to: entry, maxPerDay: Self.maxPhotosPerDay)
                    summary.photosLinked += linked

                    var locationSet = false
                    if entry.latitude == nil || entry.longitude == nil,
                       let coordinate = Self.firstCoordinate(in: group.infos) {
                        entry.latitude = coordinate.latitude
                        entry.longitude = coordinate.longitude
                        entry.locationCapturedAt = entry.locationCapturedAt ?? Date()
                        if let place = await reverseGeocode(latitude: coordinate.latitude, longitude: coordinate.longitude) {
                            if entry.city == nil { entry.city = place.city }
                            if entry.state == nil { entry.state = place.state }
                            if entry.country == nil { entry.country = place.country }
                        }
                        summary.locationsSet += 1
                        locationSet = true
                    }

                    if linked > 0 || locationSet {
                        entry.updatedAt = Date()
                    }
                } catch {
                    photoSyncLogger.error("Failed to sync photos for \(group.day, privacy: .public): \(error)")
                }
            }

            if summary.didAnything {
                do {
                    try context.save()
                } catch {
                    photoSyncLogger.error("Failed to save photo sync results: \(error)")
                }
            }
            return summary
        }

        private func reverseGeocode(
            latitude: Double,
            longitude: Double
        ) async -> (city: String?, state: String?, country: String?)? {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
                return nil
            }
            return (placemark.locality, placemark.administrativeArea, placemark.isoCountryCode)
        }

        // MARK: - Pure helpers (unit-tested)

        /// Bucket assets by their calendar day, returning groups sorted
        /// chronologically. Photos within a day keep their fetch order (ascending
        /// creation date).
        static func groupByDay(
            _ infos: [PhotoAssetInfo],
            calendar: Calendar
        ) -> [(day: Date, infos: [PhotoAssetInfo])] {
            var buckets: [Date: [PhotoAssetInfo]] = [:]
            for info in infos {
                let day = calendar.startOfDay(for: info.creationDate)
                buckets[day, default: []].append(info)
            }
            return buckets
                .sorted { $0.key < $1.key }
                .map { (day: $0.key, infos: $0.value) }
        }

        /// Coordinate of the first geotagged asset in the day, if any.
        static func firstCoordinate(in infos: [PhotoAssetInfo]) -> (latitude: Double, longitude: Double)? {
            for info in infos {
                if let lat = info.latitude, let lon = info.longitude {
                    return (lat, lon)
                }
            }
            return nil
        }

        /// Union `infos`' identifiers into the entry, skipping duplicates and
        /// stopping once the per-day cap is reached. Returns how many were added.
        @discardableResult
        static func linkPhotos(_ infos: [PhotoAssetInfo], to entry: DailyEntry, maxPerDay: Int) -> Int {
            var identifiers = entry.autoPhotoIdentifiers ?? []
            let existing = Set(identifiers)
            var added = 0
            for info in infos {
                guard identifiers.count < maxPerDay else { break }
                guard !existing.contains(info.localIdentifier) else { continue }
                identifiers.append(info.localIdentifier)
                added += 1
            }
            if added > 0 {
                entry.autoPhotoIdentifiers = identifiers
            }
            return added
        }
    }
#endif
