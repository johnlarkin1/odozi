import Foundation
import SwiftData

@Model
final class UserPreferences {
    var reminderEnabled: Bool = true
    var reminderTimeOfDay: String = ReminderTimeOfDay.evening.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(reminderEnabled: Bool = true, reminderTimeOfDay: ReminderTimeOfDay = .evening) {
        self.reminderEnabled = reminderEnabled
        self.reminderTimeOfDay = reminderTimeOfDay.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
