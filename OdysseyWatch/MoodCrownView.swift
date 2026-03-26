import SwiftUI

struct MoodCrownView: View {
    @Binding var moodScore: Double
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("How are you?")
                .font(.headline)

            ZStack {
                Circle()
                    .fill(Color.moodGradient(for: Int(moodScore)).opacity(0.3))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Color.moodGradient(for: Int(moodScore)))
                    .frame(width: 60, height: 60)

                Text("\(Int(moodScore))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(moodLabel)
                .font(.caption)
                .foregroundStyle(Color.moodGradient(for: Int(moodScore)))

            Button {
                onConfirm()
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                    PhosphorIcon.arrowRightFill.image
                        .frame(width: 12, height: 12)
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.accentTeal, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .focusable()
        .digitalCrownRotation(
            $moodScore,
            from: 1,
            through: 10,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .containerBackground(.black.gradient, for: .tabView)
    }

    private var moodLabel: String {
        switch Int(moodScore) {
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
