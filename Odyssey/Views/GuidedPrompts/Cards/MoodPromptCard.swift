import SwiftUI

struct MoodPromptCard: View {
    @Binding var feeling: Int

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.mood.iconName,
            iconColor: PromptStep.mood.iconColor,
            title: PromptStep.mood.title,
            subtitle: PromptStep.mood.subtitle
        ) {
            VStack(spacing: 32) {
                Text(moodLabel)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.moodGradient(for: feeling))

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(1 ... 10, id: \.self) { value in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    feeling = value
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(value <= feeling ? Color.moodGradient(for: value) : Color.white.opacity(0.15))
                                    .frame(height: 40)
                            }
                            .accessibilityLabel("Mood score \(value) out of 10")
                            .accessibilityHint("Double tap to select")
                            .accessibilityValue(value == feeling ? "Selected" : "Not selected")
                        }
                    }

                    HStack {
                        Text("Awful")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Best Ever")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(feeling) / 10")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.moodGradient(for: feeling))
            }
        }
    }

    private var moodLabel: String {
        switch feeling {
        case 1: return "Awful"
        case 2: return "Very Bad"
        case 3: return "Bad"
        case 4: return "Below Avg"
        case 5: return "Okay"
        case 6: return "Decent"
        case 7: return "Good"
        case 8: return "Great"
        case 9: return "Amazing"
        case 10: return "Best Ever"
        default: return "Okay"
        }
    }
}
