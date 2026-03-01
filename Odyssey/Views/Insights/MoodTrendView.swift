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
                        ForEach(entries, id: \.date) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Mood", entry.feeling),
                                series: .value("Type", "Mood")
                            )
                            .foregroundStyle(Color.accentAmber)
                            .interpolationMethod(.catmullRom)
                        }

                        // Average line
                        let avg = entries.isEmpty ? 0 : Double(entries.reduce(0) { $0 + $1.feeling }) / Double(entries.count)
                        RuleMark(y: .value("Avg Mood", avg))
                            .foregroundStyle(Color.accentAmber.opacity(0.4))
                            .lineStyle(StrokeStyle(dash: [5, 5]))
                    }

                    if showSleep {
                        ForEach(entries, id: \.date) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Sleep", entry.sleepQuality),
                                series: .value("Type", "Sleep")
                            )
                            .foregroundStyle(Color.accentTeal)
                            .interpolationMethod(.catmullRom)
                        }
                    }

                    if showDrinks {
                        ForEach(entries, id: \.date) { entry in
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

    private var averageMood: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.feeling }) / Double(entries.count)
    }

    private var averageSleep: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.sleepQuality }) / Double(entries.count)
    }

    private var totalDrinks: Int {
        entries.reduce(0) { $0 + $1.drinks }
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
