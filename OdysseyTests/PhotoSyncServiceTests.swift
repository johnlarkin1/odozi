#if os(iOS)
    @testable import Odyssey
    import SwiftData
    import XCTest

    @MainActor
    final class PhotoSyncServiceTests: XCTestCase {
        private var calendar: Calendar!

        override func setUp() {
            super.setUp()
            calendar = Calendar(identifier: .gregorian)
        }

        private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = day
            comps.hour = hour
            return calendar.date(from: comps)!
        }

        // MARK: - groupByDay

        func testGroupByDayBucketsSameDayPhotosTogether() {
            let infos = [
                PhotoAssetInfo(localIdentifier: "a", creationDate: date(2026, 6, 1, hour: 8), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "b", creationDate: date(2026, 6, 1, hour: 20), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "c", creationDate: date(2026, 6, 2, hour: 9), latitude: nil, longitude: nil)
            ]

            let groups = PhotoSyncService.groupByDay(infos, calendar: calendar)

            XCTAssertEqual(groups.count, 2)
            XCTAssertEqual(groups[0].infos.map(\.localIdentifier), ["a", "b"])
            XCTAssertEqual(groups[1].infos.map(\.localIdentifier), ["c"])
        }

        func testGroupByDayReturnsChronologicalOrder() {
            let infos = [
                PhotoAssetInfo(localIdentifier: "late", creationDate: date(2026, 6, 3), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "early", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            ]

            let groups = PhotoSyncService.groupByDay(infos, calendar: calendar)

            XCTAssertEqual(groups.map { calendar.component(.day, from: $0.day) }, [1, 3])
        }

        func testGroupByDayEmptyInput() {
            XCTAssertTrue(PhotoSyncService.groupByDay([], calendar: calendar).isEmpty)
        }

        // MARK: - firstCoordinate

        func testFirstCoordinateReturnsFirstGeotaggedAsset() {
            let infos = [
                PhotoAssetInfo(localIdentifier: "a", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "b", creationDate: date(2026, 6, 1), latitude: 40.7, longitude: -74.0),
                PhotoAssetInfo(localIdentifier: "c", creationDate: date(2026, 6, 1), latitude: 41.0, longitude: -73.0)
            ]

            let coordinate = PhotoSyncService.firstCoordinate(in: infos)

            XCTAssertEqual(coordinate?.latitude, 40.7)
            XCTAssertEqual(coordinate?.longitude, -74.0)
        }

        func testFirstCoordinateReturnsNilWhenNoGeotag() {
            let infos = [
                PhotoAssetInfo(localIdentifier: "a", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            ]
            XCTAssertNil(PhotoSyncService.firstCoordinate(in: infos))
        }

        // MARK: - linkPhotos

        func testLinkPhotosAddsIdentifiersToEntry() {
            let entry = DailyEntry(date: date(2026, 6, 1))
            let infos = [
                PhotoAssetInfo(localIdentifier: "a", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "b", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            ]

            let added = PhotoSyncService.linkPhotos(infos, to: entry, maxPerDay: 30)

            XCTAssertEqual(added, 2)
            XCTAssertEqual(entry.autoPhotoIdentifiers, ["a", "b"])
        }

        func testLinkPhotosSkipsDuplicates() {
            let entry = DailyEntry(date: date(2026, 6, 1))
            entry.autoPhotoIdentifiers = ["a"]
            let infos = [
                PhotoAssetInfo(localIdentifier: "a", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "b", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            ]

            let added = PhotoSyncService.linkPhotos(infos, to: entry, maxPerDay: 30)

            XCTAssertEqual(added, 1)
            XCTAssertEqual(entry.autoPhotoIdentifiers, ["a", "b"])
        }

        func testLinkPhotosIsIdempotent() {
            let entry = DailyEntry(date: date(2026, 6, 1))
            let infos = [
                PhotoAssetInfo(localIdentifier: "a", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            ]

            _ = PhotoSyncService.linkPhotos(infos, to: entry, maxPerDay: 30)
            let secondAdd = PhotoSyncService.linkPhotos(infos, to: entry, maxPerDay: 30)

            XCTAssertEqual(secondAdd, 0)
            XCTAssertEqual(entry.autoPhotoIdentifiers, ["a"])
        }

        func testLinkPhotosDedupesRepeatedIdentifiersWithinInput() {
            let entry = DailyEntry(date: date(2026, 6, 1))
            let infos = [
                PhotoAssetInfo(localIdentifier: "dup", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "dup", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil),
                PhotoAssetInfo(localIdentifier: "unique", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            ]

            let added = PhotoSyncService.linkPhotos(infos, to: entry, maxPerDay: 30)

            XCTAssertEqual(added, 2)
            XCTAssertEqual(entry.autoPhotoIdentifiers, ["dup", "unique"])
        }

        func testLinkPhotosRespectsPerDayCap() {
            let entry = DailyEntry(date: date(2026, 6, 1))
            let infos = (0 ..< 50).map {
                PhotoAssetInfo(localIdentifier: "id\($0)", creationDate: date(2026, 6, 1), latitude: nil, longitude: nil)
            }

            let added = PhotoSyncService.linkPhotos(infos, to: entry, maxPerDay: 30)

            XCTAssertEqual(added, 30)
            XCTAssertEqual(entry.autoPhotoIdentifiers?.count, 30)
        }

        // MARK: - PhotoAssetInfo

        func testHasLocation() {
            let geotagged = PhotoAssetInfo(localIdentifier: "a", creationDate: Date(), latitude: 1, longitude: 2)
            let plain = PhotoAssetInfo(localIdentifier: "b", creationDate: Date(), latitude: nil, longitude: nil)
            XCTAssertTrue(geotagged.hasLocation)
            XCTAssertFalse(plain.hasLocation)
        }

        // MARK: - PhotoSyncSummary

        func testSummaryDidAnything() {
            XCTAssertFalse(PhotoSyncSummary().didAnything)
            XCTAssertTrue(PhotoSyncSummary(photosLinked: 1).didAnything)
            XCTAssertTrue(PhotoSyncSummary(locationsSet: 1).didAnything)
        }
    }
#endif
