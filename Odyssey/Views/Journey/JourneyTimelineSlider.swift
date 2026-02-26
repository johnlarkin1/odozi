import SwiftUI

struct JourneyTimelineSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let currentEntry: DailyEntry?
    let totalCount: Int
    var onChanged: ((Double) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if let entry = currentEntry {
                Text(entry.date.shortFormatted)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }

            Slider(value: $value, in: range, step: 1) { editing in
                if !editing {
                    onChanged?(value)
                }
            }
            .tint(Color.accentAmber)
            .onChange(of: value) { _, newValue in
                onChanged?(newValue)
            }

            Text("\(Int(value) + 1) of \(totalCount) days")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }
}
