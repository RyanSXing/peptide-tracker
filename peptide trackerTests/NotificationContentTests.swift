import XCTest
@testable import peptide_tracker

final class NotificationContentTests: XCTestCase {

    func test_reminderContent_usesGenericHealthTrackingCopy() {
        let content = NotificationService.reminderContent(
            peptideName: "BPC-157",
            doseAmount: 250,
            doseUnit: .mcg
        )

        XCTAssertEqual(content.title, "Protocol reminder")
        XCTAssertEqual(content.body, "Open Peptide Tracker to review your scheduled entry.")
        XCTAssertFalse(content.title.contains("BPC-157"))
        XCTAssertFalse(content.body.contains("250"))
        XCTAssertFalse(content.body.lowercased().contains("inject"))
    }
}
