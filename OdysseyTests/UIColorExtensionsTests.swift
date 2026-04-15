@testable import Odyssey
import XCTest

final class UIColorExtensionsTests: XCTestCase {
    // MARK: - toHexString

    func testRedToHex() {
        let hex = UIColor.red.toHexString()
        XCTAssertEqual(hex, "#ff0000")
    }

    func testGreenToHex() {
        let hex = UIColor.green.toHexString()
        XCTAssertEqual(hex, "#00ff00")
    }

    func testBlueToHex() {
        let hex = UIColor.blue.toHexString()
        XCTAssertEqual(hex, "#0000ff")
    }

    func testWhiteToHex() {
        let hex = UIColor.white.toHexString()
        XCTAssertEqual(hex, "#ffffff")
    }

    func testBlackToHex() {
        let hex = UIColor.black.toHexString()
        XCTAssertEqual(hex, "#000000")
    }

    // MARK: - fromHexString

    func testFromHexStringWithHash() {
        let color = UIColor.fromHexString("#FF0000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testFromHexStringWithoutHash() {
        let color = UIColor.fromHexString("00FF00")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func testFromHexStringLowercase() {
        let color = UIColor.fromHexString("#0000ff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    func testFromHexStringInvalidLengthReturnsGray() {
        let color = UIColor.fromHexString("#FFF")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        // UIColor.gray is (0.5, 0.5, 0.5)
        XCTAssertEqual(r, 0.5, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.5, accuracy: 0.01)
    }

    func testFromHexStringEmptyReturnsGray() {
        let color = UIColor.fromHexString("")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.5, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.5, accuracy: 0.01)
    }

    // MARK: - Round-trip

    func testRoundTripConversion() {
        let originalHex = "#F5A623"
        let color = UIColor.fromHexString(originalHex)
        let resultHex = color.toHexString()
        XCTAssertEqual(resultHex.lowercased(), originalHex.lowercased())
    }

    func testRoundTripBlue() {
        let hex = "#2EC4B6"
        let color = UIColor.fromHexString(hex)
        let result = color.toHexString()
        XCTAssertEqual(result.lowercased(), hex.lowercased())
    }

    // MARK: - Alpha (8-digit) support

    func testFromHexStringWithAlpha() {
        let color = UIColor.fromHexString("#FF000080")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
        XCTAssertEqual(a, 128.0 / 255.0, accuracy: 0.01)
    }

    func testToHexStringEmitsAlphaWhenNotOpaque() {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 128.0 / 255.0)
        XCTAssertEqual(color.toHexString().lowercased(), "#ff000080")
    }

    func testToHexStringOmitsAlphaWhenOpaque() {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        XCTAssertEqual(color.toHexString().lowercased(), "#ff0000")
    }

    func testRoundTripWithAlpha() {
        let hex = "#80c0ff40"
        let color = UIColor.fromHexString(hex)
        XCTAssertEqual(color.toHexString().lowercased(), hex.lowercased())
    }

    func testFromHexStringInvalidLengthSevenReturnsGray() {
        let color = UIColor.fromHexString("#FFFFFFF")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.5, accuracy: 0.01)
        XCTAssertEqual(g, 0.5, accuracy: 0.01)
        XCTAssertEqual(b, 0.5, accuracy: 0.01)
    }
}
