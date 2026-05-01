import XCTest
@testable import peptide_tracker
import SwiftUI

final class PeptideTests: XCTestCase {

    // MARK: - displayColor Tests

    func testDisplayColorWithValidHex() {
        let peptide = Peptide(
            id: "test-id",
            name: "TestPeptide",
            halfLifeHours: 12.0,
            defaultDoseAmount: 100.0,
            defaultDoseUnit: .mcg,
            createdAt: Date(),
            isBlendOnly: false,
            color: "#FF5733"
        )

        let color = peptide.displayColor

        XCTAssertNotNil(color)
    }

    func testDisplayColorWithNilColor() {
        let peptide = Peptide(
            id: "test-id",
            name: "TestPeptide",
            halfLifeHours: 12.0,
            defaultDoseAmount: 100.0,
            defaultDoseUnit: .mcg,
            createdAt: Date(),
            isBlendOnly: false,
            color: nil
        )

        let color = peptide.displayColor
        let fallbackColor = ColorGenerator.color(for: "TestPeptide")

        XCTAssertEqual(color, fallbackColor)
    }

    func testDisplayColorWithInvalidHex() {
        let peptide = Peptide(
            id: "test-id",
            name: "TestPeptide",
            halfLifeHours: 12.0,
            defaultDoseAmount: 100.0,
            defaultDoseUnit: .mcg,
            createdAt: Date(),
            isBlendOnly: false,
            color: "INVALID"
        )

        let color = peptide.displayColor
        let fallbackColor = ColorGenerator.color(for: "TestPeptide")

        XCTAssertEqual(color, fallbackColor)
    }

    func testDisplayColorWithEmptyString() {
        let peptide = Peptide(
            id: "test-id",
            name: "TestPeptide",
            halfLifeHours: 12.0,
            defaultDoseAmount: 100.0,
            defaultDoseUnit: .mcg,
            createdAt: Date(),
            isBlendOnly: false,
            color: ""
        )

        let color = peptide.displayColor
        let fallbackColor = ColorGenerator.color(for: "TestPeptide")

        XCTAssertEqual(color, fallbackColor)
    }

    // MARK: - Color Extension Tests

    func testColorExtensionWith3CharHex() {
        let color = Color(hex: "#F00")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWith6CharHex() {
        let color = Color(hex: "#FF5733")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWith8CharHex() {
        let color = Color(hex: "#FF5733AA")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWith3CharHexWithoutHash() {
        let color = Color(hex: "F00")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWith6CharHexWithoutHash() {
        let color = Color(hex: "FF5733")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWith8CharHexWithoutHash() {
        let color = Color(hex: "FF5733AA")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWithInvalidHex() {
        let color = Color(hex: "INVALID")
        XCTAssertNil(color)
    }

    func testColorExtensionWithEmptyString() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testColorExtensionWithTooShortHex() {
        let color = Color(hex: "#FF")
        XCTAssertNil(color)
    }

    func testColorExtensionWithInvalidLength() {
        let color = Color(hex: "#FF573")
        XCTAssertNil(color)
    }

    func testColorExtensionWithInvalidCharacters() {
        let color = Color(hex: "#GG5733")
        XCTAssertNil(color)
    }

    func testColorExtensionWith7CharHex() {
        let color = Color(hex: "#FF5733")
        XCTAssertNotNil(color)
    }

    func testColorExtensionWith9CharHex() {
        let color = Color(hex: "#FF5733AA")
        XCTAssertNotNil(color)
    }
}