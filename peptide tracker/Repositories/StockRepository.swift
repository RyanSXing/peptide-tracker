import FirebaseFirestore

final class StockRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("peptideStock")
    }

    func fetchAll() async throws -> [PeptideStock] {
        let snap = try await collection.getDocuments()
        return try snap.documents.compactMap { try $0.data(as: PeptideStock.self) }
    }

    func fetch(for peptideId: String) async throws -> [PeptideStock] {
        let snap = try await collection.whereField("peptideId", isEqualTo: peptideId).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: PeptideStock.self) }
    }

    func add(_ stock: PeptideStock) async throws {
        _ = try collection.addDocument(from: stock)
    }

    func update(_ stock: PeptideStock) async throws {
        guard let id = stock.id else { return }
        try collection.document(id).setData(from: stock, merge: true)
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }

    func listen(onChange: @escaping ([PeptideStock]) -> Void) -> ListenerRegistration {
        collection.addSnapshotListener { snap, _ in
            let items = snap?.documents.compactMap { try? $0.data(as: PeptideStock.self) } ?? []
            onChange(items)
        }
    }
}
