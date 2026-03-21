import Charts
import SwiftUI

struct ReviewMoodCard: View {
    let averageMood: Double
    let moodByMonth: [(month: String, avgMood: Double)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.moodGradient(for: Int(averageMood)).opacity(0.3), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Average Mood")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.1f", averageMood))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.moodGradient(for: Int(averageMood)))

                Text("out of 10")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                // Mini sparkline
                Chart(moodByMonth, id: \.month) { data in
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Mood", data.avgMood)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentAmber)

                    AreaMark(
                        x: .value("Month", data.month),
                        y: .value("Mood", data.avgMood)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentAmber.opacity(0.1))
                }
                .chartYScale(domain: 0 ... 10)
                .frame(height: 120)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}
