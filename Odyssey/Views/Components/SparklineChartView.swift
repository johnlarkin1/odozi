import SwiftUI
import Charts

struct SparklineChartView: View {
    let data: [(Date, Double)]
    let color: Color
    @State private var revealFraction: CGFloat = 0

    var body: some View {
        Chart {
            ForEach(data, id: \.0) { point in
                LineMark(
                    x: .value("Date", point.0),
                    y: .value("Value", point.1)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.0),
                    y: .value("Value", point.1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 40)
        .mask(
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * revealFraction)
            }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                revealFraction = 1
            }
        }
    }
}
