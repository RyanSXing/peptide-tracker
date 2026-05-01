import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var schedules: [Schedule] = []
    @Published var notificationsEnabled: Bool = false
    @Published var accountStatus = FirebaseManager.shared.accountStatus
    @Published var emailAddress = ""
    @Published var emailSignInLink = ""
    @Published var authMessage: String?
    @Published var authError: String?
    @Published var isSendingEmailLink = false
    @Published var isCompletingEmailSignIn = false
    @Published var isSigningInWithGoogle = false
    @Published var isLoading = false

    private let peptideRepo: PeptideRepository
    private let scheduleRepo: ScheduleRepository
    private let userRepo: UserRepository
    private let userId: String
    private var listeners: [ListenerRegistration] = []
    private var currentAppleNonce: String?

    init(
        userId: String,
        peptideRepo: PeptideRepository,
        scheduleRepo: ScheduleRepository,
        userRepo: UserRepository
    ) {
        self.userId = userId
        self.peptideRepo = peptideRepo
        self.scheduleRepo = scheduleRepo
        self.userRepo = userRepo

        FirebaseManager.shared.$accountStatus
            .receive(on: RunLoop.main)
            .assign(to: &$accountStatus)
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in self?.schedules = $0 })
        Task { notificationsEnabled = await NotificationService.requestPermission() }
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try FirebaseManager.shared.makeAppleNonce()
            currentAppleNonce = nonce
            request.requestedScopes = [.email]
            request.nonce = FirebaseManager.shared.sha256(nonce)
            authError = nil
            authMessage = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            guard case let .success(authorization) = result else {
                if case let .failure(error) = result {
                    throw error
                }
                return
            }
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthFlowError.invalidAppleCredential
            }
            guard let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                throw AuthFlowError.missingAppleIdentityToken
            }
            guard let nonce = currentAppleNonce else {
                throw AuthFlowError.missingAppleNonce
            }

            try await FirebaseManager.shared.linkOrSignInWithApple(
                idToken: token,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            authMessage = "Apple sign-in enabled."
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
        currentAppleNonce = nil
    }

    func signInWithGoogle() {
        isSigningInWithGoogle = true
        authError = nil
        authMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authError = "Google Sign-In configuration error."
            isSigningInWithGoogle = false
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            authError = "Unable to present Google Sign-In."
            isSigningInWithGoogle = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            Task { @MainActor in
                self.isSigningInWithGoogle = false

                if error != nil {
                    self.authError = "Google Sign-In failed. Please try again."
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.authError = "Google Sign-In failed. Please try again."
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )

                do {
                    try await FirebaseManager.shared.linkCurrentUserOrSignIn(with: credential)
                    self.authMessage = "Google sign-in enabled."
                    self.authError = nil
                } catch {
                    self.authError = "Google Sign-In failed. Please try again."
                }
            }
        }
    }

    func sendEmailSignInLink() async {
        let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            authError = "Enter an email address first."
            return
        }

        isSendingEmailLink = true
        defer { isSendingEmailLink = false }

        do {
            try await FirebaseManager.shared.sendEmailSignInLink(to: email)
            authMessage = "Check your email for a sign-in link."
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    func completeEmailSignIn() async {
        let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = emailSignInLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !link.isEmpty else {
            authError = "Enter your email and paste the sign-in link."
            return
        }

        isCompletingEmailSignIn = true
        defer { isCompletingEmailSignIn = false }

        do {
            try await FirebaseManager.shared.linkOrSignInWithEmail(email: email, link: link)
            authMessage = "Email sign-in enabled."
            authError = nil
            emailSignInLink = ""
        } catch {
            authError = error.localizedDescription
        }
    }

    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }

    func addPeptide(name: String, halfLifeHours: Double, defaultDoseAmount: Double, defaultDoseUnit: DoseUnit) async throws {
        let peptide = Peptide(
            name: name,
            halfLifeHours: halfLifeHours,
            defaultDoseAmount: defaultDoseAmount,
            defaultDoseUnit: defaultDoseUnit,
            createdAt: Date()
        )
        try await peptideRepo.add(peptide)
    }

    func deletePeptide(_ peptide: Peptide) async throws {
        guard let id = peptide.id else { return }
        try await peptideRepo.delete(id: id)
    }

    func updatePeptide(_ peptide: Peptide) {
        Task {
            try? await peptideRepo.update(peptide)
        }
    }

    func clearAllData() async throws {
        let db = Firestore.firestore().collection("users").document(userId)
        for colName in ["peptides", "peptideStock", "activeVials", "injectionLogs", "schedules", "blends"] {
            let snap = try await db.collection(colName).getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
        }
        try await db.delete()
    }

    func saveSchedule(for peptide: Peptide, frequency: DoseFrequency, doseAmount: Double, doseUnit: DoseUnit, timeSeconds: Int) async throws {
        guard let peptideId = peptide.id else { return }
        // Deactivate existing schedules for this peptide
        for sched in schedules where sched.peptideId == peptideId {
            if var updated = Optional(sched) {
                updated.isActive = false
                try await scheduleRepo.update(updated)
            }
        }
        let sched = Schedule(
            peptideId: peptideId,
            doseAmount: doseAmount,
            doseUnit: doseUnit,
            frequency: frequency,
            timeOfDaySeconds: timeSeconds,
            startDate: Date(),
            endDate: nil,
            isActive: true,
            notificationIds: []
        )
        let schedId = try await scheduleRepo.add(sched)
        // Schedule notifications
        var newSched = sched
        newSched.id = schedId
        let slots = NotificationService.slotsPerPeptide(activePeptideCount: max(1, schedules.filter(\.isActive).count + 1))
        let ids = await NotificationService.schedule(for: newSched, peptideName: peptide.name, slotsPerPeptide: slots)
        try await scheduleRepo.updateNotificationIds(ids, for: schedId)
    }
}
