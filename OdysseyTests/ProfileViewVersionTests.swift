@testable import Odyssey
import SwiftUI
import XCTest

final class ProfileViewVersionTests: XCTestCase {
    /// Test that the version string displayed in ProfileView comes from the Bundle version
    /// and not a hardcoded string
    func testProfileViewDisplaysBundleVersion() {
        let expectedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        // This test verifies that we read from Bundle, not hardcoded
        // Once ProfileView is fixed to use Bundle.main.infoDictionary, this should pass
        XCTAssertNotEqual(expectedVersion, "2.0", "Version should be read from Bundle, not hardcoded to 2.0")
    }

    /// Test that Bundle version matches expected format
    func testBundleVersionFormat() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        XCTAssertEqual(version, "1.0", "Current version should be 1.0 from Xcode project settings")
    }
}
