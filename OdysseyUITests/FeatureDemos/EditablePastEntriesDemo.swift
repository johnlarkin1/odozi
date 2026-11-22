import XCTest

/// Demo of the editable past entries flow introduced in PR #145.
///
/// Walks the full loop:
///   1. Open a blank past day from the Journal tab → detail view opens in
///      placeholder mode.
///   2. Tap "Start entry" → complete the guided prompt flow.
///   3. Verify the detail view transitions out of placeholder mode and now
///      renders mood/journal content plus the "Journaled" badge.
///
/// The auto-captured-day probe (steps 1-7 in the plan) is attempted first
/// and skipped gracefully if the current seed does not include an auto-only
/// past day. See TODO about proper seeding.
@MainActor
final class EditablePastEntriesDemo: FeatureDemoBase {
    func testEditablePastEntriesDemo() throws {
        app.launch()
        pause(2)

        tapTab("Journal")
        pause(2)

        // Try the auto-captured path first. If no auto-only badge is visible
        // in the current seed, skip ahead to the placeholder path.
        // TODO: Add a dedicated seed mode that guarantees an auto-only past
        // day so this branch exercises the "Add journal details" CTA too.
        let autoBadge = app.staticTexts["Auto-captured"]
        if autoBadge.exists {
            walkAutoCapturedDayIfPresent()
        }

        // Placeholder-mode path: tap a blank past calendar cell.
        tapTab("Journal")
        pause(1)

        let blankDayCell = firstBlankCalendarCell()
        guard let cell = blankDayCell else {
            throw XCTSkip("No blank past calendar cell found in current seed.")
        }
        cell.tap()
        pause(2)

        // Verify placeholder copy is visible.
        let placeholderCopy = app.staticTexts["No data captured for this day"]
        XCTAssertTrue(wait(for: placeholderCopy), "Expected placeholder copy to be visible")

        // Tap the "Start entry" CTA to open the guided flow.
        let startEntry = app.buttons["Start entry"]
        XCTAssertTrue(wait(for: startEntry), "Expected Start entry CTA")
        startEntry.tap()
        pause(2)

        walkThroughGuidedPrompt()
        pause(2)

        // After dismissing the guided flow, the detail view should reload and
        // show the Journaled badge + mood content instead of the placeholder.
        let journaledBadge = app.staticTexts["Journaled"]
        XCTAssertTrue(wait(for: journaledBadge, timeout: 6),
                      "Expected Journaled badge after submitting guided flow")
        XCTAssertFalse(app.staticTexts["No data captured for this day"].exists,
                       "Placeholder copy should no longer be visible")
    }

    // MARK: - Helpers

    /// If an auto-captured day is reachable from the Journal list, open it,
    /// add journal details, and verify both badges show.
    private func walkAutoCapturedDayIfPresent() {
        let autoBadge = app.staticTexts["Auto-captured"]
        guard autoBadge.exists else { return }

        // Find an entries row that has no Journaled badge yet. Cheap heuristic:
        // the entries list only shows rows with prompt data, so we need to go
        // through the calendar. For now just skip this branch if we can't find
        // a tappable empty-journaled day quickly.
        // TODO: replace with a dedicated seed once we have one.
        let addDetailsCTA = app.buttons["Add journal details"]
        if wait(for: addDetailsCTA, timeout: 2) {
            addDetailsCTA.tap()
            pause(2)
            walkThroughGuidedPrompt()
            pause(2)

            let journaledBadge = app.staticTexts["Journaled"]
            XCTAssertTrue(wait(for: journaledBadge, timeout: 6),
                          "Expected Journaled badge after guided flow on auto day")
            XCTAssertTrue(app.staticTexts["Auto-captured"].exists,
                          "Auto-captured badge should still be visible")
        }
    }

    /// Return the first calendar day cell that looks like a blank past day.
    /// Uses a label prefix match on the calendar's accessibility identifiers.
    private func firstBlankCalendarCell() -> XCUIElement? {
        // SCREENSHOT_MODE seeds an entry for each of the last 30 days, so the
        // current month's past days are usually all filled — the old "first
        // hittable day" probe opened a day *with* data and never saw the
        // placeholder. Two months back is always older than the seed window,
        // so every past day there is blank, whatever today's date is.
        let previousMonth = app.buttons["calendar.previousMonth"]
        guard wait(for: previousMonth) else { return nil }
        previousMonth.tap()
        previousMonth.tap()
        pause(1)

        // The calendar cells render their accessibility label as the day
        // number; empty-day cells navigate to EmptyDayDate. Pick the first
        // hittable one.
        let dayButtons = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-9]{1,2}$")
        )
        for i in 0 ..< min(dayButtons.count, 20) {
            let button = dayButtons.element(boundBy: i)
            if button.exists && button.isHittable {
                return button
            }
        }
        return nil
    }
}
