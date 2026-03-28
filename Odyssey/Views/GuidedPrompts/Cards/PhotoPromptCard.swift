import PhotosUI
import SwiftUI

struct PhotoPromptCard: View {
    @Binding var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PromptCardContainer(
            iconName: PromptStep.photo.iconName,
            iconColor: PromptStep.photo.iconColor,
            title: PromptStep.photo.title,
            subtitle: PromptStep.photo.subtitle
        ) {
            #if os(iOS)
                if let photoData, let uiImage = UIImage(data: photoData) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 280, maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                            )

                        Button {
                            self.photoData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, Color.black.opacity(0.6))
                        }
                        .offset(x: 8, y: -8)
                    }
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.purple.opacity(0.7))

                            Text("Tap to add a photo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: 280, minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.cardSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                        )
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                            selectedItem = nil
                        }
                    }
                }
            #else
                Text("Photo attachment is available on iPhone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            #endif
        }
    }
}
