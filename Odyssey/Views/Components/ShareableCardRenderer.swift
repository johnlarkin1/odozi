import SwiftUI

enum ShareableCardRenderer {
    /// Standard share card size — 9:19.5 aspect ratio matching iPhone Pro dimensions.
    /// Used as a consistent canvas for all shareable card renders.
    private static let standardShareCardSize = CGSize(width: 390, height: 844)

    /// Render scale for share cards. Uses 3x Retina as a safe default that produces
    /// high-quality output suitable for sharing on any device.
    private static let shareRenderScale: CGFloat = 3.0

    #if os(macOS)
        @MainActor
        static func render<Content: View>(_ content: Content, size: CGSize = standardShareCardSize) -> NSImage? {
            let renderer = ImageRenderer(content:
                content
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, .dark)
            )
            renderer.scale = shareRenderScale
            return renderer.nsImage
        }
    #else
        @MainActor
        static func render<Content: View>(_ content: Content, size: CGSize = standardShareCardSize) -> UIImage? {
            let renderer = ImageRenderer(content:
                content
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, .dark)
            )
            renderer.scale = shareRenderScale
            return renderer.uiImage
        }
    #endif
}
