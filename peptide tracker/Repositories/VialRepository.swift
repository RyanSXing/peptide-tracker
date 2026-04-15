import FirebaseFirestore

final class VialRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("activeVials")
    }

    func fetchActive() async throws -> [ActiveVial] {
        let snap = try await collection.whereField("isActive", isEqualTo: true).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: ActiveVial.self) }
    }

    func add(_ vial: ActiveVial) async throws {
        _ = try collection.addDocument(from: vial)
    }

    func update(_ vial: ActiveVial) async throws {
        guard let id = vial.id else { return }
        try collection.document(id).setData(from: vial, merge: true)
    }

    func delete(vialId: String) async throws {
        try await collection.document(vialId).delete()
    }

    func decrementDose(vialId: String) async throws {
        try await collection.document(vialId)
            .updateData(["dosesRemaining": FieldValue.increment(Int64(-1))])
    }

    func listen(onChange: @escaping ([ActiveVial]) -> Void) -> ListenerRegistration {
        collection.whereField("isActive", isEqualTo: true).addSnapshotListener { snap, _ in
            let vials = snap?.documents.compactMap { try? $0.data(as: ActiveVial.self) } ?? []
            onChange(vials)
        }
    }
}
