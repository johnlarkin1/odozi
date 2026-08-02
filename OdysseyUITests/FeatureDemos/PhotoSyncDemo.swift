import XCTest

/// Feature demo for the photo sync flow: opening the sync sheet from Profile,
/// picking a date range, and running a sync that links photos to days and
/// backfills locations from photo metadata.
@MainActor
final class PhotoSyncDemo: FeatureDemoBase {
    func testPhotoSyncDemo() {
        app.launch()
        pause(2)

        // Navigate to the Profile tab
        tapTab("Profile")
        pause(1.5)

        // Scroll down to reveal the Photos section
        let syncButton = app.buttons["Sync Photos"]
        var attempts = 0
        while !syncButton.exists, attempts < 6 {
            app.swipeUp()
            pause(0.5)
            attempts += 1
        }

        guard wait(for: syncButton) else {
            XCTFail("Could not find the Sync Photos button in Profile")
            return
        }
        pause(1)

        // Open the sync sheet
        syncButton.tap()
        pause(2)

        // Show the date range pickers, then start the sync
        let syncActionButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sync Photos' OR label CONTAINS[c] 'Syncing'")
        ).firstMatch
        if wait(for: syncActionButton) {
            syncActionButton.tap()
            pause(3) // Allow the sync + result summary to render
        }

        // Dismiss the sheet
        let doneButton = app.buttons["Done"]
        if wait(for: doneButton) {
            doneButton.tap()
            pause(1)
        }
    }
}
