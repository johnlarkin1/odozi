import os
import Photos
import UIKit

private let photoLibraryLogger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "PhotoLibrary")

actor PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private init() {}

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchAssets(for date: Date) -> [PHAsset] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.fetchLimit = 20

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func loadThumbnail(for asset: PHAsset, targetSize: CGSize = CGSize(width: 200, height: 200)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func loadJpegData(for asset: PHAsset, compressionQuality: CGFloat = 0.8) async -> Data? {
        guard let image = await loadThumbnail(for: asset, targetSize: CGSize(width: 800, height: 800)) else {
            return nil
        }
        return image.jpegData(compressionQuality: compressionQuality)
    }

    static func generateMapThumbnail(from jpegData: Data, size: CGFloat = 80) -> Data? {
        guard let image = UIImage(data: jpegData) else {
            photoLibraryLogger.warning("Failed to create UIImage from data (\(jpegData.count) bytes) for map thumbnail")
            return nil
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        guard let result = thumbnail.jpegData(compressionQuality: 0.7) else {
            photoLibraryLogger.warning("Failed to compress thumbnail to JPEG")
            return nil
        }
        return result
    }

    /// Compresses and resizes photo data for storage (max 1200px, 0.8 JPEG quality).
    static func compressForStorage(data: Data, maxDimension: CGFloat = 1200) -> Data? {
        guard let uiImage = UIImage(data: data) else {
            photoLibraryLogger.warning("Failed to create UIImage for compression (\(data.count) bytes)")
            return nil
        }
        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let compressed = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return compressed.jpegData(compressionQuality: 0.8)
    }
}
