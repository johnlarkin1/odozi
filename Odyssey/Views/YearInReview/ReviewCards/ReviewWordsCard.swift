import SwiftUI

struct ReviewWordsCard: View {
    let words: [(word: String, count: Int)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.black],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Your Words")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    ForEach(words.prefix(5), id: \.word) { item in
                        Text(item.word)
                            .font(.system(size: fontSize(for: item), weight: .bold, design: .rounded))
                            .foregroundStyle(colorFor(item.word))
                    }
                }

                Spacer()
                Spacer()
            }
        }
    }

    private func fontSize(for item: (word: String, count: Int)) -> CGFloat {
        let maxCount = words.first?.count ?? 1
        let ratio = Double(item.count) / Double(max(maxCount, 1))
        return 24 + ratio * 32
    }

    private func colorFor(_ word: String) -> Color {
        let colors: [Color] = [.accentAmber, .accentTeal, .coralRed, .successGreen, .purple]
        let index = abs(word.hashValue) % colors.count
        return colors[index]
    }
}
