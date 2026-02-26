import SwiftUI

struct ShareableCardRenderer {
    @MainActor
    static func render<Content: View>(_ content: Content, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage? {
        let renderer = ImageRenderer(content:
            content
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
