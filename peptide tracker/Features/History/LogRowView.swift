import SwiftUI

struct LogRowView: View {
    let log: InjectionLog
    let peptideName: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(peptideName)
                    .font(.headline)
                    .foregroundColor(.white)
                if let site = log.injectionSite {
                    Text(site)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(log.doseAmount, specifier: "%.0f") \(log.doseUnit.label)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(log.timestamp.formatted(as: "MMM d, h:mm a"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}
