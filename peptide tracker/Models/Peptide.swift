import FirebaseFirestore
import SwiftUI

enum DoseUnit: String, Codable, CaseIterable, Identifiable {
    case mcg, mg, iu = "IU"
    var id: String { rawValue }
    var label: String { rawValue }
}

enum DoseFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, eod = "EOD", threeTimesWeek = "3xWeek"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "Daily"
        case .eod: return "Every Other Day"
        case .threeTimesWeek: return "3× per Week"
        }
    }
}

struct Peptide: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var halfLifeHours: Double
    var defaultDoseAmount: Double
    var defaultDoseUnit: DoseUnit
    var createdAt: Date
    var isBlendOnly: Bool = false
    var color: String?

    var displayColor: Color {
        if let colorHex = color {
            return Color(hex: colorHex) ?? ColorGenerator.color(for: name)
        }
        return ColorGenerator.color(for: name)
    }

    static func == (lhs: Peptide, rhs: Peptide) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
