import XCTest
@testable import Odyssey

final class FoundationModelsAvailabilityTests: XCTestCase {

    // Availability depends on SDK, OS version and whether Apple Intelligence is
    // enabled, so we only assert the property is safe and deterministic.
    func testIsAvailableIsConsistentAcrossMultipleCalls() {
        let first = FoundationModelsAvailability.isAvailable
        let second = FoundationModelsAvailability.isAvailable
        XCTAssertEqual(first, second, "Availability check should be deterministic")
    }
}
