import XCTest

@MainActor
final class AppStoreScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment["SCREENSHOT_MODE"] = "1"
        setupSnapshot(app)
    }

    // MARK: - Helpers

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // MARK: - 1. Today Tab

    func testScreenshot01_TodayTab() throws {
        app.launch()
        sleep(2)
        snapshot("01_TodayTab")
    }

    // MARK: - 2. Guided Journaling (Mood Selection)

    func testScreenshot02_GuidedJournaling() throws {
        app.launch()
        sleep(1)

        let setSail = app.buttons["Set sail on today's entry"]
        let editEntry = app.buttons["Edit today's entry"]

        if waitForElement(setSail) {
            setSail.tap()
        } else if waitForElement(editEntry) {
            editEntry.tap()
        }

        sleep(2)
        snapshot("02_GuidedJournaling")
    }

    // MARK: - 3. Insights Dashboard

    func testScreenshot03_InsightsDashboard() throws {
        app.launch()
        sleep(1)

        app.tabBars.buttons["Insights"].tap()
        sleep(2)
        snapshot("03_InsightsDashboard")
    }

    // MARK: - 4. Map Visualization

    func testScreenshot04_MapVisualization() throws {
        app.launch()
        sleep(1)

        app.tabBars.buttons["Insights"].tap()
        sleep(1)

        let worldTab = app.buttons["World tab"]
        if waitForElement(worldTab) {
            worldTab.tap()
            sleep(1)
        }

        let mapCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Map'")).firstMatch
        if waitForElement(mapCard) {
            mapCard.tap()
            sleep(4) // Extra time for map tiles to load
        }

        snapshot("04_MapVisualization")
    }

    // MARK: - 5. Word Cloud

    func testScreenshot05_WordCloud() throws {
        app.launch()
        sleep(1)

        app.tabBars.buttons["Insights"].tap()
        sleep(1)

        let feelingWords = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Feeling'")).firstMatch
        if waitForElement(feelingWords) {
            feelingWords.tap()
            sleep(2)
        }

        snapshot("05_WordCloud")
    }

    // MARK: - 6. Year in Review Title Card

    func testScreenshot06_YearInReview() throws {
        app.launch()
        sleep(1)

        app.tabBars.buttons["Insights"].tap()
        sleep(1)

        // Scroll to Journey Explorer and tap
        let journeyExplorer = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Journey Explorer'")).firstMatch
        if !waitForElement(journeyExplorer, timeout: 3) {
            app.swipeUp()
            sleep(1)
        }
        if waitForElement(journeyExplorer) {
            journeyExplorer.tap()
            sleep(1)
        }

        // Tap sparkles toolbar button to open Year in Review
        let navBarButtons = app.navigationBars.buttons
        // The sparkles button is the trailing toolbar item
        for i in 0..<navBarButtons.count {
            let btn = navBarButtons.element(boundBy: i)
            if btn.label != "Insights" && btn.label != "Back" {
                btn.tap()
                break
            }
        }
        sleep(3) // Let the Lottie globe animation load

        snapshot("06_YearInReview")
    }
}
