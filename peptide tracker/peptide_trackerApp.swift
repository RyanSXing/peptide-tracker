import SwiftUI

@main
struct peptide_trackerApp: App {
    @StateObject private var firebase = FirebaseManager.shared

    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if OnboardingCoordinator.hasCompletedOnboarding() {
                    if let userId = firebase.userId {
                        ContentView(userId: userId)
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
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                handleIncomingURL(url)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        Task {
            _ = try? await FirebaseManager.shared.completeEmailSignInIfPossible(
                with: url.absoluteString
            )
        }
    }
}
