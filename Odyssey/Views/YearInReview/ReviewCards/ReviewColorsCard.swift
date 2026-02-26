import SwiftUI

struct ReviewColorsCard: View {
    let colors: [String]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 8)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Your Color Fingerprint")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if colors.isEmpty {
                    Text("No colors recorded")
                        .foregroundStyle(.tertiary)
                } else {
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(Array(colors.prefix(64).enumerated()), id: \.offset) { _, hex in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: hex))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.horizontal, 32)

                    Text("\(Set(colors).count) unique colors")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Spacer()
            }
        }
    }
}
