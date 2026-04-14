import FirebaseFirestore

final class UserRepository {
    private let docRef: DocumentReference

    init(userId: String) {
        docRef = Firestore.firestore().collection("users").document(userId)
    }

    func fetchProfile() async throws -> UserProfile? {
        try? await docRef.collection("userProfile").document("profile").getDocument(as: UserProfile.self)
    }

    func createProfileIfNeeded(userId: String) async throws {
        let ref = docRef.collection("userProfile").document("profile")
        let snap = try await ref.getDocument()
        guard !snap.exists else { return }
        let profile = UserProfile(
            userId: userId,
            isPremium: false,
            preferredUnit: .mcg,
            createdAt: Date()
        )
        try ref.setData(from: profile)
    }

    func update(_ profile: UserProfile) async throws {
        let ref = docRef.collection("userProfile").document("profile")
        try ref.setData(from: profile, merge: true)
    }
}
