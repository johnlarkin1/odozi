import SwiftUI
import WatchKit
import WidgetKit

struct CheckInConfirmationView: View {
    let moodScore: Int
    let feeling: String
    var onDismiss: () -> Void

    @State private var showCheck = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.successGreen)
                .scaleEffect(showCheck ? 1.0 : 0.5)
                .opacity(showCheck ? 1.0 : 0.0)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.moodGradient(for: moodScore))
                    .frame(width: 12, height: 12)
                Text("Mood: \(moodScore)/10")
                    .font(.caption)
            }

            if !feeling.isEmpty {
                Text(feeling.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Saved!")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.black.gradient, for: .tabView)
        .onAppear {
            WKInterfaceDevice.current().play(.success)
            WidgetCenter.shared.reloadAllTimelines()

            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheck = true
            }

            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onDismiss()
            }
        }
    }
}
