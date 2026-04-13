import FirebaseFirestore
import FirebaseFirestoreSwift

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var isPremium: Bool
    var preferredUnit: DoseUnit
    var createdAt: Date
}
