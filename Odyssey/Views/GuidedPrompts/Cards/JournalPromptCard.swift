import SwiftUI

struct JournalPromptCard: View {
    @Binding var text: String

    var body: some View {
        PromptCardContainer(
            emoji: PromptStep.journal.emoji,
            title: PromptStep.journal.title,
            subtitle: PromptStep.journal.subtitle
        ) {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardSurface)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Write freely...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
