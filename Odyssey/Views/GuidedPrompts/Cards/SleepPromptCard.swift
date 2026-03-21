import SwiftUI

struct SleepPromptCard: View {
    @Binding var sleepQuality: Int

    private let sleepLabels: [(value: Int, label: String)] = [
        (1, "Terrible"), (2, "Very Poor"), (3, "Poor"), (4, "Below Avg"),
        (5, "Average"), (6, "Decent"), (7, "Good"), (8, "Great"),
        (9, "Excellent"), (10, "Perfect")
    ]

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.sleep.iconName,
            iconColor: PromptStep.sleep.iconColor,
            title: PromptStep.sleep.title,
            subtitle: PromptStep.sleep.subtitle
        ) {
            VStack(spacing: 32) {
                Text(currentLabel)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(sleepColor(for: sleepQuality))

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(1 ... 10, id: \.self) { value in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    sleepQuality = value
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(value <= sleepQuality ? sleepColor(for: value) : Color.white.opacity(0.15))
                                    .frame(height: 40)
                            }
                            .accessibilityLabel("Sleep quality \(value) out of 10")
                            .accessibilityHint("Double tap to select")
                            .accessibilityValue(value == sleepQuality ? "Selected" : "Not selected")
                        }
                    }

                    HStack {
                        Text("Terrible")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Perfect")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(sleepQuality) / 10")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(sleepColor(for: sleepQuality))
            }
        }
    }

    private var currentLabel: String {
        sleepLabels.first { $0.value == sleepQuality }?.label ?? "Average"
    }

    private func sleepColor(for value: Int) -> Color {
        let t = Double(value - 1) / 9.0
        return Color(
            red: 0.90 - t * 0.72,
            green: 0.45 + t * 0.32,
            blue: 0.45 + t * 0.26
        )
    }
}
