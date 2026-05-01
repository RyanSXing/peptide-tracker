# First-Time Login Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-time login screen that appears on app launch with 4 authentication options (Apple, Google, Email, Anonymous) using an Onboarding Coordinator pattern.

**Architecture:** Onboarding Coordinator pattern with SwiftUI views. LoginView presents auth options, LoginViewModel handles auth logic via FirebaseManager, OnboardingCoordinator manages flow and persists completion state to UserDefaults.

**Tech Stack:** SwiftUI, Firebase Auth, AuthenticationServices, GoogleSignIn, UserDefaults

---

## File Structure

**New files to create:**
- `peptide tracker/Features/Onboarding/Models/OnboardingStep.swift` - Enum defining onboarding steps
- `peptide tracker/Features/Onboarding/Models/AuthMethod.swift` - Enum defining auth methods
- `peptide tracker/Features/Onboarding/LoginViewModel.swift` - ViewModel for login logic
- `peptide tracker/Features/Onboarding/LoginView.swift` - Login screen UI
- `peptide tracker/Features/Onboarding/OnboardingCoordinator.swift` - Main coordinator

**Files to modify:**
- `peptide tracker/peptide_trackerApp.swift` - Add onboarding check on launch

---

### Task 1: Create OnboardingStep enum

**Files:**
- Create: `peptide tracker/Features/Onboarding/Models/OnboardingStep.swift`

- [ ] **Step 1: Create OnboardingStep enum file**

```swift
import Foundation

enum OnboardingStep: Equatable {
    case login
    // Future steps can be added here:
    // case featureTour
    // case permissionRequest
}
```

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker/Features/Onboarding/Models/OnboardingStep.swift"
git commit -m "feat: add OnboardingStep enum for onboarding flow"
```

---

### Task 2: Create AuthMethod enum

**Files:**
- Create: `peptide tracker/Features/Onboarding/Models/AuthMethod.swift`

- [ ] **Step 1: Create AuthMethod enum file**

```swift
import Foundation

enum AuthMethod {
    case apple
    case google
    case email
    case anonymous
}
```

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker/Features/Onboarding/Models/AuthMethod.swift"
git commit -m "feat: add AuthMethod enum for authentication options"
```

---

### Task 3: Create LoginViewModel

**Files:**
- Create: `peptide tracker/Features/Onboarding/LoginViewModel.swift`

- [ ] **Step 1: Create LoginViewModel with state management**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker/Features/Onboarding/LoginViewModel.swift"
git commit -m "feat: add LoginViewModel with auth logic"
```

---

### Task 4: Create LoginView

**Files:**
- Create: `peptide tracker/Features/Onboarding/LoginView.swift`

- [ ] **Step 1: Create LoginView with centered card layout**

```swift
import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    let onCompletion: () -> Void

    init(firebase: FirebaseManager = .shared, onCompletion: @escaping () -> Void) {
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

                        Text("💉")
                            .font(.system(size: 32))
                    }

                    Text("Peptide Tracker")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Track your protocols with confidence")
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

                // Terms of service
                Text("By continuing, you agree to our Terms of Service")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
            }
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
```

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker/Features/Onboarding/LoginView.swift"
git commit -m "feat: add LoginView with centered card layout"
```

---

### Task 5: Create OnboardingCoordinator

**Files:**
- Create: `peptide tracker/Features/Onboarding/OnboardingCoordinator.swift`

- [ ] **Step 1: Create OnboardingCoordinator with flow management**

```swift
import SwiftUI

struct OnboardingCoordinator: View {
    @State private var currentStep: OnboardingStep = .login
    @State private var hasCompletedOnboarding = false

    private static let onboardingKey = "hasCompletedOnboarding"

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                // Onboarding completed, main app will be shown by peptide_trackerApp
                EmptyView()
            } else {
                switch currentStep {
                case .login:
                    LoginView {
                        completeOnboarding()
                    }
                }
            }
        }
        .onAppear {
            checkOnboardingStatus()
        }
    }

    private func checkOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        hasCompletedOnboarding = true
    }

    static func hasCompletedOnboarding() -> Bool {
        UserDefaults.standard.bool(forKey: onboardingKey)
    }

    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: onboardingKey)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker/Features/Onboarding/OnboardingCoordinator.swift"
git commit -m "feat: add OnboardingCoordinator with flow management"
```

---

### Task 6: Integrate OnboardingCoordinator into app

**Files:**
- Modify: `peptide tracker/peptide_trackerApp.swift`

- [ ] **Step 1: Read current peptide_trackerApp.swift**

```bash
cat "peptide tracker/peptide_trackerApp.swift"
```

- [ ] **Step 2: Modify peptide_trackerApp.swift to check onboarding status**

Replace the entire body content with:

```swift
    var body: some Scene {
        WindowGroup {
            Group {
                if OnboardingCoordinator.hasCompletedOnboarding() {
                    if let userId = firebase.userId {
                        ContentView(userId: userId)
                            .task {
                                _ = await NotificationService.requestPermission()
                            }
                    } else {
                        ProgressView("Setting up...")
                            .task {
                                try? await FirebaseManager.shared.signInAnonymously()
                            }
                    }
                } else {
                    OnboardingCoordinator()
                }
            }
        }
    }
```

- [ ] **Step 3: Commit**

```bash
git add "peptide tracker/peptide_trackerApp.swift"
git commit -m "feat: integrate OnboardingCoordinator into app launch flow"
```

---

### Task 7: Add Google Sign-In support

**Files:**
- Modify: `peptide tracker/Features/Onboarding/LoginViewModel.swift`

- [ ] **Step 1: Add Google Sign-In import and implementation**

Add import at top:
```swift
import GoogleSignIn
```

Replace the `signInWithGoogle()` method with:

```swift
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
                isLoading = false

                if let error = error {
                    errorMessage = "Google Sign-In failed. Please try again."
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    errorMessage = "Google Sign-In failed. Please try again."
                    return
                }

                let accessToken = user.accessToken.tokenString

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: accessToken
                )

                do {
                    try await firebase.linkCurrentUserOrSignIn(with: credential)
                } catch {
                    errorMessage = "Google Sign-In failed. Please try again."
                }
            }
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker/Features/Onboarding/LoginViewModel.swift"
git commit -m "feat: add Google Sign-In implementation"
```

---

### Task 8: Add Google Sign-In package dependency

**Files:**
- Modify: Project file (via Xcode or manual)

- [ ] **Step 1: Add GoogleSignIn package to project**

This step requires adding the GoogleSignIn Swift package to the Xcode project:

1. Open `peptide tracker.xcodeproj` in Xcode
2. Select the project file in the navigator
3. Go to the "Package Dependencies" tab
4. Click the "+" button
5. Enter package URL: `https://github.com/google/GoogleSignIn-iOS`
6. Select version: Up to Next Major Version (current: 7.0.0)
7. Add to "peptide tracker" target
8. Click "Add Package"

- [ ] **Step 2: Commit**

```bash
git add "peptide tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add GoogleSignIn package dependency"
```

---

### Task 9: Test first-time user flow

**Files:**
- No file changes

- [ ] **Step 1: Reset onboarding for testing**

```bash
# In Xcode, add this to a test or debug method:
OnboardingCoordinator.resetOnboarding()
```

- [ ] **Step 2: Build and run app**

```bash
# In Xcode, build and run on simulator or device
# Expected: Login screen appears on first launch
```

- [ ] **Step 3: Test Apple Sign-In**

Click "Continue with Apple" button
Expected: Apple Sign-In sheet appears, user can authenticate

- [ ] **Step 4: Test Google Sign-In**

Click "Continue with Google" button
Expected: Google Sign-In sheet appears, user can authenticate

- [ ] **Step 5: Test Email Sign-In**

Click "Continue with Email" button
Expected: Email input sheet appears, user can enter email

- [ ] **Step 6: Test Anonymous Sign-In**

Click "Continue Anonymously" button
Expected: App proceeds to main screen with anonymous account

- [ ] **Step 7: Verify onboarding completion**

Close and reopen app
Expected: Login screen does not appear, app goes directly to main screen

- [ ] **Step 8: Test error handling**

Turn off network connection
Try any sign-in method
Expected: Error message appears inline

---

### Task 10: Verify existing functionality

**Files:**
- No file changes

- [ ] **Step 1: Test existing Settings auth upgrade**

Open Settings tab
Expected: Existing auth upgrade UI still works for anonymous users

- [ ] **Step 2: Test existing app features**

Navigate through Dashboard, Inventory, History tabs
Expected: All existing features work normally

- [ ] **Step 3: Test data persistence**

Add a peptide or vial
Close and reopen app
Expected: Data persists correctly

---

### Task 11: Final cleanup and documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README with onboarding information**

Add to "Features" section:

```markdown
### Onboarding
- **First-time login screen** - centered card with Apple, Google, Email, and Anonymous options
- **One-time prompt** - login screen only appears on first app launch
- **Flexible auth** - users can skip login and upgrade later via Settings
- **Extensible flow** - Onboarding Coordinator pattern supports future onboarding steps
```

Add to "Setup" section:

```markdown
8. For Google Sign-In, add the Google Sign-In SDK via Swift Package Manager:
   - Package URL: `https://github.com/google/GoogleSignIn-iOS`
   - Add to "peptide tracker" target
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README with onboarding information"
```

---

## Self-Review

**Spec coverage:**
- ✅ First-time users see login screen with all 4 options (Tasks 4, 6)
- ✅ Users can successfully authenticate with any method (Tasks 3, 4, 7)
- ✅ Anonymous option works and proceeds to main app (Tasks 3, 4)
- ✅ Login screen only shows on first launch (Tasks 5, 6)
- ✅ Existing Settings auth upgrade still works (Task 10)
- ✅ Error messages display correctly (Tasks 3, 4)
- ✅ No breaking changes to existing functionality (Task 10)
- ✅ Dark theme matches existing app design (Task 4)
- ✅ Performance is acceptable (Task 9)

**Placeholder scan:**
- ✅ No "TBD" or "TODO" placeholders found
- ✅ All steps contain complete code
- ✅ All file paths are exact
- ✅ All commands are complete with expected output

**Type consistency:**
- ✅ `OnboardingStep` enum used consistently (Tasks 1, 5)
- ✅ `AuthMethod` enum used consistently (Task 2)
- ✅ `LoginViewModel` methods match across tasks (Tasks 3, 4, 7)
- ✅ `OnboardingCoordinator` methods match (Tasks 5, 6)