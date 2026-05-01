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

    /// Returns the custom color if set, otherwise generates a deterministic color from the peptide name
    var displayColor: Color {
        if let colorString = color, let customColor = Color(hex: colorString) {
            return customColor
        }
        return ColorGenerator.color(for: name)
    }

    static func == (lhs: Peptide, rhs: Peptide) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
