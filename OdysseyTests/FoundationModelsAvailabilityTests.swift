import XCTest
@testable import Odyssey

final class FoundationModelsAvailabilityTests: XCTestCase {

    func testIsAvailableReturnsBool() {
        // On current test hardware (simulator, CI), FoundationModels is not available.
        // This verifies the property doesn't crash and returns a stable Bool.
        let result = FoundationModelsAvailability.isAvailable
        // On Xcode 16 / iOS 18 SDK, canImport(FoundationModels) is false,
        // so this should always be false in the test environment.
        XCTAssertFalse(result, "FoundationModels should not be available on simulator / CI")
    }

    func testIsAvailableIsConsistentAcrossMultipleCalls() {
        let first = FoundationModelsAvailability.isAvailable
        let second = FoundationModelsAvailability.isAvailable
        XCTAssertEqual(first, second, "Availability check should be deterministic")
    }
}
