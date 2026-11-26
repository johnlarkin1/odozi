import CoreLocation
import os
import SwiftData
import SwiftUI

private let guidedPromptLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "GuidedPrompt")

@MainActor
@Observable
final class GuidedPromptViewModel {
    var currentStep: PromptStep = .mood
    var responses = PromptResponses()
    var skippedSteps: Set<PromptStep> = []
    var isComplete = false
    var showingCompletion = false
    var newlyUnlockedAchievements: [Achievement] = []
    var isUpdatingLocation = false
    var currentLocationDisplay: String = "No location captured"
    var locationCapturedAt: Date?
    var locationErrorMessage: String?
    var locationPermissionDenied = false
    var isGeneratingInsight = false
    var insight: JournalInsightResult?

    private let modelContext: ModelContext
    let targetDate: Date

    var isPastEntry: Bool {
        !Calendar.current.isDateInToday(targetDate)
    }

    init(modelContext: ModelContext, date: Date = Date()) {
        self.modelContext = modelContext
        targetDate = Calendar.current.startOfDay(for: date)
        loadExistingEntry()
    }

    private func loadExistingEntry() {
        // Pre-fill from any existing entry for this date — including auto-captured
        // entries with only background data. Loading zero/empty values is harmless
        // because the prompt cards treat 0/"" as "not answered", and it lets users
        // who hit "Add journal details" on an auto-captured day pick up anything
        // they'd previously typed.
        // fetch, not fetchOrCreate: merely opening the flow mustn't insert an empty row (it would
        // autosave). submit() creates the entry when there's something to save.
        let repository = DailyEntryRepository(context: modelContext)
        guard let entry = try? repository.fetchEntry(for: targetDate) else { return }

        responses.feeling = entry.feeling
        responses.singleWordFeeling = entry.singleWordFeeling
        responses.feelingColorHex = entry.feelingColorHex
        responses.sleepQuality = entry.sleepQuality
        responses.gratitude = entry.gratitude
        responses.win = entry.win
        responses.tension = entry.tension
        responses.journalEntry = entry.journalEntry
        responses.drinks = entry.drinks
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
              currentIndex + 1 < PromptStep.allCases.count
        else {
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
        // Skipped steps are left alone, so their defaults (e.g. sleepQuality = 5) never
        // become phantom answers.
        let answered = Set(PromptStep.allCases).subtracting(skippedSteps)

        do {
            let result = try EntrySubmitter(context: modelContext)
                .submit(responses, answered: answered, for: targetDate)

            // Capture GPS so the new entry shows up on the map immediately
            // instead of waiting for the next BackgroundSnapshotService run.
            // Non-blocking: a failure here is fine (background task will try
            // again at 8 PM / 2 AM). Only runs for today's entry — past
            // entries should keep whatever location they already have.
            let needsLocation = result.entry.latitude == nil || result.entry.longitude == nil
            if needsLocation, Calendar.current.isDateInToday(targetDate) {
                Task { await updateLocationFromGPS() }
            }

            if !result.unlockedAchievements.isEmpty {
                newlyUnlockedAchievements = result.unlockedAchievements
            }
        } catch {
            guidedPromptLogger.error("Failed to save guided prompt entry: \(error)")
        }

        isComplete = true
        showingCompletion = true

        generateInsight()
    }

    private func generateInsight() {
        guard UserDefaults.standard.bool(forKey: "aiReflectionsEnabled"),
              FoundationModelsAvailability.isAvailable else { return }

        isGeneratingInsight = true
        let responses = self.responses
        Task {
            let result = await JournalInsightService.generateInsight(from: responses)
            self.isGeneratingInsight = false
            if let result {
                self.insight = result
                cacheInsightJSON(result)
            }
        }
    }

    private func cacheInsightJSON(_ result: JournalInsightResult) {
        let repository = DailyEntryRepository(context: modelContext)
        guard let entry = try? repository.fetchOrCreateToday() else { return }
        let dict: [String: String] = [
            "followUpQuestion": result.followUpQuestion,
            "detectedEmotion": result.detectedEmotion,
            "encouragement": result.encouragement,
            "suggestion": result.suggestion
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let json = String(data: data, encoding: .utf8) {
            entry.aiReflectionJSON = json
            try? modelContext.save()
        }
    }

    func loadCurrentLocation() {
        let repository = DailyEntryRepository(context: modelContext)
        guard let entry = try? repository.fetchEntry(for: targetDate) else {
            currentLocationDisplay = "No location captured"
            locationCapturedAt = nil
            return
        }

        if let city = entry.city, let state = entry.state {
            currentLocationDisplay = "\(city), \(state)"
        } else if let city = entry.city {
            currentLocationDisplay = city
        } else {
            currentLocationDisplay = "No location captured"
        }
        locationCapturedAt = entry.locationCapturedAt
    }

    func updateLocationFromGPS() async {
        // One capture at a time: the button, the card's onAppear and submit() can all ask.
        guard !isUpdatingLocation else { return }
        isUpdatingLocation = true
        locationErrorMessage = nil
        defer { isUpdatingLocation = false }

        await performLocationCapture(allowPermissionPrompt: true)
    }

    /// Fires on LocationCard.onAppear for today's entry when no coordinates
    /// are stored yet. Silent on failure — the explicit button handles retries.
    func autoCaptureLocationIfNeeded() async {
        guard !isPastEntry else { return }
        let repository = DailyEntryRepository(context: modelContext)
        let entry = try? repository.fetchEntry(for: targetDate)
        guard entry?.latitude == nil || entry?.longitude == nil else { return }
        await updateLocationFromGPS()
    }

    private func performLocationCapture(allowPermissionPrompt: Bool) async {
        // Current GPS describes today, not a past day being edited.
        guard !isPastEntry else {
            locationErrorMessage = "Location can only be captured for today's entry."
            return
        }

        do {
            let service = LocationCaptureService()
            let snapshot = try await service.captureCurrentLocation()

            // Create the row only once there's something to put in it.
            let repository = DailyEntryRepository(context: modelContext)
            let entry = try repository.fetchOrCreate(for: targetDate)
            entry.latitude = snapshot.latitude
            entry.longitude = snapshot.longitude
            entry.city = snapshot.city
            entry.state = snapshot.state
            entry.country = snapshot.country
            entry.locationCapturedAt = snapshot.timestamp
            entry.updatedAt = Date()

            try modelContext.save()
            locationPermissionDenied = false
            locationErrorMessage = nil
            loadCurrentLocation()
        } catch LocationCaptureError.permissionNotDetermined where allowPermissionPrompt {
            // First tap with undetermined status: ask, wait for the user's actual answer, retry once.
            _ = await LocationAuthorization.shared.requestWhenInUse()
            await performLocationCapture(allowPermissionPrompt: false)
        } catch LocationCaptureError.permissionNotDetermined {
            locationPermissionDenied = false
            locationErrorMessage = "Grant location access to capture where you are."
            loadCurrentLocation()
        } catch LocationCaptureError.permissionDenied {
            locationPermissionDenied = true
            locationErrorMessage = "Location is off for Odozi. Enable it in Settings."
            loadCurrentLocation()
        } catch {
            locationPermissionDenied = false
            locationErrorMessage = "Couldn't get your location. Try again."
            loadCurrentLocation()
            guidedPromptLogger.error("Failed to update location from GPS: \(error)")
        }
    }
}
