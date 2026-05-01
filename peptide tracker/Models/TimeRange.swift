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
            return calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
    }

    var endDate: Date {
        Date()
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var visibleDuration: TimeInterval {
        let day: TimeInterval = 24 * 60 * 60

        switch self {
        case .last7Days:
            return 7 * day
        case .last30Days:
            return 7 * day
        case .last90Days:
            return 14 * day
        case .allTime:
            return 30 * day
        }
    }

    var sampleIntervalHours: Double {
        switch self {
        case .last7Days:
            return 1
        case .last30Days:
            return 2
        case .last90Days:
            return 6
        case .allTime:
            return 12
        }
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
