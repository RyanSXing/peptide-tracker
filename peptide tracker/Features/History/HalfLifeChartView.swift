import SwiftUI
import Charts

struct HalfLifeChartView: View {
    let peptides: [Peptide]
    let logs: [InjectionLog]

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let peptideName: String
        let date: Date
        let concentration: Double
    }

    private var chartData: [ChartPoint] {
        var points: [ChartPoint] = []
        for peptide in peptides {
            guard peptide.halfLifeHours > 0 else { continue }
            let peptideLogs = logs.filter { $0.peptideId == peptide.id }
            guard !peptideLogs.isEmpty else { continue }
            let doses = peptideLogs.map { (amount: $0.doseAmount, timestamp: $0.timestamp) }
            let days = max(1, Int(peptide.halfLifeHours * 4 / 24))
            let data = HalfLifeService.chartData(
                doses: doses,
                halfLifeHours: peptide.halfLifeHours,
                days: days
            )
            for dp in data {
                points.append(ChartPoint(
                    peptideName: peptide.name,
                    date: dp.date,
                    concentration: dp.concentration
                ))
            }
        }
        return points
    }

    var body: some View {
        if chartData.isEmpty {
            Text("Log an injection to see concentration curves.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            Chart {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("mcg", point.concentration)
                    )
                    .foregroundStyle(by: .value("Peptide", point.peptideName))
                }
            }
            .chartXAxisLabel("Time")
            .chartYAxisLabel("Concentration (mcg)")
            .frame(height: 200)
            .padding()
            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}
