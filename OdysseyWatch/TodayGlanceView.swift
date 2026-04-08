import SwiftData
import SwiftUI

struct TodayGlanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DailyEntry> { _ in true },
           sort: \DailyEntry.date,
           order: .reverse)
    private var entries: [DailyEntry]

    private var todayEntry: DailyEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var streakDays: Int {
        guard !entries.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for entry in entries {
            let entryDay = calendar.startOfDay(for: entry.date)
            if entryDay == checkDate && entry.hasUserSubmitted {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else if entryDay < checkDate {
                break
            }
        }
        return streak
    }

    var body: some View {
        VStack(spacing: 12) {
            if let entry = todayEntry, entry.hasUserSubmitted {
                // Mood orb
                Circle()
                    .fill(Color.moodGradient(for: entry.feeling ?? 5))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Text("\(entry.feeling ?? 0)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                if !entry.singleWordFeeling.isEmpty {
                    Text(entry.singleWordFeeling.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentAmber)
                        Text("\(streakDays)-day streak")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } else {
                // No entry yet
                Circle()
                    .fill(Color.cardSurface)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                Text("No check-in yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Swipe up to check in")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(.black.gradient, for: .tabView)
    }
}
