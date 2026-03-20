import SwiftUI

struct MoodCrownView: View {
    @Binding var moodScore: Double
    var onConfirm: () -> Void

    @State private var isFocused = false

    var body: some View {
        VStack(spacing: 8) {
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

            Text("/10")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Turn Crown")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
        .onTapGesture {
            onConfirm()
        }
        .containerBackground(.black.gradient, for: .tabView)
    }
}
