import Foundation
import SwiftData

@Model
final class Achievement {
    var id: String = ""
    var category: String = ""
    var title: String = ""
    var achievementDescription: String = ""
    var iconName: String = ""

    var unlockedDate: Date?
    var isNew: Bool = false

    var sortOrder: Int = 0
    var tier: Int = 0

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
        achievementDescription = description
        self.iconName = iconName
        unlockedDate = nil
        isNew = false
        self.sortOrder = sortOrder
        self.tier = tier
    }
}
