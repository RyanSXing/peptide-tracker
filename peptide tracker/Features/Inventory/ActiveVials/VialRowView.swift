import SwiftUI

struct VialRowView: View {
    let vial: ActiveVial
    let peptideName: String

    private var ageFraction: Double {
        min(1.0, Double(vial.daysSinceConstitution) / 30.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(peptideName).font(.headline).foregroundColor(.white)
                Spacer()
                if vial.isExpired {
                    Text("EXPIRED")
                        .font(.caption).bold().foregroundColor(.red)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.red.opacity(0.15)).cornerRadius(4)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vial.dosesRemaining) doses remaining")
                        .font(.subheadline).foregroundColor(.blue)
                    Text("\(vial.concentrationMcgPerML, specifier: "%.0f") mcg/mL · \(vial.daysSinceConstitution) days old")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("Exp \(vial.estimatedExpiry.formatted(as: .short))")
                    .font(.caption2).foregroundColor(vial.isExpired ? .red : .secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(vial.isExpired ? Color.red : Color.blue)
                        .frame(width: geo.size.width * ageFraction, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}
