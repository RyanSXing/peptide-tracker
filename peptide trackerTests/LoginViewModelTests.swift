import AuthenticationServices
import XCTest
@testable import peptide_tracker

@MainActor
final class LoginViewModelTests: XCTestCase {

    func test_signInWithApple_attachesNonceBeforeAuthorization() {
        let viewModel = LoginViewModel(firebase: .shared)
        let request = ASAuthorizationAppleIDProvider().createRequest()

        viewModel.signInWithApple(request: request)

        XCTAssertEqual(request.requestedScopes, [.fullName, .email])
        XCTAssertNotNil(request.nonce)
        XCTAssertFalse(request.nonce?.isEmpty ?? true)
    }
}
