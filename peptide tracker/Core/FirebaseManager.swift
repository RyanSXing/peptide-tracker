import Combine
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Foundation
import Security

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    nonisolated static let emailSignInURL = URL(string: "https://peptide-tracker.firebaseapp.com/email-sign-in")!

    @Published var userId: String?
    @Published var accountStatus = AccountStatus(isAnonymous: true, email: nil, providerIds: [])

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let pendingEmailSignInKey = "pendingEmailSignInAddress"

    private init() {}

    func configure() {
        FirebaseApp.configure()
        let cache = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        let settings = FirestoreSettings()
        settings.cacheSettings = cache
        Firestore.firestore().settings = settings

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.applyUser(user)
            }
        }
    }

    func signInAnonymously() async throws {
        if let user = Auth.auth().currentUser {
            applyUser(user)
            return
        }
        let result = try await Auth.auth().signInAnonymously()
        applyUser(result.user)
    }

    func makeAppleNonce() throws -> String {
        try Self.randomNonceString()
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
    }

    func linkOrSignInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        try await linkCurrentUserOrSignIn(with: credential)
    }

    func sendEmailSignInLink(to email: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let settings = ActionCodeSettings()
        settings.url = Self.emailSignInURL
        settings.handleCodeInApp = true
        settings.iOSBundleID = Bundle.main.bundleIdentifier
        try await Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: settings)
        UserDefaults.standard.set(email, forKey: pendingEmailSignInKey)
    }

    func linkOrSignInWithEmail(email: String, link: String) async throws {
        guard Auth.auth().isSignIn(withEmailLink: link) else {
            throw AuthFlowError.invalidEmailLink
        }
        let credential = EmailAuthProvider.credential(withEmail: email, link: link)
        try await linkCurrentUserOrSignIn(with: credential)
    }

    @discardableResult
    func completeEmailSignInIfPossible(with link: String) async throws -> Bool {
        guard Auth.auth().isSignIn(withEmailLink: link) else {
            return false
        }

        guard let email = UserDefaults.standard.string(forKey: pendingEmailSignInKey),
              !email.isEmpty else {
            throw AuthFlowError.missingEmailForLink
        }

        try await linkOrSignInWithEmail(email: email, link: link)
        UserDefaults.standard.removeObject(forKey: pendingEmailSignInKey)
        return true
    }

    func linkCurrentUserOrSignIn(with credential: AuthCredential) async throws {
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            let result = try await currentUser.link(with: credential)
            applyUser(result.user)
        } else {
            let result = try await Auth.auth().signIn(with: credential)
            applyUser(result.user)
        }
    }

    func revokeAppleToken(authorizationCode: String) async throws {
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }

    func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        applyUser(nil)
    }

    private func applyUser(_ user: User?) {
        userId = user?.uid
        accountStatus = AccountStatus(
            isAnonymous: user?.isAnonymous ?? true,
            email: user?.email ?? user?.providerData.compactMap(\.email).first,
            providerIds: user?.providerData.map(\.providerID) ?? []
        )
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                throw AuthFlowError.nonceGenerationFailed
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

enum AuthFlowError: LocalizedError {
    case invalidAppleCredential
    case missingAppleIdentityToken
    case missingAppleNonce
    case invalidEmailLink
    case missingEmailForLink
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Apple did not return a usable credential."
        case .missingAppleIdentityToken:
            return "Apple did not return an identity token."
        case .missingAppleNonce:
            return "The Apple sign-in request expired. Please try again."
        case .invalidEmailLink:
            return "That does not look like a valid sign-in link."
        case .missingEmailForLink:
            return "Enter your email address before opening the sign-in link."
        case .nonceGenerationFailed:
            return "Could not prepare Apple sign-in securely. Please try again."
        }
    }
}
