import SwiftUI

struct ReviewEntryCountCard: View {
    let count: Int
    let percentage: Double

    @State private var animatedCount = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentAmber.opacity(0.2), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("You showed up")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("\(animatedCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentAmber)
                    .contentTransition(.numericText(value: Double(animatedCount)))

                Text("days this year")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)

                Text(String(format: "%.0f%% of the year", percentage))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                animatedCount = count
            }
        }
    }
}
