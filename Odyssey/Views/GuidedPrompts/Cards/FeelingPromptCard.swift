import SwiftUI

struct FeelingPromptCard: View {
    @Binding var word: String
    @Binding var colorHex: String

    private let neutrals: [(name: String, hex: String)] = [
        ("Sand", "#A1887F"),
        ("Silver", "#90A4AE"),
        ("Pearl", "#E0E0E0"),
        ("Snow", "#FFFFFF"),
        ("Night", "#546E7A")
    ]

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

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .indigo, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = max(0, min(value.location.x, geo.size.width))
                                    let hue = x / geo.size.width
                                    let color = PlatformColor(hue: hue, saturation: 0.6, brightness: 0.85, alpha: 1.0)
                                    colorHex = color.toHexString()
                                }
                        )
                        .accessibilityLabel("Color picker gradient")
                        .accessibilityHint("Drag left or right to choose a feeling color")
                        .accessibilityValue("Current color: \(colorHex)")
                }
                .frame(height: 36)

                HStack(spacing: 12) {
                    ForEach(neutrals, id: \.hex) { option in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                colorHex = option.hex
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: colorHex == option.hex ? 2 : 0)
                                )
                        }
                        .accessibilityLabel("\(option.name) color")
                        .accessibilityHint("Double tap to select")
                        .accessibilityValue(colorHex == option.hex ? "Selected" : "Not selected")
                    }
                }

                TextField("One word...", text: $word)
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
                    .accessibilityHint("Enter a single word describing how you feel")
            }
        }
    }
}
