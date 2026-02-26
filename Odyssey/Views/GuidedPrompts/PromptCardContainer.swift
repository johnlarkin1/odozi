import SwiftUI

struct PromptCardContainer<Content: View>: View {
    let emoji: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(emoji)
                .font(.system(size: 56))

            Text(title)
                .font(.title3.bold())
                .fontDesign(.rounded)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content()
                .padding(.top, 8)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
