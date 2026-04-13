import FirebaseFirestore
import FirebaseFirestoreSwift

struct PeptideStock: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var mgPerVial: Double
    var quantityOnHand: Int
    var purchaseDate: Date
    var expiryDate: Date
}
