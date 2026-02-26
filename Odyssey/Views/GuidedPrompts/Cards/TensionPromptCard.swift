import SwiftUI

struct TensionPromptCard: View {
    @Binding var text: String

    var body: some View {
        PromptCardContainer(
            emoji: PromptStep.tension.emoji,
            title: PromptStep.tension.title,
            subtitle: PromptStep.tension.subtitle
        ) {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(minHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.coralRed.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What's weighing on you?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
