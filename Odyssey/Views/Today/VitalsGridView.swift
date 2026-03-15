import SwiftUI

struct VitalsGridView: View {
    let entry: DailyEntry?
    let streak: Int
    var animateIn: Bool = false

    @State private var cardsVisible = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            vitalCard(
                icon: "figure.walk",
                value: stepsValue,
                label: "Steps",
                color: .accentTeal,
                index: 0
            )
            vitalCard(
                icon: "moon.fill",
                value: sleepValue,
                label: "Sleep",
                color: .accentTeal,
                index: 1
            )
            vitalCard(
                icon: "iphone",
                value: screenTimeValue,
                label: "Screen Time",
                color: .coralRed,
                index: 2
            )
            vitalCard(
                icon: "flame.fill",
                value: streak > 0 ? "\(streak)" : "--",
                label: nextMilestoneLabel,
                color: .accentAmber,
                index: 3
            )
        }
        .onChange(of: animateIn) { _, newValue in
            if newValue {
                withAnimation {
                    cardsVisible = true
                }
            }
        }
    }

    private var stepsValue: String {
        if let steps = entry?.stepCount {
            return formatNumber(steps)
        }
        return "--"
    }

    private var sleepValue: String {
        if let hours = entry?.sleepHours {
            return String(format: "%.1fh", hours)
        }
        return "--"
    }

    private var screenTimeValue: String {
        if let entry = entry, entry.screenTimeSeconds != nil {
            return entry.screenTimeFormatted
        }
        return "--"
    }

    private var nextMilestoneLabel: String {
        let milestones = [3, 7, 14, 30, 60, 90, 180, 365]
        if let next = milestones.first(where: { $0 > streak }) {
            let remaining = next - streak
            if remaining == 1 {
                return "1 day to \(next)!"
            }
        }
        return "Day Streak"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(n)"
    }

    private func vitalCard(icon: String, value: String, label: String, color: Color, index: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(value == "--" ? Color.secondary : Color.white)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
        )
        .scaleEffect(cardsVisible ? 1 : 0.8)
        .opacity(cardsVisible ? 1 : 0)
        .animation(
            .easeOut(duration: 0.4).delay(Double(index) * 0.05),
            value: cardsVisible
        )
    }
}
