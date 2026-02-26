import XCTest
import SwiftUI
@testable import Odyssey

final class DailyEntryComputedTests: XCTestCase {

    // MARK: - moodEmoji

    func testMoodEmojiSad() {
        let entry = DailyEntry(feeling: 1)
        XCTAssertEqual(entry.moodEmoji, "😢")
        entry.feeling = 2
        XCTAssertEqual(entry.moodEmoji, "😢")
    }

    func testMoodEmojiSlightlyDown() {
        let entry = DailyEntry(feeling: 3)
        XCTAssertEqual(entry.moodEmoji, "😕")
        entry.feeling = 4
        XCTAssertEqual(entry.moodEmoji, "😕")
    }

    func testMoodEmojiNeutral() {
        let entry = DailyEntry(feeling: 5)
        XCTAssertEqual(entry.moodEmoji, "😐")
        entry.feeling = 6
        XCTAssertEqual(entry.moodEmoji, "😐")
    }

    func testMoodEmojiHappy() {
        let entry = DailyEntry(feeling: 7)
        XCTAssertEqual(entry.moodEmoji, "😊")
        entry.feeling = 8
        XCTAssertEqual(entry.moodEmoji, "😊")
    }

    func testMoodEmojiVeryHappy() {
        let entry = DailyEntry(feeling: 9)
        XCTAssertEqual(entry.moodEmoji, "😄")
        entry.feeling = 10
        XCTAssertEqual(entry.moodEmoji, "😄")
    }

    func testMoodEmojiOutOfRangeDefaultsToNeutral() {
        let entry = DailyEntry(feeling: 0)
        XCTAssertEqual(entry.moodEmoji, "😐")
        entry.feeling = 11
        XCTAssertEqual(entry.moodEmoji, "😐")
    }

    // MARK: - screenTimeFormatted

    func testScreenTimeFormattedNilReturnsNA() {
        let entry = DailyEntry(screenTimeSeconds: nil)
        XCTAssertEqual(entry.screenTimeFormatted, "N/A")
    }

    func testScreenTimeFormattedHoursAndMinutes() {
        let entry = DailyEntry(screenTimeSeconds: 7380) // 2h 3m
        XCTAssertEqual(entry.screenTimeFormatted, "2h 3m")
    }

    func testScreenTimeFormattedMinutesOnly() {
        let entry = DailyEntry(screenTimeSeconds: 2700) // 45m
        XCTAssertEqual(entry.screenTimeFormatted, "45m")
    }

    func testScreenTimeFormattedZeroSeconds() {
        let entry = DailyEntry(screenTimeSeconds: 0)
        XCTAssertEqual(entry.screenTimeFormatted, "0m")
    }

    func testScreenTimeFormattedExactHours() {
        let entry = DailyEntry(screenTimeSeconds: 3600) // 1h 0m
        XCTAssertEqual(entry.screenTimeFormatted, "1h 0m")
    }

    // MARK: - locationDisplay

    func testLocationDisplayCityAndState() {
        let entry = DailyEntry(city: "Chicago", state: "IL")
        XCTAssertEqual(entry.locationDisplay, "Chicago, IL")
    }

    func testLocationDisplayCityOnly() {
        let entry = DailyEntry(city: "Chicago")
        XCTAssertEqual(entry.locationDisplay, "Chicago")
    }

    func testLocationDisplayCoordsOnly() {
        let entry = DailyEntry(latitude: 41.8, longitude: -87.6)
        XCTAssertEqual(entry.locationDisplay, "Location recorded")
    }

    func testLocationDisplayNoLocation() {
        let entry = DailyEntry()
        XCTAssertEqual(entry.locationDisplay, "No location")
    }

    // MARK: - walkingDistanceFormatted

    func testWalkingDistanceFormattedNil() {
        let entry = DailyEntry(walkingDistanceMeters: nil)
        XCTAssertEqual(entry.walkingDistanceFormatted, "N/A")
    }

    func testWalkingDistanceFormattedOneMile() {
        let entry = DailyEntry(walkingDistanceMeters: 1609.34)
        XCTAssertEqual(entry.walkingDistanceFormatted, "1.0 mi")
    }

    func testWalkingDistanceFormattedPartialMile() {
        let entry = DailyEntry(walkingDistanceMeters: 804.67) // ~0.5 miles
        XCTAssertEqual(entry.walkingDistanceFormatted, "0.5 mi")
    }

    // MARK: - hasPromptData

    func testHasPromptDataFalseWhenAllEmpty() {
        let entry = DailyEntry()
        XCTAssertFalse(entry.hasPromptData)
    }

    func testHasPromptDataTrueWithJournalEntry() {
        let entry = DailyEntry(journalEntry: "Had a good day")
        XCTAssertTrue(entry.hasPromptData)
    }

    func testHasPromptDataTrueWithGratitude() {
        let entry = DailyEntry(gratitude: "Family")
        XCTAssertTrue(entry.hasPromptData)
    }

    func testHasPromptDataTrueWithWin() {
        let entry = DailyEntry(win: "Got promoted")
        XCTAssertTrue(entry.hasPromptData)
    }

    func testHasPromptDataTrueWithTension() {
        let entry = DailyEntry(tension: "Work stress")
        XCTAssertTrue(entry.hasPromptData)
    }

    func testHasPromptDataTrueWithSingleWordFeeling() {
        let entry = DailyEntry(singleWordFeeling: "peaceful")
        XCTAssertTrue(entry.hasPromptData)
    }

    // MARK: - moodGradientColor

    func testMoodGradientColorLowMoodIsRedish() {
        let entry = DailyEntry(feeling: 1)
        let components = UIColor(entry.moodGradientColor).cgColor.components!
        XCTAssertGreaterThan(components[0], 0.9) // High red
    }

    func testMoodGradientColorHighMoodIsGreenish() {
        let entry = DailyEntry(feeling: 10)
        let components = UIColor(entry.moodGradientColor).cgColor.components!
        XCTAssertLessThan(components[0], 0.4) // Low red
        XCTAssertGreaterThan(components[1], 0.6) // High green
    }

    // MARK: - feelingColor

    func testFeelingColorParsesHex() {
        let entry = DailyEntry(feelingColorHex: "#FF0000")
        let components = UIColor(entry.feelingColor).cgColor.components!
        XCTAssertEqual(components[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(components[1], 0.0, accuracy: 0.01)
        XCTAssertEqual(components[2], 0.0, accuracy: 0.01)
    }
}
