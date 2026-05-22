import XCTest
@testable import peptide_tracker

@MainActor
final class OnboardingStepTests: XCTestCase {

    func testEquatableConformance() {
        let step1 = OnboardingStep.login
        let step2 = OnboardingStep.login

        XCTAssertEqual(step1, step2)
    }

    func testEnumCaseAccessibility() {
        let loginStep = OnboardingStep.login

        XCTAssertNotNil(loginStep)
    }

    func testFutureExtensibility() {
        let currentStep = OnboardingStep.login

        switch currentStep {
        case .login:
            break
        }
    }
}
