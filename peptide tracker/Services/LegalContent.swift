import Foundation

enum LegalContent {
    static let privacyPolicyURL = URL(string: "https://peptide-tracker.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://peptide-tracker.app/terms")!
    static let supportURL = URL(string: "https://peptide-tracker.app/support")!

    static let medicalDisclaimer = """
    Peptide Tracker is a personal logging tool and is not medical advice. Track only protocols prescribed by a licensed clinician. Consult your clinician or doctor before making medical decisions or changing any dose, schedule, or treatment plan.
    """
}
