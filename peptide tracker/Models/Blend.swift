import FirebaseFirestore

struct BlendComponent: Codable, Hashable {
    var peptideId: String
    var peptideName: String
    var mgAmount: Double
    var defaultDoseAmountMcg: Double
}

struct Blend: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var components: [BlendComponent]
    var quantityOnHand: Int
    var purchaseDate: Date
    var expiryDate: Date

    var displayComponents: String {
        components.map(\.peptideName).joined(separator: " + ")
    }
}
