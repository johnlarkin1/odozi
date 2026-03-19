import SwiftUI

// MARK: - Cross-platform compatibility helpers

#if os(macOS)
extension View {
    /// No-op on macOS — iOS-only navigation bar title display mode.
    func navigationBarTitleDisplayMode(_ mode: Any) -> some View {
        self
    }
}

extension ToolbarItemPlacement {
    /// Maps iOS topBarTrailing to macOS automatic placement.
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
    /// Maps iOS topBarLeading to macOS automatic placement.
    static var topBarLeading: ToolbarItemPlacement { .automatic }
}

/// PlatformImage typealias for cross-platform image handling.
typealias PlatformImage = NSImage

extension Image {
    /// Create an Image from platform-native image data.
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}

#else

typealias PlatformImage = UIImage

extension Image {
    /// Create an Image from platform-native image data.
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif
