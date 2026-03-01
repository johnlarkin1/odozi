import SwiftUI

struct TrendArrow: View {
    let trend: TrendCalculator.Trend

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption2.weight(.bold))
            if trend.percentage > 0 {
                Text(String(format: "%.0f%%", trend.percentage))
                    .font(.caption2.weight(.medium))
                    .fontDesign(.rounded)
            }
        }
        .foregroundStyle(color)
    }

    private var iconName: String {
        switch trend.direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    private var color: Color {
        switch trend.direction {
        case .up: return .successGreen
        case .down: return .coralRed
        case .flat: return .secondary
        }
    }
}
