import XCTest
import SwiftUI
@testable import Odyssey

final class ColorExtensionsTests: XCTestCase {

    // MARK: - moodGradient

    func testMoodGradientAtMinimumValue() {
        // Value 1 should be coral-red range (high red, low green)
        let color = Color.moodGradient(for: 1)
        let components = UIColor(color).cgColor.components!
        XCTAssertGreaterThan(components[0], 0.9, "Red should be high at mood 1")
        XCTAssertLessThan(components[1], 0.4, "Green should be low at mood 1")
    }

    func testMoodGradientAtMaximumValue() {
        // Value 10 should be emerald-green range (low red, high green)
        let color = Color.moodGradient(for: 10)
        let components = UIColor(color).cgColor.components!
        XCTAssertLessThan(components[0], 0.4, "Red should be low at mood 10")
        XCTAssertGreaterThan(components[1], 0.6, "Green should be high at mood 10")
    }

    func testMoodGradientAtMidValue() {
        // Value 5 or 6 is around the amber transition
        let color = Color.moodGradient(for: 5)
        let components = UIColor(color).cgColor.components!
        // Should be in the amber range
        XCTAssertGreaterThan(components[0], 0.8, "Red should be high-ish at mood 5")
        XCTAssertGreaterThan(components[1], 0.5, "Green should be moderate at mood 5")
    }

    func testMoodGradientClampsBelowMinimum() {
        // Value 0 should clamp to 1
        let colorZero = Color.moodGradient(for: 0)
        let colorOne = Color.moodGradient(for: 1)
        let c0 = UIColor(colorZero).cgColor.components!
        let c1 = UIColor(colorOne).cgColor.components!
        XCTAssertEqual(c0[0], c1[0], accuracy: 0.01)
        XCTAssertEqual(c0[1], c1[1], accuracy: 0.01)
    }

    func testMoodGradientClampsAboveMaximum() {
        // Value 15 should clamp to 10
        let colorFifteen = Color.moodGradient(for: 15)
        let colorTen = Color.moodGradient(for: 10)
        let c15 = UIColor(colorFifteen).cgColor.components!
        let c10 = UIColor(colorTen).cgColor.components!
        XCTAssertEqual(c15[0], c10[0], accuracy: 0.01)
        XCTAssertEqual(c15[1], c10[1], accuracy: 0.01)
    }

    func testMoodGradientIsMonotonicallyShiftingGreenUp() {
        // Green component should generally increase from 1 to 10
        let green1 = UIColor(Color.moodGradient(for: 1)).cgColor.components![1]
        let green10 = UIColor(Color.moodGradient(for: 10)).cgColor.components![1]
        XCTAssertGreaterThan(green10, green1)
    }

    // MARK: - init(hex:)

    func testHexInitWhite() {
        let color = Color(hex: "#FFFFFF")
        let components = UIColor(color).cgColor.components!
        XCTAssertEqual(components[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(components[1], 1.0, accuracy: 0.01)
        XCTAssertEqual(components[2], 1.0, accuracy: 0.01)
    }

    func testHexInitBlack() {
        let color = Color(hex: "#000000")
        let components = UIColor(color).cgColor.components!
        XCTAssertEqual(components[0], 0.0, accuracy: 0.01)
        XCTAssertEqual(components[1], 0.0, accuracy: 0.01)
        XCTAssertEqual(components[2], 0.0, accuracy: 0.01)
    }

    func testHexInitInvalidLengthDefaultsToWhite() {
        let color = Color(hex: "FFF")
        let components = UIColor(color).cgColor.components!
        XCTAssertEqual(components[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(components[1], 1.0, accuracy: 0.01)
        XCTAssertEqual(components[2], 1.0, accuracy: 0.01)
    }

    func testHexInitAccentAmber() {
        let color = Color(hex: "#F5A623")
        let components = UIColor(color).cgColor.components!
        XCTAssertEqual(components[0], 0.96, accuracy: 0.02) // Red
        XCTAssertEqual(components[1], 0.65, accuracy: 0.02) // Green
        XCTAssertEqual(components[2], 0.14, accuracy: 0.02) // Blue
    }
}
