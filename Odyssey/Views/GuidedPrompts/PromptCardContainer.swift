import SwiftUI

struct PromptCardContainer<Content: View>: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }

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
