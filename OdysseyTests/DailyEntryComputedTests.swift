@testable import Odyssey
import SwiftUI
import XCTest

final class DailyEntryComputedTests: XCTestCase {
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

    // MARK: - hasSleepStageData

    func testHasSleepStageDataFalseWhenAllNil() {
        let entry = DailyEntry()
        XCTAssertFalse(entry.hasSleepStageData)
    }

    func testHasSleepStageDataTrueWithREMOnly() {
        let entry = DailyEntry(sleepREMHours: 1.5)
        XCTAssertTrue(entry.hasSleepStageData)
    }

    func testHasSleepStageDataTrueWithDeepOnly() {
        let entry = DailyEntry(sleepDeepHours: 1.0)
        XCTAssertTrue(entry.hasSleepStageData)
    }

    func testHasSleepStageDataTrueWithCoreOnly() {
        let entry = DailyEntry(sleepCoreHours: 3.0)
        XCTAssertTrue(entry.hasSleepStageData)
    }

    // MARK: - sleepStageBreakdown

    func testSleepStageBreakdownOrdering() {
        let entry = DailyEntry(sleepREMHours: 1.5, sleepDeepHours: 1.0, sleepCoreHours: 3.0, sleepAwakeMinutes: 30.0)
        let labels = entry.sleepStageBreakdown.map(\.label)
        XCTAssertEqual(labels, ["Core", "Deep", "REM", "Awake"])
    }

    func testSleepStageBreakdownExcludesNilStages() {
        let entry = DailyEntry(sleepDeepHours: 1.0)
        let labels = entry.sleepStageBreakdown.map(\.label)
        XCTAssertEqual(labels, ["Deep"])
    }

    func testSleepStageBreakdownAwakeConvertsMinutesToHours() {
        let entry = DailyEntry(sleepCoreHours: 3.0, sleepAwakeMinutes: 90.0)
        let awakeStage = entry.sleepStageBreakdown.first(where: { $0.label == "Awake" })
        XCTAssertNotNil(awakeStage)
        XCTAssertEqual(awakeStage!.hours, 1.5, accuracy: 0.01)
    }

    // MARK: - sleepScoreLabel

    func testSleepScoreLabelNilWhenNoScore() {
        let entry = DailyEntry()
        XCTAssertNil(entry.sleepScoreLabel)
    }

    // MARK: - hasMapPhoto

    func testHasMapPhotoTrueWhenEnabledAndThumbnailPresent() {
        let entry = DailyEntry()
        entry.showOnPhotoMap = true
        entry.mapThumbnailData = Data([0xFF, 0xD8, 0xFF]) // minimal JPEG-like data
        XCTAssertTrue(entry.hasMapPhoto)
    }

    func testHasMapPhotoFalseWhenDisabledWithThumbnail() {
        let entry = DailyEntry()
        entry.showOnPhotoMap = false
        entry.mapThumbnailData = Data([0xFF, 0xD8, 0xFF])
        XCTAssertFalse(entry.hasMapPhoto)
    }

    func testHasMapPhotoFalseWhenEnabledWithoutThumbnail() {
        let entry = DailyEntry()
        entry.showOnPhotoMap = true
        entry.mapThumbnailData = nil
        XCTAssertFalse(entry.hasMapPhoto)
    }

    func testHasMapPhotoFalseWhenBothDisabledAndNoThumbnail() {
        let entry = DailyEntry()
        entry.showOnPhotoMap = false
        entry.mapThumbnailData = nil
        XCTAssertFalse(entry.hasMapPhoto)
    }

    // MARK: - hasAutoData

    func testHasAutoDataFalseWhenAllNil() {
        let entry = DailyEntry()
        XCTAssertFalse(entry.hasAutoData)
    }

    func testHasAutoDataTrueWithStepCount() {
        let entry = DailyEntry(stepCount: 5000)
        XCTAssertTrue(entry.hasAutoData)
    }

    func testHasAutoDataTrueWithSleepHours() {
        let entry = DailyEntry(sleepHours: 7.5)
        XCTAssertTrue(entry.hasAutoData)
    }

    func testHasAutoDataTrueWithScreenTime() {
        let entry = DailyEntry(screenTimeSeconds: 3600)
        XCTAssertTrue(entry.hasAutoData)
    }

    func testHasAutoDataTrueWithWorkoutData() {
        let entry = DailyEntry(workoutDataJSON: Data([0x01]))
        XCTAssertTrue(entry.hasAutoData)
    }

    func testHasAutoDataTrueWithLocation() {
        let entry = DailyEntry(latitude: 40.7)
        XCTAssertTrue(entry.hasAutoData)
    }

    func testHasAutoDataTrueWithHeartRate() {
        let entry = DailyEntry(restingHeartRate: 65.0)
        XCTAssertTrue(entry.hasAutoData)
    }

    func testHasAutoDataIndependentOfPromptData() {
        let entry = DailyEntry(gratitude: "Family", win: "Shipped feature")
        XCTAssertFalse(entry.hasAutoData)
    }

    // MARK: - sleepScoreLabel

    func testSleepScoreLabelBoundaries() {
        XCTAssertEqual(DailyEntry(sleepScore: 40).sleepScoreLabel, "Low")
        XCTAssertEqual(DailyEntry(sleepScore: 41).sleepScoreLabel, "Fair")
        XCTAssertEqual(DailyEntry(sleepScore: 60).sleepScoreLabel, "Fair")
        XCTAssertEqual(DailyEntry(sleepScore: 61).sleepScoreLabel, "Good")
        XCTAssertEqual(DailyEntry(sleepScore: 80).sleepScoreLabel, "Good")
        XCTAssertEqual(DailyEntry(sleepScore: 81).sleepScoreLabel, "Excellent")
    }
}
