import XCTest
@testable import peptide_tracker

final class TimeRangeTests: XCTestCase {
    func testLast7DaysRange() {
        let range = TimeRange.last7Days
        let now = Date()
        let expectedStart = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        // Should be approximately 7 days ago (within 1 second tolerance)
        let timeDiff = range.startDate.timeIntervalSince(expectedStart)
        XCTAssertLessThan(abs(timeDiff), 1.0)

        // End date should be now
        let endDiff = range.endDate.timeIntervalSince(now)
        XCTAssertLessThan(abs(endDiff), 1.0)
    }

    func testLast30DaysRange() {
        let range = TimeRange.last30Days
        let now = Date()
        let expectedStart = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        let timeDiff = range.startDate.timeIntervalSince(expectedStart)
        XCTAssertLessThan(abs(timeDiff), 1.0)
    }

    func testLast90DaysRange() {
        let range = TimeRange.last90Days
        let now = Date()
        let expectedStart = Calendar.current.date(byAdding: .day, value: -90, to: now)!

        let timeDiff = range.startDate.timeIntervalSince(expectedStart)
        XCTAssertLessThan(abs(timeDiff), 1.0)
    }

    func testAllTimeRange() {
        let range = TimeRange.allTime
        let now = Date()

        // End date should be now
        let endDiff = range.endDate.timeIntervalSince(now)
        XCTAssertLessThan(abs(endDiff), 1.0)

        // Start date should be far in the past (before any reasonable data)
        let farPast = Calendar.current.date(byAdding: .year, value: -10, to: now)!
        XCTAssertLessThan(range.startDate, farPast)
    }

    func testCaseIterable() {
        // Verify all cases are accessible
        let allRanges = TimeRange.allCases
        XCTAssertEqual(allRanges.count, 4)
        XCTAssertTrue(allRanges.contains(.last7Days))
        XCTAssertTrue(allRanges.contains(.last30Days))
        XCTAssertTrue(allRanges.contains(.last90Days))
        XCTAssertTrue(allRanges.contains(.allTime))
    }
}
