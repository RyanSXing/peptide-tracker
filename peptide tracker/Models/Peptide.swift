import FirebaseFirestore
import FirebaseFirestoreSwift

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

    static func == (lhs: Peptide, rhs: Peptide) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
