import XCTest

/// Demo of the Insights dashboard: sparkline cards, map, word cloud.
@MainActor
final class InsightsDashboardDemo: FeatureDemoBase {
    func testInsightsDashboardDemo() throws {
        app.launch()
        pause(1)

        tapTab("Insights")
        pause(3)

        // Slowly scroll through all insight cards
        for _ in 0 ..< 3 {
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
            pause(4) // Map tiles loading
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
}
