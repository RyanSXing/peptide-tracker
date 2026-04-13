import XCTest
@testable import peptide_tracker

final class HalfLifeServiceTests: XCTestCase {

    func test_singleDose_atTime0_fullConcentration() {
        let now = Date()
        let doses = [(amount: 250.0, timestamp: now)]
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: now)
        XCTAssertEqual(conc, 250.0, accuracy: 0.01)
    }

    func test_singleDose_afterOneHalfLife_halfConcentration() {
        let ref = Date()
        let doseTime = ref.addingTimeInterval(-4 * 3600) // 4 hours ago
        let doses = [(amount: 250.0, timestamp: doseTime)]
        // After 1 half-life (4h), concentration = 250 * 0.5 = 125
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: ref)
        XCTAssertEqual(conc, 125.0, accuracy: 0.1)
    }

    func test_singleDose_afterTwoHalfLives_quarterConcentration() {
        let ref = Date()
        let doseTime = ref.addingTimeInterval(-8 * 3600) // 8 hours ago
        let doses = [(amount: 200.0, timestamp: doseTime)]
        // After 2 half-lives (8h), concentration = 200 * 0.25 = 50
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: ref)
        XCTAssertEqual(conc, 50.0, accuracy: 0.1)
    }

    func test_futureDose_notIncluded() {
        let ref = Date()
        let futureTime = ref.addingTimeInterval(3600) // 1 hour in future
        let doses = [(amount: 250.0, timestamp: futureTime)]
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: ref)
        XCTAssertEqual(conc, 0.0, accuracy: 0.001)
    }

    func test_twoDoses_summedCorrectly() {
        let ref = Date()
        let dose1Time = ref.addingTimeInterval(-4 * 3600) // 4h ago
        let dose2Time = ref.addingTimeInterval(-2 * 3600) // 2h ago
        let doses = [
            (amount: 250.0, timestamp: dose1Time),
            (amount: 250.0, timestamp: dose2Time)
        ]
        let halfLife = 4.0
        let expected = 250.0 * pow(0.5, 1.0) + 250.0 * pow(0.5, 0.5)
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: halfLife, at: ref)
        XCTAssertEqual(conc, expected, accuracy: 0.01)
    }

    func test_chartData_returnsCorrectPointCount() {
        let doses = [(amount: 250.0, timestamp: Date())]
        let points = HalfLifeService.chartData(doses: doses, halfLifeHours: 4.0, days: 7, intervalHours: 1.0)
        // 7 days * 24 hours + 1 = 169 points (0...168)
        XCTAssertEqual(points.count, 169)
    }
}
