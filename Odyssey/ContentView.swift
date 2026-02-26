import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(try! DataContainer.previewContainer())
        .environment(\.colorScheme, .dark)
}
