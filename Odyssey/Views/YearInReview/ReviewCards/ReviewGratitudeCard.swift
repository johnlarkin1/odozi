import SwiftUI

struct ReviewGratitudeCard: View {
    let gratitudes: [String]

    @State private var visibleCount = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentAmber.opacity(0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Moments of Gratitude")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(gratitudes.prefix(5).enumerated()), id: \.offset) { index, text in
                        if index < visibleCount {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(text)
                                    .font(.body)
                                    .foregroundStyle(.white)
                            }
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            for i in 0 ..< min(5, gratitudes.count) {
                withAnimation(.easeOut(duration: 0.5).delay(Double(i) * 0.3)) {
                    visibleCount = i + 1
                }
            }
        }
    }
}
