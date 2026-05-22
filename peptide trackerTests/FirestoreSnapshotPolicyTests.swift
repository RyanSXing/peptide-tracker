import XCTest
@testable import peptide_tracker

final class FirestoreSnapshotPolicyTests: XCTestCase {

    func test_shouldRenderSnapshot_rejectsCacheOnlySnapshots() {
        XCTAssertFalse(FirestoreSnapshotPolicy.shouldRenderSnapshot(isFromCache: true, hasPendingWrites: false))
    }

    func test_shouldRenderSnapshot_allowsServerSnapshots() {
        XCTAssertTrue(FirestoreSnapshotPolicy.shouldRenderSnapshot(isFromCache: false, hasPendingWrites: false))
    }

    func test_shouldRenderSnapshot_allowsPendingLocalWrites() {
        XCTAssertTrue(FirestoreSnapshotPolicy.shouldRenderSnapshot(isFromCache: true, hasPendingWrites: true))
    }
}
