import FirebaseFirestore

final class BlendRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("blends")
    }

    func add(_ blend: Blend) async throws {
        _ = try collection.addDocument(from: blend)
    }

    func update(_ blend: Blend) async throws {
        guard let id = blend.id else { return }
        try collection.document(id).setData(from: blend, merge: true)
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }

    func fetch(id: String) async throws -> Blend? {
        let doc = try await collection.document(id).getDocument()
        return try? doc.data(as: Blend.self)
    }

    func listen(onChange: @escaping ([Blend]) -> Void) -> ListenerRegistration {
        collection.addSnapshotListener { snap, _ in
            let blends = snap?.documents.compactMap { try? $0.data(as: Blend.self) } ?? []
            onChange(blends)
        }
    }
}
