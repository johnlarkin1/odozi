import SwiftUI

struct MindTabView: View {
    let viewModel: InsightsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MindCardsGrid(viewModel: viewModel)
                    .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }
}
