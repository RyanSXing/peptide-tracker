import Foundation

struct AccountStatus: Equatable {
    let isAnonymous: Bool
    let email: String?
    let providerIds: [String]

    var title: String {
        if isAnonymous {
            return "Continue without account"
        }
        if providerIds.contains("apple.com") {
            return "Signed in with Apple"
        }
        if providerIds.contains("google.com") {
            return "Signed in with Google"
        }
        return email ?? "Signed in"
    }

    var detail: String {
        if isAnonymous {
            return "Tracking works now. Sign in when you want backup and sync."
        }
        return "Backup and sync are enabled."
    }

    var badge: String {
        isAnonymous ? "Local" : "Synced"
    }
}
