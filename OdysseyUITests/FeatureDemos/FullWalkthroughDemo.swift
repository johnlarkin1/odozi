import XCTest

/// End-to-end walkthrough of the entire app: Today → Guided Prompt → Journal → Insights → Profile.
@MainActor
final class FullWalkthroughDemo: FeatureDemoBase {

    func testFullAppWalkthrough() throws {
        app.launch()
        pause(2)

        // ── Today Tab ────────────────────────────────────────────
        pause(2)

        // ── Start Guided Prompt Flow ─────────────────────────────
        startGuidedPrompt()
        pause(2)
        walkThroughGuidedPrompt()

        // ── Journal Tab ──────────────────────────────────────────
        tapTab("Journal")
        pause(2)

        app.swipeUp()
        pause(1)
        app.swipeDown()
        pause(1)

        // ── Insights Tab ─────────────────────────────────────────
        tapTab("Insights")
        pause(3)

        app.swipeUp()
        pause(2)
        app.swipeUp()
        pause(2)
        app.swipeDown()
        pause(1)
        app.swipeDown()
        pause(1)

        // ── Profile Tab ──────────────────────────────────────────
        tapTab("Profile")
        pause(2)

        tapTab("Today")
        pause(1)
    }
}
