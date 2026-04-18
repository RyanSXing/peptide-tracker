# Peptide Tracker — iOS App

A personal health-tracking iOS app for managing peptide protocols — inventory, dosing, injection logs, and pharmacokinetic concentration curves. Built entirely in SwiftUI with Firebase Firestore as an offline-first backend.

---

## Features

### Dashboard
- **Vial-centric view** — each active vial displayed as a card with a visual liquid-level indicator showing remaining doses
- **Inline injection** — tap any vial card to open the injection sheet with that vial pre-selected
- **Smart alerts** — warning banners surface expired vials and low-dose warnings (≤3 doses remaining)
- **Reminder nudges** — vials without a dosing schedule surface an inline prompt to set one, directly from the dashboard
- **Quick reconstitution** — swipe left on any vial to immediately open a fresh vial from stock

### Injection Logging
- **Dose validation** — prevents entering a dose that exceeds remaining vial quantity; enforces hard cap with auto-adjustment
- **Partial last-dose auto-fill** — detects when the final dose in a vial is fractional and pre-fills the exact remaining amount
- **Blend auto-proportioning** — editing one compound in a multi-compound vial automatically scales all others by the same ratio
- **Auto-prompt for restock** — when a vial empties, prompts to open a new one; supports multi-size vial selection when multiple stock sizes exist
- **Injection site logging** — optional free-text field saved with each log entry

### Inventory Management
- **Peptides & Blends** — separate tabs for single-compound peptides and pre-mixed blend vials
- **Reconstitution flow** — step-by-step BAC water calculation; single-compound vials auto-prompt to set a dosing reminder on completion
- **Multi-size stock** — tracks vials of different milligram sizes per peptide; selecting a new vial size recalculates concentration and total doses automatically
- **Click-to-edit** — tap any peptide or blend to edit its properties inline

### History & Pharmacokinetics
- **Injection log** — full timestamped history of every dose, grouped by date
- **Half-life concentration curves** — interactive Swift Charts graph modeling plasma concentration over time using the standard exponential decay formula `C(t) = dose × 0.5^(t / t½)`
- **Multi-compound overlay** — plots curves for all active peptides on the same chart with distinct line styles
- **Toggle modes** — switch between absolute concentration (mcg) and normalized % of peak; per-compound filter chips hide/show individual curves
- **"Now" marker** — a dashed rule line marks the current time on the chart

### Scheduling & Notifications
- **Dosing schedules** — daily, every-other-day, or 3×/week frequencies
- **Local push notifications** — uses `UNUserNotificationCenter`; notification IDs stored per schedule in Firestore for reliable reschedule on each injection
- **SetReminderSheet** — inline sheet for creating a schedule, accessible from the dashboard nudge or post-reconstitution flow

---

## Architecture

**Pattern:** MVVM with a Repository layer separating Firestore access from view logic.

```
App
├── ContentView           — TabView shell wiring repos into ViewModels
├── Features/
│   ├── Dashboard/        — DashboardView + DashboardViewModel
│   ├── Inject/           — InjectSheetView + InjectViewModel
│   ├── Inventory/        — InventoryView, sub-tabs: Peptides, ActiveVials, Stock, Reconstitution
│   ├── History/          — HistoryView + HalfLifeChartView
│   ├── Settings/         — SettingsView + PeptideManagementView
│   └── Shared/           — SetReminderSheet
├── Repositories/         — PeptideRepository, VialRepository, StockRepository,
│                           BlendRepository, LogRepository, ScheduleRepository, UserRepository
├── Services/             — HalfLifeService, ReconstitutionService, NotificationService
├── Models/               — Peptide, ActiveVial, VialCompound, PeptideStock, Blend,
│                           InjectionLog, Schedule, UserProfile
└── Core/                 — FirebaseManager, Date+Helpers
```

**Key design decisions:**
- **Offline-first** — Firestore offline persistence enabled; app is fully functional without a network connection
- **Repository pattern** — all Firestore queries isolated in repository classes; ViewModels never touch the SDK directly
- **`@MainActor` ViewModels** — all published state mutations happen on the main actor; no manual `DispatchQueue.main` calls
- **Combine listeners** — Firestore `addSnapshotListener` wrapped to return `ListenerRegistration` handles; ViewModels start/stop listeners with the view lifecycle
- **Anonymous auth** — Firebase Anonymous Authentication provides a stable `userId` without requiring a login flow; architecture stubs for Sign in with Apple upgrade path

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 16+) |
| Charts | Swift Charts |
| Backend | Firebase Firestore |
| Auth | Firebase Anonymous Auth |
| Notifications | `UNUserNotificationCenter` (local) |
| Language | Swift 5.9 |

---

## Data Model

All collections live under `users/{userId}/` in Firestore:

| Collection | Purpose |
|---|---|
| `peptides` | Compound catalog (name, half-life, default dose) |
| `peptideStock` | Vial inventory (mg/vial, quantity on hand) |
| `activeVials` | Reconstituted vials currently in use |
| `injectionLogs` | Per-dose log entries with timestamp and site |
| `schedules` | Dosing frequency and notification config |
| `userProfile` | User preferences and premium flag stub |

---

## Pharmacokinetics Model

The half-life chart uses superposition of exponential decay across all logged doses:

```
C(t) = Σ [ doseᵢ × 0.5^( (t − tᵢ) / t½ ) ]
```

`HalfLifeService` is a pure stateless enum — no dependencies, fully unit tested via `HalfLifeServiceTests`.

---

## Testing

- `HalfLifeServiceTests` — unit tests for the concentration formula and chart data generation
- `ReconstitutionServiceTests` — unit tests for BAC water dilution calculations and dose count derivation

---

## Setup

1. Clone the repo
2. Add your `GoogleService-Info.plist` to the `peptide tracker/` target directory (not committed)
3. Enable **Anonymous Authentication** in your Firebase project console
4. Enable **Firestore** and deploy with default rules (auth-scoped)
5. Open `peptide tracker.xcodeproj` in Xcode 15+ and run on a simulator or device (iOS 16+)

> Firebase config file is gitignored. The app will not launch without it.

---

## Roadmap

- [ ] Sign in with Apple (auth upgrade path already stubbed)
- [ ] RevenueCat in-app purchases for premium features
- [ ] iCloud Keychain / data export
- [ ] Apple Health integration for injection logging
- [ ] Widget for next scheduled dose
