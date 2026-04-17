import FirebaseFirestore

final class PeptideRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("peptides")
    }

    func fetchAll() async throws -> [Peptide] {
        let snap = try await collection.order(by: "createdAt").getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Peptide.self) }
    }

    @discardableResult
    func add(_ peptide: Peptide) async throws -> String {
        let ref = try collection.addDocument(from: peptide)
        return ref.documentID
    }

    func update(_ peptide: Peptide) async throws {
        guard let id = peptide.id else { return }
        try collection.document(id).setData(from: peptide, merge: true)
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }

    func listen(onChange: @escaping ([Peptide]) -> Void) -> ListenerRegistration {
        collection.order(by: "createdAt").addSnapshotListener { snap, _ in
            let peptides = snap?.documents.compactMap { try? $0.data(as: Peptide.self) } ?? []
            onChange(peptides)
        }
    }
}
