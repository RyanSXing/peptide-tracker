import FirebaseFirestore

final class ScheduleRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("schedules")
    }

    func fetchActive() async throws -> [Schedule] {
        let snap = try await collection.whereField("isActive", isEqualTo: true).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Schedule.self) }
    }

    func add(_ schedule: Schedule) async throws -> String {
        let ref = try collection.addDocument(from: schedule)
        return ref.documentID
    }

    func update(_ schedule: Schedule) async throws {
        guard let id = schedule.id else { return }
        try collection.document(id).setData(from: schedule, merge: true)
    }

    func updateNotificationIds(_ ids: [String], for scheduleId: String) async throws {
        try await collection.document(scheduleId).updateData(["notificationIds": ids])
    }

    func listen(onChange: @escaping ([Schedule]) -> Void) -> ListenerRegistration {
        collection.whereField("isActive", isEqualTo: true).addSnapshotListener { snap, _ in
            let schedules = snap?.documents.compactMap { try? $0.data(as: Schedule.self) } ?? []
            onChange(schedules)
        }
    }
}
