import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer((try? DataContainer.previewContainer()) ?? {
            try! ModelContainer(for: DailyEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }())
        .environment(\.colorScheme, .dark)
}
