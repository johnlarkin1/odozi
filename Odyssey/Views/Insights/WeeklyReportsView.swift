import SwiftData
import SwiftUI

struct WeeklyReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var digests: [WeeklyDigestData] = []
    @State private var hasLoaded = false

    private static let weeksToLoad = 12

    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if digests.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        Text("Your last \(digests.count) week\(digests.count == 1 ? "" : "s") at a glance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        ForEach(digests, id: \.weekStartDate) { digest in
                            WeeklyDigestCardView(data: digest)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Weekly Reports")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .cosmicBackground()
        .task {
            loadDigests()
        }
    }

    private func loadDigests() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [WeeklyDigestData] = []

        for weekOffset in 0 ..< Self.weeksToLoad {
            guard let endDate = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today) else { continue }
            let digest = WeeklyDigestService.computeDigest(context: modelContext, endDate: endDate)
            if digest.hasData {
                results.append(digest)
            }
        }

        digests = results
        hasLoaded = true
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentAmber.opacity(0.7))
            Text("No Reports Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Once you start journaling, your weekly digests will appear here so you can revisit how each week went.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
