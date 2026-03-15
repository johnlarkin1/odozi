import XCTest

/// Demo of the streaks & achievements feature:
/// 1. Today tab — streak count and next-milestone hint in vitals grid
/// 2. Guided prompt → submit → CompletionCard with achievement unlock banner
/// 3. Insights tab → Achievements card → Achievement Gallery
/// 4. Streaks detail card
@MainActor
final class StreaksAchievementsDemo: FeatureDemoBase {

    func testStreaksAndAchievementsDemo() throws {
        app.launch()
        pause(2)

        // ── Today Tab: streak vitals card ────────────────────────
        // The vitals grid shows the flame icon with current streak
        // and next-milestone hint (e.g. "1 day to 7!")
        pause(2)

        // Scroll to ensure vitals grid is visible
        app.swipeUp()
        pause(2)
        app.swipeDown()
        pause(1)

        // ── Guided Prompt → Completion with Achievement Banner ───
        startGuidedPrompt()
        pause(2)

        walkThroughGuidedPrompt()
        // CompletionCard shows achievement unlock banner after ~1.5s delay
        pause(4)

        // Dismiss the completion card
        let doneButton = app.buttons["Done"]
        if wait(for: doneButton) {
            doneButton.tap()
            pause(1)
        }

        // ── Insights Tab: Achievements Card ──────────────────────
        tapTab("Insights")
        pause(2)

        // Scroll to find the Achievements card ("X / 30" unlocked)
        app.swipeUp()
        pause(2)

        let achievementsCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'achievement'")
        ).firstMatch
        if wait(for: achievementsCard) {
            pause(1)
            achievementsCard.tap()
            pause(2)

            // ── Achievement Gallery ──────────────────────────────
            // Categories: Streak Milestones, First Steps,
            // Going Deeper, Explorer, Wellness
            app.swipeUp()
            pause(2)
            app.swipeUp()
            pause(2)
            app.swipeUp()
            pause(2)

            // Scroll back to show the summary header
            app.swipeDown()
            pause(1)
            app.swipeDown()
            pause(1)
            app.swipeDown()
            pause(2)

            navigateBack()
        }

        // ── Streaks detail card ──────────────────────────────────
        let streaksCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'streak'")
        ).firstMatch
        if wait(for: streaksCard) {
            streaksCard.tap()
            pause(3)
            navigateBack()
        }

        tapTab("Today")
        pause(1)
    }
}
