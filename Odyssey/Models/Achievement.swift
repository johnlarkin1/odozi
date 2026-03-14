import Foundation
import SwiftData

@Model
final class Achievement {
    var id: String
    var category: String
    var title: String
    var achievementDescription: String
    var iconName: String

    var unlockedDate: Date?
    var isNew: Bool

    var sortOrder: Int
    var tier: Int

    var isUnlocked: Bool { unlockedDate != nil }

    init(
        id: String,
        category: String,
        title: String,
        description: String,
        iconName: String,
        sortOrder: Int = 0,
        tier: Int = 0
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.achievementDescription = description
        self.iconName = iconName
        self.unlockedDate = nil
        self.isNew = false
        self.sortOrder = sortOrder
        self.tier = tier
    }
}
