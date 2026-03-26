import Charts
import SwiftUI

// MARK: - Compact Card (for BodyTabView grid)

struct SleepArchitectureCard: View {
    let viewModel: InsightsViewModel

    private var latestEntry: DailyEntry? {
        viewModel.filteredEntries.last(where: { $0.hasSleepStageData })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentTeal)
                Text("Sleep Stages")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let entry = latestEntry, let hours = entry.sleepHours {
                    Text(String(format: "%.1fh", hours))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                }
            }

            if let entry = latestEntry {
                SleepStageBar(stages: entry.sleepStageBreakdown)

                // Stage labels
                HStack(spacing: 8) {
                    ForEach(entry.sleepStageBreakdown, id: \.label) { stage in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(stage.color)
                                .frame(width: 6, height: 6)
                            Text("\(stage.label) \(String(format: "%.1fh", stage.hours))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.cardSurface)
                    .frame(height: 40)
                    .overlay(
                        Text("No stage data")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .cosmicCard(accent: .accentTeal)
    }
}

// MARK: - Sleep Score Card

struct SleepScoreCard: View {
    let viewModel: InsightsViewModel

    private var latestScore: (score: Int, label: String)? {
        guard let entry = viewModel.filteredEntries.last(where: { $0.sleepScore != nil }),
              let score = entry.sleepScore,
              let label = entry.sleepScoreLabel else { return nil }
        return (score, label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentTeal)
                Text("Sleep Score")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                TrendArrow(trend: viewModel.trend(for: .sleepScore))
            }

            if let latest = latestScore {
                SleepScoreGauge(score: latest.score)
                    .frame(height: 40)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(latest.score)")
                        .font(.title3.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                    Text(latest.label)
                        .font(.caption)
                        .foregroundStyle(scoreColor(latest.score))
                }
            } else {
                Rectangle()
                    .fill(Color.cardSurface)
                    .frame(height: 40)
                    .overlay(
                        Text("No score data")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .cosmicCard(accent: .accentTeal)
    }

    private func scoreColor(_ score: Int) -> Color {
        SleepScoreService.color(for: score)
    }
}

// MARK: - Sleep Score Gauge

struct SleepScoreGauge: View {
    let score: Int

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = CGFloat(min(score, 100)) / 100.0

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cardSurface)
                    .frame(height: 8)

                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.coralRed, .accentAmber, .successGreen, .accentTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * fraction, height: 8)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Stacked Bar Component

struct SleepStageBar: View {
    let stages: [(label: String, hours: Double, color: Color)]

    private var totalHours: Double {
        stages.reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 1) {
                ForEach(stages, id: \.label) { stage in
                    let fraction = totalHours > 0 ? stage.hours / totalHours : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(stage.color)
                        .frame(width: max(4, width * fraction))
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Detail View

struct SleepArchitectureDetailView: View {
    let viewModel: InsightsViewModel

    private var entriesWithStages: [DailyEntry] {
        viewModel.filteredEntries.filter { $0.hasSleepStageData }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sleep Score Summary
                if let avgScore = averageScore {
                    sleepScoreSection(avgScore)
                }

                // Stage Proportions Donut
                if !entriesWithStages.isEmpty {
                    stageDonutSection
                }

                // Historical Stacked Bar Chart
                if entriesWithStages.count >= 2 {
                    historicalStackedChart
                }

                // Stats Row
                statsSection

                Spacer(minLength: 32)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Sleep Architecture")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Score Section

    private var averageScore: Double? {
        let scores = viewModel.filteredEntries.compactMap(\.sleepScore)
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    @ViewBuilder
    private func sleepScoreSection(_ avgScore: Double) -> some View {
        VStack(spacing: 12) {
            Text("Average Sleep Score")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("\(Int(avgScore))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(scoreLabel(Int(avgScore)))
                .font(.headline)
                .foregroundStyle(scoreColor(Int(avgScore)))

            // Score breakdown bars
            if let latest = viewModel.filteredEntries.last(where: { $0.sleepScore != nil }) {
                scoreBreakdown(for: latest)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.cardSurface.clipShape(RoundedRectangle(cornerRadius: 16)))
    }

    @ViewBuilder
    private func scoreBreakdown(for entry: DailyEntry) -> some View {
        let recentEntries = viewModel.filteredEntries.filter { $0.date < entry.date }.suffix(13)
        if let score = SleepScoreService.computeScore(for: entry, recentEntries: Array(recentEntries)) {
            VStack(spacing: 8) {
                scoreBar(label: "Duration", points: score.durationPoints, maxPoints: 50, color: .accentTeal)
                scoreBar(label: "Consistency", points: score.consistencyPoints, maxPoints: 30, color: .cosmicPurple)
                scoreBar(label: "Interruptions", points: score.interruptionPoints, maxPoints: 20, color: .accentAmber)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func scoreBar(label: String, points: Int, maxPoints: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(points)/\(maxPoints)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.cardSurface.opacity(0.5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(points) / CGFloat(maxPoints))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Stage Donut

    @ViewBuilder
    private var stageDonutSection: some View {
        VStack(spacing: 12) {
            Text("Average Stage Proportions")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Chart(averageStages, id: \.label) { stage in
                SectorMark(
                    angle: .value("Hours", stage.hours),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(stage.color)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartBackground { _ in
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", averageStages.reduce(0) { $0 + $1.hours }))
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                    Text("avg hrs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Legend
            HStack(spacing: 16) {
                ForEach(averageStages, id: \.label) { stage in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 8, height: 8)
                        Text("\(stage.label) \(String(format: "%.1fh", stage.hours))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.cardSurface.clipShape(RoundedRectangle(cornerRadius: 16)))
    }

    private var averageStages: [(label: String, hours: Double, color: Color)] {
        let entries = entriesWithStages
        guard !entries.isEmpty else { return [] }

        let coreValues = entries.compactMap(\.sleepCoreHours)
        let deepValues = entries.compactMap(\.sleepDeepHours)
        let remValues = entries.compactMap(\.sleepREMHours)
        let awakeValues = entries.compactMap(\.sleepAwakeMinutes)

        var stages: [(label: String, hours: Double, color: Color)] = []
        if !coreValues.isEmpty {
            stages.append(("Core", coreValues.reduce(0, +) / Double(coreValues.count), .accentAmber))
        }
        if !deepValues.isEmpty {
            stages.append(("Deep", deepValues.reduce(0, +) / Double(deepValues.count), .accentTeal))
        }
        if !remValues.isEmpty {
            stages.append(("REM", remValues.reduce(0, +) / Double(remValues.count), .cosmicPurple))
        }
        if !awakeValues.isEmpty {
            stages.append(("Awake", awakeValues.reduce(0, +) / Double(awakeValues.count) / 60.0, .coralRed))
        }

        return stages
    }

    // MARK: - Historical Stacked Chart

    @ViewBuilder
    private var historicalStackedChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(entriesWithStages, id: \.date) { entry in
                    if let core = entry.sleepCoreHours {
                        BarMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Hours", core)
                        )
                        .foregroundStyle(Color.accentAmber)
                        .position(by: .value("Stage", "Core"))
                    }
                    if let deep = entry.sleepDeepHours {
                        BarMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Hours", deep)
                        )
                        .foregroundStyle(Color.accentTeal)
                        .position(by: .value("Stage", "Deep"))
                    }
                    if let rem = entry.sleepREMHours {
                        BarMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Hours", rem)
                        )
                        .foregroundStyle(Color.cosmicPurple)
                        .position(by: .value("Stage", "REM"))
                    }
                }
            }
            .chartForegroundStyleScale([
                "Core": Color.accentAmber,
                "Deep": Color.accentTeal,
                "REM": Color.cosmicPurple,
            ])
            .chartYAxisLabel("Hours")
            .frame(height: 220)
        }
        .padding(16)
        .background(Color.cardSurface.clipShape(RoundedRectangle(cornerRadius: 16)))
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        let metrics: [(String, MetricDefinition)] = [
            ("Avg REM", .sleepREM),
            ("Avg Deep", .sleepDeep),
            ("Avg Core", .sleepCore),
            ("Avg Score", .sleepScore),
        ]

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics, id: \.0) { label, metric in
                VStack(spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(metric.formatValue(viewModel.average(for: metric)))
                            .font(.title3.bold())
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)
                        Text(metric.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.cardSurface.clipShape(RoundedRectangle(cornerRadius: 12)))
            }
        }
    }

    // MARK: - Helpers

    private func scoreLabel(_ score: Int) -> String {
        SleepScoreService.label(for: score)
    }

    private func scoreColor(_ score: Int) -> Color {
        SleepScoreService.color(for: score)
    }
}
