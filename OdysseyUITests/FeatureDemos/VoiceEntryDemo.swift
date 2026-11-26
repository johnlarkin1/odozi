import XCTest

/// Voice journaling: talk through your day, and Odozi fills in the answers and saves them.
/// The simulator has no real speech, so the app "hears" a scripted note (VOICE_DEMO_NOTE).
final class VoiceEntryDemo: FeatureDemoBase {
    func testVoiceEntryDemo() {
        app.launchEnvironment["VOICE_DEMO_NOTE"] = "1"
        app.launch()
        pause(2)

        let voiceButton = app.buttons["voiceEntryButton"]
        XCTAssertTrue(wait(for: voiceButton, timeout: 10), "Talk through your day button should be on Today")
        voiceButton.tap()
        pause(1.5)

        let record = app.buttons["voiceRecordButton"]
        XCTAssertTrue(wait(for: record))
        record.tap()

        // Let the live transcript stream in.
        pause(9)

        let stop = app.buttons["voiceStopButton"]
        XCTAssertTrue(wait(for: stop))
        stop.tap()

        let title = app.staticTexts["voiceResultsTitle"]
        XCTAssertTrue(wait(for: title, timeout: 15), "Results should show after processing")
        pause(2)

        app.swipeUp()
        pause(2)
        app.swipeDown()
        pause(1)

        app.buttons["voiceDoneButton"].tap()
        pause(2)
    }
}
