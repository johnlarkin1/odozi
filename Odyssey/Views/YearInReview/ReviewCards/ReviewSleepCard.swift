import SwiftUI

struct ReviewSleepCard: View {
    let averageSleep: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentTeal.opacity(0.3), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("🌙")
                    .font(.system(size: 64))

                Text("Sleep Quality")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.1f", averageSleep))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentTeal)

                Text("average out of 10")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Spacer()
                Spacer()
            }
        }
    }
}
