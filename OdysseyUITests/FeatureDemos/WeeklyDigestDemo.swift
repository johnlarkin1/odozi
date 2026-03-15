import XCTest

/// Demo of the Weekly Digest settings: toggle, day picker, time picker.
@MainActor
final class WeeklyDigestDemo: FeatureDemoBase {

    func testWeeklyDigestSettingsDemo() throws {
        app.launch()
        pause(2)

        // Navigate to Profile tab
        tapTab("Profile")
        pause(2)

        // Tap into Weekly Digest settings
        let digestRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Weekly Digest'")
        ).firstMatch
        if wait(for: digestRow) {
            digestRow.tap()
            pause(2)
        }

        // Toggle Weekly Digest on
        let toggle = app.switches["Weekly Digest"]
        if wait(for: toggle) {
            toggle.tap()
            pause(2)
        }

        // Select a different day (e.g., Friday = row 5)
        let friday = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Friday'")
        ).firstMatch
        if wait(for: friday) {
            friday.tap()
            pause(1.5)
        }

        // Scroll down to show the time picker
        app.swipeUp()
        pause(2)

        // Navigate back to Profile to show the updated status text
        navigateBack()
        pause(2)
    }
}
