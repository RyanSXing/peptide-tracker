import FirebaseFirestore
import FirebaseFirestoreSwift

struct InjectionLog: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var vialId: String
    var doseAmount: Double
    var doseUnit: DoseUnit
    var timestamp: Date
    var injectionSite: String?
}
