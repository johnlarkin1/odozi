import SwiftUI

struct WelcomeCard: View {
    @State private var showIcon = false
    @State private var showText = false
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated sailboat with floating effect
            Image(systemName: "sailboat.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentAmber, .accentAmber.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .accentAmber.opacity(0.4), radius: 20, y: 4)
                .offset(y: floatOffset)
                .scaleEffect(showIcon ? 1 : 0.5)
                .opacity(showIcon ? 1 : 0)

            VStack(spacing: 12) {
                Text("Your Odyssey Begins")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text("A space for daily reflection. Track how you feel, where you've been, and where you're going.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 12)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.2)) {
                showIcon = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                showText = true
            }
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                floatOffset = -8
            }
        }
    }
}
