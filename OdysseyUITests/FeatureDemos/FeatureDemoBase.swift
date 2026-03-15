import XCTest

/// Base class for feature demo UI tests.
///
/// Provides shared helpers for navigating the app, interacting with the guided
/// prompt flow, and pacing interactions for watchable demo videos.
///
/// ## Adding a demo for a new feature
///
/// 1. Create a new file in `FeatureDemos/` — name it `<FeatureName>Demo.swift`.
/// 2. Subclass `FeatureDemoBase` and add one or more `test…Demo` methods.
/// 3. Start with `app.launch()` + `pause(2)` to show the initial state.
/// 4. Walk through the feature at a human-readable pace — add `pause()` calls
///    between interactions so the recorded video is watchable.
/// 5. Use the inherited helpers (`tapTab`, `wait(for:)`, `advancePrompt`, etc.).
/// 6. If the feature needs a journal entry to exist first, call
///    `submitQuickEntry()` to create one before navigating to the feature.
/// 7. Run `/demo` to record and verify the video looks good.
///
/// ## Running demos
///
/// All demos:
///   make demo
///
/// Single demo class:
///   ./scripts/record-demo.sh --tests "OdysseyUITests/StreaksAchievementsDemo"
///
/// Single test method:
///   ./scripts/record-demo.sh --tests "OdysseyUITests/StreaksAchievementsDemo/testStreaksAndAchievementsDemo"
///
@MainActor
class FeatureDemoBase: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true  // Keep recording even if an assertion fails
        app.launchEnvironment["SCREENSHOT_MODE"] = "1"
    }

    // MARK: - Guided Prompt Helpers

    /// Tap "Set sail" or "Edit today's entry" to open the guided prompt flow.
    func startGuidedPrompt() {
        let setSail = app.buttons["Set sail on today's entry"]
        let editEntry = app.buttons["Edit today's entry"]

        if wait(for: setSail) {
            setSail.tap()
        } else if wait(for: editEntry) {
            editEntry.tap()
        }
    }

    /// Walk through all guided prompt steps, filling in sample data.
    /// Ends with the submit action (CompletionCard will appear as fullScreenCover).
    func walkThroughGuidedPrompt() {
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
    }

    /// Submit a quick entry without pausing for video. Useful as setup
    /// when the demo needs existing data but the prompt flow isn't the focus.
    func submitQuickEntry() {
        startGuidedPrompt()
        pause(1)

        // Tap a mood
        let moodButtons = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'good' OR label CONTAINS[c] 'great' OR label CONTAINS[c] 'okay'")
        )
        if moodButtons.count > 0 {
            moodButtons.firstMatch.tap()
        }

        // Skip through all steps
        for _ in 1...7 {
            advancePrompt()
            pause(0.3)
        }

        // Submit
        let submitButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'submit' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'save'")
        ).firstMatch
        if wait(for: submitButton) {
            submitButton.tap()
            pause(1)
        }

        // Dismiss completion
        let doneButton = app.buttons["Done"]
        if wait(for: doneButton) {
            doneButton.tap()
            pause(0.5)
        }
    }

    // MARK: - Navigation Helpers

    func advancePrompt() {
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
            app.swipeLeft()
        }
        pause(0.5)
    }

    func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.exists {
            tab.tap()
        }
    }

    @discardableResult
    func wait(for element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Tap the first back button in the navigation bar.
    func navigateBack() {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            pause(1)
        }
    }

    // MARK: - Sample Data

    func sampleText(for step: Int) -> String {
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
