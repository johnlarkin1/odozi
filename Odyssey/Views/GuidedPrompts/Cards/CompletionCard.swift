import SwiftUI

struct CompletionCard: View {
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var showMessage = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.successGreen)
                        .transition(.scale.combined(with: .opacity))
                }

                if showMessage {
                    VStack(spacing: 12) {
                        Text("Entry Saved")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)

                        Text("Keep sailing on your odyssey")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }

                Spacer()

                if showButton {
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showCheckmark = true
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.6)) {
                showMessage = true
            }
            withAnimation(.easeInOut(duration: 0.4).delay(1.2)) {
                showButton = true
            }
        }
    }
}
