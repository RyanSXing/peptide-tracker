import SwiftUI
import Charts

struct HalfLifeChartView: View {
    let peptides: [Peptide]
    let logs: [InjectionLog]

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let peptideName: String
        let hour: Double
        let concentration: Double
    }

    private var chartData: [ChartPoint] {
        var points: [ChartPoint] = []
        for peptide in peptides {
            guard peptide.halfLifeHours > 0 else { continue }
            let recentLog = logs
                .filter { $0.peptideId == peptide.id }
                .sorted { $0.timestamp > $1.timestamp }
                .first
            guard let log = recentLog else { continue }
            let data = HalfLifeService.chartData(
                doseMcg: log.doseAmount,
                halfLifeHours: peptide.halfLifeHours,
                hoursToPlot: peptide.halfLifeHours * 4
            )
            for dp in data {
                points.append(ChartPoint(
                    peptideName: peptide.name,
                    hour: dp.hourOffset,
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
                        x: .value("Hours", point.hour),
                        y: .value("mcg", point.concentration)
                    )
                    .foregroundStyle(by: .value("Peptide", point.peptideName))
                }
            }
            .chartXAxisLabel("Hours since dose")
            .chartYAxisLabel("Concentration (mcg)")
            .frame(height: 200)
            .padding()
            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}
