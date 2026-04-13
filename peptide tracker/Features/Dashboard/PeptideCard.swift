import SwiftUI

struct PeptideCard: View {
    let peptide: Peptide
    let vial: ActiveVial?
    let schedule: Schedule?
    let daysOfSupply: Double?

    private var stockColor: Color {
        guard let days = daysOfSupply else { return .secondary }
        if days < 7 { return .red }
        if days < 14 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(peptide.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let schedule {
                    Text("\(schedule.doseAmount, specifier: "%.0f") \(schedule.doseUnit.label)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if let schedule {
                Text(schedule.frequency.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                stat(
                    value: vial.map { "\($0.dosesRemaining)" } ?? "—",
                    label: "doses left",
                    color: .blue
                )
                Divider().frame(height: 30).background(Color.gray.opacity(0.3))
                stat(
                    value: vial.map { "\($0.daysSinceConstitution)d" } ?? "—",
                    label: "vial age",
                    color: vial?.isExpired == true ? .red : .white
                )
                Divider().frame(height: 30).background(Color.gray.opacity(0.3))
                stat(
                    value: daysOfSupply.map { "\(Int($0))d" } ?? "—",
                    label: "stock left",
                    color: stockColor
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(14)
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
