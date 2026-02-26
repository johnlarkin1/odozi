import SwiftUI

struct MoodPromptCard: View {
    @Binding var feeling: Int

    private let moods: [(emoji: String, label: String, value: Int)] = [
        ("😢", "Awful", 1),
        ("😕", "Bad", 3),
        ("😐", "Okay", 5),
        ("🙂", "Good", 7),
        ("😊", "Great", 8),
        ("😄", "Amazing", 9),
        ("🤩", "Best Ever", 10)
    ]

    var body: some View {
        PromptCardContainer(
            emoji: PromptStep.mood.emoji,
            title: PromptStep.mood.title,
            subtitle: PromptStep.mood.subtitle
        ) {
            VStack(spacing: 24) {
                // Emoji selector
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(moods, id: \.value) { mood in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                feeling = mood.value
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.system(size: feeling == mood.value ? 48 : 36))
                                Text(mood.label)
                                    .font(.caption2)
                                    .foregroundStyle(feeling == mood.value ? .white : .secondary)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(feeling == mood.value ? Color.moodGradient(for: mood.value).opacity(0.3) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(feeling == mood.value ? Color.moodGradient(for: mood.value) : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }

                // Current value indicator
                Text("\(feeling) / 10")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.moodGradient(for: feeling))
            }
        }
    }
}
