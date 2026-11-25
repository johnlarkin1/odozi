import SwiftUI

struct JourneyDayDetailCard: View {
    let entry: DailyEntry
    #if os(iOS)
        let autoThumbnails: [UIImage]
    #endif
    let isLoadingPhotos: Bool
    var onAttachPhoto: ((Data) -> Void)?
    var onRemoveAttached: ((Int) -> Void)?
    var onAutoPhotoTapped: ((Int) -> Void)?
    var onAttachedPhotoTapped: ((Int) -> Void)?

    @State private var isPinning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: date, mood, location
            HStack(spacing: 12) {
                // Mood circle (hidden when user didn't answer)
                if entry.feeling > 0 {
                    Circle()
                        .fill(entry.moodGradientColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("\(entry.feeling)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.shortFormatted)
                        .font(.headline)
                    if entry.city != nil {
                        Text(entry.locationDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if entry.hasPhotos {
                    Button {
                        let newValue = !entry.showOnPhotoMap
                        isPinning = true
                        Task {
                            await PhotoMapPinning.setShowOnPhotoMap(newValue, for: entry)
                            isPinning = false
                        }
                    } label: {
                        Group {
                            if isPinning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: entry.showOnPhotoMap ? "mappin.circle.fill" : "mappin.circle")
                                    .font(.body)
                                    .foregroundStyle(entry.showOnPhotoMap ? Color.accentTeal : .secondary)
                            }
                        }
                        .padding(8)
                        .background(Circle().fill(Color.cardSurface))
                    }
                    .disabled(isPinning)
                    .accessibilityLabel(entry.showOnPhotoMap ? "Remove from Photo Map" : "Show on Photo Map")
                }

                NavigationLink(destination: JournalEntryDetailView(entry: entry)) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color.cardSurface))
                }
            }

            // Journal snippet
            if !entry.journalEntry.isEmpty {
                Text(entry.journalEntry)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Feeling word
            if !entry.singleWordFeeling.isEmpty {
                Text(entry.singleWordFeeling)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.feelingColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(entry.feelingColor.opacity(0.15))
                    )
            }

            // Photo strip
            let attachedData = entry.attachedPhotoData ?? []
            #if os(iOS)
                if !autoThumbnails.isEmpty || !attachedData.isEmpty {
                    JourneyPhotoStrip(
                        autoThumbnails: autoThumbnails,
                        attachedPhotoData: attachedData,
                        isLoading: isLoadingPhotos,
                        onAttachPhoto: onAttachPhoto,
                        onRemoveAttached: onRemoveAttached,
                        onAutoPhotoTapped: onAutoPhotoTapped,
                        onAttachedPhotoTapped: onAttachedPhotoTapped
                    )
                } else {
                    JourneyPhotoStrip(
                        autoThumbnails: [],
                        attachedPhotoData: [],
                        isLoading: isLoadingPhotos,
                        onAttachPhoto: onAttachPhoto,
                        onRemoveAttached: onRemoveAttached,
                        onAutoPhotoTapped: onAutoPhotoTapped,
                        onAttachedPhotoTapped: onAttachedPhotoTapped
                    )
                }
            #else
                if !attachedData.isEmpty {
                    JourneyPhotoStrip(
                        attachedPhotoData: attachedData,
                        isLoading: isLoadingPhotos,
                        onAttachPhoto: onAttachPhoto,
                        onRemoveAttached: onRemoveAttached,
                        onAttachedPhotoTapped: onAttachedPhotoTapped
                    )
                }
            #endif
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }
}
