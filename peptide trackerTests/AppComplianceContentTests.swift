import XCTest
@testable import peptide_tracker

final class AppComplianceContentTests: XCTestCase {

    func test_legalLinks_arePublicHTTPSURLs() throws {
        let links = [LegalContent.privacyPolicyURL, LegalContent.termsOfServiceURL, LegalContent.supportURL]

        for link in links {
            let components = try XCTUnwrap(URLComponents(url: link, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertFalse(components.host?.isEmpty ?? true)
        }
    }

    func test_medicalDisclaimer_tellsUsersToConsultClinician() {
        let disclaimer = LegalContent.medicalDisclaimer.lowercased()

        XCTAssertTrue(disclaimer.contains("not medical advice"))
        XCTAssertTrue(disclaimer.contains("clinician") || disclaimer.contains("doctor"))
        XCTAssertTrue(disclaimer.contains("prescribed"))
    }

    func test_infoPlist_declaresGoogleSignInCallbackScheme() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repoRoot.appendingPathComponent("Config/Info.plist")
        let plist = try XCTUnwrap(NSDictionary(contentsOf: plistURL) as? [String: Any])
        let urlTypes = try XCTUnwrap(plist["CFBundleURLTypes"] as? [[String: Any]])
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }

        XCTAssertTrue(schemes.contains("com.googleusercontent.apps.115413399280-pq1iq7jfioabfbbegmk0rbe6sqdhchoc"))
    }

    func test_emailLinkDomain_isConfiguredForUniversalLinks() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementsURL = repoRoot.appendingPathComponent("peptide tracker/peptide_tracker.entitlements")
        let entitlements = try XCTUnwrap(NSDictionary(contentsOf: entitlementsURL) as? [String: Any])
        let domains = try XCTUnwrap(entitlements["com.apple.developer.associated-domains"] as? [String])

        XCTAssertTrue(domains.contains("applinks:peptide-tracker.firebaseapp.com"))
        XCTAssertEqual(FirebaseManager.emailSignInURL.host, "peptide-tracker.firebaseapp.com")
    }
}
