import SwiftUI

struct EmojiMoodSelector: View {
    @Binding var selectedMood: Int

    private let moods: [(emoji: String, value: Int)] = [
        ("😢", 1), ("😕", 3), ("😐", 5), ("🙂", 7), ("😊", 8), ("😄", 9), ("🤩", 10)
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(moods, id: \.value) { mood in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedMood = mood.value
                    }
                } label: {
                    Text(mood.emoji)
                        .font(.system(size: selectedMood == mood.value ? 36 : 28))
                        .opacity(selectedMood == mood.value ? 1.0 : 0.5)
                }
            }
        }
    }
}
