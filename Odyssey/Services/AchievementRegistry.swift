import Foundation
import SwiftData

struct AchievementDefinition {
    let id: String
    let category: String
    let title: String
    let description: String
    let iconName: String
    let sortOrder: Int
    let tier: Int
    let condition: ([DailyEntry], DailyEntry?) -> Bool
}

enum AchievementConditions {
    static func consecutiveDays(
        in entries: [DailyEntry],
        count target: Int,
        matching predicate: (DailyEntry) -> Bool
    ) -> Bool {
        let sorted = entries.filter(predicate).sorted { $0.date < $1.date }
        let calendar = Calendar.current
        var streak = 0
        var lastDate: Date?
        for entry in sorted {
            let entryDate = calendar.startOfDay(for: entry.date)
            if let last = lastDate {
                let gap = calendar.dateComponents([.day], from: last, to: entryDate).day ?? 0
                if gap == 1 { streak += 1 } else if gap > 1 { streak = 1 }
            } else {
                streak = 1
            }
            if streak >= target { return true }
            lastDate = entryDate
        }
        return false
    }

    static func hasStepMaster(entries: [DailyEntry]) -> Bool {
        entries.contains { ($0.stepCount ?? 0) >= 10_000 }
    }

    static func hasEntryAtHour(entries: [DailyEntry], before hour: Int) -> Bool {
        let calendar = Calendar.current
        return entries.contains { entry in
            guard entry.hasUserSubmitted else { return false }
            return calendar.component(.hour, from: entry.updatedAt) < hour
        }
    }

    static func hasEntryAtHour(entries: [DailyEntry], onOrAfter hour: Int) -> Bool {
        let calendar = Calendar.current
        return entries.contains { entry in
            guard entry.hasUserSubmitted else { return false }
            return calendar.component(.hour, from: entry.updatedAt) >= hour
        }
    }

    static func hasComeback(entries: [DailyEntry], latest: DailyEntry?) -> Bool {
        guard let latest = latest, latest.hasPromptData else { return false }
        let sorted = entries.filter { $0.hasPromptData }
            .sorted { $0.date > $1.date }
        guard sorted.count >= 2 else { return false }
        let calendar = Calendar.current
        let latestDate = calendar.startOfDay(for: latest.date)
        for entry in sorted.dropFirst() {
            let entryDate = calendar.startOfDay(for: entry.date)
            let gap = calendar.dateComponents([.day], from: entryDate, to: latestDate).day ?? 0
            if gap >= 7 { return true }
            break
        }
        return false
    }
}

enum AchievementRegistry {
    static let all: [AchievementDefinition] = streakAchievements
        + firstTimeAchievements
        + depthAchievements
        + explorationAchievements
        + wellnessAchievements

    // MARK: - Streak Milestones

    private static let streakAchievements: [AchievementDefinition] = [
        .init(
            id: "streak_3", category: "streak",
            title: "Spark",
            description: "Three days in a row — a spark is catching",
            iconName: "flame",
            sortOrder: 0, tier: 0,
            condition: { entries, _ in entries.longestStreak >= 3 }
        ),
        .init(
            id: "streak_7", category: "streak",
            title: "Kindling",
            description: "A full week of showing up for yourself",
            iconName: "flame.fill",
            sortOrder: 1, tier: 0,
            condition: { entries, _ in entries.longestStreak >= 7 }
        ),
        .init(
            id: "streak_14", category: "streak",
            title: "Steady Flame",
            description: "Two weeks of consistent reflection",
            iconName: "flame.circle.fill",
            sortOrder: 2, tier: 1,
            condition: { entries, _ in entries.longestStreak >= 14 }
        ),
        .init(
            id: "streak_30", category: "streak",
            title: "Campfire",
            description: "A month of daily journaling — warmth you built",
            iconName: "fireplace",
            sortOrder: 3, tier: 1,
            condition: { entries, _ in entries.longestStreak >= 30 }
        ),
        .init(
            id: "streak_60", category: "streak",
            title: "Bonfire",
            description: "60 days — your practice is burning bright",
            iconName: "flame.fill",
            sortOrder: 4, tier: 1,
            condition: { entries, _ in entries.longestStreak >= 60 }
        ),
        .init(
            id: "streak_90", category: "streak",
            title: "Signal Fire",
            description: "Three months — a beacon others can see",
            iconName: "light.beacon.max",
            sortOrder: 5, tier: 2,
            condition: { entries, _ in entries.longestStreak >= 90 }
        ),
        .init(
            id: "streak_180", category: "streak",
            title: "Eternal Flame",
            description: "Half a year of unbroken reflection",
            iconName: "flame.circle",
            sortOrder: 6, tier: 2,
            condition: { entries, _ in entries.longestStreak >= 180 }
        ),
        .init(
            id: "streak_365", category: "streak",
            title: "Odyssey Complete",
            description: "A full year. What a journey.",
            iconName: "safari.fill",
            sortOrder: 7, tier: 2,
            condition: { entries, _ in entries.longestStreak >= 365 }
        ),
    ]

    // MARK: - First-Time Achievements

    private static let firstTimeAchievements: [AchievementDefinition] = [
        .init(
            id: "first_entry", category: "first",
            title: "First Step",
            description: "Every odyssey begins with a single step",
            iconName: "figure.walk",
            sortOrder: 0, tier: 0,
            condition: { entries, _ in
                entries.contains { $0.hasPromptData }
            }
        ),
        .init(
            id: "first_gratitude", category: "first",
            title: "Grateful Heart",
            description: "You found something to be grateful for",
            iconName: "heart.fill",
            sortOrder: 1, tier: 0,
            condition: { entries, _ in
                entries.contains { !$0.gratitude.isEmpty }
            }
        ),
        .init(
            id: "first_photo", category: "first",
            title: "Picture Worth 1000 Words",
            description: "A moment captured in your journal",
            iconName: "camera.fill",
            sortOrder: 2, tier: 0,
            condition: { entries, _ in
                entries.contains { $0.hasPhotos }
            }
        ),
        .init(
            id: "full_week", category: "first",
            title: "Full Week",
            description: "Your first complete week",
            iconName: "calendar.badge.checkmark",
            sortOrder: 3, tier: 0,
            condition: { entries, _ in
                entries.filter { $0.hasPromptData }.count >= 7
            }
        ),
        .init(
            id: "mood_pioneer", category: "first",
            title: "Mood Pioneer",
            description: "You checked in with yourself",
            iconName: "face.smiling",
            sortOrder: 4, tier: 0,
            condition: { entries, _ in
                entries.contains { $0.feeling > 0 && $0.hasUserSubmitted }
            }
        ),
    ]

    // MARK: - Depth Achievements

    private static let depthAchievements: [AchievementDefinition] = [
        .init(
            id: "deep_dive", category: "depth",
            title: "Deep Dive",
            description: "You went deep today — that takes courage",
            iconName: "text.page.fill",
            sortOrder: 0, tier: 1,
            condition: { entries, _ in
                entries.contains { $0.journalEntry.split(separator: " ").count >= 500 }
            }
        ),
        .init(
            id: "open_book", category: "depth",
            title: "Open Book",
            description: "Every prompt answered — full transparency with yourself",
            iconName: "book.fill",
            sortOrder: 1, tier: 1,
            condition: { entries, _ in
                entries.contains { entry in
                    entry.hasUserSubmitted &&
                    !entry.singleWordFeeling.isEmpty &&
                    !entry.gratitude.isEmpty &&
                    !entry.win.isEmpty &&
                    !entry.tension.isEmpty &&
                    !entry.journalEntry.isEmpty &&
                    entry.sleepQuality > 0 &&
                    entry.feeling > 0
                }
            }
        ),
        .init(
            id: "mood_cartographer", category: "depth",
            title: "Mood Cartographer",
            description: "A full month of emotional mapping",
            iconName: "map.fill",
            sortOrder: 2, tier: 1,
            condition: { entries, _ in entries.longestStreak >= 30 }
        ),
        .init(
            id: "sleep_scholar", category: "depth",
            title: "Sleep Scholar",
            description: "30 days of tracking your rest",
            iconName: "moon.stars.fill",
            sortOrder: 3, tier: 1,
            condition: { entries, _ in
                AchievementConditions.consecutiveDays(in: entries, count: 30) { $0.sleepQuality > 0 && $0.hasUserSubmitted }
            }
        ),
        .init(
            id: "thousand_words", category: "depth",
            title: "Thousand Words",
            description: "A thousand words of self-reflection",
            iconName: "textformat.size.larger",
            sortOrder: 4, tier: 0,
            condition: { entries, _ in entries.totalJournalWordCount >= 1000 }
        ),
        .init(
            id: "novelist", category: "depth",
            title: "Novelist",
            description: "You have written a novel about your life",
            iconName: "books.vertical.fill",
            sortOrder: 5, tier: 1,
            condition: { entries, _ in entries.totalJournalWordCount >= 10_000 }
        ),
        .init(
            id: "war_and_peace", category: "depth",
            title: "War and Peace",
            description: "An epic chronicle of your inner world",
            iconName: "text.book.closed.fill",
            sortOrder: 6, tier: 2,
            condition: { entries, _ in entries.totalJournalWordCount >= 50_000 }
        ),
    ]

    // MARK: - Exploration Achievements

    private static let explorationAchievements: [AchievementDefinition] = [
        .init(
            id: "prompt_sampler", category: "exploration",
            title: "Prompt Sampler",
            description: "You have tried every kind of reflection",
            iconName: "checklist",
            sortOrder: 0, tier: 0,
            condition: { entries, _ in
                let hasMood = entries.contains { $0.feeling > 0 && $0.hasUserSubmitted }
                let hasFeeling = entries.contains { !$0.singleWordFeeling.isEmpty }
                let hasGratitude = entries.contains { !$0.gratitude.isEmpty }
                let hasWin = entries.contains { !$0.win.isEmpty }
                let hasTension = entries.contains { !$0.tension.isEmpty }
                let hasJournal = entries.contains { !$0.journalEntry.isEmpty }
                return hasMood && hasFeeling && hasGratitude && hasWin && hasTension && hasJournal
            }
        ),
        .init(
            id: "journey_mapper", category: "exploration",
            title: "Journey Mapper",
            description: "Your odyssey spans the map",
            iconName: "mappin.and.ellipse",
            sortOrder: 1, tier: 1,
            condition: { entries, _ in entries.uniqueCityCount >= 5 }
        ),
        .init(
            id: "globetrotter", category: "exploration",
            title: "Globetrotter",
            description: "A truly international odyssey",
            iconName: "airplane",
            sortOrder: 2, tier: 2,
            condition: { entries, _ in entries.uniqueCountryCount >= 3 }
        ),
    ]

    // MARK: - Wellness Achievements

    private static let wellnessAchievements: [AchievementDefinition] = [
        .init(
            id: "dry_week", category: "wellness",
            title: "Dry Week",
            description: "A full week without drinks — noted",
            iconName: "drop.degreesign",
            sortOrder: 0, tier: 0,
            condition: { entries, _ in
                AchievementConditions.consecutiveDays(in: entries, count: 7) { $0.hasUserSubmitted && $0.drinks == 0 }
            }
        ),
        .init(
            id: "step_master", category: "wellness",
            title: "Step Master",
            description: "You moved your body today",
            iconName: "figure.run",
            sortOrder: 1, tier: 0,
            condition: { entries, _ in
                AchievementConditions.hasStepMaster(entries: entries)
            }
        ),
        .init(
            id: "early_bird", category: "wellness",
            title: "Early Bird",
            description: "Morning reflection sets the tone",
            iconName: "sunrise.fill",
            sortOrder: 2, tier: 0,
            condition: { entries, _ in
                AchievementConditions.hasEntryAtHour(entries: entries, before: 9)
            }
        ),
        .init(
            id: "night_owl", category: "wellness",
            title: "Night Owl",
            description: "Closing the day with reflection",
            iconName: "moon.fill",
            sortOrder: 3, tier: 0,
            condition: { entries, _ in
                AchievementConditions.hasEntryAtHour(entries: entries, onOrAfter: 22)
            }
        ),
        .init(
            id: "tension_tamer", category: "wellness",
            title: "Tension Tamer",
            description: "Two weeks of naming what weighs on you",
            iconName: "wind",
            sortOrder: 4, tier: 1,
            condition: { entries, _ in
                AchievementConditions.consecutiveDays(in: entries, count: 14) { !$0.tension.isEmpty }
            }
        ),
        .init(
            id: "gratitude_garden", category: "wellness",
            title: "Gratitude Garden",
            description: "A garden of things you appreciate",
            iconName: "leaf.fill",
            sortOrder: 5, tier: 1,
            condition: { entries, _ in entries.uniqueGratitudeCount >= 30 }
        ),
        .init(
            id: "color_spectrum", category: "wellness",
            title: "Color Spectrum",
            description: "Your emotional palette is rich",
            iconName: "paintpalette.fill",
            sortOrder: 6, tier: 1,
            condition: { entries, _ in entries.uniqueFeelingColorCount >= 10 }
        ),
        .init(
            id: "comeback", category: "wellness",
            title: "Comeback",
            description: "You came back — that is what matters",
            iconName: "arrow.uturn.up",
            sortOrder: 7, tier: 1,
            condition: { entries, latest in
                AchievementConditions.hasComeback(entries: entries, latest: latest)
            }
        ),
    ]
}
