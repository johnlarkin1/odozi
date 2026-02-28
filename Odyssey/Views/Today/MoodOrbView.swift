import SwiftUI

struct MoodOrbView: View {
    let entry: DailyEntry?
    let hasEntry: Bool
    let onBeginEntry: () -> Void
    var animateIn: Bool = false

    @State private var pulse = false

    var body: some View {
        if hasEntry, let entry = entry {
            completedState(entry: entry)
        } else {
            emptyState
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                // Dashed circle border
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Color.accentAmber.opacity(0.3))
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.02 : 1.0)

                // Pulsing icon
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentAmber)
                    .opacity(pulse ? 0.8 : 0.4)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(spacing: 6) {
                Text("How are you today?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Take a moment to reflect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.easeInOut(duration: 0.4).delay(0.45), value: animateIn)

            Button(action: onBeginEntry) {
                Text("Begin Today's Entry")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeInOut(duration: 0.4).delay(0.45), value: animateIn)
        }
        .scaleEffect(animateIn ? 1 : 0.8)
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15), value: animateIn)
    }

    // MARK: - Completed State

    private func completedState(entry: DailyEntry) -> some View {
        let moodColor = Color.moodGradient(for: entry.feeling)

        return VStack(spacing: 16) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(moodColor.opacity(0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 100)

                // Main orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [moodColor, moodColor.opacity(0.15)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)

                // Mood number
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(entry.feeling)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("/10")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .scaleEffect(animateIn ? 1 : 0.5)
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15), value: animateIn)

            VStack(spacing: 4) {
                if !entry.singleWordFeeling.isEmpty {
                    Text(entry.singleWordFeeling)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(entry.feelingColor)
                }
                Text(entry.moodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.easeInOut(duration: 0.4).delay(0.45), value: animateIn)

            Button(action: onBeginEntry) {
                HStack(spacing: 4) {
                    Text("Edit Entry")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.easeInOut(duration: 0.4).delay(0.45), value: animateIn)
        }
    }
}
