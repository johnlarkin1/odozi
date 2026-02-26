import SwiftUI

struct WinPromptCard: View {
    @Binding var text: String

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.win.iconName,
            iconColor: PromptStep.win.iconColor,
            title: PromptStep.win.title,
            subtitle: PromptStep.win.subtitle
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
                        .stroke(Color.successGreen.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What's one thing that went well?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
