import SwiftUI
import SwiftData

struct JourneyExplorerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: JourneyExplorerViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ZStack(alignment: .bottom) {
                    // Globe map
                    JourneyGlobeView(
                        entries: vm.filteredEntries,
                        cameraPosition: Binding(
                            get: { vm.cameraPosition },
                            set: { vm.cameraPosition = $0 }
                        ),
                        onEntryTapped: { entry in
                            vm.selectEntry(entry)
                        }
                    )
                    .ignoresSafeArea(edges: .top)

                    // Bottom overlay
                    VStack(spacing: 12) {
                        // Detail card (slides up when entry selected)
                        if let entry = vm.selectedEntry {
                            #if os(iOS)
                            JourneyDayDetailCard(
                                entry: entry,
                                autoThumbnails: vm.autoPhotoThumbnails,
                                isLoadingPhotos: vm.isLoadingPhotos,
                                onAttachPhoto: { data in
                                    vm.attachPhoto(jpegData: data, to: entry)
                                },
                                onRemoveAttached: { index in
                                    vm.removeAttachedPhoto(at: index, from: entry)
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            #else
                            JourneyDayDetailCard(
                                entry: entry,
                                isLoadingPhotos: vm.isLoadingPhotos,
                                onAttachPhoto: { data in
                                    vm.attachPhoto(jpegData: data, to: entry)
                                },
                                onRemoveAttached: { index in
                                    vm.removeAttachedPhoto(at: index, from: entry)
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            #endif
                        }

                        // Timeline slider (always visible when entries exist)
                        if vm.entryCount > 1 {
                            JourneyTimelineSlider(
                                value: Binding(
                                    get: { vm.selectedIndex },
                                    set: { vm.selectedIndex = $0 }
                                ),
                                range: vm.sliderRange,
                                currentEntry: vm.selectedEntry,
                                totalCount: vm.entryCount,
                                onChanged: { index in
                                    vm.selectBySliderIndex(index)
                                }
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
                .safeAreaInset(edge: .top) {
                    DateRangePicker(selection: Binding(
                        get: { vm.dateRange },
                        set: { newRange in
                            vm.dateRange = newRange
                            if let first = vm.locatedEntries.first {
                                vm.selectEntry(first)
                            }
                        }
                    ))
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Journey")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: YearInReviewView()) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentAmber)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = JourneyExplorerViewModel(modelContext: modelContext)
            }
            viewModel?.loadEntries()
        }
    }
}
