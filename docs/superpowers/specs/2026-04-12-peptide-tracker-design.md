# Peptide Tracker — Design Spec
**Date:** 2026-04-12
**Status:** Approved

---

## Overview

A personal iOS app for tracking peptide protocols. Acts as both an inventory system and a health prescription tracker. Designed for single-user, offline-first use with Firebase cloud backup.

---

## Constraints & Decisions

| Decision | Choice | Reason |
|---|---|---|
| Platform | iOS 16+ | ~95% device coverage, Swift Charts available |
| UI framework | SwiftUI + MVVM | Existing project, Apple-native |
| Backend | Firebase Firestore (offline persistence) | Free tier, single data layer, offline handled by SDK |
| Auth | Firebase Anonymous Auth (→ upgradeable to Sign in with Apple / email) | No login UX now; anonymous session links to real account later |
| Notifications | Local `UNUserNotificationCenter` | No server needed for personal reminders |
| Charts | Swift Charts (iOS 16+) | Built-in, no extra dependency |
| Payments (future) | RevenueCat stub | `isPremium` flag in user profile; paywall added later without restructuring |
| Multi-user | No — single user only (for now) | Personal tool |
| Visual style | Slate Blue dark theme | Dark slate background, blue accents, 3-stat card rows |

---

## Architecture

```
Views (SwiftUI)
  └── ViewModels (ObservableObject, one per feature)
        └── Repositories (Firestore SDK with offline cache)
              └── Firestore Cloud (syncs when online)

Notifications: UNUserNotificationCenter (local only, rescheduled on each log)
Charts: Swift Charts — half-life concentration curves
```

**Firebase free tier usage estimate:** <50 Firestore writes/day vs 20k limit. Well within free tier indefinitely for personal use.

**Auth upgrade path:** Anonymous UID is used from day one. When login is added, `Auth.auth().currentUser.link(with:)` migrates the anonymous session to a real credential — all Firestore data persists under the same UID.

---

## Data Model

All collections live under `users/{userId}/`.

### `peptides`
Peptide type definition.
```
id: String
name: String                    // "BPC-157"
halfLifeHours: Double           // e.g. 1.5
defaultDoseAmount: Double       // e.g. 250
defaultDoseUnit: String         // "mcg" | "mg" | "IU"
createdAt: Timestamp
```

### `peptideStock`
Unconstituted vials in inventory.
```
id: String
peptideId: String
mgPerVial: Double
quantityOnHand: Int
purchaseDate: Timestamp
expiryDate: Timestamp
```

### `activeVials`
Reconstituted vials currently in use.
```
id: String
peptideId: String
stockId: String
totalMg: Double
bacWaterML: Double
concentrationMcgPerML: Double   // calculated on write: (totalMg * 1000) / bacWaterML
dosesRemaining: Int
dateConstituted: Timestamp
estimatedExpiry: Timestamp      // dateConstituted + 30 days (refrigerated)
isActive: Bool
```

### `injectionLogs`
Every injection ever logged.
```
id: String
peptideId: String
vialId: String
doseAmount: Double
doseUnit: String
timestamp: Timestamp
injectionSite: String?          // optional, e.g. "abdomen"
```

### `schedules`
Dosing protocol and notification config per peptide.
```
id: String
peptideId: String
doseAmount: Double
doseUnit: String
frequency: String               // "daily" | "EOD" | "3xWeek" — "custom" is out of scope for v1
timeOfDay: Int                  // seconds since midnight, e.g. 28800 = 8:00 AM
startDate: Timestamp
endDate: Timestamp?
isActive: Bool
notificationIds: [String]       // UNNotificationRequest identifiers
```

### `userProfile`
One document per user.
```
userId: String
isPremium: Bool                 // false by default; paywall gates features later
preferredUnit: String           // "mcg" | "mg" | "IU"
createdAt: Timestamp
```

---

## Navigation

5-tab structure with center FAB-style inject button:

```
[Dashboard] [Inventory] [💉 Inject] [History] [Settings]
```

### Tab 1 — Dashboard
- Slate Blue stat cards per active peptide: doses left, next dose countdown, stock level
- Amber/red alert banners: low stock (<14 days / <7 days supply)
- Vial expiry warnings (>30 days since reconstitution)
- "Today's schedule" checklist — peptides due today, checkmark on log

### Tab 2 — Inventory
Two sub-tabs:
- **Stock** — unconstituted vials: quantity, mg/vial, expiry, days-of-supply indicator
- **Active Vials** — constituted vials: doses remaining, days since reconstitution, progress bar
- Reconstitution calculator accessible when activating a new vial
- Add/edit/delete via swipe gestures or "+" button

### Tab 3 — Inject (center button)
Sheet slides up. Flow: select peptide → dose auto-filled from schedule → optional injection site → confirm. Updates `dosesRemaining` on active vial, reschedules notifications. Target: <10 seconds end-to-end.

### Tab 4 — History
- Injection log grouped by day, filterable by peptide
- Half-life concentration graph at top: 7 / 14 / 30 day toggle, one color-coded line per peptide

### Tab 5 — Settings
- Notification preferences per peptide (on/off, time)
- Preferred dose unit
- Peptide management (add/edit/delete definitions)
- Account section (placeholder for future Sign in with Apple + RevenueCat paywall)

---

## Key Flows

### Reconstitution Calculator
1. User taps "Open New Vial" on a stock item
2. Enters: mg in vial + mL of bacteriostatic water
3. App calculates: `concentration = (mg * 1000) / mL` → displays mcg/mL and syringe draw volume per dose
4. App pre-fills `dosesRemaining = floor((totalMg * 1000) / schedule.doseAmount)` (editable by user before confirming)
5. Confirm → creates `activeVials` record, decrements `peptideStock.quantityOnHand` by 1

### Low Stock Alert Logic
```
daysOfSupply = (quantityOnHand * mgPerVial * 1000) / (dailyDoseMcg * dosesPerDay)
```
- ≥ 14 days → no alert
- < 14 days → amber warning on card + Dashboard banner
- < 7 days → red warning

### Half-Life Graph
For each peptide, sum concentration contributions from all injection logs within the last 30 days:
```
C(t) = Σ [ dose_i * e^(-0.693 * (t - t_i) / halfLifeHours) ]
```
Rendered with Swift Charts. One line per peptide, color-coded. Time axis: last 7 / 14 / 30 days selectable.

### Notification Scheduling
On every injection log or schedule change:
1. Cancel all existing notifications for that peptide (`notificationIds` array)
2. Calculate next N dose times from schedule
3. Create `UNCalendarNotificationTrigger` for each
4. iOS limit: 64 total local notifications — slots distributed proportionally across active peptides (e.g. 2 peptides → 32 slots each). If a peptide has fewer upcoming doses than its allocation, unused slots are not redistributed (acceptable for personal use scale).

---

## Out of Scope (for now)
- Multi-user / sharing
- Vendor / lot number tracking
- Apple Watch companion
- Web dashboard
- User login UI (anonymous auth only — upgrade path designed in)
- RevenueCat paywall (isPremium flag stubbed only)
- FCM / server-triggered push notifications

---

## Future Considerations
- Sign in with Apple + email/password auth (anonymous session links via `link(with:)`)
- RevenueCat integration for premium tier
- CloudKit as alternative/fallback if Firestore costs become relevant
- Export to CSV / PDF for sharing with a practitioner
