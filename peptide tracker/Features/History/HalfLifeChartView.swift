import SwiftUI
import Charts

private extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

struct HalfLifeChartView: View {
    let peptides: [Peptide]
    let logs: [InjectionLog]

    @State private var normalized = false
    @State private var hiddenPeptides: Set<String> = []
    @State private var timeRange: TimeRange = .last90Days
    @State private var scrollPosition: Date = Date()

    private let lineStyles: [StrokeStyle] = [
        StrokeStyle(lineWidth: 2),
        StrokeStyle(lineWidth: 2, dash: [6, 3]),
        StrokeStyle(lineWidth: 2, dash: [2, 2]),
        StrokeStyle(lineWidth: 2, dash: [10, 3, 2, 3]),
    ]

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let peptideName: String
        let date: Date
        let value: Double
    }

    private var allPeptideData: [String: [ChartPoint]] {
        var result: [String: [ChartPoint]] = [:]
        for peptide in peptides {
            guard peptide.halfLifeHours > 0 else { continue }
            let peptideLogs = logs.filter { $0.peptideId == peptide.id }
            guard !peptideLogs.isEmpty else { continue }
            let doses = peptideLogs.map { (amount: $0.doseAmount, timestamp: $0.timestamp) }
            let rawData = HalfLifeService.chartData(
                doses: doses,
                halfLifeHours: peptide.halfLifeHours,
                startDate: timeRange.startDate,
                endDate: timeRange.endDate,
                intervalHours: timeRange.sampleIntervalHours
            )
            let maxConc = rawData.map(\.concentration).max() ?? 1.0
            result[peptide.name] = rawData.map { dp in
                let value = normalized
                    ? (maxConc > 0 ? (dp.concentration / maxConc) * 100.0 : 0)
                    : dp.concentration
                return ChartPoint(peptideName: peptide.name, date: dp.date, value: value)
            }
        }
        return result
    }

    private var allPeptideNames: [String] { allPeptideData.keys.sorted() }

    private var visibleNames: [String] { allPeptideNames.filter { !hiddenPeptides.contains($0) } }

    @ChartContentBuilder
    private func peptideSeries(name: String, index: Int) -> some ChartContent {
        let points = allPeptideData[name] ?? []
        let style = lineStyles[index % lineStyles.count]
        let yLabel = normalized ? "%" : "mcg"
        ForEach(points) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value(yLabel, point.value),
                series: .value("Peptide", name)
            )
            .foregroundStyle(colorForPeptide(named: name))
            .lineStyle(style)
        }
    }

    private func colorForPeptide(named name: String) -> Color {
        if let peptide = peptides.first(where: { $0.name == name }) {
            return peptide.displayColor
        }
        return ColorGenerator.color(for: name)
    }

    private func scrollToRightEdge(for range: TimeRange) {
        let endDate = range.endDate
        let visibleDuration = min(range.visibleDuration, range.duration)
        scrollPosition = endDate.addingTimeInterval(-visibleDuration)
    }

    var body: some View {
        if allPeptideData.isEmpty {
            Text("Log an injection to see concentration curves.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            VStack(spacing: 10) {
                // Scale toggle
                Picker("Scale", selection: $normalized) {
                    Text("Absolute").tag(false)
                    Text("% of Peak").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Compound filter chips
                if allPeptideNames.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allPeptideNames, id: \.self) { name in
                                let hidden = hiddenPeptides.contains(name)
                                Button {
                                    if hidden {
                                        hiddenPeptides.remove(name)
                                    } else {
                                        // Don't allow hiding the last visible one
                                        if visibleNames.count > 1 {
                                            hiddenPeptides.insert(name)
                                        }
                                    }
                                } label: {
                                    Text(name)
                                        .font(.caption).bold()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(hidden ? Color.white.opacity(0.07) : Color.blue.opacity(0.25))
                                        .foregroundColor(hidden ? .secondary : .white)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(hidden ? Color.white.opacity(0.15) : Color.blue.opacity(0.5), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: hidden)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Chart
                Chart {
                    RuleMark(x: .value("Now", Date()))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.white.opacity(0.25))
                        .annotation(position: .top, alignment: .center) {
                            Text("now")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.4))
                        }

                    ForEach(Array(allPeptideNames.enumerated()), id: \.element) { index, name in
                        if !hiddenPeptides.contains(name) {
                            peptideSeries(name: name, index: index)
                        }
                    }
                }
                .chartYAxisLabel(normalized ? "% of Peak" : "Concentration (mcg)")
                .if(normalized) { $0.chartYScale(domain: 0.0...105.0) }
                .chartScrollableAxes(.horizontal)
                .chartXScale(domain: timeRange.startDate...timeRange.endDate)
                .chartXVisibleDomain(length: min(timeRange.visibleDuration, timeRange.duration))
                .chartScrollPosition(x: $scrollPosition)
                .frame(height: 220)
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
            .cornerRadius(12)
            .padding(.horizontal)
            .onAppear {
                scrollToRightEdge(for: timeRange)
            }
            .onChange(of: timeRange) { _, newRange in
                scrollToRightEdge(for: newRange)
            }
        }
    }
}
