import SwiftUI

enum DateRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case year = "Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -7, to: now)!
        case .month: return calendar.date(byAdding: .month, value: -1, to: now)!
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now)!
        case .year: return calendar.date(byAdding: .year, value: -1, to: now)!
        case .allTime: return calendar.date(byAdding: .year, value: -10, to: now)!
        }
    }

    var formattedRange: String {
        let now = Date()
        let formatter = DateFormatter()
        switch self {
        case .allTime:
            return "All Entries"
        case .year:
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) – \(formatter.string(from: now))"
        default:
            let sameYear = Calendar.current.component(.year, from: startDate) == Calendar.current.component(.year, from: now)
            formatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
            let startStr = formatter.string(from: startDate)
            formatter.dateFormat = "MMM d, yyyy"
            let endStr = formatter.string(from: now)
            return "\(startStr) – \(endStr)"
        }
    }
}

struct DateRangePicker: View {
    @Binding var selection: DateRange

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateRange.allCases) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selection = range
                            }
                        } label: {
                            Text(range.rawValue)
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selection == range ? Color.accentAmber : Color.cardSurface)
                                )
                                .foregroundStyle(selection == range ? .black : .white)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Text(selection.formattedRange)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
