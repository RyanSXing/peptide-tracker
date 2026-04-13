import FirebaseFirestore
import FirebaseFirestoreSwift

struct ActiveVial: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var stockId: String
    var totalMg: Double
    var bacWaterML: Double
    var concentrationMcgPerML: Double
    var dosesRemaining: Int
    var dateConstituted: Date
    var estimatedExpiry: Date
    var isActive: Bool

    var daysSinceConstitution: Int {
        Calendar.current.dateComponents([.day], from: dateConstituted, to: Date()).day ?? 0
    }

    var isExpired: Bool { Date() > estimatedExpiry }
}
