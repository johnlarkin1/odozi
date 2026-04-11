import SwiftData
import SwiftUI

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: JournalViewModel?
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm = viewModel {
                    List {
                        // Calendar section
                        Section {
                            JournalCalendarView(
                                entries: vm.allEntries,
                                selectedDate: Binding(
                                    get: { vm.selectedDate },
                                    set: { vm.selectedDate = $0 }
                                ),
                                onTapEntry: { entry in
                                    navigationPath.append(entry)
                                },
                                onTapEmptyDate: { date in
                                    navigationPath.append(EmptyDayDate(date: date))
                                }
                            )
                        }
                        .listRowBackground(Color.cardSurface)

                        // Entries list — only show entries where the user actually journaled
                        Section("Entries") {
                            let filtered = filteredEntries(vm.allEntries).filter { $0.hasPromptData }
                            if filtered.isEmpty {
                                Text("No entries yet")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(filtered, id: \.date) { entry in
                                    NavigationLink(value: entry) {
                                        journalRow(entry: entry)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color.cardSurface)
                    }
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search entries")
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Journal")
            .cosmicBackground()
            .navigationDestination(for: DailyEntry.self) { entry in
                JournalEntryDetailView(entry: entry)
            }
            .navigationDestination(for: EmptyDayDate.self) { destination in
                JournalEntryDetailView(date: destination.date)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = JournalViewModel(modelContext: modelContext)
            }
            viewModel?.loadEntries()
        }
    }

    private func filteredEntries(_ entries: [DailyEntry]) -> [DailyEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.journalEntry.localizedCaseInsensitiveContains(searchText) ||
                entry.singleWordFeeling.localizedCaseInsensitiveContains(searchText) ||
                entry.gratitude.localizedCaseInsensitiveContains(searchText) ||
                entry.win.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func journalRow(entry: DailyEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.moodGradientColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.shortFormatted)
                    .font(.subheadline.weight(.medium))

                if !entry.singleWordFeeling.isEmpty {
                    Text(entry.singleWordFeeling)
                        .font(.caption)
                        .foregroundStyle(entry.feelingColor)
                }
            }

            Spacer()

            if !entry.wasCompletedOnDay {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.feeling > 0 {
                MoodIndicator(feeling: entry.feeling, size: 10)

                Text("\(entry.feeling)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
