import os
import PhotosUI
import SwiftUI

private let photoPromptLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "PhotoPrompt")

struct PhotoPromptCard: View {
    @Binding var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingError = false
    @State private var errorMessage = ""

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
                                    .stroke(Color.cosmicPurple.opacity(0.4), lineWidth: 1)
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
                } else if photoData != nil {
                    // photoData exists but UIImage(data:) failed -- corrupted/unsupported
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.coralRed.opacity(0.7))
                        Text("This photo could not be displayed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Try a different image") {
                            self.photoData = nil
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cosmicPurple)
                    }
                    .frame(maxWidth: 280, minHeight: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardSurface)
                    )
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.cosmicPurple.opacity(0.7))

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
                                .stroke(Color.cosmicPurple.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                        )
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            guard let newItem else { return }
                            do {
                                guard let data = try await newItem.loadTransferable(type: Data.self) else {
                                    photoPromptLogger.warning("Photo transferable returned nil (unsupported format)")
                                    errorMessage = "This photo format isn't supported. Please try a different image."
                                    showingError = true
                                    return
                                }
                                photoData = PhotoLibraryService.compressForStorage(data: data)
                            } catch {
                                photoPromptLogger.error("Failed to load photo: \(error)")
                                errorMessage = "Could not load photo. Please try a different image."
                                showingError = true
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
        .alert("Photo Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}
