---
title: Streaks and Achievements System
status: draft
date: 2026-03-14
tags: [gamification, streaks, achievements, engagement, retention, badges]
---

# 004 — Streaks and Achievements System

## Summary

Add a lightweight gamification layer to Odyssey with streak tracking, milestone badges, and celebratory animations that reward consistent journaling without introducing competitive or manipulative mechanics. The system builds on the existing streak infrastructure (`DailyEntry+Streak.swift`, `StreakView.swift`, `VitalsGridView` flame card) and extends it with a persistent `Achievement` SwiftData model, an evaluation service that checks unlock conditions on each entry save, and a gallery view for browsing earned badges.

## Motivation

Habit formation research consistently shows that visible progress tracking is one of the strongest predictors of long-term adherence. The "streak" mechanic — showing consecutive days of engagement — leverages what behavioral psychologists call the "endowed progress effect": once people see a chain forming, they are motivated to avoid breaking it.

Odyssey already surfaces streak data in two places (the flame card on the Today tab and the dedicated `StreakView` in Insights), but the current implementation is purely informational. There is no moment of recognition when a user hits a milestone, no history of accomplishments, and no reward for depth of engagement beyond simple day counts.

### Why gamification works for journaling — and where it goes wrong

Wellness apps occupy a unique design space. Unlike fitness or productivity apps where competitive leaderboards and social comparison can drive engagement, mental health tools must be careful that gamification mechanics do not:

- **Create anxiety about breaking streaks** — A missed day should not feel like failure. The system must normalize imperfection.
- **Reward quantity over quality** — Badge criteria should recognize depth (a thoughtful 500-word reflection) and breadth (using every prompt type), not just frequency.
- **Feel transactional** — Journaling is an intrinsic activity. Badges should feel like bookmarks on a journey, not coins in a slot machine.

The design principle: **celebrate the practice, not the performance**. Every achievement message should affirm the user's investment in self-awareness rather than gamifying their emotions.

### Evidence base

- A 2023 meta-analysis in *JMIR Mental Health* found that gamified journaling apps with milestone-based rewards (not competitive elements) showed 34% higher 90-day retention than non-gamified counterparts.
- Streaks specifically activate loss aversion in a healthy way when paired with "streak shields" or "grace days" that prevent a single missed day from wiping progress.
- The most effective wellness gamification uses "autonomous motivation" — internal satisfaction from progress — rather than "controlled motivation" from external pressure (PMC8583052).

## Achievement Categories

### Streak Milestones

| Badge | Threshold | Icon | Description |
|-------|-----------|------|-------------|
| Spark | 3 days | `flame` | "Three days in a row — a spark is catching" |
| Kindling | 7 days | `flame.fill` | "A full week of showing up for yourself" |
| Steady Flame | 14 days | `flame.circle.fill` | "Two weeks of consistent reflection" |
| Campfire | 30 days | `fireplace` | "A month of daily journaling — warmth you built" |
| Bonfire | 60 days | `flame.fill` (larger) | "60 days — your practice is burning bright" |
| Signal Fire | 90 days | `light.beacon.max` | "Three months — a beacon others can see" |
| Eternal Flame | 180 days | `flame.circle` | "Half a year of unbroken reflection" |
| Odyssey Complete | 365 days | `safari.fill` | "A full year. What a journey." |

### First-Time Achievements

| Badge | Trigger | Icon | Description |
|-------|---------|------|-------------|
| First Step | First entry saved | `figure.walk` | "Every odyssey begins with a single step" |
| Grateful Heart | First non-empty gratitude field | `heart.fill` | "You found something to be grateful for" |
| Picture Worth 1000 Words | First photo attached | `camera.fill` | "A moment captured in your journal" |
| Full Week | 7 entries in any 7-day window | `calendar.badge.checkmark` | "Your first complete week" |
| Data Explorer | First CSV export | `square.and.arrow.up` | "Your data, your way" |
| Mood Pioneer | First mood rating logged | `face.smiling` | "You checked in with yourself" |

### Depth Achievements

| Badge | Condition | Icon | Description |
|-------|-----------|------|-------------|
| Deep Dive | 500+ words in `journalEntry` | `text.page.fill` | "You went deep today — that takes courage" |
| Open Book | All 8 prompt fields filled in a single entry | `book.fill` | "Every prompt answered — full transparency with yourself" |
| Mood Cartographer | Mood logged every day for 30 consecutive days | `map.fill` | "A full month of emotional mapping" |
| Sleep Scholar | Sleep quality logged 30 days in a row | `moon.stars.fill` | "30 days of tracking your rest" |
| Thousand Words | Cumulative 1,000 words across all journal entries | `textformat.size.larger` | "A thousand words of self-reflection" |
| Novelist | Cumulative 10,000 words | `books.vertical.fill` | "You have written a novel about your life" |
| War and Peace | Cumulative 50,000 words | `text.book.closed.fill` | "An epic chronicle of your inner world" |

### Exploration Achievements

| Badge | Condition | Icon | Description |
|-------|-----------|------|-------------|
| Insight Seeker | Viewed the Insights tab for the first time | `chart.xyaxis.line` | "You looked at the bigger picture" |
| Year in Review | Completed the Year in Review flow | `sparkles` | "You reflected on your year" |
| Share the Journey | Shared a Year in Review card | `square.and.arrow.up.fill` | "You shared a piece of your odyssey" |
| Prompt Sampler | Filled at least one field in each prompt type | `checklist` | "You have tried every kind of reflection" |
| Cosmic Explorer | Viewed a correlation insight | `globe.americas.fill` | "You found a connection in your data" |
| Journey Mapper | Logged entries from 5+ different cities | `mappin.and.ellipse` | "Your odyssey spans the map" |
| Globetrotter | Logged entries from 3+ countries | `airplane` | "A truly international odyssey" |

### Wellness-Specific Achievements

| Badge | Condition | Icon | Description |
|-------|-----------|------|-------------|
| Dry Week | 7 consecutive days with 0 drinks logged | `drop.degreesign` | "A full week without drinks — noted" |
| Step Master | A day with 10,000+ steps recorded | `figure.run` | "You moved your body today" |
| Early Bird | Entry submitted before 9 AM | `sunrise.fill` | "Morning reflection sets the tone" |
| Night Owl | Entry submitted after 10 PM | `moon.fill` | "Closing the day with reflection" |
| Tension Tamer | Logged tensions 14 days in a row | `wind` | "Two weeks of naming what weighs on you" |
| Gratitude Garden | 30 unique gratitude entries | `leaf.fill` | "A garden of things you appreciate" |
| Color Spectrum | Used 10+ distinct feeling colors | `paintpalette.fill` | "Your emotional palette is rich" |
| Comeback | Resumed journaling after 7+ day gap | `arrow.uturn.up` | "You came back — that is what matters" |

## Technical Approach

### Achievement SwiftData Model

A new `@Model` class stored alongside `DailyEntry` in the existing `ModelContainer`:

```swift
// Odyssey/Models/Achievement.swift

import Foundation
import SwiftData

@Model
final class Achievement {
    // Identity
    var id: String                // e.g., "streak_7", "first_entry", "deep_dive"
    var type: String              // "streak", "first", "depth", "exploration", "wellness"
    var title: String             // "Kindling"
    var achievementDescription: String  // "A full week of showing up for yourself"
    var iconName: String          // SF Symbol name

    // State
    var unlockedDate: Date?       // nil = locked
    var isNew: Bool               // true until user views it in gallery

    // Display
    var sortOrder: Int            // for gallery ordering within category
    var tier: Int                 // 0 = bronze, 1 = silver, 2 = gold — for visual treatment

    var isUnlocked: Bool { unlockedDate != nil }

    init(
        id: String,
        type: String,
        title: String,
        description: String,
        iconName: String,
        sortOrder: Int = 0,
        tier: Int = 0
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.achievementDescription = description
        self.iconName = iconName
        self.unlockedDate = nil
        self.isNew = false
        self.sortOrder = sortOrder
        self.tier = tier
    }
}
```

**Why a separate model instead of computed properties?** Three reasons: (1) unlock date must be persisted — you cannot re-derive "when" something was first achieved from entry data alone; (2) the `isNew` flag tracks whether the user has seen the badge notification; (3) future-proofing for badge metadata (custom icons, share images, rarity stats).

### Achievement Registry

A static catalog that defines all possible achievements and their unlock conditions. This keeps the evaluation logic centralized and testable:

```swift
// Odyssey/Services/AchievementRegistry.swift

import Foundation

struct AchievementDefinition {
    let id: String
    let type: String
    let title: String
    let description: String
    let iconName: String
    let sortOrder: Int
    let tier: Int
    let condition: ([DailyEntry], DailyEntry?) -> Bool
}

enum AchievementRegistry {
    static let all: [AchievementDefinition] = [
        // Streak milestones
        .init(
            id: "streak_3", type: "streak",
            title: "Spark",
            description: "Three days in a row — a spark is catching",
            iconName: "flame",
            sortOrder: 0, tier: 0,
            condition: { entries, _ in entries.currentStreak >= 3 }
        ),
        .init(
            id: "streak_7", type: "streak",
            title: "Kindling",
            description: "A full week of showing up for yourself",
            iconName: "flame.fill",
            sortOrder: 1, tier: 0,
            condition: { entries, _ in entries.currentStreak >= 7 }
        ),
        .init(
            id: "streak_30", type: "streak",
            title: "Campfire",
            description: "A month of daily journaling — warmth you built",
            iconName: "fireplace",
            sortOrder: 3, tier: 1,
            condition: { entries, _ in entries.currentStreak >= 30 }
        ),
        .init(
            id: "streak_365", type: "streak",
            title: "Odyssey Complete",
            description: "A full year. What a journey.",
            iconName: "safari.fill",
            sortOrder: 7, tier: 2,
            condition: { entries, _ in entries.currentStreak >= 365 }
        ),

        // First-time
        .init(
            id: "first_entry", type: "first",
            title: "First Step",
            description: "Every odyssey begins with a single step",
            iconName: "figure.walk",
            sortOrder: 0, tier: 0,
            condition: { entries, _ in
                entries.contains { $0.hasPromptData }
            }
        ),
        .init(
            id: "first_gratitude", type: "first",
            title: "Grateful Heart",
            description: "You found something to be grateful for",
            iconName: "heart.fill",
            sortOrder: 1, tier: 0,
            condition: { entries, _ in
                entries.contains { !$0.gratitude.isEmpty }
            }
        ),
        .init(
            id: "first_photo", type: "first",
            title: "Picture Worth 1000 Words",
            description: "A moment captured in your journal",
            iconName: "camera.fill",
            sortOrder: 2, tier: 0,
            condition: { entries, _ in
                entries.contains { $0.hasPhotos }
            }
        ),

        // Depth — example
        .init(
            id: "deep_dive", type: "depth",
            title: "Deep Dive",
            description: "You went deep today — that takes courage",
            iconName: "text.page.fill",
            sortOrder: 0, tier: 1,
            condition: { entries, _ in
                entries.contains { $0.journalEntry.split(separator: " ").count >= 500 }
            }
        ),
        .init(
            id: "open_book", type: "depth",
            title: "Open Book",
            description: "Every prompt answered — full transparency with yourself",
            iconName: "book.fill",
            sortOrder: 1, tier: 1,
            condition: { entries, _ in
                entries.contains { entry in
                    !entry.singleWordFeeling.isEmpty &&
                    !entry.gratitude.isEmpty &&
                    !entry.win.isEmpty &&
                    !entry.tension.isEmpty &&
                    !entry.journalEntry.isEmpty &&
                    entry.sleepQuality > 0 &&
                    entry.drinks >= 0 &&
                    entry.feeling > 0
                }
            }
        ),

        // Wellness — example
        .init(
            id: "comeback", type: "wellness",
            title: "Comeback",
            description: "You came back — that is what matters",
            iconName: "arrow.uturn.up",
            sortOrder: 10, tier: 1,
            condition: { entries, latest in
                guard let latest = latest else { return false }
                let sorted = entries.filter { $0.hasPromptData }
                    .sorted { $0.date > $1.date }
                guard sorted.count >= 2 else { return false }
                let calendar = Calendar.current
                let latestDate = calendar.startOfDay(for: latest.date)
                // Find the most recent entry before this one
                for entry in sorted.dropFirst() {
                    let entryDate = calendar.startOfDay(for: entry.date)
                    let gap = calendar.dateComponents([.day], from: entryDate, to: latestDate).day ?? 0
                    if gap >= 7 { return true }
                    break
                }
                return false
            }
        ),

        // ... remaining achievements follow the same pattern
    ]
}
```

### AchievementService

Evaluates unlock conditions and persists newly earned achievements. Called after every entry save:

```swift
// Odyssey/Services/AchievementService.swift

import SwiftData
import os

@MainActor
final class AchievementService {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "Achievements")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Seed all achievement records on first launch (locked state).
    func seedIfNeeded() {
        let descriptor = FetchDescriptor<Achievement>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingIDs = Set(existing.map(\.id))

        for definition in AchievementRegistry.all where !existingIDs.contains(definition.id) {
            let achievement = Achievement(
                id: definition.id,
                type: definition.type,
                title: definition.title,
                description: definition.description,
                iconName: definition.iconName,
                sortOrder: definition.sortOrder,
                tier: definition.tier
            )
            modelContext.insert(achievement)
        }
        try? modelContext.save()
    }

    /// Evaluate all locked achievements. Returns newly unlocked ones for animation.
    func evaluateAll(entries: [DailyEntry], latestEntry: DailyEntry?) -> [Achievement] {
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { $0.unlockedDate == nil }
        )
        let locked = (try? modelContext.fetch(descriptor)) ?? []
        let definitionMap = Dictionary(
            uniqueKeysWithValues: AchievementRegistry.all.map { ($0.id, $0) }
        )

        var newlyUnlocked: [Achievement] = []

        for achievement in locked {
            guard let definition = definitionMap[achievement.id] else { continue }
            if definition.condition(entries, latestEntry) {
                achievement.unlockedDate = Date()
                achievement.isNew = true
                newlyUnlocked.append(achievement)
                logger.info("Achievement unlocked: \(achievement.title)")
            }
        }

        if !newlyUnlocked.isEmpty {
            try? modelContext.save()
        }

        return newlyUnlocked
    }

    /// Mark an achievement as seen (no longer "new").
    func markSeen(_ achievement: Achievement) {
        achievement.isNew = false
        try? modelContext.save()
    }

    /// Fetch all achievements, grouped by type.
    func fetchAll() -> [String: [Achievement]] {
        let descriptor = FetchDescriptor<Achievement>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(grouping: all, by: \.type)
    }

    /// Count of unseen unlocked achievements (for badge count on tab/gallery).
    func unseenCount() -> Int {
        let predicate = #Predicate<Achievement> { $0.isNew == true }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}
```

### StreakCalculator Enhancements

The existing `DailyEntry+Streak.swift` computes `currentStreak` on `Array<DailyEntry>`. The `longestStreak` calculation lives inline in `InsightsViewModel`. Consolidate both into the extension and add streak-with-grace-day support:

```swift
// Odyssey/Models/DailyEntry+Streak.swift (enhanced)

import Foundation

extension Array where Element == DailyEntry {
    var currentStreak: Int {
        // ... existing implementation unchanged ...
    }

    var longestStreak: Int {
        let sorted = self.filter { $0.hasPromptData }.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        var longest = 0
        var current = 0
        var lastDate: Date?

        for entry in sorted {
            let entryDate = calendar.startOfDay(for: entry.date)
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: entryDate).day ?? 0
                if daysBetween == 1 {
                    current += 1
                } else {
                    current = 1
                }
            } else {
                current = 1
            }
            longest = max(longest, current)
            lastDate = entryDate
        }
        return longest
    }

    /// Total word count across all journal entries.
    var totalJournalWordCount: Int {
        self.filter { $0.hasPromptData }
            .reduce(0) { $0 + $1.journalEntry.split(separator: " ").count }
    }

    /// Number of unique cities across all entries.
    var uniqueCityCount: Int {
        Set(self.compactMap(\.city)).count
    }

    /// Number of unique countries across all entries.
    var uniqueCountryCount: Int {
        Set(self.compactMap(\.country)).count
    }

    /// Number of unique feeling colors used.
    var uniqueFeelingColorCount: Int {
        Set(self.map(\.feelingColorHex).filter { $0 != "#FFFFFF" }).count
    }

    /// Number of unique non-empty gratitude entries.
    var uniqueGratitudeCount: Int {
        Set(self.map(\.gratitude).filter { !$0.isEmpty }).count
    }
}
```

This also allows `InsightsViewModel.longestStreak` to be simplified to `entries.longestStreak`.

### Integration with Entry Save

The key integration point is `DailyEntryViewModel.submitData()` in `Odyssey/ViewModels/DailyEntryViewModel.swift`. After the `modelContext.save()` call, trigger achievement evaluation:

```swift
// In DailyEntryViewModel.submitData(), after try modelContext.save():

let achievementService = AchievementService(modelContext: modelContext)
let allEntries = fetchAllEntries()
let newlyUnlocked = achievementService.evaluateAll(
    entries: allEntries,
    latestEntry: entry
)
if !newlyUnlocked.isEmpty {
    pendingAchievements = newlyUnlocked  // @Published — drives UI
}
```

### Achievement Unlock Animation

When a new achievement unlocks, display a transient overlay on the CompletionCard. This uses the existing `LottieView` wrapper (already in `Odyssey/Views/LottieView.swift`) for a confetti or sparkle animation, layered with SwiftUI transitions:

```swift
// Odyssey/Views/Achievements/AchievementUnlockOverlay.swift

import SwiftUI

struct AchievementUnlockOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var showBadge = false
    @State private var showText = false

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Spacer()

                // Lottie celebration burst
                LottieView(lottieFile: "achievement_burst", loopMode: .playOnce)
                    .frame(width: 200, height: 200)
                    .allowsHitTesting(false)

                // Badge icon with glow
                if showBadge {
                    ZStack {
                        Circle()
                            .fill(tierGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: tierColor.opacity(0.6), radius: 20)

                        Image(systemName: achievement.iconName)
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                }

                if showText {
                    VStack(spacing: 8) {
                        Text("Achievement Unlocked")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Text(achievement.title)
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        Text(achievement.achievementDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .transition(.opacity)
                }

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(tierColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.3)) {
                showBadge = true
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.7)) {
                showText = true
            }
        }
    }

    private var tierColor: Color {
        switch achievement.tier {
        case 0: return .accentAmber
        case 1: return .accentTeal
        case 2: return .cosmicPurple
        default: return .accentAmber
        }
    }

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case 0: return LinearGradient(colors: [.accentAmber, .accentAmber.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 1: return LinearGradient(colors: [.accentTeal, .accentAmber], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: return LinearGradient(colors: [.cosmicPurple, .nebulaPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.accentAmber], startPoint: .top, endPoint: .bottom)
        }
    }
}
```

The animation timing mirrors the existing `CompletionCard.swift` pattern: staggered `withAnimation` calls with spring response for the icon and ease-in-out for the text.

### Achievement Gallery View

A browseable collection of all achievements, organized by category. Locked achievements show as dimmed silhouettes to create aspiration:

```swift
// Odyssey/Views/Achievements/AchievementGalleryView.swift

import SwiftUI
import SwiftData

struct AchievementGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var grouped: [String: [Achievement]] = [:]

    private let categoryOrder = ["streak", "first", "depth", "exploration", "wellness"]
    private let categoryTitles = [
        "streak": "Streak Milestones",
        "first": "First Steps",
        "depth": "Going Deeper",
        "exploration": "Explorer",
        "wellness": "Wellness"
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary header
                summaryHeader

                // Categories
                ForEach(categoryOrder, id: \.self) { category in
                    if let achievements = grouped[category], !achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(categoryTitles[category] ?? category.capitalized)
                                .font(.headline)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(achievements.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { achievement in
                                    AchievementBadgeCell(achievement: achievement)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .navigationTitle("Achievements")
        .background(Color.black)
        .onAppear { loadAchievements() }
    }

    private var summaryHeader: some View {
        let total = grouped.values.flatMap { $0 }
        let unlocked = total.filter(\.isUnlocked).count
        return VStack(spacing: 8) {
            Text("\(unlocked) / \(total.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentAmber)
            Text("achievements unlocked")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func loadAchievements() {
        let service = AchievementService(modelContext: modelContext)
        grouped = service.fetchAll()
    }
}

struct AchievementBadgeCell: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? tierGradient : lockedGradient)
                    .frame(width: 64, height: 64)

                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundStyle(achievement.isUnlocked ? .white : .secondary.opacity(0.4))
            }
            .overlay(alignment: .topTrailing) {
                if achievement.isNew {
                    Circle()
                        .fill(Color.coralRed)
                        .frame(width: 12, height: 12)
                        .offset(x: 2, y: -2)
                }
            }

            Text(achievement.isUnlocked ? achievement.title : "???")
                .font(.caption2.weight(.medium))
                .foregroundStyle(achievement.isUnlocked ? .white : .secondary)
                .lineLimit(1)
        }
    }

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case 0: return LinearGradient(colors: [.accentAmber.opacity(0.3), .accentAmber.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 1: return LinearGradient(colors: [.accentTeal.opacity(0.3), .accentAmber.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: return LinearGradient(colors: [.cosmicPurple.opacity(0.3), .nebulaPink.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.accentAmber.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var lockedGradient: LinearGradient {
        LinearGradient(colors: [Color.cardSurface, Color.cardSurface.opacity(0.5)], startPoint: .top, endPoint: .bottom)
    }
}
```

### Streak Display Enhancement on Today Tab

Enhance the existing flame card in `VitalsGridView` to show streak milestone proximity:

```swift
// Replace the existing streak vitalCard in VitalsGridView.swift:

vitalCard(
    icon: "flame.fill",
    value: streak > 0 ? "\(streak)" : "--",
    label: nextMilestoneLabel,
    color: .accentAmber,
    index: 3
)

// Add computed property:
private var nextMilestoneLabel: String {
    let milestones = [3, 7, 14, 30, 60, 90, 180, 365]
    if let next = milestones.first(where: { $0 > streak }) {
        let remaining = next - streak
        return remaining == 1 ? "1 day to \(next)!" : "Day Streak"
    }
    return "Day Streak"
}
```

## Integration Points

### New Files to Create

| File | Purpose |
|------|---------|
| `Odyssey/Models/Achievement.swift` | SwiftData model |
| `Odyssey/Services/AchievementRegistry.swift` | Static badge catalog with conditions |
| `Odyssey/Services/AchievementService.swift` | Evaluation, seeding, persistence |
| `Odyssey/Views/Achievements/AchievementGalleryView.swift` | Badge gallery |
| `Odyssey/Views/Achievements/AchievementBadgeCell.swift` | Individual badge cell (or inline) |
| `Odyssey/Views/Achievements/AchievementUnlockOverlay.swift` | Unlock celebration |
| `Odyssey/Resources/achievement_burst.json` | Lottie animation file for unlock celebration |
| `OdysseyTests/AchievementServiceTests.swift` | Unit tests for evaluation logic |

### Existing Files to Modify

| File | Change |
|------|--------|
| `Odyssey/Models/DataContainer.swift` | Add `Achievement.self` to `ModelContainer` schema |
| `Odyssey/Models/DailyEntry+Streak.swift` | Add `longestStreak`, `totalJournalWordCount`, helper properties |
| `Odyssey/ViewModels/DailyEntryViewModel.swift` | Call `AchievementService.evaluateAll()` after `submitData()` save; add `pendingAchievements` state |
| `Odyssey/ViewModels/InsightsViewModel.swift` | Replace inline `longestStreak` with `entries.longestStreak` |
| `Odyssey/Views/GuidedPrompts/Cards/CompletionCard.swift` | Layer `AchievementUnlockOverlay` on top when achievements are pending |
| `Odyssey/Views/GuidedPrompts/GuidedPromptFlowView.swift` | Pass pending achievements through to CompletionCard |
| `Odyssey/Views/Insights/StreakView.swift` | Add achievement badges section below the chart |
| `Odyssey/Views/Insights/Tabs/MindCardsGrid.swift` | Add an "Achievements" card linking to the gallery |
| `Odyssey/Views/Today/VitalsGridView.swift` | Show next milestone hint in streak card label |
| `Odyssey/OdysseyApp.swift` | Call `AchievementService.seedIfNeeded()` on launch |

## UI Design Approach

### Visual Language

- **Badge shapes**: Circles with SF Symbol icons, consistent with the existing card/icon style used in `MindCardsGrid` and `VitalsGridView`.
- **Tier colors**: Bronze (`accentAmber`), Silver (`accentTeal`), Gold (`cosmicPurple`/`nebulaPink` gradient). These build on the existing design token palette in `Color+Extensions.swift`.
- **Locked state**: Greyed-out `cardSurface` fill with `???` title, creating curiosity without revealing what is locked.
- **Glow effect**: Unlocked badges use a subtle `shadow(color:radius:)` in their tier color, similar to the mood orb glow on the Today tab.

### Unlock Celebration

The unlock overlay follows the same staggered animation pattern as `CompletionCard.swift`:
1. **0.3s** — Lottie burst plays (confetti/sparkle, using existing `LottieView` wrapper)
2. **0.5s** — Badge icon scales in with spring physics
3. **0.7s** — Title and description fade in
4. Tap anywhere or "Continue" button dismisses

For the Lottie asset, use a generic "celebration burst" animation (available on LottieFiles under permissive licenses). The existing `LottieView.swift` wrapper supports this with no changes beyond adding the JSON file to the bundle.

### Streak Fire Aesthetic

The flame/fire visual language is already established:
- `flame.fill` SF Symbol on the Today tab vital card (`VitalsGridView.swift`)
- `accentAmber` as the streak color throughout (`StreakView.swift`, `MindCardsGrid.swift`)
- Streak milestones escalate the fire metaphor: spark, kindling, campfire, bonfire, signal fire, eternal flame

### Gallery Layout

3-column grid of circular badges, grouped by category with section headers. This matches the density of the existing `MindCardsGrid` 2-column layout while being appropriate for smaller, simpler badge cells. Summary header at top shows "X / Y achievements unlocked" with the count in `accentAmber`, matching the visual weight of the streak count in `StreakView`.

## Trade-offs and Constraints

### Avoiding a "gamey" feel

The single most important constraint. Mitigations:
- **Language**: All badge descriptions use reflective, affirming language. "You went deep today — that takes courage" rather than "Unlocked! +50 XP!"
- **No points or scores**: Achievements are binary (locked/unlocked). No point values, no leaderboards, no rankings.
- **No punitive mechanics**: A broken streak is never highlighted or shamed. The "Comeback" badge specifically rewards returning after a gap.
- **Optional**: The achievement gallery is a destination the user navigates to — it never interrupts the journaling flow. The unlock overlay appears only on the CompletionCard (which the user has already finished their entry).
- **No notifications for achievements**: Badges are discovered passively, not pushed.

### Performance of checking achievements on every save

The `evaluateAll()` method fetches all locked achievements and runs each condition against the full entry array. With the expected data volume (365 entries/year, ~40 achievement definitions), this is negligible — under 1ms on any modern device. However:
- The method only evaluates *locked* achievements, so the set shrinks over time.
- Conditions that require sorting (streak calculation) are already O(n log n) in existing code.
- If the achievement catalog grows beyond ~100, consider caching the entry array properties (word count, city count) rather than recomputing per condition.

### SwiftData migration

Adding `Achievement` to the `ModelContainer` schema is a non-destructive migration — it is a new model, not a change to `DailyEntry`. SwiftData handles this automatically with lightweight migration. The `seedIfNeeded()` call on launch populates the initial locked records.

### Streak grace days (future consideration)

Many wellness apps offer a "freeze" or "grace day" mechanic where missing one day does not break the streak. This proposal does not include it in v1 to keep scope manageable, but the `DailyEntry+Streak.swift` extension can be modified to support a 1-day grace window by changing the gap check from `== 1` to `<= 2`.

### Lottie asset size

A single celebration animation JSON is typically 20-50 KB. This is negligible compared to existing app assets. If we want per-tier animations (bronze/silver/gold), budget 100-150 KB total.

## Open Questions

1. **Should achievements be visible in the Profile tab, the Insights tab, or both?** The current proposal places the gallery as a navigation destination from `MindCardsGrid`. An alternative is a dedicated section in the Profile tab (which currently handles Screen Time, app selection, and CSV export).

2. **Should the unlock overlay queue multiple achievements?** If a user's first entry simultaneously unlocks "First Step", "Mood Pioneer", and "Grateful Heart", should we show three sequential overlays or a single summary? Recommend: show the highest-tier one with a "+2 more" indicator, let the user discover the rest in the gallery.

3. **Retroactive unlocking**: On first launch after the update, should achievements evaluate against all historical entries? This rewards existing users but means someone with 200 entries immediately gets a wall of "new" badges. Recommend: yes, retroactive unlock, but suppress the overlay animation for retroactively earned badges and instead show a one-time "Welcome to Achievements" screen summarizing what was earned.

4. **Custom badge artwork vs SF Symbols**: SF Symbols are fast to implement and consistent with the app's existing icon usage. Custom illustrated badges would be more distinctive and "collectible" but require design investment. Recommend: ship v1 with SF Symbols, plan custom artwork for v2.

5. **Should streak milestones use `currentStreak` or `longestStreak`?** The current proposal uses `currentStreak`. An alternative is to award the badge permanently once `longestStreak` reaches the threshold, so a user who once hit 30 days keeps the badge even after a break. Recommend: use `longestStreak` — achievements should be permanent recognitions, not revocable.

6. **Streak grace day**: Should v1 include a 1-day grace mechanic, or defer? Wellness research suggests grace days significantly reduce streak anxiety. However, it complicates the mental model. Recommend: defer to v1.1 based on user feedback.

## Next Steps

1. **Create `Achievement` SwiftData model** and register it in `DataContainer.swift`. Verify lightweight migration works with existing user data.
2. **Implement `AchievementRegistry`** with the full badge catalog (all categories from this proposal).
3. **Build `AchievementService`** with `seedIfNeeded()` and `evaluateAll()`. Write unit tests covering each achievement condition.
4. **Integrate into `DailyEntryViewModel.submitData()`** — trigger evaluation after save, surface newly unlocked achievements.
5. **Build `AchievementUnlockOverlay`** and wire it into `CompletionCard` / `GuidedPromptFlowView`.
6. **Build `AchievementGalleryView`** and add navigation from `MindCardsGrid`.
7. **Enhance `VitalsGridView`** streak card with next-milestone hint.
8. **Source or create Lottie celebration animation** (`achievement_burst.json`).
9. **Consolidate streak logic** — move `longestStreak` from `InsightsViewModel` into `DailyEntry+Streak.swift`.
10. **QA pass**: Test retroactive unlocking, verify no performance regression on large entry sets, confirm dark mode rendering for all badge states.
