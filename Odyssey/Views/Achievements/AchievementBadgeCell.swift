import SwiftUI

struct AchievementBadgeCell: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? tierGradient : lockedGradient)
                    .frame(width: 64, height: 64)

                Image(systemName: achievement.iconName)
                    .font(.title2)
                    .foregroundStyle(achievement.isUnlocked ? .white : .secondary.opacity(0.4))
            }
            .overlay(alignment: .topTrailing) {
                if achievement.isNew {
                    Circle()
                        .fill(Color.coralRed)
                        .frame(width: 12, height: 12)
                        .offset(x: 2, y: -2)
                }
            }

            Text(achievement.isUnlocked ? achievement.title : "???")
                .font(.caption2.weight(.medium))
                .foregroundStyle(achievement.isUnlocked ? .white : .secondary)
                .lineLimit(1)
        }
    }

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case 0: return LinearGradient(
                colors: [.accentAmber.opacity(0.3), .accentAmber.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case 1: return LinearGradient(
                colors: [.accentTeal.opacity(0.3), .accentAmber.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case 2: return LinearGradient(
                colors: [.cosmicPurple.opacity(0.3), .nebulaPink.opacity(0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        default: return LinearGradient(colors: [.accentAmber.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var lockedGradient: LinearGradient {
        LinearGradient(colors: [Color.cardSurface, Color.cardSurface.opacity(0.5)], startPoint: .top, endPoint: .bottom)
    }
}
