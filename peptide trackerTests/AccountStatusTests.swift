import XCTest
@testable import peptide_tracker

final class AccountStatusTests: XCTestCase {

    func test_guestStatusExplainsLocalStartAndBackupUpgrade() {
        let status = AccountStatus(isAnonymous: true, email: nil, providerIds: [])

        XCTAssertEqual(status.title, "Continue without account")
        XCTAssertEqual(status.detail, "Tracking works now. Sign in when you want backup and sync.")
        XCTAssertEqual(status.badge, "Local")
    }

    func test_appleLinkedStatusShowsPrivateAppleAccount() {
        let status = AccountStatus(isAnonymous: false, email: nil, providerIds: ["apple.com"])

        XCTAssertEqual(status.title, "Signed in with Apple")
        XCTAssertEqual(status.detail, "Backup and sync are enabled.")
        XCTAssertEqual(status.badge, "Synced")
    }

    func test_emailLinkedStatusShowsEmailAccount() {
        let status = AccountStatus(isAnonymous: false, email: "ryan@example.com", providerIds: ["password"])

        XCTAssertEqual(status.title, "ryan@example.com")
        XCTAssertEqual(status.detail, "Backup and sync are enabled.")
        XCTAssertEqual(status.badge, "Synced")
    }
}
