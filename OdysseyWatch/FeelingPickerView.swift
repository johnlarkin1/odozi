import SwiftUI

struct FeelingPickerView: View {
    var onSelect: (String) -> Void

    private let feelings: [(icon: PhosphorIcon, label: String, color: Color)] = [
        (.heartFill, "Grateful", .accentAmber),
        (.leafFill, "Calm", .accentTeal),
        (.lightningFill, "Stressed", .coralRed),
        (.cloudRainFill, "Sad", Color(.sRGB, red: 0.39, green: 0.71, blue: 0.96, opacity: 1)),
        (.starFill, "Excited", .successGreen),
        (.minusCircleFill, "Meh", .secondary),
        (.wavesFill, "Anxious", .coralRed.opacity(0.8)),
        (.sunFill, "Hopeful", .accentAmber.opacity(0.8)),
    ]

    var body: some View {
        List {
            ForEach(feelings, id: \.label) { feeling in
                Button {
                    onSelect(feeling.label)
                } label: {
                    HStack(spacing: 10) {
                        feeling.icon.image
                            .frame(width: 18, height: 18)
                            .foregroundStyle(feeling.color)
                        Text(feeling.label)
                            .foregroundStyle(.primary)
                    }
                }
            }

            Button {
                onSelect("Custom")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .frame(width: 18, height: 18)
                    Text("Custom...")
                }
                .foregroundStyle(Color.accentTeal)
            }
        }
        .navigationTitle("One word?")
    }
}
