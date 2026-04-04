import Foundation
import SwiftData

extension Notification.Name {
    static let didSaveFirstEntry = Notification.Name("didSaveFirstEntry")
    static let screenTimeDidUpdate = Notification.Name("screenTimeDidUpdate")
    static let snapshotDidUpdate = Notification.Name("snapshotDidUpdate")
    static let openGuidedPrompt = Notification.Name("openGuidedPrompt")
}

struct WorkoutSummary: Codable, Sendable, Identifiable {
    // Stable ID derived from content — survives re-capture without causing SwiftUI remounts
    var id: String { "\(activityType)-\(startDate.timeIntervalSince1970)" }

    let activityType: UInt            // HKWorkoutActivityType.rawValue
    let activityName: String          // Human-readable name (e.g., "Running")
    let durationSeconds: Double
    let totalCalories: Double?        // kcal
    let totalDistanceMeters: Double?
    let averageHeartRate: Double?     // bpm during workout
    let startDate: Date
    let endDate: Date

    enum CodingKeys: String, CodingKey {
        case activityType, activityName, durationSeconds, totalCalories
        case totalDistanceMeters, averageHeartRate, startDate, endDate
    }
}

@Model
final class DailyEntry {
    // Note: #Unique requires iOS 18+. Uniqueness on `date` is enforced in application code
    // via fetch-before-insert in DailyEntryViewModel.submitData and applySnapshotData.

    // Identity
    var date: Date

    // Guided prompts (non-optional, defaults provided)
    var feeling: Int
    var singleWordFeeling: String
    @Attribute(originalName: "feelingColor")
    var feelingColorHex: String
    var sleepQuality: Int
    var gratitude: String
    var win: String
    var tension: String
    var journalEntry: String
    var drinks: Int

    // Background: Location (optional)
    var latitude: Double?
    var longitude: Double?
    var city: String?
    var state: String?
    var country: String?
    var locationCapturedAt: Date?

    // Background: HealthKit (optional)
    var stepCount: Int?
    var walkingDistanceMeters: Double?
    var sleepHours: Double?
    var sleepREMHours: Double?
    var sleepDeepHours: Double?
    var sleepCoreHours: Double?
    var sleepAwakeMinutes: Double?
    var sleepOnset: Date?
    var sleepInterruptionCount: Int?
    var sleepScore: Int?

    // Background: Workouts & Heart Rate (optional)
    var workoutDataJSON: Data?
    var workoutCount: Int?
    var totalWorkoutMinutes: Double?
    var workoutIntensityScore: Int?
    var restingHeartRate: Double?
    var averageHeartRate: Double?

    // Background: Screen Time (optional)
    @Attribute(originalName: "screenTime")
    var screenTimeSeconds: Double?
    var pickups: Int?

    // Photos
    @Attribute(.externalStorage) var attachedPhotoData: [Data]?
    var autoPhotoIdentifiers: [String]?
    var showOnPhotoMap: Bool = false
    @Attribute(.externalStorage) var mapThumbnailData: Data?

    // User submission flag
    var hasUserSubmitted: Bool = false
    var firstSubmittedAt: Date?

    // Metadata
    var createdAt: Date
    var updatedAt: Date

    // Sync metadata (lightweight migration-safe: optional + default)
    var lastSyncedAt: Date?
    var needsSync: Bool = false

    init(
        date: Date = Calendar.current.startOfDay(for: Date()),
        feeling: Int = 5,
        singleWordFeeling: String = "",
        feelingColorHex: String = "#FFFFFF",
        sleepQuality: Int = 5,
        gratitude: String = "",
        win: String = "",
        tension: String = "",
        journalEntry: String = "",
        drinks: Int = 0,
        latitude: Double? = nil,
        longitude: Double? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        stepCount: Int? = nil,
        walkingDistanceMeters: Double? = nil,
        sleepHours: Double? = nil,
        sleepREMHours: Double? = nil,
        sleepDeepHours: Double? = nil,
        sleepCoreHours: Double? = nil,
        sleepAwakeMinutes: Double? = nil,
        sleepOnset: Date? = nil,
        sleepInterruptionCount: Int? = nil,
        sleepScore: Int? = nil,
        workoutDataJSON: Data? = nil,
        workoutCount: Int? = nil,
        totalWorkoutMinutes: Double? = nil,
        workoutIntensityScore: Int? = nil,
        restingHeartRate: Double? = nil,
        averageHeartRate: Double? = nil,
        screenTimeSeconds: Double? = nil,
        pickups: Int? = nil,
        lastSyncedAt: Date? = nil,
        needsSync: Bool = false
    ) {
        self.date = date
        self.feeling = feeling
        self.singleWordFeeling = singleWordFeeling
        self.feelingColorHex = feelingColorHex
        self.sleepQuality = sleepQuality
        self.gratitude = gratitude
        self.win = win
        self.tension = tension
        self.journalEntry = journalEntry
        self.drinks = drinks
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.state = state
        self.country = country
        self.stepCount = stepCount
        self.walkingDistanceMeters = walkingDistanceMeters
        self.sleepHours = sleepHours
        self.sleepREMHours = sleepREMHours
        self.sleepDeepHours = sleepDeepHours
        self.sleepCoreHours = sleepCoreHours
        self.sleepAwakeMinutes = sleepAwakeMinutes
        self.sleepOnset = sleepOnset
        self.sleepInterruptionCount = sleepInterruptionCount
        self.sleepScore = sleepScore
        self.workoutDataJSON = workoutDataJSON
        self.workoutCount = workoutCount
        self.totalWorkoutMinutes = totalWorkoutMinutes
        self.workoutIntensityScore = workoutIntensityScore
        self.restingHeartRate = restingHeartRate
        self.averageHeartRate = averageHeartRate
        self.screenTimeSeconds = screenTimeSeconds
        self.pickups = pickups
        createdAt = Date()
        updatedAt = Date()
        self.lastSyncedAt = lastSyncedAt
        self.needsSync = needsSync
    }
}
