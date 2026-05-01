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
