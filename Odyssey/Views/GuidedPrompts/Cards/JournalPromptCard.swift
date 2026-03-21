import SwiftUI

struct JournalPromptCard: View {
    @Binding var text: String

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.journal.iconName,
            iconColor: PromptStep.journal.iconColor,
            title: PromptStep.journal.title,
            subtitle: PromptStep.journal.subtitle
        ) {
            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(16)
            #if os(macOS)
                .frame(minHeight: 200, maxHeight: .infinity)
            #else
                .frame(maxHeight: .infinity)
            #endif
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
                .accessibilityLabel("Journal entry")
                .accessibilityHint("Write your free-form journal entry")
        }
    }
}
