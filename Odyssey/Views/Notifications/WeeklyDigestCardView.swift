import SwiftUI

struct WeeklyDigestCardView: View {
    let data: WeeklyDigestData

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: data.weekStartDate)
        let end = formatter.string(from: data.weekEndDate)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Digest")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentAmber)
            }

            if data.hasData {
                // Primary stats grid
                HStack(spacing: 12) {
                    statCell(
                        value: "\(data.daysJournaled)/\(data.totalDays)",
                        label: "Journaled",
                        color: .accentTeal
                    )
                    statCell(
                        value: String(format: "%.1f", data.averageMood),
                        label: "Avg Mood",
                        color: .accentAmber,
                        trend: data.moodTrendSymbol
                    )
                    statCell(
                        value: "\(data.currentStreak)",
                        label: "Streak",
                        color: .cosmicPurple
                    )
                }

                // Secondary stats
                HStack(spacing: 12) {
                    if let emotion = data.topEmotion {
                        secondaryStat(icon: "heart.fill", value: emotion, color: .nebulaPink)
                    }
                    if data.totalSteps > 0 {
                        secondaryStat(icon: "figure.walk", value: formatSteps(data.totalSteps), color: .successGreen)
                    }
                    if let sleep = data.averageSleepHours {
                        secondaryStat(icon: "moon.fill", value: String(format: "%.1fh", sleep), color: .accentTeal)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Start journaling this week!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
        )
        .frame(width: 340)
    }

    private func statCell(value: String, label: String, color: Color, trend: String = "") -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if !trend.isEmpty {
                    Text(trend)
                        .font(.caption.bold())
                        .foregroundStyle(trendColor(trend))
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
        )
    }

    private func secondaryStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }

    private func trendColor(_ symbol: String) -> Color {
        switch symbol {
        case "↑": return .successGreen
        case "↓": return .coralRed
        default: return .secondary
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

@MainActor
func renderDigestCard(_ data: WeeklyDigestData) -> URL? {
    let renderer = ImageRenderer(content:
        WeeklyDigestCardView(data: data)
            .environment(\.colorScheme, .dark)
    )
    renderer.scale = 3.0

    #if os(macOS)
        guard let image = renderer.nsImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
    #else
        guard let image = renderer.uiImage,
              let pngData = image.pngData() else { return nil }
    #endif

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("weekly-digest-card-\(UUID().uuidString).png")
    do {
        try pngData.write(to: url)
        return url
    } catch {
        return nil
    }
}

#Preview {
    WeeklyDigestCardView(data: WeeklyDigestData(
        weekStartDate: Calendar.current.date(byAdding: .day, value: -6, to: Date())!,
        weekEndDate: Date(),
        daysJournaled: 5,
        totalDays: 7,
        averageMood: 7.2,
        previousWeekAverageMood: 6.5,
        moodTrendDelta: 0.7,
        topEmotion: "Grateful",
        currentStreak: 5,
        averageSleepQuality: 7.0,
        totalSteps: 42000,
        totalDrinks: 3,
        averageSleepHours: 7.5,
        averageScreenTimeHours: 4.2
    ))
    .padding()
    .background(Color.deepSpaceBlue)
    .environment(\.colorScheme, .dark)
}
