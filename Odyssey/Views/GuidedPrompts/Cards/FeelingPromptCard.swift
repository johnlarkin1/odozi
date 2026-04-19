import SwiftUI

struct FeelingPromptCard: View {
    @Binding var word: String
    @Binding var colorHex: String
    var focusedField: FocusState<PromptStep?>.Binding

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

                HStack(spacing: 8) {
                    TextField("A word or phrase...", text: $word)
                        .focused(focusedField, equals: .feeling)
                        .submitLabel(.done)
                        .onSubmit { focusedField.wrappedValue = nil }
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color(hex: colorHex))
                        .accessibilityLabel("Feeling word")
                        .accessibilityHint("Enter a word or phrase describing how you feel")

                    if !word.isEmpty {
                        Button {
                            word = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear feeling word")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardSurface)
                )
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focusedField.wrappedValue = nil }
                    }
                }
            }
        }
    }
}

/// 2D touch pad for picking a color — classic HSV picker.
/// - X axis controls hue (0.0 → 1.0)
/// - Y axis controls brightness (1.0 at top → 0.0 at bottom)
/// Saturation is fixed so the picker stays colorful and readable.
private struct ColorGridPicker: View {
    @Binding var colorHex: String
    @State private var pinLocation: CGPoint?

    private let fixedSaturation: CGFloat = 0.85

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Horizontal hue rainbow...
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .indigo, .purple, .pink, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                // ...faded down to black for the brightness axis.
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
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
            .accessibilityHint("Drag across the grid to choose a color. Up and down adjusts brightness; left and right adjusts hue.")
            .accessibilityValue("Current color: \(colorHex)")
        }
    }

    private func updateSelection(at rawPoint: CGPoint, in size: CGSize) {
        let x = max(0, min(rawPoint.x, size.width))
        let y = max(0, min(rawPoint.y, size.height))
        pinLocation = CGPoint(x: x, y: y)

        let hue = size.width > 0 ? x / size.width : 0
        let brightness = size.height > 0 ? 1 - (y / size.height) : 1
        let color = PlatformColor(
            hue: hue,
            saturation: fixedSaturation,
            brightness: brightness,
            alpha: 1.0
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
        let y: CGFloat = (1 - bright) * size.height
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
