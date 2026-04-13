import XCTest
@testable import peptide_tracker

final class ReconstitutionServiceTests: XCTestCase {

    func test_concentration_5mg_in_2mL() {
        // 5mg in 2mL bac water → 2500 mcg/mL
        let result = ReconstitutionService.calculate(totalMg: 5, bacWaterML: 2, targetDoseMcg: 250)
        XCTAssertEqual(result.concentrationMcgPerML, 2500, accuracy: 0.01)
    }

    func test_drawVolume_250mcg_from_2500mcgPerML() {
        // 250 mcg ÷ 2500 mcg/mL = 0.1 mL
        let result = ReconstitutionService.calculate(totalMg: 5, bacWaterML: 2, targetDoseMcg: 250)
        XCTAssertEqual(result.drawVolumeML, 0.1, accuracy: 0.001)
    }

    func test_syringeUnits_100unit_syringe() {
        // 0.1 mL on 100-unit insulin syringe = 10 units
        let result = ReconstitutionService.calculate(totalMg: 5, bacWaterML: 2, targetDoseMcg: 250)
        XCTAssertEqual(result.syringeUnits, 10, accuracy: 0.1)
    }

    func test_initialDoses_5mg_at_250mcg() {
        // 5mg = 5000mcg ÷ 250mcg = 20 doses
        XCTAssertEqual(ReconstitutionService.initialDoses(totalMg: 5, targetDoseMcg: 250), 20)
    }

    func test_initialDoses_floors_fractional() {
        // 5mg = 5000mcg ÷ 300mcg = 16.67 → 16
        XCTAssertEqual(ReconstitutionService.initialDoses(totalMg: 5, targetDoseMcg: 300), 16)
    }
}
