import SwiftUI
import Charts

struct MoodTrendView: View {
    let entries: [DailyEntry]

    @State private var showMood = true
    @State private var showSleep = true
    @State private var showDrinks = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Toggle controls
                HStack(spacing: 12) {
                    toggleChip("Mood", isOn: $showMood, color: .accentAmber)
                    toggleChip("Sleep", isOn: $showSleep, color: .accentTeal)
                    toggleChip("Drinks", isOn: $showDrinks, color: .coralRed)
                }
                .padding(.horizontal, 16)

                // Chart
                Chart {
                    if showMood {
                        ForEach(moodEntries, id: \.date) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Mood", entry.feeling),
                                series: .value("Type", "Mood")
                            )
                            .foregroundStyle(Color.accentAmber)
                            .interpolationMethod(.catmullRom)
                        }

                        // Filled circles for completed entries, hollow for background-only
                        ForEach(moodEntries, id: \.date) { entry in
                            if entry.hasPromptData {
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Mood", entry.feeling)
                                )
                                .foregroundStyle(Color.accentAmber)
                                .symbolSize(30)
                            } else {
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Mood", entry.feeling)
                                )
                                .foregroundStyle(Color.cardSurface)
                                .symbolSize(30)
                                .annotation(position: .overlay) {
                                    Circle()
                                        .strokeBorder(Color.accentAmber, lineWidth: 1.5)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }

                        // Average line
                        let avg = averageMood
                        RuleMark(y: .value("Avg Mood", avg))
                            .foregroundStyle(Color.accentAmber.opacity(0.4))
                            .lineStyle(StrokeStyle(dash: [5, 5]))
                    }

                    if showSleep {
                        ForEach(sleepEntries, id: \.date) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Sleep", entry.sleepQuality),
                                series: .value("Type", "Sleep")
                            )
                            .foregroundStyle(Color.accentTeal)
                            .interpolationMethod(.catmullRom)
                        }

                        ForEach(sleepEntries, id: \.date) { entry in
                            if entry.hasPromptData {
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Sleep", entry.sleepQuality)
                                )
                                .foregroundStyle(Color.accentTeal)
                                .symbolSize(30)
                            } else {
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Sleep", entry.sleepQuality)
                                )
                                .foregroundStyle(Color.cardSurface)
                                .symbolSize(30)
                                .annotation(position: .overlay) {
                                    Circle()
                                        .strokeBorder(Color.accentTeal, lineWidth: 1.5)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }

                    if showDrinks {
                        ForEach(entries.filter { $0.hasPromptData }, id: \.date) { entry in
                            BarMark(
                                x: .value("Date", entry.date),
                                y: .value("Drinks", entry.drinks)
                            )
                            .foregroundStyle(Color.coralRed.opacity(0.6))
                        }
                    }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 300)
                .padding(.horizontal, 16)

                // Stats
                HStack(spacing: 12) {
                    statBox("Avg Mood", value: String(format: "%.1f", averageMood), color: .accentAmber)
                    statBox("Avg Sleep", value: String(format: "%.1f", averageSleep), color: .accentTeal)
                    statBox("Total Drinks", value: "\(totalDrinks)", color: .coralRed)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .navigationTitle("Mood Trends")
        .cosmicBackground()
    }

    /// All entries that have mood data (user-submitted entries only for averages, all for line continuity)
    private var moodEntries: [DailyEntry] { entries }
    private var sleepEntries: [DailyEntry] { entries }

    private var averageMood: Double {
        let valid = entries.filter { $0.hasPromptData }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0) { $0 + $1.feeling }) / Double(valid.count)
    }

    private var averageSleep: Double {
        let valid = entries.filter { $0.hasPromptData }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.reduce(0) { $0 + $1.sleepQuality }) / Double(valid.count)
    }

    private var totalDrinks: Int {
        entries.filter { $0.hasPromptData }.reduce(0) { $0 + $1.drinks }
    }

    private func toggleChip(_ label: String, isOn: Binding<Bool>, color: Color) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(isOn.wrappedValue ? color.opacity(0.3) : Color.cardSurface))
                .foregroundStyle(isOn.wrappedValue ? color : .secondary)
        }
        .accessibilityLabel("\(label) toggle")
        .accessibilityHint("Double tap to \(isOn.wrappedValue ? "hide" : "show") \(label) data")
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
    }

    private func statBox(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .fontDesign(.rounded)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardSurface))
    }
}
