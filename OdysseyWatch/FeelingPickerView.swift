import SwiftUI

struct FeelingPickerView: View {
    var onSelect: (String) -> Void

    private let feelings: [(emoji: String, label: String)] = [
        ("grateful", "Grateful"),
        ("calm", "Calm"),
        ("stressed", "Stressed"),
        ("sad", "Sad"),
        ("excited", "Excited"),
        ("meh", "Meh")
    ]

    var body: some View {
        List {
            ForEach(feelings, id: \.label) { feeling in
                Button {
                    onSelect(feeling.label)
                } label: {
                    HStack {
                        Text(emoji(for: feeling.label))
                        Text(feeling.label)
                    }
                }
            }

            Button {
                // Custom dictation input — watchOS will show dictation UI
                onSelect("Custom")
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Custom...")
                }
                .foregroundStyle(Color.accentTeal)
            }
        }
        .navigationTitle("One word?")
    }

    private func emoji(for feeling: String) -> String {
        switch feeling.lowercased() {
        case "grateful": return "🙏"
        case "calm": return "😌"
        case "stressed": return "😤"
        case "sad": return "😢"
        case "excited": return "🤩"
        case "meh": return "😐"
        default: return "💭"
        }
    }
}
