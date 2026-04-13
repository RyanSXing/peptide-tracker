import FirebaseFirestore
import FirebaseFirestoreSwift

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

    func decrementDose(vialId: String) async throws {
        let ref = collection.document(vialId)
        try await Firestore.firestore().runTransaction { transaction, _ in
            let snap = try transaction.getDocument(ref)
            let current = snap.data()?["dosesRemaining"] as? Int ?? 0
            transaction.updateData(["dosesRemaining": max(0, current - 1)], forDocument: ref)
            return nil
        }
    }

    func listen(onChange: @escaping ([ActiveVial]) -> Void) -> ListenerRegistration {
        collection.whereField("isActive", isEqualTo: true).addSnapshotListener { snap, _ in
            let vials = snap?.documents.compactMap { try? $0.data(as: ActiveVial.self) } ?? []
            onChange(vials)
        }
    }
}
