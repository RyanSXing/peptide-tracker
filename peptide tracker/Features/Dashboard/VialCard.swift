import SwiftUI

struct VialCard: View {
    let vial: ActiveVial

    private var liquidColor: Color {
        if vial.isExpired { return .red }
        if vial.liquidFraction < 0.2 { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(vial.displayName)
                    .font(.headline).foregroundColor(.white)
                Spacer()
                if vial.isExpired {
                    Text("EXPIRED")
                        .font(.caption2).bold().foregroundColor(.red)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.15)).cornerRadius(4)
                } else {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(.blue.opacity(0.6))
                        .font(.caption)
                }
            }

            // Liquid remaining bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(vial.dosesRemaining) of \(vial.totalDoses) doses")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%% remaining", vial.liquidFraction * 100))
                        .font(.caption).bold().foregroundColor(liquidColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(liquidColor)
                            .frame(width: geo.size.width * CGFloat(vial.liquidFraction), height: 8)
                            .animation(.easeInOut, value: vial.liquidFraction)
                    }
                }
                .frame(height: 8)
            }

            // Per-compound dose info
            ForEach(vial.compounds, id: \.peptideId) { compound in
                HStack {
                    Text(compound.peptideName)
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f mcg/dose", compound.defaultDoseAmountMcg))
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            HStack {
                Text("\(vial.daysSinceConstitution)d old · exp \(vial.estimatedExpiry.formatted(as: .short))")
                    .font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("Tap to inject")
                    .font(.caption2).bold().foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(vial.isExpired ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
