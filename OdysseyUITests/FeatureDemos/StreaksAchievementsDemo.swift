import XCTest

/// Demo of the streaks & achievements feature:
/// 1. Today tab — show streak count in vitals grid
/// 2. Insights tab → Achievements card → Achievement Gallery (populated from seed data)
/// 3. Scroll through gallery categories showing unlocked/locked badges
/// 4. Back to Insights → Streaks detail card
///
/// Note: In screenshot mode, `createSeededContainer()` seeds 30 days of entries
/// and evaluates achievements, so the gallery is pre-populated with unlocked badges.
@MainActor
final class StreaksAchievementsDemo: FeatureDemoBase {

    func testStreaksAndAchievementsDemo() throws {
        app.launch()
        pause(3)

        // ── Today Tab: streak vitals card ────────────────────────
        // The vitals grid shows the flame icon with current streak
        // and next-milestone hint (e.g. "1 day to 7!")
        // Scroll down to make sure vitals are visible, then back up
        app.swipeUp()
        pause(2)
        app.swipeDown()
        pause(2)

        // ── Insights Tab ─────────────────────────────────────────
        tapTab("Insights")
        pause(3)

        // ── Achievement Gallery ──────────────────────────────────
        let achievementsCard = app.buttons["achievementsCard"]
        scrollUntilVisible(achievementsCard)
        pause(1)

        if achievementsCard.exists && achievementsCard.isHittable {
            achievementsCard.tap()
            pause(3)

            // Gallery: summary header "X / 30 achievements unlocked"
            // Then categories: Streak Milestones, First Steps,
            // Going Deeper, Explorer, Wellness
            app.swipeUp()
            pause(2)
            app.swipeUp()
            pause(2)
            app.swipeUp()
            pause(2)

            // Scroll back to top to show the full summary
            app.swipeDown()
            pause(1)
            app.swipeDown()
            pause(1)
            app.swipeDown()
            pause(2)

            navigateBack()
            pause(1)
        }

        // ── Streaks detail card ──────────────────────────────────
        let streaksCard = app.buttons["streaksCard"]
        scrollUntilVisible(streaksCard)
        pause(1)

        if streaksCard.exists && streaksCard.isHittable {
            streaksCard.tap()
            pause(3)
            navigateBack()
        }

        // Back to Today to close the loop
        tapTab("Today")
        pause(2)
    }

    /// Swipe up repeatedly until the element is hittable (max 5 attempts).
    private func scrollUntilVisible(_ element: XCUIElement, maxAttempts: Int = 5) {
        for _ in 0..<maxAttempts {
            if element.exists && element.isHittable {
                return
            }
            app.swipeUp()
            pause(0.5)
        }
    }
}
