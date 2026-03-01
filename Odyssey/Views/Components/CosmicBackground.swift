import SwiftUI

// Isolated view — keeps TimelineView redraws from invalidating parent content
private struct CosmicCanvasView: View {
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

    private static let shootingStars: [(startX: Double, startY: Double, dx: Double, dy: Double, length: Double)] = {
        var rng = SeededRandomNumberGenerator(seed: 99)
        return (0..<12).map { _ in
            let startX = Double.random(in: 0.1...0.9, using: &rng)
            let startY = Double.random(in: 0.05...0.4, using: &rng)
            let angle = Double.random(in: 0.4...1.0, using: &rng)
            return (
                startX: startX,
                startY: startY,
                dx: cos(angle),
                dy: sin(angle),
                length: Double.random(in: 0.1...0.18, using: &rng)
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Deep space gradient
                let gradient = Gradient(colors: [.deepSpaceBlue, Color(red: 0.08, green: 0.06, blue: 0.18)])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
                )

                // Stars with twinkle
                let twinklePhase = time * (2 * .pi / 8)
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

                // Shooting stars
                let interval: Double = 7
                let duration: Double = 1.0
                let cycleIndex = Int(time / interval) % Self.shootingStars.count
                let elapsed = time.truncatingRemainder(dividingBy: interval)
                let t = elapsed / duration

                if t <= 1 {
                    let config = Self.shootingStars[cycleIndex]

                    let headX = (config.startX + config.dx * config.length * t) * size.width
                    let headY = (config.startY + config.dy * config.length * t) * size.height

                    let tailLen = config.length * 0.5 * size.width

                    let fadeIn = min(t * 5, 1.0)
                    let fadeOut = t > 0.6 ? max(1 - (t - 0.6) / 0.4, 0) : 1.0
                    let fade = fadeIn * fadeOut

                    // Tail segments with decreasing brightness
                    let segments = 5
                    for i in 0..<segments {
                        let segStart = Double(i) / Double(segments)
                        let segEnd = Double(i + 1) / Double(segments)

                        let sx = headX - config.dx * tailLen * segEnd
                        let sy = headY - config.dy * tailLen * segEnd
                        let ex = headX - config.dx * tailLen * segStart
                        let ey = headY - config.dy * tailLen * segStart

                        context.opacity = fade * (1 - segStart) * 0.7
                        var segPath = Path()
                        segPath.move(to: CGPoint(x: sx, y: sy))
                        segPath.addLine(to: CGPoint(x: ex, y: ey))
                        context.stroke(
                            segPath,
                            with: .color(.starWhite),
                            lineWidth: 1.5 * (1 - segStart * 0.6)
                        )
                    }

                    // Bright head
                    context.opacity = fade
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: headX - 2, y: headY - 2,
                            width: 4, height: 4
                        )),
                        with: .color(.starWhite)
                    )
                }
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
    }
}

struct CosmicBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background { CosmicCanvasView() }
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
