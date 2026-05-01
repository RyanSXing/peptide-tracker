# First-Time Login Screen Design

**Date:** 2026-04-30
**Status:** Approved

## Overview

Add a first-time login screen that appears when users launch the app for the first time, offering multiple authentication options including the ability to continue anonymously. The screen uses an Onboarding Coordinator pattern for extensibility and remembers the user's choice to avoid repeated prompts.

## Requirements

### Functional Requirements
- Show login screen on first app launch only
- Display 4 authentication options: Sign in with Apple, Sign in with Google, Email link, Continue anonymously
- Allow users to skip login and continue with anonymous access
- Remember user's choice and never show the screen again
- Anonymous users can upgrade to a real account later via Settings
- Handle authentication errors gracefully with inline error messages
- Support existing Firebase auth providers (Apple, Email, Anonymous)

### Non-Functional Requirements
- Maintain existing app functionality and data flow
- No breaking changes to current auth implementation
- Dark theme matching existing app design
- Fast loading and responsive UI
- Clean error handling without app crashes

## Architecture

### Onboarding Coordinator Pattern

The onboarding flow is managed by an `OnboardingCoordinator` SwiftUI view that:
- Owns the onboarding state (current step, user choices)
- Persists completion state to UserDefaults
- Presents the appropriate onboarding step
- Transitions to the main app when complete

### Components

#### 1. OnboardingCoordinator.swift
Main coordinator view managing the entire onboarding flow.

**Responsibilities:**
- Check if onboarding has been completed
- Present LoginView as first step
- Handle completion and transition to main app
- Persist completion state to UserDefaults

**State:**
- `hasCompletedOnboarding: Bool` - persisted in UserDefaults
- `currentStep: OnboardingStep` - tracks current onboarding step

#### 2. LoginView.swift
Centered login screen with authentication options.

**UI Elements:**
- App logo/branding at top (gradient background with peptide icon)
- App name and tagline
- 4 login buttons stacked vertically:
  - Sign in with Apple (white button, Apple icon)
  - Sign in with Google (white button, Google icon)
  - Email link (blue button, envelope icon)
  - Continue anonymously (outlined button, gray text)
- Terms of service text at bottom
- Dark theme matching existing app design

**Button Behavior:**
- Apple/Google: One-tap authentication via respective SDKs
- Email: Opens email input sheet → sends magic link
- Anonymous: Immediately proceeds to main app

#### 3. LoginViewModel.swift
Handles authentication logic and state management.

**Responsibilities:**
- Manage authentication state (loading, success, error)
- Coordinate with FirebaseManager for auth operations
- Handle Apple Sign-In nonce generation
- Send email sign-in links
- Handle anonymous sign-in
- Provide error messages for display

**State:**
- `isLoading: Bool` - shows loading state on buttons
- `errorMessage: String?` - inline error messages
- `authMethod: AuthMethod?` - tracks selected auth method

#### 4. Modified peptide_trackerApp.swift
Integration point for onboarding flow.

**Changes:**
- Check `OnboardingCoordinator.hasCompletedOnboarding()` on launch
- Show `OnboardingCoordinator` if not completed
- Show `ContentView` if completed
- Maintain existing Firebase initialization

## Data Flow

### Onboarding Flow
```
App Launch
  ↓
Check UserDefaults: hasCompletedOnboarding?
  ↓ NO
Show OnboardingCoordinator
  ↓
Present LoginView
  ↓
User selects auth method
  ↓
FirebaseManager handles auth
  ↓
OnboardingCoordinator saves completion flag
  ↓
Transition to ContentView
  ↓
App proceeds normally
```

### Auth Flow Details
- **Apple/Google:** OAuth flow → FirebaseManager links credential → user signed in
- **Email:** User enters email → FirebaseManager sends magic link → user clicks link → app opens → FirebaseManager completes sign-in
- **Anonymous:** FirebaseManager.signInAnonymously() → user proceeds with anonymous account

### State Persistence
- `UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")`
- Stored immediately after user makes any auth choice
- Checked on every app launch in `peptide_trackerApp.swift`

### Upgrade Path
- Anonymous users can upgrade anytime via Settings screen
- Existing Settings auth UI remains unchanged
- FirebaseManager's `linkCurrentUserOrSignIn()` handles linking anonymous to real accounts

## Error Handling

### LoginView Error States
- **Network errors:** "Unable to connect. Please check your internet connection."
- **Auth errors:** "Authentication failed. Please try again."
- **Email errors:** "Unable to send email link. Please verify your email address."
- **Apple/Google errors:** "Sign in failed. Please try again."

### Error Display
- Inline error messages below the relevant button
- Red/orange text color for visibility
- Auto-dismiss after 5 seconds or on next action
- Non-blocking - user can try other options

### Recovery
- All buttons remain active after errors
- User can retry same method or choose different option
- No app crashes or stuck states

### Edge Cases
- User cancels Apple/Google sheet → return to login screen
- Email link expires → show error, offer to resend
- Firebase auth unavailable → show error, offer anonymous option

## UI Design

### Login Screen Layout
- **Style:** Centered card on dark background
- **Dimensions:** Max width 400px, centered vertically and horizontally
- **Colors:** Dark theme (#0f1014 background) matching existing app
- **Typography:** System fonts, white text for headings, gray for secondary text

### Button Styling
- **Apple/Google:** White background, black text, 10px border radius
- **Email:** Blue (#3b82f6) background, white text, 10px border radius
- **Anonymous:** Transparent background, gray text, 1px border, 10px border radius
- **All buttons:** 14px vertical padding, full width

### Visual Hierarchy
1. App branding (logo + name + tagline)
2. Primary auth options (Apple, Google)
3. Secondary auth option (Email)
4. Tertiary option (Anonymous)
5. Legal text (terms of service)

## Integration Points

### Existing Components
- **FirebaseManager:** Already handles Apple, Email, and Anonymous auth
- **SettingsView:** Existing auth upgrade UI remains unchanged
- **ContentView:** Main app UI unchanged
- **All Repositories:** No changes needed

### New Dependencies
- **AuthenticationServices:** For Apple Sign-In (already imported in Settings)
- **GoogleSignIn:** For Google Sign-In (needs to be added)
- **UserDefaults:** For onboarding completion flag

## Testing Considerations

### Unit Tests
- LoginViewModel state management
- OnboardingCoordinator completion logic
- Error message handling and display

### Integration Tests
- First launch flow shows login screen
- Subsequent launches skip login screen
- All auth methods complete successfully
- Error states display correctly
- Anonymous users can upgrade via Settings

### Edge Cases
- App backgrounded during auth flow
- Network interruptions during auth
- User cancels auth sheets
- Email link handling from deep links

## Future Extensibility

The Onboarding Coordinator pattern allows easy addition of future onboarding steps:

1. **FeatureTourView:** Quick tutorial for new users
2. **PermissionRequestView:** Notification permission request
3. **DataImportView:** Option to import data from other apps
4. **PersonalizationView:** User preferences setup

Each new step would be a separate view that reports completion back to the coordinator.

## Implementation Notes

### Google Sign-In Setup
- Add GoogleSignIn package to project
- Configure Google Sign-In in Firebase console
- Add GoogleService-Info.plist configuration
- Handle Google Sign-In callback in LoginViewModel

### Email Link Handling
- Ensure Firebase Action Code Settings are configured
- Handle deep link opening from email
- Verify email link in app delegate or scene delegate

### Apple Sign-In
- Reuse existing nonce generation logic from FirebaseManager
- Handle Apple Sign-In callback properly
- Extract full name from Apple credential if available

## Success Criteria

- [ ] First-time users see login screen with all 4 options
- [ ] Users can successfully authenticate with any method
- [ ] Anonymous option works and proceeds to main app
- [ ] Login screen only shows on first launch
- [ ] Existing Settings auth upgrade still works
- [ ] Error messages display correctly
- [ ] No breaking changes to existing functionality
- [ ] Dark theme matches existing app design
- [ ] Performance is acceptable (no noticeable lag)