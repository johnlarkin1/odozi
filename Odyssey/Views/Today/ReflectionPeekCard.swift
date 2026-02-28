import SwiftUI

struct ReflectionPeekCard: View {
    let entry: DailyEntry?
    var animateIn: Bool = false

    var body: some View {
        if let (icon, label, text, color) = reflectionContent {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(color)
                        Text(label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(color)
                    }

                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSurface)
            )
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.65), value: animateIn)
        }
    }

    private var reflectionContent: (String, String, String, Color)? {
        guard let entry = entry else { return nil }

        if !entry.gratitude.isEmpty {
            return ("heart.fill", "Today's Gratitude", entry.gratitude, .accentAmber)
        }
        if !entry.win.isEmpty {
            return ("star.fill", "Today's Win", entry.win, .successGreen)
        }
        return nil
    }
}
