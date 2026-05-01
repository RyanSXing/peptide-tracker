import XCTest
@testable import peptide_tracker

final class ColorGeneratorTests: XCTestCase {
    func testColorGenerationIsDeterministic() {
        let name = "TestPeptide"
        let color1 = ColorGenerator.color(for: name)
        let color2 = ColorGenerator.color(for: name)

        XCTAssertEqual(color1, color2)
    }

    func testDifferentNamesProduceDifferentColors() {
        let color1 = ColorGenerator.color(for: "PeptideA")
        let color2 = ColorGenerator.color(for: "PeptideB")

        XCTAssertNotEqual(color1, color2)
    }

    func testColorGenerationIsCaseSensitive() {
        let color1 = ColorGenerator.color(for: "peptide")
        let color2 = ColorGenerator.color(for: "Peptide")

        XCTAssertNotEqual(color1, color2)
    }
}
