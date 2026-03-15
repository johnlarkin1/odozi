import SwiftUI

struct ColorPaletteView: View {
    let colors: [String]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if colors.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No colors yet")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 80)
                } else {
                    Text("Your Feeling Colors")
                        .font(.title2.bold())
                        .padding(.horizontal, 16)

                    // Mosaic grid
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { _, hex in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: hex))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Unique colors count
                    let uniqueCount = Set(colors).count
                    Text("\(uniqueCount) unique colors from \(colors.count) entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)
        }
        .navigationTitle("Color Palette")
        .cosmicBackground()
    }
}
