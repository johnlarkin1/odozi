import SwiftUI

/// A grid that adapts its column count based on available width.
/// On narrow screens (iPhone) it shows 2 columns; on wider screens (macOS / iPad)
/// it expands to 3 or 4 columns automatically.
struct AdaptiveGrid<Content: View>: View {
    var minColumnWidth: CGFloat = 160
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        WidthReader { width in
            let count = max(2, Int(width / minColumnWidth))
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: spacing),
                count: count
            )
            LazyVGrid(columns: columns, spacing: spacing) {
                content()
            }
        }
    }
}

/// Reads the available width without affecting layout height.
/// Unlike GeometryReader, this doesn't collapse to zero height.
private struct WidthReader<Content: View>: View {
    @ViewBuilder var content: (CGFloat) -> Content
    @State private var width: CGFloat = 320

    var body: some View {
        content(width)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(WidthPreferenceKey.self) { newWidth in
                if newWidth > 0 {
                    width = newWidth
                }
            }
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}
