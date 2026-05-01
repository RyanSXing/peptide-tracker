import AuthenticationServices
import Foundation
import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var emailInput = ""
    @Published var showEmailInputSheet = false

    private let firebase: FirebaseManager

    init(firebase: FirebaseManager = .shared) {
        self.firebase = firebase
    }

    func signInWithApple(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
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
            let nonce: String

            do {
                nonce = try firebase.makeAppleNonce()
            } catch {
                errorMessage = "Could not prepare Apple sign-in securely. Please try again."
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
    }

    func signInWithGoogle() {
        // Google Sign-In will be implemented in a separate task
        errorMessage = "Google Sign-In not yet implemented."
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
