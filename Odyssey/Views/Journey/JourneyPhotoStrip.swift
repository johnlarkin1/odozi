import PhotosUI
import SwiftUI

struct JourneyPhotoStrip: View {
    #if os(iOS)
        let autoThumbnails: [UIImage]
    #endif
    let attachedPhotoData: [Data]
    let isLoading: Bool
    var onAttachPhoto: ((Data) -> Void)?
    var onRemoveAttached: ((Int) -> Void)?

    #if os(iOS)
        @State private var selectedItem: PhotosPickerItem?
    #endif

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                #if os(iOS)
                    // Auto-surfaced photos
                    ForEach(Array(autoThumbnails.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                #endif

                // Attached photos
                ForEach(Array(attachedPhotoData.enumerated()), id: \.offset) { index, data in
                    #if os(macOS)
                        if let nsImage = NSImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentAmber.opacity(0.4), lineWidth: 1)
                                    )

                                Button {
                                    onRemoveAttached?(index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white, Color.black.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    #else
                        if let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentAmber.opacity(0.4), lineWidth: 1)
                                    )

                                Button {
                                    onRemoveAttached?(index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white, Color.black.opacity(0.6))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    #endif
                }

                #if os(iOS)
                    // Add button
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cardSurface)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            )
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                onAttachPhoto?(data)
                            }
                            selectedItem = nil
                        }
                    }
                #endif

                if isLoading {
                    ProgressView()
                        .frame(width: 64, height: 64)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
