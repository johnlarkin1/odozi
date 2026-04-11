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
        let repository = DailyEntryRepository(context: modelContext)
        guard let entry = try? repository.fetchOrCreate(for: targetDate),
              entry.hasUserSubmitted else { return }

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
        let repository = DailyEntryRepository(context: modelContext)

        do {
            let entry = try repository.fetchOrCreate(for: targetDate)

            // Only write fields for steps the user didn't skip — prevents phantom
            // defaults (e.g., sleepQuality=5) for steps the user explicitly skipped.
            if !skippedSteps.contains(.mood) {
                entry.feeling = responses.feeling
            }
            if !skippedSteps.contains(.feeling) {
                entry.singleWordFeeling = responses.singleWordFeeling
                entry.feelingColorHex = responses.feelingColorHex
            }
            if !skippedSteps.contains(.sleep) {
                entry.sleepQuality = responses.sleepQuality
            }
            if !skippedSteps.contains(.gratitude) {
                entry.gratitude = responses.gratitude
            }
            if !skippedSteps.contains(.win) {
                entry.win = responses.win
            }
            if !skippedSteps.contains(.tension) {
                entry.tension = responses.tension
            }
            if !skippedSteps.contains(.journal) {
                entry.journalEntry = responses.journalEntry
            }
            if !skippedSteps.contains(.drinks) {
                entry.drinks = responses.drinks
            }

            if let photoData = responses.attachedPhotoData {
                var existing = entry.attachedPhotoData ?? []
                existing.append(photoData)
                entry.attachedPhotoData = existing
                if let thumbnail = PhotoLibraryService.generateMapThumbnail(from: photoData) {
                    entry.mapThumbnailData = thumbnail
                    entry.showOnPhotoMap = true
                } else {
                    guidedPromptLogger.error("Failed to generate map thumbnail from attached photo (\(photoData.count) bytes)")
                }
            }

            // Only mark as submitted if the user actually provided content.
            // hasPromptData checks text fields (journal/gratitude/win/tension/singleWordFeeling)
            // which are the signal for "user entered something meaningful."
            if entry.hasPromptData {
                entry.hasUserSubmitted = true
                if entry.firstSubmittedAt == nil {
                    entry.firstSubmittedAt = Date()
                }
            }
            entry.updatedAt = Date()

            try modelContext.save()
            NotificationCenter.default.post(name: .didSaveFirstEntry, object: nil)

            let achievementService = AchievementService(modelContext: modelContext)
            let allEntries = (try? modelContext.fetch(FetchDescriptor<DailyEntry>())) ?? []
            let unlocked = achievementService.evaluateAll(entries: allEntries, latestEntry: entry)
            if !unlocked.isEmpty {
                newlyUnlockedAchievements = unlocked
            }
        } catch {
            guidedPromptLogger.error("Failed to save guided prompt entry: \(error)")
        }

        isComplete = true
        showingCompletion = true
    }

    func loadCurrentLocation() {
        let repository = DailyEntryRepository(context: modelContext)
        guard let entry = try? repository.fetchOrCreate(for: targetDate) else { return }

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
        isUpdatingLocation = true
        defer { isUpdatingLocation = false }

        do {
            let repository = DailyEntryRepository(context: modelContext)
            let entry = try repository.fetchOrCreate(for: targetDate)

            let service = LocationCaptureService()
            let snapshot = try await service.captureCurrentLocation()

            entry.latitude = snapshot.latitude
            entry.longitude = snapshot.longitude
            entry.city = snapshot.city
            entry.state = snapshot.state
            entry.country = snapshot.country
            entry.locationCapturedAt = Date()
            entry.updatedAt = Date()

            try modelContext.save()
            loadCurrentLocation()
        } catch {
            guidedPromptLogger.error("Failed to update location from GPS: \(error)")
        }
    }
}
