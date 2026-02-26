import SwiftUI

struct FeelingPromptCard: View {
    @Binding var word: String
    @Binding var colorHex: String

    private let colorOptions: [(name: String, hex: String)] = [
        ("Coral", "#E57373"),
        ("Rose", "#F06292"),
        ("Lavender", "#BA68C8"),
        ("Indigo", "#7986CB"),
        ("Sky", "#64B5F6"),
        ("Teal", "#4DB6AC"),
        ("Mint", "#81C784"),
        ("Lime", "#AED581"),
        ("Amber", "#FFD54F"),
        ("Orange", "#FFB74D"),
        ("Peach", "#FF8A65"),
        ("Sand", "#A1887F"),
        ("Silver", "#90A4AE"),
        ("Pearl", "#E0E0E0"),
        ("Snow", "#FFFFFF"),
        ("Night", "#546E7A"),
    ]

    var body: some View {
        PromptCardContainer(
            emoji: PromptStep.feeling.emoji,
            title: PromptStep.feeling.title,
            subtitle: PromptStep.feeling.subtitle
        ) {
            VStack(spacing: 24) {
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

                Text("Pick a color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(colorOptions, id: \.hex) { option in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                colorHex = option.hex
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: colorHex == option.hex ? 3 : 0)
                                )
                                .scaleEffect(colorHex == option.hex ? 1.15 : 1.0)
                        }
                    }
                }
            }
        }
    }
}
