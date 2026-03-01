import SwiftUI

struct CosmicCardStyle: ViewModifier {
    var accentColor: Color = .cosmicPurple
    @State private var glowPhase: Double = 0

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(0.08), Color.cardSurface],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: accentColor.opacity(0.15 + 0.1 * sin(glowPhase)), radius: 8, x: 0, y: 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    glowPhase = .pi
                }
            }
    }
}

extension View {
    func cosmicCard(accent: Color = .cosmicPurple) -> some View {
        modifier(CosmicCardStyle(accentColor: accent))
    }
}
