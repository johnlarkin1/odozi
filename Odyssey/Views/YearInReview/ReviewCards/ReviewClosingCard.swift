import SwiftUI

struct ReviewClosingCard: View {
    let year: Int
    let onDismiss: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentAmber.opacity(0.2), Color.accentTeal.opacity(0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if showContent {
                    VStack(spacing: 16) {
                        Text("⛵")
                            .font(.system(size: 64))

                        Text("Keep Sailing")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Your odyssey continues into \(String(year + 1))")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer()

                if showContent {
                    // Share button placeholder
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showContent = true
            }
        }
    }
}
