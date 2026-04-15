import SwiftUI

struct VialRowView: View {
    let vial: ActiveVial

    private var liquidColor: Color {
        if vial.isExpired { return .red }
        if vial.liquidFraction < 0.2 { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vial.displayName).font(.headline).foregroundColor(.white)
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
                    Text("\(vial.dosesRemaining) of \(vial.totalDoses) doses remaining")
                        .font(.subheadline).foregroundColor(liquidColor)
                    if let c = vial.compounds.first {
                        Text(String(format: "%.0f mcg/mL · %d days old", c.concentrationMcgPerML, vial.daysSinceConstitution))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("Exp \(vial.estimatedExpiry.formatted(as: .short))")
                    .font(.caption2).foregroundColor(vial.isExpired ? .red : .secondary)
            }

            // Liquid remaining bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(liquidColor)
                        .frame(width: geo.size.width * CGFloat(vial.liquidFraction), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}
