import SwiftUI

extension Color {
    // Design tokens
    static let accentAmber = Color(red: 0.96, green: 0.65, blue: 0.14)     // #F5A623
    static let accentTeal = Color(red: 0.18, green: 0.77, blue: 0.71)      // #2EC4B6
    static let successGreen = Color(red: 0.30, green: 0.69, blue: 0.31)    // #4CAF50
    static let coralRed = Color(red: 0.90, green: 0.45, blue: 0.45)        // E57373
    static let cardSurface = Color(red: 0.11, green: 0.11, blue: 0.12)

    static func moodGradient(for value: Int) -> Color {
        let t = Double(max(1, min(10, value)) - 1) / 9.0
        if t < 0.5 {
            // Coral-red to amber
            let u = t / 0.5
            return Color(
                red: 1.0 - u * 0.04,
                green: 0.32 + u * 0.33,
                blue: 0.31 + u * 0.05
            )
        } else {
            // Amber to emerald-green
            let u = (t - 0.5) / 0.5
            return Color(
                red: 0.96 - u * 0.66,
                green: 0.65 + u * 0.04,
                blue: 0.36 - u * 0.05
            )
        }
    }

    init(hex: String) {
        let cleanedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleanedHex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}
