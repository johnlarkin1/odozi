@testable import Odyssey
import SwiftData
import UIKit
import XCTest

@MainActor
final class GuidedPromptViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try DataContainer.create(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Initial State

    func testInitialStepIsMood() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStep, .mood)
    }

    func testInitialStateIsNotComplete() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertFalse(vm.isComplete)
        XCTAssertFalse(vm.showingCompletion)
    }

    func testInitialSkippedStepsIsEmpty() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertTrue(vm.skippedSteps.isEmpty)
    }

    // MARK: - Step Navigation

    func testGoToNextAdvancesStep() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStep, .mood)
        vm.goToNext()
        XCTAssertEqual(vm.currentStep, .feeling)
    }

    func testGoToNextSequence() {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.goToNext() // mood -> feeling
        vm.goToNext() // feeling -> sleep
        vm.goToNext() // sleep -> gratitude
        XCTAssertEqual(vm.currentStep, .gratitude)
    }

    func testGoToPreviousFromFirstStepStaysOnFirst() {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.goToPrevious()
        XCTAssertEqual(vm.currentStep, .mood)
    }

    func testGoToPreviousGoesBack() {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.goToNext() // mood -> feeling
        vm.goToNext() // feeling -> sleep
        vm.goToPrevious() // sleep -> feeling
        XCTAssertEqual(vm.currentStep, .feeling)
    }

    func testGoToNextFromLastStepSubmits() {
        let vm = GuidedPromptViewModel(modelContext: context)
        // Navigate to last step (10 steps: mood, feeling, sleep, gratitude, win, tension, journal, photo, drinks, location)
        for _ in 0 ..< 9 {
            vm.goToNext()
        }
        XCTAssertEqual(vm.currentStep, .location)
        vm.goToNext() // Should trigger submit
        XCTAssertTrue(vm.isComplete)
        XCTAssertTrue(vm.showingCompletion)
    }

    // MARK: - Skip

    func testSkipRecordsStepAndAdvances() {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.skip() // Skip mood
        XCTAssertTrue(vm.skippedSteps.contains(.mood))
        XCTAssertEqual(vm.currentStep, .feeling)
    }

    func testSkipMultipleSteps() {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.skip() // mood
        vm.skip() // feeling
        vm.skip() // sleep
        XCTAssertEqual(vm.skippedSteps.count, 3)
        XCTAssertTrue(vm.skippedSteps.contains(.mood))
        XCTAssertTrue(vm.skippedSteps.contains(.feeling))
        XCTAssertTrue(vm.skippedSteps.contains(.sleep))
        XCTAssertEqual(vm.currentStep, .gratitude)
    }

    // MARK: - Computed Properties

    func testCurrentStepIndex() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertEqual(vm.currentStepIndex, 0)
        vm.goToNext()
        XCTAssertEqual(vm.currentStepIndex, 1)
        vm.goToNext()
        XCTAssertEqual(vm.currentStepIndex, 2)
    }

    func testTotalSteps() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertEqual(vm.totalSteps, 10)
    }

    func testProgress() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertEqual(vm.progress, 0.0, accuracy: 0.001) // 0/10
        vm.goToNext()
        XCTAssertEqual(vm.progress, 1.0 / 10.0, accuracy: 0.001) // 1/10
    }

    func testIsFirstStep() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertTrue(vm.isFirstStep)
        vm.goToNext()
        XCTAssertFalse(vm.isFirstStep)
    }

    func testIsLastStep() {
        let vm = GuidedPromptViewModel(modelContext: context)
        XCTAssertFalse(vm.isLastStep)
        for _ in 0 ..< 9 {
            vm.goToNext()
        }
        XCTAssertTrue(vm.isLastStep)
    }

    // MARK: - Submit

    func testSubmitCreatesDailyEntry() throws {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.responses.feeling = 8
        vm.responses.singleWordFeeling = "happy"
        vm.responses.gratitude = "sunshine"
        vm.submit()

        let descriptor = FetchDescriptor<DailyEntry>()
        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.feeling, 8)
        XCTAssertEqual(entries.first?.singleWordFeeling, "happy")
        XCTAssertEqual(entries.first?.gratitude, "sunshine")
    }

    func testSubmitWithPhotoSetsMapThumbnailAndFlag() throws {
        let vm = GuidedPromptViewModel(modelContext: context)
        // Create a valid JPEG for the photo
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let jpegData = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }.jpegData(compressionQuality: 0.8)!

        vm.responses.attachedPhotoData = jpegData
        vm.submit()

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)

        let entry = entries.first!
        XCTAssertNotNil(entry.attachedPhotoData)
        XCTAssertEqual(entry.attachedPhotoData?.count, 1)
        XCTAssertNotNil(entry.mapThumbnailData, "Thumbnail should be generated from valid photo")
        XCTAssertTrue(entry.showOnPhotoMap, "showOnPhotoMap should be true when thumbnail succeeds")
    }

    func testSubmitWithoutPhotoLeavesPhotoFieldsAtDefaults() throws {
        let vm = GuidedPromptViewModel(modelContext: context)
        vm.responses.feeling = 7
        vm.submit()

        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        let entry = entries.first!
        XCTAssertNil(entry.attachedPhotoData)
        XCTAssertNil(entry.mapThumbnailData)
        XCTAssertFalse(entry.showOnPhotoMap)
    }
}
