import SwiftUI

struct AchievementUnlockBanner: View {
    let achievement: Achievement
    let additionalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tierGradient)
                    .frame(width: 48, height: 48)

                Image(systemName: achievement.iconName)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(achievement.achievementDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if additionalCount > 0 {
                Text("+\(additionalCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tierColor.opacity(0.6)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(tierColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private var tierColor: Color {
        switch achievement.tier {
        case 0: return .accentAmber
        case 1: return .accentTeal
        case 2: return .cosmicPurple
        default: return .accentAmber
        }
    }

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case 0: return LinearGradient(colors: [.accentAmber, .accentAmber.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 1: return LinearGradient(colors: [.accentTeal, .accentAmber], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: return LinearGradient(colors: [.cosmicPurple, .nebulaPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.accentAmber], startPoint: .top, endPoint: .bottom)
        }
    }
}
