import SwiftUI

struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("odyssey_1")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 12) {
                Text("Welcome to Odyssey")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)

                Text("Track your mental wellness journey with daily reflections, health data, and beautiful visualizations.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
