import Foundation

enum HalfLifeService {
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let concentration: Double
    }

    /// Summed plasma concentration at `at` across all prior doses.
    /// Uses C(t) = dose × 0.5^(elapsed_hours / halfLifeHours)
    static func concentration(
        doses: [(amount: Double, timestamp: Date)],
        halfLifeHours: Double,
        at date: Date = Date()
    ) -> Double {
        doses.reduce(0.0) { sum, dose in
            let elapsedHours = date.timeIntervalSince(dose.timestamp) / 3600
            guard elapsedHours >= 0 else { return sum }
            return sum + dose.amount * pow(0.5, elapsedHours / halfLifeHours)
        }
    }

    /// Generate chart data points over `days` days sampled every `intervalHours`.
    static func chartData(
        doses: [(amount: Double, timestamp: Date)],
        halfLifeHours: Double,
        days: Int,
        intervalHours: Double = 1.0
    ) -> [DataPoint] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        let totalSteps = Int(Double(days) * 24.0 / intervalHours)
        return (0...totalSteps).map { i in
            let date = start.addingTimeInterval(Double(i) * intervalHours * 3600)
            let conc = concentration(doses: doses, halfLifeHours: halfLifeHours, at: date)
            return DataPoint(date: date, concentration: conc)
        }
    }
}
