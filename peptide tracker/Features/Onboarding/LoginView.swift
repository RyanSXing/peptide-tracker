import AuthenticationServices
import Combine
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    let onCompletion: () -> Void

    init(onCompletion: @escaping () -> Void) {
        self.init(firebase: .shared, onCompletion: onCompletion)
    }

    init(firebase: FirebaseManager, onCompletion: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: LoginViewModel(firebase: firebase))
        self.onCompletion = onCompletion
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App branding
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("Peptide Tracker")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Track clinician-prescribed protocols with confidence")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Login options
                VStack(spacing: 12) {
                    // Apple Sign-In
                    SignInWithAppleButton(.continue) { request in
                        viewModel.signInWithApple(request: request)
                    } onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result)
                            if viewModel.errorMessage == nil {
                                onCompletion()
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(10)
                    .disabled(viewModel.isLoading)

                    // Google Sign-In
                    Button {
                        viewModel.signInWithGoogle()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.green)
                            Text("Continue with Google")
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading)

                    // Email Sign-In
                    Button {
                        viewModel.showEmailInputSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Continue with Email")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading)
                    .sheet(isPresented: $viewModel.showEmailInputSheet) {
                        EmailInputSheet(viewModel: viewModel, onCompletion: onCompletion)
                    }

                    Divider()
                        .background(Color.gray)

                    // Anonymous
                    Button {
                        Task {
                            await viewModel.signInAnonymously()
                            if viewModel.errorMessage == nil {
                                onCompletion()
                            }
                        }
                    } label: {
                        Text("Continue Anonymously")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .foregroundColor(.secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 32)

                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text(LegalContent.medicalDisclaimer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Link("Privacy", destination: LegalContent.privacyPolicyURL)
                        Link("Terms", destination: LegalContent.termsOfServiceURL)
                        Link("Support", destination: LegalContent.supportURL)
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onReceive(FirebaseManager.shared.$userId.compactMap { $0 }.removeDuplicates()) { _ in
            onCompletion()
        }
    }
}

// Email Input Sheet
struct EmailInputSheet: View {
    @ObservedObject var viewModel: LoginViewModel
    let onCompletion: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $viewModel.emailInput)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter your email address")
                } footer: {
                    Text("We'll send you a magic link to sign in.")
                        .font(.caption)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Email Sign-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send Link") {
                        Task {
                            await viewModel.sendEmailSignInLink()
                            if viewModel.errorMessage?.contains("Check your email") == true {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.emailInput.isEmpty || viewModel.isLoading)
                }
            }
        }
    }
}
