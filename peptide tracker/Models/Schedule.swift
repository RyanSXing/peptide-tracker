import FirebaseFirestore
import FirebaseFirestoreSwift

struct Schedule: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var doseAmount: Double
    var doseUnit: DoseUnit
    var frequency: DoseFrequency
    /// Seconds since midnight, e.g. 28800 = 8:00 AM
    var timeOfDaySeconds: Int
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var notificationIds: [String]

    func timeOfDay(on day: Date = Date()) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        return start.addingTimeInterval(TimeInterval(timeOfDaySeconds))
    }

    func nextDoseDates(from: Date = Date(), count: Int = 10) -> [Date] {
        var dates: [Date] = []
        var candidate = timeOfDay(on: from)
        if candidate <= from { candidate = nextCandidate(after: candidate) }

        while dates.count < count {
            if let end = endDate, candidate > end { break }
            dates.append(candidate)
            candidate = nextCandidate(after: candidate)
        }
        return dates
    }

    private func nextCandidate(after date: Date) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date)!
        case .eod:
            return cal.date(byAdding: .day, value: 2, to: date)!
        case .threeTimesWeek:
            var next = cal.date(byAdding: .day, value: 1, to: date)!
            let valid: Set<Int> = [2, 4, 6] // Mon=2, Wed=4, Fri=6
            while !valid.contains(cal.component(.weekday, from: next)) {
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            return timeOfDay(on: next)
        }
    }
}
