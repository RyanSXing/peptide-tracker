# App Review Notes

Peptide Tracker is a personal record-keeping app for users who are already following clinician-prescribed protocols. It does not diagnose, treat, recommend, prescribe, sell, or encourage use of any medication or controlled substance.

The app stores user-entered protocol, inventory, schedule, and injection-log data under the signed-in Firebase user account. Users may also continue with an anonymous Firebase account. Account deletion is available in Settings > Data > Delete Account and removes associated Firestore tracking data, cancels local reminders, and deletes the Firebase Auth account. For Sign in with Apple accounts, the app requests a fresh Apple authorization code and revokes the Apple token before account deletion.

Half-life charts are estimates generated from user-entered dose logs using exponential decay. The app displays a medical disclaimer during onboarding and in Settings > Legal.

Notification reminders use generic private wording and do not include compound names, dose amounts, injection language, or other sensitive health details.

Reviewer access:
- Continue Anonymously can be used to review the full app without a pre-created account.
- Backend services must be live in Firebase before review.
- Privacy Policy, Terms of Service, and Support URLs in `LegalContent.swift` must point to publicly accessible pages before submission.
