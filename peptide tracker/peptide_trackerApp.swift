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
                if let userId = firebase.userId {
                    ContentView(userId: userId)
                } else {
                    ProgressView("Setting up...")
                        .task {
                            try? await FirebaseManager.shared.signInAnonymously()
                        }
                }
            }
        }
    }
}
