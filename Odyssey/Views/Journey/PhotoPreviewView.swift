import Photos
import SwiftUI

struct PhotoPreviewView: View {
    let source: ImageSource

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGFloat = 0

    enum ImageSource: Identifiable {
        case asset(PHAsset)
        case data(Data)

        var id: String {
            switch self {
            case let .asset(asset): asset.localIdentifier
            case let .data(data): "\(data.hashValue)"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height + dragOffset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                lastScale = max(scale, 1.0)
                                scale = lastScale
                                if scale == 1.0 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        offset = .zero
                                    }
                                    lastOffset = .zero
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                } else {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { _ in
                                if scale > 1.0 {
                                    lastOffset = offset
                                } else {
                                    if abs(dragOffset) > 100 {
                                        dismiss()
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 3.0
                                lastScale = 3.0
                            }
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .opacity(image != nil ? 1.0 - min(abs(dragOffset) / 300, 0.5) : 1.0)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, Color.black.opacity(0.6))
                    .padding(16)
            }
        }
        .task {
            switch source {
            case let .asset(asset):
                image = await PhotoLibraryService.shared.loadFullImage(for: asset)
            case let .data(data):
                image = UIImage(data: data)
            }
        }
        .statusBarHidden()
    }
}
