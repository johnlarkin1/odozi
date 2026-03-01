import SwiftUI
import SwiftData
import os

private let guidedPromptLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "GuidedPrompt")

@MainActor
@Observable
final class GuidedPromptViewModel {
    var currentStep: PromptStep = .mood
    var responses = PromptResponses()
    var skippedSteps: Set<PromptStep> = []
    var isComplete = false
    var showingCompletion = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var currentStepIndex: Int {
        PromptStep.allCases.firstIndex(of: currentStep) ?? 0
    }

    var totalSteps: Int {
        PromptStep.allCases.count
    }

    var progress: Double {
        Double(currentStepIndex) / Double(totalSteps)
    }

    var isFirstStep: Bool {
        currentStep == PromptStep.allCases.first
    }

    var isLastStep: Bool {
        currentStep == PromptStep.allCases.last
    }

    func goToNext() {
        guard let currentIndex = PromptStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < PromptStep.allCases.count else {
            submit()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = PromptStep.allCases[currentIndex + 1]
        }
    }

    func goToPrevious() {
        guard let currentIndex = PromptStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = PromptStep.allCases[currentIndex - 1]
        }
    }

    func skip() {
        skippedSteps.insert(currentStep)
        goToNext()
    }

    func submit() {
        let repository = DailyEntryRepository(context: modelContext)

        do {
            let entry = try repository.fetchOrCreateToday()

            entry.feeling = responses.feeling
            entry.singleWordFeeling = responses.singleWordFeeling
            entry.feelingColorHex = responses.feelingColorHex
            entry.sleepQuality = responses.sleepQuality
            entry.gratitude = responses.gratitude
            entry.win = responses.win
            entry.tension = responses.tension
            entry.journalEntry = responses.journalEntry
            entry.drinks = responses.drinks
            entry.updatedAt = Date()
            entry.needsSync = true

            try modelContext.save()
            NotificationCenter.default.post(name: .didSaveFirstEntry, object: nil)
        } catch {
            guidedPromptLogger.error("Failed to save guided prompt entry: \(error)")
        }

        isComplete = true
        showingCompletion = true
    }
}
