import FirebaseFirestore

struct VialCompound: Codable, Hashable {
    var peptideId: String
    var peptideName: String
    var mgInVial: Double
    var concentrationMcgPerML: Double
    var defaultDoseAmountMcg: Double
}

struct ActiveVial: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var stockId: String
    var compounds: [VialCompound]
    var bacWaterML: Double
    var dosesRemaining: Int
    var totalDoses: Int
    var dateConstituted: Date
    var estimatedExpiry: Date
    var isActive: Bool
    var isBlend: Bool = false

    var liquidFraction: Double {
        guard totalDoses > 0 else { return 0 }
        return Double(dosesRemaining) / Double(totalDoses)
    }

    var displayName: String {
        compounds.map(\.peptideName).joined(separator: " + ")
    }

    var daysSinceConstitution: Int {
        Calendar.current.dateComponents([.day], from: dateConstituted, to: Date()).day ?? 0
    }

    var isExpired: Bool { Date() > estimatedExpiry }

    func contains(peptideId: String) -> Bool {
        compounds.contains { $0.peptideId == peptideId }
    }
}
