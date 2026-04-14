import SwiftUI

struct StockRowView: View {
    let stock: PeptideStock
    let peptideName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(peptideName).font(.headline).foregroundColor(.white)
                Spacer()
                Text("\(stock.quantityOnHand) vials")
                    .font(.subheadline).bold()
                    .foregroundColor(stock.quantityOnHand <= 1 ? .orange : .green)
            }
            HStack {
                Text("\(stock.mgPerVial, specifier: "%.1f") mg/vial")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("Expires \(stock.expiryDate.formatted(as: .medium))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}
