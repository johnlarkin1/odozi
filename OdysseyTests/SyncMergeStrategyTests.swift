@testable import Odyssey
import SwiftData
import XCTest

final class SyncMergeStrategyTests: XCTestCase {
    // Timestamps used throughout
    private let older = Date(timeIntervalSince1970: 1_000_000)
    private let newer = Date(timeIntervalSince1970: 2_000_000)

    // MARK: - mergeTextField

    func testTextFieldBothEmpty() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "", remote: "", localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, "")
    }

    func testTextFieldIdentical() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "hello", remote: "hello", localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, "hello")
    }

    func testTextFieldLocalEmptyRemoteWins() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "", remote: "remote text", localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(result, "remote text", "Non-empty should win regardless of timestamp")
    }

    func testTextFieldRemoteEmptyLocalWins() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "local text", remote: "", localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, "local text", "Non-empty should win regardless of timestamp")
    }

    func testTextFieldRemoteLongerWins() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "short", remote: "much longer text here", localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(result, "much longer text here", "Longer text should win regardless of timestamp")
    }

    func testTextFieldLocalLongerWins() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "much longer text here", remote: "short", localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, "much longer text here", "Longer text should win regardless of timestamp")
    }

    func testTextFieldEqualLengthRemoteNewerWins() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "aaaa", remote: "bbbb", localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, "bbbb", "Equal length: newer timestamp should win")
    }

    func testTextFieldEqualLengthLocalNewerWins() {
        let result = SyncMergeStrategy.mergeTextField(
            local: "aaaa", remote: "bbbb", localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(result, "aaaa", "Equal length: newer timestamp should win")
    }

    // MARK: - mergeNumericField

    func testNumericFieldIdentical() {
        let result = SyncMergeStrategy.mergeNumericField(
            local: 5, remote: 5, localTimestamp: older, remoteTimestamp: newer, defaultValue: 0
        )
        XCTAssertEqual(result, 5)
    }

    func testNumericFieldLocalDefaultRemoteWins() {
        let result = SyncMergeStrategy.mergeNumericField(
            local: 0, remote: 7, localTimestamp: newer, remoteTimestamp: older, defaultValue: 0
        )
        XCTAssertEqual(result, 7, "Non-default should win regardless of timestamp")
    }

    func testNumericFieldRemoteDefaultLocalWins() {
        let result = SyncMergeStrategy.mergeNumericField(
            local: 3, remote: 0, localTimestamp: older, remoteTimestamp: newer, defaultValue: 0
        )
        XCTAssertEqual(result, 3, "Non-default should win regardless of timestamp")
    }

    func testNumericFieldBothNonDefaultRemoteNewerWins() {
        let result = SyncMergeStrategy.mergeNumericField(
            local: 3, remote: 7, localTimestamp: older, remoteTimestamp: newer, defaultValue: 0
        )
        XCTAssertEqual(result, 7, "Both non-default: newer timestamp should win")
    }

    func testNumericFieldBothNonDefaultLocalNewerWins() {
        let result = SyncMergeStrategy.mergeNumericField(
            local: 3, remote: 7, localTimestamp: newer, remoteTimestamp: older, defaultValue: 0
        )
        XCTAssertEqual(result, 3, "Both non-default: newer timestamp should win")
    }

    // MARK: - mergeOptionalField

    func testOptionalFieldBothNil() {
        let result: Int? = SyncMergeStrategy.mergeOptionalField(
            local: nil, remote: nil, localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertNil(result)
    }

    func testOptionalFieldIdentical() {
        let result: Int? = SyncMergeStrategy.mergeOptionalField(
            local: 42, remote: 42, localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, 42)
    }

    func testOptionalFieldLocalNilRemoteWins() {
        let result: Int? = SyncMergeStrategy.mergeOptionalField(
            local: nil, remote: 99, localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(result, 99, "Non-nil should win regardless of timestamp")
    }

    func testOptionalFieldRemoteNilLocalWins() {
        let result: Int? = SyncMergeStrategy.mergeOptionalField(
            local: 99, remote: nil, localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, 99, "Non-nil should win regardless of timestamp")
    }

    func testOptionalFieldBothNonNilRemoteNewerWins() {
        let result: Int? = SyncMergeStrategy.mergeOptionalField(
            local: 10, remote: 20, localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(result, 20, "Both non-nil: newer timestamp should win")
    }

    func testOptionalFieldBothNonNilLocalNewerWins() {
        let result: Int? = SyncMergeStrategy.mergeOptionalField(
            local: 10, remote: 20, localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(result, 10, "Both non-nil: newer timestamp should win")
    }

    // MARK: - mergeLocationFields

    func testLocationBothNil() {
        let entry = makeEntry()
        SyncMergeStrategy.mergeLocationFields(
            localEntry: entry,
            remoteLatitude: nil, remoteLongitude: nil,
            remoteCity: nil, remoteState: nil, remoteCountry: nil,
            localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertNil(entry.latitude)
        XCTAssertNil(entry.longitude)
    }

    func testLocationLocalNilRemotePresent() {
        let entry = makeEntry() // no location
        SyncMergeStrategy.mergeLocationFields(
            localEntry: entry,
            remoteLatitude: 40.7, remoteLongitude: -74.0,
            remoteCity: "NYC", remoteState: "NY", remoteCountry: "US",
            localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(entry.latitude, 40.7)
        XCTAssertEqual(entry.longitude, -74.0)
        XCTAssertEqual(entry.city, "NYC")
        XCTAssertEqual(entry.state, "NY")
        XCTAssertEqual(entry.country, "US")
    }

    func testLocationRemoteNilLocalPresent() {
        let entry = makeEntry(latitude: 34.0, longitude: -118.2, city: "LA", state: "CA", country: "US")
        SyncMergeStrategy.mergeLocationFields(
            localEntry: entry,
            remoteLatitude: nil, remoteLongitude: nil,
            remoteCity: nil, remoteState: nil, remoteCountry: nil,
            localTimestamp: older, remoteTimestamp: newer
        )
        // Local should be preserved
        XCTAssertEqual(entry.latitude, 34.0)
        XCTAssertEqual(entry.city, "LA")
    }

    func testLocationBothPresentRemoteNewerWins() {
        let entry = makeEntry(latitude: 34.0, longitude: -118.2, city: "LA", state: "CA", country: "US")
        SyncMergeStrategy.mergeLocationFields(
            localEntry: entry,
            remoteLatitude: 40.7, remoteLongitude: -74.0,
            remoteCity: "NYC", remoteState: "NY", remoteCountry: "US",
            localTimestamp: older, remoteTimestamp: newer
        )
        XCTAssertEqual(entry.latitude, 40.7)
        XCTAssertEqual(entry.city, "NYC")
    }

    func testLocationBothPresentLocalNewerWins() {
        let entry = makeEntry(latitude: 34.0, longitude: -118.2, city: "LA", state: "CA", country: "US")
        SyncMergeStrategy.mergeLocationFields(
            localEntry: entry,
            remoteLatitude: 40.7, remoteLongitude: -74.0,
            remoteCity: "NYC", remoteState: "NY", remoteCountry: "US",
            localTimestamp: newer, remoteTimestamp: older
        )
        XCTAssertEqual(entry.latitude, 34.0)
        XCTAssertEqual(entry.city, "LA")
    }
}
