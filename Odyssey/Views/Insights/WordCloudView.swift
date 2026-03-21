import SwiftUI

struct WordCloudView: View {
    let words: [(word: String, count: Int)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if words.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "textformat")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No feeling words yet")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 80)
                } else {
                    // Word display
                    FlowLayout(spacing: 12) {
                        ForEach(words, id: \.word) { item in
                            Text(item.word)
                                .font(.system(size: fontSize(for: item.count), weight: .bold, design: .rounded))
                                .foregroundStyle(colorForWord(item.word))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorForWord(item.word).opacity(0.15))
                                )
                        }
                    }
                    .padding(16)

                    // Frequency list
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(words, id: \.word) { item in
                            HStack {
                                Text(item.word)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text("\(item.count)x")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .navigationTitle("Feeling Words")
        .cosmicBackground()
    }

    private func fontSize(for count: Int) -> CGFloat {
        let maxCount = words.first?.count ?? 1
        let ratio = Double(count) / Double(max(maxCount, 1))
        return 16 + ratio * 32
    }

    private func colorForWord(_ word: String) -> Color {
        let colors: [Color] = [.accentAmber, .accentTeal, .coralRed, .successGreen, .purple, .cyan, .mint, .orange]
        // DJB2 hash — stable across launches (unlike hashValue which is randomized per-process)
        var hash = 5381
        for byte in word.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ Int(byte)
        }
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

// Simple flow layout for word cloud
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
