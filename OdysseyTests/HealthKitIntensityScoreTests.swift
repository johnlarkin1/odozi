@testable import Odyssey
import XCTest

final class HealthKitIntensityScoreTests: XCTestCase {

    private func makeWorkout(
        activityName: String = "Running",
        durationSeconds: Double = 1800,
        totalCalories: Double? = nil
    ) -> WorkoutSummary {
        let start = Date()
        return WorkoutSummary(
            activityType: 0,
            activityName: activityName,
            durationSeconds: durationSeconds,
            totalCalories: totalCalories,
            totalDistanceMeters: nil,
            averageHeartRate: nil,
            startDate: start,
            endDate: start.addingTimeInterval(durationSeconds)
        )
    }

    // MARK: - Empty Input

    func testEmptyWorkoutsReturnsNil() {
        XCTAssertNil(HealthKitService.computeIntensityScore(for: []))
    }

    // MARK: - Base Scores

    func testLowIntensityWorkout() {
        // Walking = base 3, 20 min (no duration mod), no calories
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Walking", durationSeconds: 20 * 60)
        ])
        XCTAssertEqual(score, 3)
    }

    func testHighIntensityWorkoutClampedTo10() {
        // HIIT = base 8, 90 min (+2), 800 cal (+2) = 12 → clamped to 10
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "HIIT", durationSeconds: 90 * 60, totalCalories: 800)
        ])
        XCTAssertEqual(score, 10)
    }

    func testUnknownWorkoutTypeDefaultsToBase5() {
        // Unknown type = base 5, 30 min (no mod), no calories
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Underwater Basket Weaving", durationSeconds: 30 * 60)
        ])
        XCTAssertEqual(score, 5)
    }

    // MARK: - Duration Modifiers

    func testDurationOver45MinAdds1() {
        // Running = base 7, 46 min (+1) = 8
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Running", durationSeconds: 46 * 60)
        ])
        XCTAssertEqual(score, 8)
    }

    func testDurationOver75MinAdds2() {
        // Running = base 7, 76 min (+2) = 9
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Running", durationSeconds: 76 * 60)
        ])
        XCTAssertEqual(score, 9)
    }

    // MARK: - Calorie Modifiers

    func testCaloriesOver400Adds1() {
        // Yoga = base 3, 30 min (no mod), 450 cal (+1) = 4
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Yoga", durationSeconds: 30 * 60, totalCalories: 450)
        ])
        XCTAssertEqual(score, 4)
    }

    func testCaloriesOver700Adds2() {
        // Yoga = base 3, 30 min (no mod), 750 cal (+2) = 5
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Yoga", durationSeconds: 30 * 60, totalCalories: 750)
        ])
        XCTAssertEqual(score, 5)
    }

    // MARK: - Multiple Workouts

    func testLongestWorkoutDeterminesBaseScore() {
        // Short HIIT (base 8, 10 min) + Long Walking (base 3, 50 min +1 duration mod)
        // Longest is Walking → base 3 + 1 = 4
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "HIIT", durationSeconds: 10 * 60),
            makeWorkout(activityName: "Walking", durationSeconds: 50 * 60)
        ])
        XCTAssertEqual(score, 4)
    }

    func testCaloriesSumAcrossAllWorkouts() {
        // Two workouts each with 250 cal = 500 total (+1 calorie mod)
        // Walking base 3, 30 min longest (no duration mod) + 1 = 4
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Walking", durationSeconds: 30 * 60, totalCalories: 250),
            makeWorkout(activityName: "Walking", durationSeconds: 20 * 60, totalCalories: 250)
        ])
        XCTAssertEqual(score, 4)
    }

    // MARK: - Clamping

    func testMinimumScoreIs1() {
        // Archery = base 2, short (no mod), no calories = 2 → min(max(2,1),10) = 2
        // Actually base 2 is above 1, so test with the lowest: Cooldown = 2
        // The minimum possible is base 2 (Archery/Fishing/Cooldown), no mods = 2
        // Score is already ≥ 1 for all mapped types, so clamping to 1 is a safety net
        let score = HealthKitService.computeIntensityScore(for: [
            makeWorkout(activityName: "Archery", durationSeconds: 10 * 60)
        ])
        XCTAssertEqual(score, 2)
        // Verify it's at least 1
        XCTAssertGreaterThanOrEqual(score!, 1)
    }
}
