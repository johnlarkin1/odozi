import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let container = (try? DataContainer.previewContainer()) ?? (try! ModelContainer(
        for: DailyEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ))
    ContentView()
        .modelContainer(container)
        .environment(\.colorScheme, .dark)
}
