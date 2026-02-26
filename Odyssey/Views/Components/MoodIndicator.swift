import SwiftUI

struct MoodIndicator: View {
    let feeling: Int
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(Color.moodGradient(for: feeling))
            .frame(width: size, height: size)
    }
}
