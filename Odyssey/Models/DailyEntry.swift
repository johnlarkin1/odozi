import Foundation
import SwiftData

extension Notification.Name {
    static let didSaveFirstEntry = Notification.Name("didSaveFirstEntry")
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

    // Background: Screen Time (optional)
    @Attribute(originalName: "screenTime")
    var screenTimeSeconds: Double?
    var pickups: Int?

    // Photos
    @Attribute(.externalStorage) var attachedPhotoData: [Data]?
    var autoPhotoIdentifiers: [String]?

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
        self.screenTimeSeconds = screenTimeSeconds
        self.pickups = pickups
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastSyncedAt = lastSyncedAt
        self.needsSync = needsSync
    }
}
