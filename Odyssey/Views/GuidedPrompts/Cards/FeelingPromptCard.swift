import SwiftUI

struct FeelingPromptCard: View {
    @Binding var word: String
    @Binding var colorHex: String

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.feeling.iconName,
            iconColor: PromptStep.feeling.iconColor,
            title: PromptStep.feeling.title,
            subtitle: PromptStep.feeling.subtitle
        ) {
            VStack(spacing: 24) {
                Text("Pick a color that fits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ColorGridPicker(colorHex: $colorHex)
                    .frame(height: 180)

                TextField("A word or phrase...", text: $word)
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(hex: colorHex))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardSurface)
                    )
                    .accessibilityLabel("Feeling word")
                    .accessibilityHint("Enter a word or phrase describing how you feel")
            }
        }
    }
}

/// 2D touch pad for picking a color.
/// - X axis controls hue (0.0 → 1.0)
/// - Y axis controls alpha (1.0 at top → 0.0 at bottom)
/// Saturation and brightness are fixed so the picker stays readable.
private struct ColorGridPicker: View {
    @Binding var colorHex: String
    @State private var pinLocation: CGPoint?

    private let fixedSaturation: CGFloat = 0.6
    private let fixedBrightness: CGFloat = 0.85

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Checkerboard so transparency is visible.
                CheckerboardPattern()
                    .fill(Color.white.opacity(0.12))
                    .background(Color.black.opacity(0.25))

                // Hue gradient that fades to clear toward the bottom to
                // visualize the alpha axis.
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .indigo, .purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if let point = pinLocation {
                    PinIndicator(color: Color(hex: colorHex))
                        .position(point)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(at: value.location, in: geo.size)
                    }
            )
            .onAppear {
                if pinLocation == nil {
                    pinLocation = initialPinLocation(in: geo.size)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Color grid")
            .accessibilityHint("Drag across the grid to choose a color. Up and down adjusts transparency; left and right adjusts hue.")
            .accessibilityValue("Current color: \(colorHex)")
        }
    }

    private func updateSelection(at rawPoint: CGPoint, in size: CGSize) {
        let x = max(0, min(rawPoint.x, size.width))
        let y = max(0, min(rawPoint.y, size.height))
        pinLocation = CGPoint(x: x, y: y)

        let hue = size.width > 0 ? x / size.width : 0
        let alpha = size.height > 0 ? 1 - (y / size.height) : 1
        let color = PlatformColor(
            hue: hue,
            saturation: fixedSaturation,
            brightness: fixedBrightness,
            alpha: alpha
        )
        colorHex = color.toHexString()
    }

    /// Derive pin location from the current hex. Achromatic / default white
    /// lands the pin at the top-center.
    private func initialPinLocation(in size: CGSize) -> CGPoint {
        let platformColor = PlatformColor.fromHexString(colorHex)
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bright: CGFloat = 0
        var alpha: CGFloat = 1
        #if os(macOS)
        platformColor.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &sat, brightness: &bright, alpha: &alpha)
        #else
        platformColor.getHue(&hue, saturation: &sat, brightness: &bright, alpha: &alpha)
        #endif

        // If the stored color has no saturation (e.g. pure white default), we
        // can't recover a hue, so anchor the pin at top-center.
        let x: CGFloat = sat < 0.01 ? size.width / 2 : hue * size.width
        let y: CGFloat = (1 - alpha) * size.height
        return CGPoint(x: x, y: y)
    }
}

private struct PinIndicator: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 22, height: 22)
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                .frame(width: 24, height: 24)
        }
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
    }
}

/// Simple checkerboard used behind the hue gradient so the alpha axis is
/// visually apparent.
private struct CheckerboardPattern: Shape {
    var tile: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cols = Int((rect.width / tile).rounded(.up))
        let rows = Int((rect.height / tile).rounded(.up))
        for row in 0..<rows {
            for col in 0..<cols where (row + col).isMultiple(of: 2) {
                let square = CGRect(
                    x: CGFloat(col) * tile,
                    y: CGFloat(row) * tile,
                    width: tile,
                    height: tile
                )
                path.addRect(square)
            }
        }
        return path
    }
}
