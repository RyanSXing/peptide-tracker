import AuthenticationServices
import Combine
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var emailInput = ""
    @Published var showEmailInputSheet = false

    private let firebase: FirebaseManager
    private var currentAppleNonce: String?

    convenience init() {
        self.init(firebase: .shared)
    }

    init(firebase: FirebaseManager) {
        self.firebase = firebase
    }

    func signInWithApple(request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try firebase.makeAppleNonce()
            currentAppleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = firebase.sha256(nonce)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken else {
                errorMessage = "Apple did not return an identity token."
                return
            }

            let token = String(data: identityToken, encoding: .utf8) ?? ""
            guard let nonce = currentAppleNonce else {
                errorMessage = "The Apple sign-in request expired. Please try again."
                return
            }

            do {
                try await firebase.linkOrSignInWithApple(
                    idToken: token,
                    rawNonce: nonce,
                    fullName: credential.fullName
                )
            } catch {
                errorMessage = "Apple sign-in failed. Please try again."
            }

        case .failure:
            errorMessage = "Apple sign-in was cancelled or failed."
        }

        currentAppleNonce = nil
    }

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In configuration error."
            isLoading = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present Google Sign-In."
            isLoading = false
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            Task { @MainActor in
                self.isLoading = false

                if error != nil {
                    self.errorMessage = "Google Sign-In failed. Please try again."
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.errorMessage = "Google Sign-In failed. Please try again."
                    return
                }

                let accessToken = user.accessToken.tokenString

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: accessToken
                )

                do {
                    try await self.firebase.linkCurrentUserOrSignIn(with: credential)
                } catch {
                    self.errorMessage = "Google Sign-In failed. Please try again."
                }
            }
        }
    }

    func sendEmailSignInLink() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        guard !emailInput.isEmpty else {
            errorMessage = "Please enter an email address."
            return
        }

        guard emailInput.contains("@") && emailInput.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        do {
            try await firebase.sendEmailSignInLink(to: emailInput)
            errorMessage = "Check your email for a sign-in link."
        } catch {
            errorMessage = "Unable to send email link. Please verify your email address."
        }
    }

    func signInAnonymously() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await firebase.signInAnonymously()
        } catch {
            errorMessage = "Unable to continue anonymously. Please try again."
        }
    }
}
