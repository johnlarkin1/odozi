import XCTest

/// Demo of the guided journaling flow (mood → feeling → sleep → … → submit).
@MainActor
final class GuidedPromptDemo: FeatureDemoBase {
    func testGuidedPromptDemo() throws {
        app.launch()
        pause(2)

        startGuidedPrompt()
        pause(2)

        walkThroughGuidedPrompt()
    }
}
