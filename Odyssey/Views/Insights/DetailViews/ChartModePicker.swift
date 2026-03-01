import SwiftUI

struct ChartModePicker: View {
    @Binding var selection: ChartMode
    let availableModes: [ChartMode]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(availableModes) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.caption2)
                        Text(mode.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selection == mode ? Color.cosmicPurple.opacity(0.4) : Color.cardSurface)
                    )
                    .foregroundStyle(selection == mode ? .white : .secondary)
                }
            }
        }
    }
}
