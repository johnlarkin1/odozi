import SwiftUI

struct DrinksPromptCard: View {
    @Binding var drinks: Int

    var body: some View {
        PromptCardContainer(
            emoji: PromptStep.drinks.emoji,
            title: PromptStep.drinks.title,
            subtitle: PromptStep.drinks.subtitle
        ) {
            VStack(spacing: 32) {
                Text("\(drinks)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(drinks == 0 ? Color.successGreen : Color.accentAmber)
                    .contentTransition(.numericText(value: Double(drinks)))

                HStack(spacing: 40) {
                    // Minus button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if drinks > 0 { drinks -= 1 }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(drinks > 0 ? Color.white : Color.white.opacity(0.3))
                    }
                    .disabled(drinks == 0)

                    // Plus button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if drinks < 20 { drinks += 1 }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.white)
                    }
                    .disabled(drinks >= 20)
                }

                if drinks == 0 {
                    Text("Nice! Staying dry tonight")
                        .font(.subheadline)
                        .foregroundStyle(Color.successGreen)
                }
            }
        }
    }
}
