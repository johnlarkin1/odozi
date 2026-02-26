import SwiftUI

struct SleepPromptCard: View {
    @Binding var sleepQuality: Int

    private let sleepLabels = [
        (1, "🌑", "Terrible"),
        (2, "🌑", "Very Poor"),
        (3, "🌘", "Poor"),
        (4, "🌗", "Below Avg"),
        (5, "🌗", "Average"),
        (6, "🌖", "Decent"),
        (7, "🌖", "Good"),
        (8, "🌕", "Great"),
        (9, "🌕", "Excellent"),
        (10, "⭐", "Perfect")
    ]

    var body: some View {
        PromptCardContainer(
            emoji: PromptStep.sleep.emoji,
            title: PromptStep.sleep.title,
            subtitle: PromptStep.sleep.subtitle
        ) {
            VStack(spacing: 32) {
                // Large display
                VStack(spacing: 8) {
                    Text(currentLabel.1)
                        .font(.system(size: 64))
                    Text(currentLabel.2)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.accentTeal)
                }

                // Custom slider
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(1...10, id: \.self) { value in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    sleepQuality = value
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(value <= sleepQuality ? Color.accentTeal : Color.white.opacity(0.15))
                                    .frame(height: 40)
                            }
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
                    .foregroundStyle(Color.accentTeal)
            }
        }
    }

    private var currentLabel: (Int, String, String) {
        sleepLabels.first { $0.0 == sleepQuality } ?? (5, "🌗", "Average")
    }
}
