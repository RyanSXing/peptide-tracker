import FirebaseFirestore

final class LogRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("injectionLogs")
    }

    func fetchRecent(days: Int = 30) async throws -> [InjectionLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let snap = try await collection
            .whereField("timestamp", isGreaterThan: cutoff)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: InjectionLog.self) }
    }

    func add(_ log: InjectionLog) async throws {
        _ = try collection.addDocument(from: log)
    }

    func listen(days: Int = 30, onChange: @escaping ([InjectionLog]) -> Void) -> ListenerRegistration {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return collection
            .whereField("timestamp", isGreaterThan: cutoff)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snap, _ in
                let logs = snap?.documents.compactMap { try? $0.data(as: InjectionLog.self) } ?? []
                onChange(logs)
            }
    }
}
