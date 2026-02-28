import SwiftUI

struct GratitudePromptCard: View {
    @Binding var text: String

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.gratitude.iconName,
            iconColor: PromptStep.gratitude.iconColor,
            title: PromptStep.gratitude.title,
            subtitle: PromptStep.gratitude.subtitle
        ) {
            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(minHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentAmber.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What are you grateful for today?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
