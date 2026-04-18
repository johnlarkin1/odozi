import SwiftUI

struct ReviewTitleCard: View {
    let year: Int

    @State private var showTitle = false
    @State private var showSubtitle = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentAmber.opacity(0.3), Color.accentTeal.opacity(0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                LottieView(lottieFile: "rotating_earth", loopMode: .loop)
                    .frame(width: 200, height: 200)

                if showTitle {
                    Text("Your \(String(year))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showSubtitle {
                    Text("Odozi")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(Color.accentAmber)
                        .transition(.opacity)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { showTitle = true }
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) { showSubtitle = true }
        }
    }
}
