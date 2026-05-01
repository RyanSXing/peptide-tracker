import Foundation

enum TimeRange: CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case allTime

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: now) ?? now
        case .allTime:
            // Return a date far in the past
            return calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
    }

    var endDate: Date {
        return Date()
    }

    var displayName: String {
        switch self {
        case .last7Days:
            return "7 Days"
        case .last30Days:
            return "30 Days"
        case .last90Days:
            return "90 Days"
        case .allTime:
            return "All Time"
        }
    }
}
