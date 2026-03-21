import SwiftUI

// MARK: - Cross-platform compatibility helpers

#if os(macOS)

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

    // MARK: - iOS-only view modifier shims

    enum UIKeyboardType { case emailAddress, numberPad, phonePad }
    enum TextInputAutocapitalization { case never }

    extension View {
        func keyboardType(_: UIKeyboardType) -> some View { self }
        func textInputAutocapitalization(_: TextInputAutocapitalization?) -> some View { self }
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
