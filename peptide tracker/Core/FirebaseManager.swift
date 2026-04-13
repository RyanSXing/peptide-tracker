import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    @Published var userId: String?

    private init() {}

    func configure() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
    }

    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        userId = result.user.uid
    }
}
