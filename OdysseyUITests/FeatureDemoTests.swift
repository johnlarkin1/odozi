import XCTest

/// UI tests designed to produce demo videos for PR review.
/// Run via: make demo
///
/// These tests walk through the app's key flows at a human-readable pace,
/// producing a smooth video when combined with `xcrun simctl recordVideo`.
@MainActor
final class FeatureDemoTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true  // Keep recording even if an assertion fails
        app.launchEnvironment["SCREENSHOT_MODE"] = "1"
    }

    // MARK: - Full App Walkthrough

    /// Single continuous demo: Today → Guided Prompt → Journal → Insights
    /// This produces one smooth video showing the core experience.
    func testFullAppWalkthrough() throws {
        app.launch()
        pause(2)

        // ── Today Tab ────────────────────────────────────────────
        // Show the greeting and entry status card
        pause(2)

        // ── Start Guided Prompt Flow ─────────────────────────────
        let setSail = app.buttons["Set sail on today's entry"]
        let editEntry = app.buttons["Edit today's entry"]

        if wait(for: setSail) {
            setSail.tap()
        } else if wait(for: editEntry) {
            editEntry.tap()
        }
        pause(2)

        // Step through the guided prompt flow
        walkThroughGuidedPrompt()

        // ── Journal Tab ──────────────────────────────────────────
        tapTab("Journal")
        pause(2)

        // Scroll through entries
        app.swipeUp()
        pause(1)
        app.swipeDown()
        pause(1)

        // ── Insights Tab ─────────────────────────────────────────
        tapTab("Insights")
        pause(3)

        // Scroll to show dashboard cards
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

        // Back to Today to close the loop
        tapTab("Today")
        pause(1)
    }

    // MARK: - Individual Feature Demos

    /// Demo just the guided journaling flow
    func testGuidedPromptDemo() throws {
        app.launch()
        pause(2)

        let setSail = app.buttons["Set sail on today's entry"]
        let editEntry = app.buttons["Edit today's entry"]

        if wait(for: setSail) {
            setSail.tap()
        } else if wait(for: editEntry) {
            editEntry.tap()
        }
        pause(2)

        walkThroughGuidedPrompt()
    }

    /// Demo the insights dashboard
    func testInsightsDashboardDemo() throws {
        app.launch()
        pause(1)

        tapTab("Insights")
        pause(3)

        // Slowly scroll through all insight cards
        for _ in 0..<3 {
            app.swipeUp()
            pause(2)
        }

        // Try to open the map visualization
        let worldTab = app.buttons["World tab"]
        if wait(for: worldTab) {
            worldTab.tap()
            pause(2)
        }

        let mapCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Map'")
        ).firstMatch
        if wait(for: mapCard) {
            mapCard.tap()
            pause(4)  // Map tiles loading
            // Go back
            if app.navigationBars.buttons["Insights"].exists {
                app.navigationBars.buttons["Insights"].tap()
                pause(1)
            }
        }

        // Open word cloud
        let feelingWords = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Feeling'")
        ).firstMatch
        if wait(for: feelingWords) {
            feelingWords.tap()
            pause(3)
        }
    }

    // MARK: - Helpers

    private func walkThroughGuidedPrompt() {
        // The guided prompt has 8 steps. We'll interact with each briefly.
        // Step 1: Mood — tap a mood option
        let moodButtons = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'good' OR label CONTAINS[c] 'great' OR label CONTAINS[c] 'okay'")
        )
        if moodButtons.count > 0 {
            moodButtons.firstMatch.tap()
            pause(1)
        }
        advancePrompt()

        // Steps 2-7: Interact briefly with each, then advance
        for step in 2...7 {
            pause(1.5)
            // Try to type in text fields if present
            let textFields = app.textViews.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
            if let field = textFields.first, field.exists {
                field.tap()
                field.typeText(sampleText(for: step))
                pause(0.5)
            }
            advancePrompt()
        }

        // Step 8: Submit
        pause(1)
        let submitButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'submit' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'save'")
        ).firstMatch
        if wait(for: submitButton) {
            submitButton.tap()
            pause(3)  // Show completion animation
        } else {
            advancePrompt()
            pause(2)
        }

        // Dismiss the completion card if shown
        let dismissButtons = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'close' OR label CONTAINS[c] 'dismiss' OR label CONTAINS[c] 'done'")
        )
        if dismissButtons.count > 0 {
            dismissButtons.firstMatch.tap()
            pause(1)
        }
    }

    private func advancePrompt() {
        // Try common "Next" / "Continue" / "Skip" buttons
        let nextButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'next' OR label CONTAINS[c] 'continue'")
        ).firstMatch

        let skipButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'skip'")
        ).firstMatch

        if nextButton.exists {
            nextButton.tap()
        } else if skipButton.exists {
            skipButton.tap()
        } else {
            // Swipe left as fallback (paged flow)
            app.swipeLeft()
        }
        pause(0.5)
    }

    private func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.exists {
            tab.tap()
        }
    }

    @discardableResult
    private func wait(for element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func sampleText(for step: Int) -> String {
        switch step {
        case 2: return "Peaceful"
        case 3: return "8"  // sleep hours
        case 4: return "Morning coffee with a friend"
        case 5: return "Shipped the new feature"
        case 6: return "Nothing major"
        case 7: return "A really great day overall. Feeling optimistic about the week ahead."
        default: return "2"
        }
    }
}
