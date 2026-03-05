import Foundation
import SwiftData

@Model
final class UserPreferences {
    var reminderEnabled: Bool = true
    var reminderTimeOfDay: String = ReminderTimeOfDay.evening.rawValue
    var locationCaptureMode: String = LocationCaptureMode.evening.rawValue
    var locationCaptureHour: Int = 20
    var locationCaptureMinute: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        reminderEnabled: Bool = true,
        reminderTimeOfDay: ReminderTimeOfDay = .evening,
        locationCaptureMode: LocationCaptureMode = .evening,
        locationCaptureHour: Int = 20,
        locationCaptureMinute: Int = 0
    ) {
        self.reminderEnabled = reminderEnabled
        self.reminderTimeOfDay = reminderTimeOfDay.rawValue
        self.locationCaptureMode = locationCaptureMode.rawValue
        self.locationCaptureHour = locationCaptureHour
        self.locationCaptureMinute = locationCaptureMinute
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
