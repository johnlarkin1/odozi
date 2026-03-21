import Foundation
import SwiftData

@Model
final class UserPreferences {
    var reminderEnabled: Bool = true
    var reminderTimeOfDay: String = ReminderTimeOfDay.evening.rawValue
    var reminderCustomHour: Int = 20
    var reminderCustomMinute: Int = 0
    var locationCaptureMode: String = LocationCaptureMode.evening.rawValue
    var locationCaptureHour: Int = 20
    var locationCaptureMinute: Int = 0
    var weeklyDigestEnabled: Bool = false
    var weeklyDigestWeekday: Int = 1
    var weeklyDigestHour: Int = 18
    var weeklyDigestMinute: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        reminderEnabled: Bool = true,
        reminderTimeOfDay: ReminderTimeOfDay = .evening,
        reminderCustomHour: Int = 20,
        reminderCustomMinute: Int = 0,
        locationCaptureMode: LocationCaptureMode = .evening,
        locationCaptureHour: Int = 20,
        locationCaptureMinute: Int = 0
    ) {
        self.reminderEnabled = reminderEnabled
        self.reminderTimeOfDay = reminderTimeOfDay.rawValue
        self.reminderCustomHour = reminderCustomHour
        self.reminderCustomMinute = reminderCustomMinute
        self.locationCaptureMode = locationCaptureMode.rawValue
        self.locationCaptureHour = locationCaptureHour
        self.locationCaptureMinute = locationCaptureMinute
        createdAt = Date()
        updatedAt = Date()
    }
}
