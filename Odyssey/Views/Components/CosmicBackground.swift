import SwiftUI

struct CosmicBackground: ViewModifier {
    @State private var twinklePhase: Double = 0

    private static let stars: [(x: Double, y: Double, size: Double, brightness: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 42)
        return (0..<40).map { _ in
            (
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                size: Double.random(in: 1...2.5, using: &rng),
                brightness: Double.random(in: 0.3...1.0, using: &rng)
            )
        }
    }()

    func body(content: Content) -> some View {
        content
            .background {
                Canvas { context, size in
                    // Deep space gradient
                    let gradient = Gradient(colors: [.deepSpaceBlue, Color(red: 0.08, green: 0.06, blue: 0.18)])
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
                    )

                    // Stars with twinkle
                    for star in Self.stars {
                        let twinkle = sin(twinklePhase * 0.5 + star.brightness * 6.28) * 0.3 + 0.7
                        let opacity = star.brightness * twinkle
                        let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
                        let starSize = star.size

                        context.opacity = opacity
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: point.x - starSize / 2,
                                y: point.y - starSize / 2,
                                width: starSize,
                                height: starSize
                            )),
                            with: .color(.starWhite)
                        )
                    }
                }
                .drawingGroup()
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        twinklePhase = .pi * 2
                    }
                }
            }
    }
}

extension View {
    func cosmicBackground() -> some View {
        modifier(CosmicBackground())
    }
}

// Deterministic RNG for consistent star positions
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
