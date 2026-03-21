import SwiftUI

struct PromptProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accentAmber : Color.white.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}
