# Peptide Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete iOS peptide tracking app covering inventory management, injection logging, half-life visualization, and local push notifications using SwiftUI + Firestore.

**Architecture:** SwiftUI + MVVM with Firestore as the single offline-first data layer (persistence enabled). Repository pattern abstracts Firestore access per collection. Pure logic services (HalfLife, Reconstitution) are unit-tested with XCTest. ViewModels are `@MainActor ObservableObject`; views are pure SwiftUI.

**Tech Stack:** SwiftUI (iOS 16+), Firebase iOS SDK (FirebaseFirestore, FirebaseFirestoreSwift, FirebaseAuth), Swift Charts (iOS 16+), UNUserNotificationCenter, XCTest

---

## File Map

All source files live under `peptide tracker/peptide tracker/` relative to the repo root. When creating new files, add them to the `peptide tracker` target in Xcode (drag into the Project Navigator or use File → Add Files).

```
peptide tracker/                          ← Xcode source root
├── peptide_trackerApp.swift              MODIFY
├── ContentView.swift                     MODIFY
├── Core/
│   ├── FirebaseManager.swift             CREATE
│   └── Date+Helpers.swift               CREATE
├── Models/
│   ├── Peptide.swift                     CREATE
│   ├── PeptideStock.swift                CREATE
│   ├── ActiveVial.swift                  CREATE
│   ├── InjectionLog.swift                CREATE
│   ├── Schedule.swift                    CREATE
│   └── UserProfile.swift                CREATE
├── Repositories/
│   ├── PeptideRepository.swift           CREATE
│   ├── StockRepository.swift             CREATE
│   ├── VialRepository.swift              CREATE
│   ├── LogRepository.swift               CREATE
│   ├── ScheduleRepository.swift          CREATE
│   └── UserRepository.swift             CREATE
├── Services/
│   ├── ReconstitutionService.swift       CREATE  ← pure logic, TDD
│   ├── HalfLifeService.swift             CREATE  ← pure logic, TDD
│   └── NotificationService.swift        CREATE
└── Features/
    ├── Dashboard/
    │   ├── DashboardViewModel.swift      CREATE
    │   ├── PeptideCard.swift             CREATE
    │   └── DashboardView.swift           CREATE
    ├── Inventory/
    │   ├── InventoryView.swift           CREATE
    │   ├── Stock/
    │   │   ├── StockViewModel.swift      CREATE
    │   │   ├── StockRowView.swift        CREATE
    │   │   └── StockTabView.swift        CREATE
    │   ├── ActiveVials/
    │   │   ├── ActiveVialsViewModel.swift CREATE
    │   │   ├── VialRowView.swift         CREATE
    │   │   └── ActiveVialsTabView.swift  CREATE
    │   └── Reconstitution/
    │       ├── ReconstitutionViewModel.swift CREATE
    │       └── ReconstitutionView.swift  CREATE
    ├── Inject/
    │   ├── InjectViewModel.swift         CREATE
    │   └── InjectSheetView.swift         CREATE
    ├── History/
    │   ├── HistoryViewModel.swift        CREATE
    │   ├── LogRowView.swift              CREATE
    │   ├── HalfLifeChartView.swift       CREATE
    │   └── HistoryView.swift             CREATE
    └── Settings/
        ├── SettingsViewModel.swift       CREATE
        ├── PeptideManagementView.swift   CREATE
        ├── NotificationSettingsView.swift CREATE
        └── SettingsView.swift            CREATE

peptide trackerTests/                     CREATE (Xcode test target)
├── ReconstitutionServiceTests.swift      CREATE
└── HalfLifeServiceTests.swift           CREATE
```

---

## Task 1: Firebase SDK + Project Setup

**Files:**
- Modify: `peptide tracker/peptide_trackerApp.swift`
- Create: `peptide tracker/Core/FirebaseManager.swift`
- Xcode: Add SPM packages, GoogleService-Info.plist, test target

- [ ] **Step 1: Add Firebase via Swift Package Manager**

In Xcode: File → Add Package Dependencies → paste URL:
```
https://github.com/firebase/firebase-ios-sdk
```
Select these products: `FirebaseFirestore`, `FirebaseFirestoreSwift`, `FirebaseAuth`. Add to target `peptide tracker`.

- [ ] **Step 2: Create a Firebase project and download config**

1. Go to console.firebase.google.com → create project "peptide-tracker"
2. Add an iOS app with bundle ID matching `peptide tracker.xcodeproj` (check target → General → Bundle Identifier)
3. Download `GoogleService-Info.plist`
4. In Xcode: drag `GoogleService-Info.plist` into the `peptide tracker` group → check "Add to target: peptide tracker" → Copy if needed

- [ ] **Step 3: Enable Firestore offline persistence in Firebase console**

Firebase Console → Firestore Database → Create database (start in test mode for now) → rules will be tightened in Step 5.

- [ ] **Step 4: Create FirebaseManager**

Create `peptide tracker/Core/FirebaseManager.swift` and add to Xcode target:

```swift
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    @Published var userId: String?

    private init() {}

    func configure() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
    }

    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        userId = result.user.uid
    }
}
```

- [ ] **Step 5: Update App entry point**

Replace `peptide tracker/peptide_trackerApp.swift`:

```swift
import SwiftUI

@main
struct peptide_trackerApp: App {
    @StateObject private var firebase = FirebaseManager.shared

    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let userId = firebase.userId {
                    ContentView(userId: userId)
                } else {
                    ProgressView("Setting up...")
                        .task {
                            try? await FirebaseManager.shared.signInAnonymously()
                        }
                }
            }
        }
    }
}
```

- [ ] **Step 6: Add unit test target**

In Xcode: File → New → Target → Unit Testing Bundle → name it `peptide trackerTests` → Finish. Ensure "Target to be Tested" is `peptide tracker`.

- [ ] **Step 7: Tighten Firestore security rules**

In Firebase Console → Firestore → Rules, replace with:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
Publish.

- [ ] **Step 8: Build the app to confirm Firebase links**

In Xcode: Product → Build (⌘B). Expected: Build Succeeded. Fix any "No such module 'FirebaseFirestore'" errors by confirming SPM packages are linked to the target.

- [ ] **Step 9: Commit**

```bash
cd "/Users/rsxing/peptide tracker/peptide tracker"
git add -A
git commit -m "feat: add Firebase SDK, anonymous auth, Firestore offline persistence"
```

---

## Task 2: Data Models

**Files:**
- Create: `peptide tracker/Models/Peptide.swift`
- Create: `peptide tracker/Models/PeptideStock.swift`
- Create: `peptide tracker/Models/ActiveVial.swift`
- Create: `peptide tracker/Models/InjectionLog.swift`
- Create: `peptide tracker/Models/Schedule.swift`
- Create: `peptide tracker/Models/UserProfile.swift`

All files must be added to the `peptide tracker` Xcode target.

- [ ] **Step 1: Create Peptide.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

enum DoseUnit: String, Codable, CaseIterable, Identifiable {
    case mcg, mg, iu = "IU"
    var id: String { rawValue }
    var label: String { rawValue }
}

enum DoseFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, eod = "EOD", threeTimesWeek = "3xWeek"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "Daily"
        case .eod: return "Every Other Day"
        case .threeTimesWeek: return "3× per Week"
        }
    }
}

struct Peptide: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var halfLifeHours: Double
    var defaultDoseAmount: Double
    var defaultDoseUnit: DoseUnit
    var createdAt: Date

    static func == (lhs: Peptide, rhs: Peptide) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

- [ ] **Step 2: Create PeptideStock.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

struct PeptideStock: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var mgPerVial: Double
    var quantityOnHand: Int
    var purchaseDate: Date
    var expiryDate: Date
}
```

- [ ] **Step 3: Create ActiveVial.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ActiveVial: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var stockId: String
    var totalMg: Double
    var bacWaterML: Double
    var concentrationMcgPerML: Double
    var dosesRemaining: Int
    var dateConstituted: Date
    var estimatedExpiry: Date
    var isActive: Bool

    /// Days since reconstitution
    var daysSinceConstitution: Int {
        Calendar.current.dateComponents([.day], from: dateConstituted, to: Date()).day ?? 0
    }

    /// True if vial is past its estimated expiry
    var isExpired: Bool { Date() > estimatedExpiry }
}
```

- [ ] **Step 4: Create InjectionLog.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

struct InjectionLog: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var vialId: String
    var doseAmount: Double
    var doseUnit: DoseUnit
    var timestamp: Date
    var injectionSite: String?
}
```

- [ ] **Step 5: Create Schedule.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Schedule: Codable, Identifiable {
    @DocumentID var id: String?
    var peptideId: String
    var doseAmount: Double
    var doseUnit: DoseUnit
    var frequency: DoseFrequency
    /// Seconds since midnight, e.g. 28800 = 8:00 AM
    var timeOfDaySeconds: Int
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var notificationIds: [String]

    /// Resolved time-of-day as a Date on a given calendar day
    func timeOfDay(on day: Date = Date()) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        return start.addingTimeInterval(TimeInterval(timeOfDaySeconds))
    }

    /// Next N dose dates from `from`, respecting frequency
    func nextDoseDates(from: Date = Date(), count: Int = 10) -> [Date] {
        var dates: [Date] = []
        var candidate = timeOfDay(on: from)
        if candidate <= from { candidate = nextCandidate(after: candidate) }

        while dates.count < count {
            if let end = endDate, candidate > end { break }
            dates.append(candidate)
            candidate = nextCandidate(after: candidate)
        }
        return dates
    }

    private func nextCandidate(after date: Date) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date)!
        case .eod:
            return cal.date(byAdding: .day, value: 2, to: date)!
        case .threeTimesWeek:
            // Mon/Wed/Fri pattern: advance to next valid weekday
            var next = cal.date(byAdding: .day, value: 1, to: date)!
            let valid: Set<Int> = [2, 4, 6] // Mon=2, Wed=4, Fri=6
            while !valid.contains(cal.component(.weekday, from: next)) {
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            return timeOfDay(on: next)
        }
    }
}
```

- [ ] **Step 6: Create UserProfile.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var isPremium: Bool
    var preferredUnit: DoseUnit
    var createdAt: Date
}
```

- [ ] **Step 7: Build to verify models compile**

Xcode: ⌘B. Expected: Build Succeeded. Fix any Codable conformance issues.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add Firestore data models"
```

---

## Task 3: Repositories

**Files:**
- Create: `peptide tracker/Repositories/PeptideRepository.swift`
- Create: `peptide tracker/Repositories/StockRepository.swift`
- Create: `peptide tracker/Repositories/VialRepository.swift`
- Create: `peptide tracker/Repositories/LogRepository.swift`
- Create: `peptide tracker/Repositories/ScheduleRepository.swift`
- Create: `peptide tracker/Repositories/UserRepository.swift`

All repositories follow the same pattern: init with `userId`, hold a `CollectionReference`, expose async CRUD + a real-time listener.

- [ ] **Step 1: Create PeptideRepository.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

final class PeptideRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("peptides")
    }

    func fetchAll() async throws -> [Peptide] {
        let snap = try await collection.order(by: "createdAt").getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Peptide.self) }
    }

    func add(_ peptide: Peptide) async throws {
        _ = try collection.addDocument(from: peptide)
    }

    func update(_ peptide: Peptide) async throws {
        guard let id = peptide.id else { return }
        try collection.document(id).setData(from: peptide, merge: true)
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }

    func listen(onChange: @escaping ([Peptide]) -> Void) -> ListenerRegistration {
        collection.order(by: "createdAt").addSnapshotListener { snap, _ in
            let peptides = snap?.documents.compactMap { try? $0.data(as: Peptide.self) } ?? []
            onChange(peptides)
        }
    }
}
```

- [ ] **Step 2: Create StockRepository.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

final class StockRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("peptideStock")
    }

    func fetchAll() async throws -> [PeptideStock] {
        let snap = try await collection.getDocuments()
        return try snap.documents.compactMap { try $0.data(as: PeptideStock.self) }
    }

    func fetch(for peptideId: String) async throws -> [PeptideStock] {
        let snap = try await collection.whereField("peptideId", isEqualTo: peptideId).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: PeptideStock.self) }
    }

    func add(_ stock: PeptideStock) async throws {
        _ = try collection.addDocument(from: stock)
    }

    func update(_ stock: PeptideStock) async throws {
        guard let id = stock.id else { return }
        try collection.document(id).setData(from: stock, merge: true)
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }

    func listen(onChange: @escaping ([PeptideStock]) -> Void) -> ListenerRegistration {
        collection.addSnapshotListener { snap, _ in
            let items = snap?.documents.compactMap { try? $0.data(as: PeptideStock.self) } ?? []
            onChange(items)
        }
    }
}
```

- [ ] **Step 3: Create VialRepository.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

final class VialRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("activeVials")
    }

    func fetchActive() async throws -> [ActiveVial] {
        let snap = try await collection.whereField("isActive", isEqualTo: true).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: ActiveVial.self) }
    }

    func add(_ vial: ActiveVial) async throws {
        _ = try collection.addDocument(from: vial)
    }

    func update(_ vial: ActiveVial) async throws {
        guard let id = vial.id else { return }
        try collection.document(id).setData(from: vial, merge: true)
    }

    func decrementDose(vialId: String) async throws {
        let ref = collection.document(vialId)
        try await Firestore.firestore().runTransaction { transaction, _ in
            let snap = try transaction.getDocument(ref)
            let current = snap.data()?["dosesRemaining"] as? Int ?? 0
            transaction.updateData(["dosesRemaining": max(0, current - 1)], forDocument: ref)
            return nil
        }
    }

    func listen(onChange: @escaping ([ActiveVial]) -> Void) -> ListenerRegistration {
        collection.whereField("isActive", isEqualTo: true).addSnapshotListener { snap, _ in
            let vials = snap?.documents.compactMap { try? $0.data(as: ActiveVial.self) } ?? []
            onChange(vials)
        }
    }
}
```

- [ ] **Step 4: Create LogRepository.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

final class LogRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("injectionLogs")
    }

    func fetchRecent(days: Int = 30) async throws -> [InjectionLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let snap = try await collection
            .whereField("timestamp", isGreaterThan: cutoff)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: InjectionLog.self) }
    }

    func add(_ log: InjectionLog) async throws {
        _ = try collection.addDocument(from: log)
    }

    func listen(days: Int = 30, onChange: @escaping ([InjectionLog]) -> Void) -> ListenerRegistration {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return collection
            .whereField("timestamp", isGreaterThan: cutoff)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snap, _ in
                let logs = snap?.documents.compactMap { try? $0.data(as: InjectionLog.self) } ?? []
                onChange(logs)
            }
    }
}
```

- [ ] **Step 5: Create ScheduleRepository.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

final class ScheduleRepository {
    private let collection: CollectionReference

    init(userId: String) {
        collection = Firestore.firestore()
            .collection("users").document(userId).collection("schedules")
    }

    func fetchActive() async throws -> [Schedule] {
        let snap = try await collection.whereField("isActive", isEqualTo: true).getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Schedule.self) }
    }

    func add(_ schedule: Schedule) async throws -> String {
        let ref = try collection.addDocument(from: schedule)
        return ref.documentID
    }

    func update(_ schedule: Schedule) async throws {
        guard let id = schedule.id else { return }
        try collection.document(id).setData(from: schedule, merge: true)
    }

    func updateNotificationIds(_ ids: [String], for scheduleId: String) async throws {
        try await collection.document(scheduleId).updateData(["notificationIds": ids])
    }

    func listen(onChange: @escaping ([Schedule]) -> Void) -> ListenerRegistration {
        collection.whereField("isActive", isEqualTo: true).addSnapshotListener { snap, _ in
            let schedules = snap?.documents.compactMap { try? $0.data(as: Schedule.self) } ?? []
            onChange(schedules)
        }
    }
}
```

- [ ] **Step 6: Create UserRepository.swift**

```swift
import FirebaseFirestore
import FirebaseFirestoreSwift

final class UserRepository {
    private let docRef: DocumentReference

    init(userId: String) {
        docRef = Firestore.firestore().collection("users").document(userId)
    }

    func fetchProfile() async throws -> UserProfile? {
        try? await docRef.collection("userProfile").document("profile").getDocument(as: UserProfile.self)
    }

    func createProfileIfNeeded(userId: String) async throws {
        let ref = docRef.collection("userProfile").document("profile")
        let snap = try await ref.getDocument()
        guard !snap.exists else { return }
        let profile = UserProfile(
            userId: userId,
            isPremium: false,
            preferredUnit: .mcg,
            createdAt: Date()
        )
        try ref.setData(from: profile)
    }

    func update(_ profile: UserProfile) async throws {
        let ref = docRef.collection("userProfile").document("profile")
        try ref.setData(from: profile, merge: true)
    }
}
```

- [ ] **Step 7: Build to verify repositories compile**

Xcode: ⌘B. Expected: Build Succeeded.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add Firestore repository layer"
```

---

## Task 4: ReconstitutionService (TDD)

**Files:**
- Create: `peptide tracker/Services/ReconstitutionService.swift`
- Create: `peptide trackerTests/ReconstitutionServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `peptide trackerTests/ReconstitutionServiceTests.swift` and add to the `peptide trackerTests` target:

```swift
import XCTest
@testable import peptide_tracker

final class ReconstitutionServiceTests: XCTestCase {

    func test_concentration_5mg_in_2mL() {
        // 5mg in 2mL bac water → 2500 mcg/mL
        let result = ReconstitutionService.calculate(totalMg: 5, bacWaterML: 2, targetDoseMcg: 250)
        XCTAssertEqual(result.concentrationMcgPerML, 2500, accuracy: 0.01)
    }

    func test_drawVolume_250mcg_from_2500mcgPerML() {
        // 250 mcg ÷ 2500 mcg/mL = 0.1 mL
        let result = ReconstitutionService.calculate(totalMg: 5, bacWaterML: 2, targetDoseMcg: 250)
        XCTAssertEqual(result.drawVolumeML, 0.1, accuracy: 0.001)
    }

    func test_syringeUnits_100unit_syringe() {
        // 0.1 mL on 100-unit insulin syringe = 10 units
        let result = ReconstitutionService.calculate(totalMg: 5, bacWaterML: 2, targetDoseMcg: 250)
        XCTAssertEqual(result.syringeUnits, 10, accuracy: 0.1)
    }

    func test_initialDoses_5mg_at_250mcg() {
        // 5mg = 5000mcg ÷ 250mcg = 20 doses
        XCTAssertEqual(ReconstitutionService.initialDoses(totalMg: 5, targetDoseMcg: 250), 20)
    }

    func test_initialDoses_floors_fractional() {
        // 5mg = 5000mcg ÷ 300mcg = 16.67 → 16
        XCTAssertEqual(ReconstitutionService.initialDoses(totalMg: 5, targetDoseMcg: 300), 16)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Xcode: ⌘U. Expected: Build fails with "Cannot find type 'ReconstitutionService'".

- [ ] **Step 3: Implement ReconstitutionService**

Create `peptide tracker/Services/ReconstitutionService.swift` and add to `peptide tracker` target:

```swift
enum ReconstitutionService {
    struct Result {
        let concentrationMcgPerML: Double
        let drawVolumeML: Double
        /// Number of units to draw on a standard 100-unit insulin syringe
        let syringeUnits: Double
    }

    static func calculate(
        totalMg: Double,
        bacWaterML: Double,
        targetDoseMcg: Double
    ) -> Result {
        let concentrationMcgPerML = (totalMg * 1000) / bacWaterML
        let drawVolumeML = targetDoseMcg / concentrationMcgPerML
        let syringeUnits = drawVolumeML * 100
        return Result(
            concentrationMcgPerML: concentrationMcgPerML,
            drawVolumeML: drawVolumeML,
            syringeUnits: syringeUnits
        )
    }

    static func initialDoses(totalMg: Double, targetDoseMcg: Double) -> Int {
        Int(floor((totalMg * 1000) / targetDoseMcg))
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Xcode: ⌘U. Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ReconstitutionService with TDD"
```

---

## Task 5: HalfLifeService (TDD)

**Files:**
- Create: `peptide tracker/Services/HalfLifeService.swift`
- Create: `peptide trackerTests/HalfLifeServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `peptide trackerTests/HalfLifeServiceTests.swift` and add to `peptide trackerTests` target:

```swift
import XCTest
@testable import peptide_tracker

final class HalfLifeServiceTests: XCTestCase {

    func test_singleDose_atTime0_fullConcentration() {
        let now = Date()
        let doses = [(amount: 250.0, timestamp: now)]
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: now)
        XCTAssertEqual(conc, 250.0, accuracy: 0.01)
    }

    func test_singleDose_afterOneHalfLife_halfConcentration() {
        let ref = Date()
        let doseTime = ref.addingTimeInterval(-4 * 3600) // 4 hours ago
        let doses = [(amount: 250.0, timestamp: doseTime)]
        // After 1 half-life (4h), concentration = 250 * 0.5 = 125
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: ref)
        XCTAssertEqual(conc, 125.0, accuracy: 0.1)
    }

    func test_singleDose_afterTwoHalfLives_quarterConcentration() {
        let ref = Date()
        let doseTime = ref.addingTimeInterval(-8 * 3600) // 8 hours ago
        let doses = [(amount: 200.0, timestamp: doseTime)]
        // After 2 half-lives (8h), concentration = 200 * 0.25 = 50
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: ref)
        XCTAssertEqual(conc, 50.0, accuracy: 0.1)
    }

    func test_futureDose_notIncluded() {
        let ref = Date()
        let futureTime = ref.addingTimeInterval(3600) // 1 hour in future
        let doses = [(amount: 250.0, timestamp: futureTime)]
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: 4.0, at: ref)
        XCTAssertEqual(conc, 0.0, accuracy: 0.001)
    }

    func test_twoDoses_summedCorrectly() {
        let ref = Date()
        let dose1Time = ref.addingTimeInterval(-4 * 3600) // 4h ago → 125 remaining
        let dose2Time = ref.addingTimeInterval(-2 * 3600) // 2h ago
        let doses = [
            (amount: 250.0, timestamp: dose1Time),
            (amount: 250.0, timestamp: dose2Time)
        ]
        let halfLife = 4.0
        let expected = 250.0 * pow(0.5, 1.0) + 250.0 * pow(0.5, 0.5)
        let conc = HalfLifeService.concentration(doses: doses, halfLifeHours: halfLife, at: ref)
        XCTAssertEqual(conc, expected, accuracy: 0.01)
    }

    func test_chartData_returnsCorrectPointCount() {
        let doses = [(amount: 250.0, timestamp: Date())]
        let points = HalfLifeService.chartData(doses: doses, halfLifeHours: 4.0, days: 7, intervalHours: 1.0)
        // 7 days * 24 hours + 1 = 169 points
        XCTAssertEqual(points.count, 169)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Xcode: ⌘U. Expected: Build fails with "Cannot find type 'HalfLifeService'".

- [ ] **Step 3: Implement HalfLifeService**

Create `peptide tracker/Services/HalfLifeService.swift` and add to `peptide tracker` target:

```swift
import Foundation

enum HalfLifeService {
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let concentration: Double
    }

    /// Summed plasma concentration at `at` across all prior doses.
    /// Uses C(t) = dose × 0.5^(elapsed_hours / halfLifeHours)
    static func concentration(
        doses: [(amount: Double, timestamp: Date)],
        halfLifeHours: Double,
        at date: Date = Date()
    ) -> Double {
        doses.reduce(0.0) { sum, dose in
            let elapsedHours = date.timeIntervalSince(dose.timestamp) / 3600
            guard elapsedHours >= 0 else { return sum }
            return sum + dose.amount * pow(0.5, elapsedHours / halfLifeHours)
        }
    }

    /// Generate chart data points over `days` days sampled every `intervalHours`.
    static func chartData(
        doses: [(amount: Double, timestamp: Date)],
        halfLifeHours: Double,
        days: Int,
        intervalHours: Double = 1.0
    ) -> [DataPoint] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        let totalSteps = Int(Double(days) * 24.0 / intervalHours)
        return (0...totalSteps).map { i in
            let date = start.addingTimeInterval(Double(i) * intervalHours * 3600)
            let conc = concentration(doses: doses, halfLifeHours: halfLifeHours, at: date)
            return DataPoint(date: date, concentration: conc)
        }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Xcode: ⌘U. Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add HalfLifeService with TDD"
```

---

## Task 6: NotificationService

**Files:**
- Create: `peptide tracker/Services/NotificationService.swift`

- [ ] **Step 1: Create NotificationService.swift** and add to `peptide tracker` target:

```swift
import UserNotifications

enum NotificationService {
    /// Max iOS local notification slots
    private static let maxSlots = 64

    /// Request notification permission. Call once on first launch.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Schedule up to `slotsPerPeptide` notifications for a schedule.
    /// Cancels existing notifications for this peptide first.
    /// Returns the notification IDs that were scheduled (save to schedule.notificationIds).
    @discardableResult
    static func schedule(
        for schedule: Schedule,
        peptideName: String,
        slotsPerPeptide: Int = 10
    ) async -> [String] {
        let center = UNUserNotificationCenter.current()

        // Cancel existing
        center.removePendingNotificationRequests(withIdentifiers: schedule.notificationIds)

        let dates = schedule.nextDoseDates(from: Date(), count: slotsPerPeptide)
        var ids: [String] = []

        for date in dates {
            let content = UNMutableNotificationContent()
            content.title = "Time to inject \(peptideName)"
            content.body = "\(schedule.doseAmount) \(schedule.doseUnit.label)"
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = "peptide-\(schedule.peptideId)-\(date.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
            ids.append(id)
        }

        return ids
    }

    /// Cancel all pending notifications for given identifiers.
    static func cancel(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Cancel all pending notifications for all peptides (use on logout/reset).
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Slot budget per peptide given total active peptide count.
    /// e.g. 2 peptides → 32 slots each (within 64 limit)
    static func slotsPerPeptide(activePeptideCount: Int) -> Int {
        guard activePeptideCount > 0 else { return maxSlots }
        return maxSlots / activePeptideCount
    }
}
```

- [ ] **Step 2: Add background modes entitlement**

In Xcode: select `peptide tracker` target → Signing & Capabilities → "+" → Background Modes → check "Background fetch" and "Remote notifications" (needed for future FCM, harmless now).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add NotificationService with slot-aware scheduling"
```

---

## Task 7: App Structure + Tab View

**Files:**
- Modify: `peptide tracker/ContentView.swift`
- Create: `peptide tracker/Core/Date+Helpers.swift`

- [ ] **Step 1: Create Date+Helpers.swift** and add to target:

```swift
import Foundation

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    func formatted(as style: DateFormatter.Style) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        f.timeStyle = .none
        return f.string(from: self)
    }

    var shortTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: self)
    }
}
```

- [ ] **Step 2: Replace ContentView.swift with 5-tab navigation**

```swift
import SwiftUI

struct ContentView: View {
    let userId: String
    @State private var showInjectSheet = false

    // Repositories — shared across feature ViewModels via init injection
    private lazy var peptideRepo = PeptideRepository(userId: userId)
    private lazy var stockRepo = StockRepository(userId: userId)
    private lazy var vialRepo = VialRepository(userId: userId)
    private lazy var logRepo = LogRepository(userId: userId)
    private lazy var scheduleRepo = ScheduleRepository(userId: userId)
    private lazy var userRepo = UserRepository(userId: userId)

    var body: some View {
        TabView {
            DashboardView(
                viewModel: DashboardViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    vialRepo: VialRepository(userId: userId),
                    stockRepo: StockRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId)
                )
            )
            .tabItem { Label("Dashboard", systemImage: "house.fill") }

            InventoryView(userId: userId)
                .tabItem { Label("Inventory", systemImage: "archivebox.fill") }

            // Center tab — tapping shows the inject sheet
            Color.clear
                .tabItem { Label("Inject", systemImage: "plus.circle.fill") }
                .onAppear { showInjectSheet = true }

            HistoryView(
                viewModel: HistoryViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    logRepo: LogRepository(userId: userId)
                )
            )
            .tabItem { Label("History", systemImage: "clock.fill") }

            SettingsView(
                viewModel: SettingsViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId),
                    userRepo: UserRepository(userId: userId)
                )
            )
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .accentColor(.blue)
        .sheet(isPresented: $showInjectSheet) {
            InjectSheetView(
                viewModel: InjectViewModel(
                    peptideRepo: PeptideRepository(userId: userId),
                    vialRepo: VialRepository(userId: userId),
                    logRepo: LogRepository(userId: userId),
                    scheduleRepo: ScheduleRepository(userId: userId)
                ),
                isPresented: $showInjectSheet
            )
        }
    }
}
```

> **Note:** The tab item for "Inject" uses a trick: selecting it triggers `onAppear` → shows the sheet. The tab itself stays visually deselected. This gives the center-button feel without a custom tab bar.

- [ ] **Step 3: Build to verify tab structure compiles**

Xcode: ⌘B. Expected: Build Succeeded (stub views are defined in later tasks — add placeholder stubs if compiler complains).

If needed, add temporary stubs at bottom of ContentView.swift:
```swift
// Temporary stubs — replace in subsequent tasks
struct DashboardView: View { let viewModel: DashboardViewModel; var body: some View { Text("Dashboard") } }
struct InventoryView: View { let userId: String; var body: some View { Text("Inventory") } }
struct HistoryView: View { let viewModel: HistoryViewModel; var body: some View { Text("History") } }
struct SettingsView: View { let viewModel: SettingsViewModel; var body: some View { Text("Settings") } }
struct InjectSheetView: View { let viewModel: InjectViewModel; @Binding var isPresented: Bool; var body: some View { Text("Inject") } }
struct DashboardViewModel { init(peptideRepo: PeptideRepository, vialRepo: VialRepository, stockRepo: StockRepository, scheduleRepo: ScheduleRepository) {} }
struct HistoryViewModel { init(peptideRepo: PeptideRepository, logRepo: LogRepository) {} }
struct SettingsViewModel { init(peptideRepo: PeptideRepository, scheduleRepo: ScheduleRepository, userRepo: UserRepository) {} }
struct InjectViewModel { init(peptideRepo: PeptideRepository, vialRepo: VialRepository, logRepo: LogRepository, scheduleRepo: ScheduleRepository) {} }
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add 5-tab app structure with inject sheet"
```

---

## Task 8: Dashboard

**Files:**
- Create: `peptide tracker/Features/Dashboard/DashboardViewModel.swift`
- Create: `peptide tracker/Features/Dashboard/PeptideCard.swift`
- Create: `peptide tracker/Features/Dashboard/DashboardView.swift`

Remove any stub for Dashboard from ContentView.swift.

- [ ] **Step 1: Create DashboardViewModel.swift**

```swift
import Foundation
import FirebaseFirestore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var activeVials: [ActiveVial] = []
    @Published var stock: [PeptideStock] = []
    @Published var schedules: [Schedule] = []
    @Published var isLoading = true

    private let peptideRepo: PeptideRepository
    private let vialRepo: VialRepository
    private let stockRepo: StockRepository
    private let scheduleRepo: ScheduleRepository
    private var listeners: [ListenerRegistration] = []

    init(
        peptideRepo: PeptideRepository,
        vialRepo: VialRepository,
        stockRepo: StockRepository,
        scheduleRepo: ScheduleRepository
    ) {
        self.peptideRepo = peptideRepo
        self.vialRepo = vialRepo
        self.stockRepo = stockRepo
        self.scheduleRepo = scheduleRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(vialRepo.listen { [weak self] in self?.activeVials = $0 })
        listeners.append(stockRepo.listen { [weak self] in self?.stock = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in
            self?.schedules = $0
            self?.isLoading = false
        })
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    /// Days of supply remaining for a peptide
    func daysOfSupply(for peptide: Peptide) -> Double? {
        guard let schedule = schedules.first(where: { $0.peptideId == peptide.id && $0.isActive }) else { return nil }
        let totalStock = stock
            .filter { $0.peptideId == peptide.id }
            .reduce(0.0) { $0 + Double($1.quantityOnHand) * $1.mgPerVial * 1000 }
        let dosesPerDay: Double
        switch schedule.frequency {
        case .daily: dosesPerDay = 1
        case .eod: dosesPerDay = 0.5
        case .threeTimesWeek: dosesPerDay = 3.0 / 7.0
        }
        let dailyMcg = schedule.doseAmount * dosesPerDay
        guard dailyMcg > 0 else { return nil }
        return totalStock / dailyMcg
    }

    /// Active vial for a peptide
    func activeVial(for peptide: Peptide) -> ActiveVial? {
        activeVials.first { $0.peptideId == peptide.id && $0.isActive }
    }

    /// Schedule for a peptide
    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }
}
```

- [ ] **Step 2: Create PeptideCard.swift**

```swift
import SwiftUI

struct PeptideCard: View {
    let peptide: Peptide
    let vial: ActiveVial?
    let schedule: Schedule?
    let daysOfSupply: Double?

    private var stockColor: Color {
        guard let days = daysOfSupply else { return .secondary }
        if days < 7 { return .red }
        if days < 14 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(peptide.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let schedule {
                    Text("\(schedule.doseAmount, specifier: "%.0f") \(schedule.doseUnit.label)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if let schedule {
                Text(schedule.frequency.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stats row
            HStack(spacing: 0) {
                stat(
                    value: vial.map { "\($0.dosesRemaining)" } ?? "—",
                    label: "doses left",
                    color: .blue
                )
                Divider().frame(height: 30).background(Color.gray.opacity(0.3))
                stat(
                    value: vial.map { "\($0.daysSinceConstitution)d" } ?? "—",
                    label: "vial age",
                    color: vial?.isExpired == true ? .red : .white
                )
                Divider().frame(height: 30).background(Color.gray.opacity(0.3))
                stat(
                    value: daysOfSupply.map { "\(Int($0))d" } ?? "—",
                    label: "stock left",
                    color: stockColor
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(14)
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3: Create DashboardView.swift**

```swift
import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView().tint(.blue)
                } else if viewModel.peptides.isEmpty {
                    ContentUnavailableView(
                        "No Peptides",
                        systemImage: "syringe",
                        description: Text("Add a peptide in Settings to get started.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Alerts
                            ForEach(viewModel.peptides) { peptide in
                                if let days = viewModel.daysOfSupply(for: peptide), days < 7 {
                                    alertBanner(
                                        text: "\(peptide.name): \(Int(days)) days of stock remaining",
                                        color: .red
                                    )
                                } else if let vial = viewModel.activeVial(for: peptide), vial.isExpired {
                                    alertBanner(
                                        text: "\(peptide.name): active vial may be expired",
                                        color: .orange
                                    )
                                }
                            }

                            // Cards
                            ForEach(viewModel.peptides) { peptide in
                                PeptideCard(
                                    peptide: peptide,
                                    vial: viewModel.activeVial(for: peptide),
                                    schedule: viewModel.schedule(for: peptide),
                                    daysOfSupply: viewModel.daysOfSupply(for: peptide)
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private func alertBanner(text: String, color: Color) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(color)
            Text(text).font(.caption).foregroundColor(.white)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1))
        .cornerRadius(8)
    }
}
```

- [ ] **Step 4: Remove Dashboard stub from ContentView.swift**

Delete the `struct DashboardViewModel` and `struct DashboardView` stubs from ContentView.swift.

- [ ] **Step 5: Build and run on simulator**

Xcode: ⌘R on iPhone 16 simulator. Dashboard should load (empty state) without crash.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Dashboard with peptide cards and stock alerts"
```

---

## Task 9: Inventory — Stock Tab

**Files:**
- Create: `peptide tracker/Features/Inventory/Stock/StockViewModel.swift`
- Create: `peptide tracker/Features/Inventory/Stock/StockRowView.swift`
- Create: `peptide tracker/Features/Inventory/Stock/StockTabView.swift`

- [ ] **Step 1: Create StockViewModel.swift**

```swift
import Foundation
import FirebaseFirestore

@MainActor
final class StockViewModel: ObservableObject {
    @Published var stockItems: [PeptideStock] = []
    @Published var peptides: [Peptide] = []
    private let stockRepo: StockRepository
    private let peptideRepo: PeptideRepository
    private var listeners: [ListenerRegistration] = []

    init(stockRepo: StockRepository, peptideRepo: PeptideRepository) {
        self.stockRepo = stockRepo
        self.peptideRepo = peptideRepo
    }

    func startListening() {
        listeners.append(stockRepo.listen { [weak self] in self?.stockItems = $0 })
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func peptide(for stockItem: PeptideStock) -> Peptide? {
        peptides.first { $0.id == stockItem.peptideId }
    }

    func addStock(_ stock: PeptideStock) async throws {
        try await stockRepo.add(stock)
    }

    func delete(_ stock: PeptideStock) async throws {
        guard let id = stock.id else { return }
        try await stockRepo.delete(id: id)
    }
}
```

- [ ] **Step 2: Create StockRowView.swift**

```swift
import SwiftUI

struct StockRowView: View {
    let stock: PeptideStock
    let peptideName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(peptideName).font(.headline).foregroundColor(.white)
                Spacer()
                Text("\(stock.quantityOnHand) vials")
                    .font(.subheadline).bold()
                    .foregroundColor(stock.quantityOnHand <= 1 ? .orange : .green)
            }
            HStack {
                Text("\(stock.mgPerVial, specifier: "%.1f") mg/vial")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("Expires \(stock.expiryDate.formatted(as: .medium))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 3: Create StockTabView.swift**

```swift
import SwiftUI

struct StockTabView: View {
    @StateObject var viewModel: StockViewModel
    let userId: String
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.stockItems) { stock in
                        StockRowView(
                            stock: stock,
                            peptideName: viewModel.peptide(for: stock)?.name ?? "Unknown"
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { try? await viewModel.delete(stock) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddStockView(viewModel: viewModel)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .preferredColorScheme(.dark)
    }
}

struct AddStockView: View {
    @ObservedObject var viewModel: StockViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPeptide: Peptide?
    @State private var mgPerVial = ""
    @State private var quantity = "1"
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!

    var body: some View {
        NavigationStack {
            Form {
                Section("Peptide") {
                    Picker("Peptide", selection: $selectedPeptide) {
                        Text("Select…").tag(Optional<Peptide>(nil))
                        ForEach(viewModel.peptides) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                }
                Section("Vial Details") {
                    TextField("mg per vial (e.g. 5)", text: $mgPerVial)
                        .keyboardType(.decimalPad)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let peptide = selectedPeptide,
                              let mg = Double(mgPerVial),
                              let qty = Int(quantity) else { return }
                        let stock = PeptideStock(
                            peptideId: peptide.id!,
                            mgPerVial: mg,
                            quantityOnHand: qty,
                            purchaseDate: Date(),
                            expiryDate: expiryDate
                        )
                        Task {
                            try? await viewModel.addStock(stock)
                            dismiss()
                        }
                    }
                    .disabled(selectedPeptide == nil || mgPerVial.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add Inventory stock tab"
```

---

## Task 10: Inventory — Active Vials Tab + InventoryView

**Files:**
- Create: `peptide tracker/Features/Inventory/ActiveVials/ActiveVialsViewModel.swift`
- Create: `peptide tracker/Features/Inventory/ActiveVials/VialRowView.swift`
- Create: `peptide tracker/Features/Inventory/ActiveVials/ActiveVialsTabView.swift`
- Create: `peptide tracker/Features/Inventory/InventoryView.swift`

- [ ] **Step 1: Create ActiveVialsViewModel.swift**

```swift
import Foundation
import FirebaseFirestore

@MainActor
final class ActiveVialsViewModel: ObservableObject {
    @Published var vials: [ActiveVial] = []
    @Published var peptides: [Peptide] = []
    private let vialRepo: VialRepository
    private let peptideRepo: PeptideRepository
    private var listeners: [ListenerRegistration] = []

    init(vialRepo: VialRepository, peptideRepo: PeptideRepository) {
        self.vialRepo = vialRepo
        self.peptideRepo = peptideRepo
    }

    func startListening() {
        listeners.append(vialRepo.listen { [weak self] in self?.vials = $0 })
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func peptide(for vial: ActiveVial) -> Peptide? {
        peptides.first { $0.id == vial.peptideId }
    }

    func deactivate(_ vial: ActiveVial) async throws {
        var updated = vial
        updated.isActive = false
        try await vialRepo.update(updated)
    }
}
```

- [ ] **Step 2: Create VialRowView.swift**

```swift
import SwiftUI

struct VialRowView: View {
    let vial: ActiveVial
    let peptideName: String

    private var progressFraction: Double {
        // We don't store initialDoses, so use a rough estimate from daysSinceConstitution/30
        // Actually we can't derive progress without initial count. Show doses remaining vs expired.
        1.0 - min(1.0, Double(vial.daysSinceConstitution) / 30.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(peptideName).font(.headline).foregroundColor(.white)
                Spacer()
                if vial.isExpired {
                    Text("EXPIRED").font(.caption).bold().foregroundColor(.red)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.red.opacity(0.15)).cornerRadius(4)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vial.dosesRemaining) doses remaining")
                        .font(.subheadline).foregroundColor(.blue)
                    Text("\(vial.concentrationMcgPerML, specifier: "%.0f") mcg/mL · \(vial.daysSinceConstitution) days old")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("Exp \(vial.estimatedExpiry.formatted(as: .short))")
                    .font(.caption2).foregroundColor(vial.isExpired ? .red : .secondary)
            }

            // Age progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(vial.isExpired ? Color.red : Color.blue)
                        .frame(width: geo.size.width * progressFraction, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 3: Create ActiveVialsTabView.swift**

```swift
import SwiftUI

struct ActiveVialsTabView: View {
    @StateObject var viewModel: ActiveVialsViewModel

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.vials) { vial in
                        VialRowView(
                            vial: vial,
                            peptideName: viewModel.peptide(for: vial)?.name ?? "Unknown"
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { try? await viewModel.deactivate(vial) }
                            } label: {
                                Label("Discard", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 4: Create InventoryView.swift**

```swift
import SwiftUI

struct InventoryView: View {
    let userId: String

    var body: some View {
        NavigationStack {
            TabView {
                StockTabView(
                    viewModel: StockViewModel(
                        stockRepo: StockRepository(userId: userId),
                        peptideRepo: PeptideRepository(userId: userId)
                    ),
                    userId: userId
                )
                .tabItem { Label("Stock", systemImage: "shippingbox.fill") }

                ActiveVialsTabView(
                    viewModel: ActiveVialsViewModel(
                        vialRepo: VialRepository(userId: userId),
                        peptideRepo: PeptideRepository(userId: userId)
                    )
                )
                .tabItem { Label("Active Vials", systemImage: "testtube.2") }
            }
            .navigationTitle("Inventory")
        }
    }
}
```

- [ ] **Step 5: Remove InventoryView stub from ContentView.swift**

Delete the `struct InventoryView` stub.

- [ ] **Step 6: Build and run — verify Inventory tabs**

⌘R. Tap Inventory tab. Verify Stock and Active Vials sub-tabs appear.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Inventory tab with stock and active vials"
```

---

## Task 11: Reconstitution Flow

**Files:**
- Create: `peptide tracker/Features/Inventory/Reconstitution/ReconstitutionViewModel.swift`
- Create: `peptide tracker/Features/Inventory/Reconstitution/ReconstitutionView.swift`

Add "Open Vial" button to `StockTabView` rows to launch ReconstitutionView.

- [ ] **Step 1: Create ReconstitutionViewModel.swift**

```swift
import Foundation

@MainActor
final class ReconstitutionViewModel: ObservableObject {
    @Published var bacWaterML: String = "2"
    @Published var confirmedDoses: String = ""
    @Published var result: ReconstitutionService.Result?

    let stock: PeptideStock
    let peptide: Peptide
    private let vialRepo: VialRepository
    private let stockRepo: StockRepository

    init(stock: PeptideStock, peptide: Peptide, vialRepo: VialRepository, stockRepo: StockRepository) {
        self.stock = stock
        self.peptide = peptide
        self.vialRepo = vialRepo
        self.stockRepo = stockRepo
        recalculate()
    }

    func recalculate() {
        guard let ml = Double(bacWaterML), ml > 0 else { result = nil; return }
        result = ReconstitutionService.calculate(
            totalMg: stock.mgPerVial,
            bacWaterML: ml,
            targetDoseMcg: peptide.defaultDoseAmount
        )
        let doses = ReconstitutionService.initialDoses(
            totalMg: stock.mgPerVial,
            targetDoseMcg: peptide.defaultDoseAmount
        )
        confirmedDoses = "\(doses)"
    }

    func confirmReconstitution() async throws {
        guard let ml = Double(bacWaterML), ml > 0,
              let calc = result,
              let doses = Int(confirmedDoses),
              let stockId = stock.id else { return }

        let vial = ActiveVial(
            peptideId: stock.peptideId,
            stockId: stockId,
            totalMg: stock.mgPerVial,
            bacWaterML: ml,
            concentrationMcgPerML: calc.concentrationMcgPerML,
            dosesRemaining: doses,
            dateConstituted: Date(),
            estimatedExpiry: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            isActive: true
        )
        try await vialRepo.add(vial)

        // Decrement stock
        var updated = stock
        updated.quantityOnHand = max(0, stock.quantityOnHand - 1)
        try await stockRepo.update(updated)
    }
}
```

- [ ] **Step 2: Create ReconstitutionView.swift**

```swift
import SwiftUI

struct ReconstitutionView: View {
    @StateObject var viewModel: ReconstitutionViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bacteriostatic Water").font(.headline).foregroundColor(.white)
                            HStack {
                                TextField("mL", text: $viewModel.bacWaterML)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: viewModel.bacWaterML) { _, _ in viewModel.recalculate() }
                                Text("mL").foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                        .cornerRadius(12)

                        // Results
                        if let result = viewModel.result {
                            VStack(spacing: 12) {
                                calcRow(label: "Concentration", value: "\(result.concentrationMcgPerML, specifier: "%.0f") mcg/mL")
                                calcRow(label: "Draw volume per dose", value: "\(result.drawVolumeML, specifier: "%.3f") mL")
                                calcRow(label: "Syringe units (100u)", value: "\(result.syringeUnits, specifier: "%.1f") units")
                            }
                            .padding()
                            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                            .cornerRadius(12)

                            // Editable doses
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Initial doses (editable)").font(.headline).foregroundColor(.white)
                                TextField("Doses", text: $viewModel.confirmedDoses)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding()
                            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                            .cornerRadius(12)
                        }

                        Button("Confirm Reconstitution") {
                            Task {
                                try? await viewModel.confirmReconstitution()
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.result == nil || viewModel.confirmedDoses.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Open Vial — \(viewModel.peptide.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func calcRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
    }
}
```

- [ ] **Step 3: Add "Open Vial" button to StockTabView**

In `StockTabView.swift`, add a context menu or swipe action to `StockRowView`:

```swift
// In StockTabView, update the ForEach body:
ForEach(viewModel.stockItems) { stock in
    if let peptide = viewModel.peptide(for: stock) {
        NavigationLink {
            ReconstitutionView(
                viewModel: ReconstitutionViewModel(
                    stock: stock,
                    peptide: peptide,
                    vialRepo: VialRepository(userId: userId),
                    stockRepo: StockRepository(userId: userId)
                )
            )
        } label: {
            StockRowView(stock: stock, peptideName: peptide.name)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { try? await viewModel.delete(stock) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
```

- [ ] **Step 4: Build and test reconstitution flow**

Run ⌘R. Add a stock item → tap it → enter bac water amount → verify calculations → Confirm. Check that an Active Vial appears in the Active Vials tab.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add reconstitution calculator and vial activation flow"
```

---

## Task 12: Inject Sheet

**Files:**
- Create: `peptide tracker/Features/Inject/InjectViewModel.swift`
- Create: `peptide tracker/Features/Inject/InjectSheetView.swift`

Remove InjectSheetView and InjectViewModel stubs from ContentView.swift.

- [ ] **Step 1: Create InjectViewModel.swift**

```swift
import Foundation
import FirebaseFirestore

@MainActor
final class InjectViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var activeVials: [ActiveVial] = []
    @Published var schedules: [Schedule] = []
    @Published var selectedPeptide: Peptide?
    @Published var doseOverride: String = ""
    @Published var injectionSite: String = ""
    @Published var isLoading = false

    private let peptideRepo: PeptideRepository
    private let vialRepo: VialRepository
    private let logRepo: LogRepository
    private let scheduleRepo: ScheduleRepository
    private var listeners: [ListenerRegistration] = []

    init(
        peptideRepo: PeptideRepository,
        vialRepo: VialRepository,
        logRepo: LogRepository,
        scheduleRepo: ScheduleRepository
    ) {
        self.peptideRepo = peptideRepo
        self.vialRepo = vialRepo
        self.logRepo = logRepo
        self.scheduleRepo = scheduleRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] p in
            self?.peptides = p
            if self?.selectedPeptide == nil { self?.selectedPeptide = p.first }
        })
        listeners.append(vialRepo.listen { [weak self] in self?.activeVials = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in self?.schedules = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }

    func activeVial(for peptide: Peptide) -> ActiveVial? {
        activeVials.first { $0.peptideId == peptide.id && $0.isActive }
    }

    var effectiveDose: Double {
        if let override = Double(doseOverride), override > 0 { return override }
        return selectedPeptide.flatMap { schedule(for: $0)?.doseAmount } ?? 0
    }

    var effectiveUnit: DoseUnit {
        selectedPeptide.flatMap { schedule(for: $0)?.doseUnit } ?? .mcg
    }

    func logInjection() async throws {
        guard let peptide = selectedPeptide, let peptideId = peptide.id,
              let vial = activeVial(for: peptide), let vialId = vial.id else { return }

        isLoading = true
        defer { isLoading = false }

        let log = InjectionLog(
            peptideId: peptideId,
            vialId: vialId,
            doseAmount: effectiveDose,
            doseUnit: effectiveUnit,
            timestamp: Date(),
            injectionSite: injectionSite.isEmpty ? nil : injectionSite
        )
        try await logRepo.add(log)
        try await vialRepo.decrementDose(vialId: vialId)

        // Reschedule notifications
        if let schedule = schedule(for: peptide), let scheduleId = schedule.id {
            let slots = NotificationService.slotsPerPeptide(activePeptideCount: schedules.count)
            let ids = await NotificationService.schedule(for: schedule, peptideName: peptide.name, slotsPerPeptide: slots)
            try await scheduleRepo.updateNotificationIds(ids, for: scheduleId)
        }
    }
}
```

- [ ] **Step 2: Create InjectSheetView.swift**

```swift
import SwiftUI

struct InjectSheetView: View {
    @StateObject var viewModel: InjectViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                VStack(spacing: 20) {
                    // Peptide picker
                    Picker("Peptide", selection: $viewModel.selectedPeptide) {
                        ForEach(viewModel.peptides) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if let peptide = viewModel.selectedPeptide {
                        VStack(spacing: 16) {
                            // Dose display
                            HStack {
                                Text("Dose")
                                    .foregroundColor(.secondary)
                                Spacer()
                                TextField(
                                    "\(viewModel.effectiveDose, specifier: "%.0f")",
                                    text: $viewModel.doseOverride
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                Text(viewModel.effectiveUnit.label)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                            .cornerRadius(12)

                            // Active vial info
                            if let vial = viewModel.activeVial(for: peptide) {
                                HStack {
                                    Text("Active vial").foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(vial.dosesRemaining) doses remaining")
                                        .foregroundColor(vial.dosesRemaining <= 3 ? .orange : .green)
                                }
                                .padding()
                                .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                .cornerRadius(12)
                            } else {
                                Text("No active vial — reconstitute a vial first.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding()
                            }

                            // Injection site (optional)
                            HStack {
                                Text("Site (optional)").foregroundColor(.secondary)
                                Spacer()
                                TextField("e.g. abdomen", text: $viewModel.injectionSite)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding()
                            .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                            .cornerRadius(12)

                            // Log button
                            Button {
                                Task {
                                    try? await viewModel.logInjection()
                                    isPresented = false
                                }
                            } label: {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "syringe")
                                        Text("Log Injection")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.activeVial(for: peptide) == nil || viewModel.isLoading)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Log Injection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
```

- [ ] **Step 3: Remove InjectSheetView and InjectViewModel stubs from ContentView.swift**

- [ ] **Step 4: Build and test inject flow**

Run ⌘R. Tap the center Inject tab. Select a peptide. Verify dose auto-fills. Log an injection. Verify doses remaining decrements on the Dashboard and Active Vials tab.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add inject sheet with dose logging and notification rescheduling"
```

---

## Task 13: History — Log List

**Files:**
- Create: `peptide tracker/Features/History/HistoryViewModel.swift`
- Create: `peptide tracker/Features/History/LogRowView.swift`
- Create: `peptide tracker/Features/History/HistoryView.swift` (partial)

Remove HistoryView and HistoryViewModel stubs from ContentView.swift.

- [ ] **Step 1: Create HistoryViewModel.swift**

```swift
import Foundation
import FirebaseFirestore

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var logs: [InjectionLog] = []
    @Published var peptides: [Peptide] = []
    @Published var selectedDays: Int = 7
    @Published var filterPeptideId: String? = nil

    private let peptideRepo: PeptideRepository
    private let logRepo: LogRepository
    private var listeners: [ListenerRegistration] = []

    init(peptideRepo: PeptideRepository, logRepo: LogRepository) {
        self.peptideRepo = peptideRepo
        self.logRepo = logRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(logRepo.listen(days: 30) { [weak self] in self?.logs = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func peptide(for log: InjectionLog) -> Peptide? {
        peptides.first { $0.id == log.peptideId }
    }

    /// Logs filtered by selectedDays and optional peptide filter, grouped by day
    var groupedLogs: [(date: Date, logs: [InjectionLog])] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedDays, to: Date())!
        let filtered = logs.filter { log in
            log.timestamp >= cutoff &&
            (filterPeptideId == nil || log.peptideId == filterPeptideId)
        }
        let grouped = Dictionary(grouping: filtered) { log in
            Calendar.current.startOfDay(for: log.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, logs: $0.value) }
    }

    /// Doses for half-life chart per peptide (all within 30 days)
    func doses(for peptide: Peptide) -> [(amount: Double, timestamp: Date)] {
        logs
            .filter { $0.peptideId == peptide.id }
            .map { (amount: $0.doseAmount, timestamp: $0.timestamp) }
    }
}
```

- [ ] **Step 2: Create LogRowView.swift**

```swift
import SwiftUI

struct LogRowView: View {
    let log: InjectionLog
    let peptideName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(peptideName).font(.subheadline).bold().foregroundColor(.white)
                if let site = log.injectionSite {
                    Text("Site: \(site)").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(log.doseAmount, specifier: "%.0f") \(log.doseUnit.label)")
                    .font(.subheadline).foregroundColor(.blue)
                Text(log.timestamp.shortTime)
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Create HistoryView.swift (log list portion — chart added in Task 14)**

```swift
import SwiftUI

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.11).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Day range picker
                        Picker("Range", selection: $viewModel.selectedDays) {
                            Text("7d").tag(7)
                            Text("14d").tag(14)
                            Text("30d").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Half-life chart placeholder (replaced in Task 14)
                        HalfLifeChartView(viewModel: viewModel)

                        // Log list grouped by day
                        ForEach(viewModel.groupedLogs, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.date.formatted(as: .medium))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    ForEach(group.logs) { log in
                                        LogRowView(
                                            log: log,
                                            peptideName: viewModel.peptide(for: log)?.name ?? "Unknown"
                                        )
                                        .padding(.horizontal)
                                        if log.id != group.logs.last?.id {
                                            Divider().padding(.horizontal)
                                        }
                                    }
                                }
                                .background(Color(red: 0.12, green: 0.14, blue: 0.2))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("History")
            .preferredColorScheme(.dark)
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}

// Placeholder replaced in Task 14
struct HalfLifeChartView: View {
    let viewModel: HistoryViewModel
    var body: some View { EmptyView() }
}
```

- [ ] **Step 4: Remove HistoryView and HistoryViewModel stubs from ContentView.swift**

- [ ] **Step 5: Build and run — verify history list**

Log a couple injections, open History tab. Grouped log rows should appear.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add History tab with grouped injection log"
```

---

## Task 14: Half-Life Chart

**Files:**
- Replace: `peptide tracker/Features/History/HalfLifeChartView.swift`

- [ ] **Step 1: Replace the HalfLifeChartView stub**

Remove the placeholder `struct HalfLifeChartView` from `HistoryView.swift` and create `HalfLifeChartView.swift`:

```swift
import SwiftUI
import Charts

struct HalfLifeChartView: View {
    @ObservedObject var viewModel: HistoryViewModel

    // Assign a stable color per peptide by index
    private let peptideColors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan]

    private func color(for peptide: Peptide) -> Color {
        let idx = (viewModel.peptides.firstIndex(of: peptide) ?? 0) % peptideColors.count
        return peptideColors[idx]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plasma Concentration").font(.headline).foregroundColor(.white)
                .padding(.horizontal)

            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.peptides) { peptide in
                        HStack(spacing: 4) {
                            Circle().fill(color(for: peptide)).frame(width: 8, height: 8)
                            Text(peptide.name).font(.caption).foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
            }

            Chart {
                ForEach(viewModel.peptides) { peptide in
                    let points = HalfLifeService.chartData(
                        doses: viewModel.doses(for: peptide),
                        halfLifeHours: peptide.halfLifeHours,
                        days: viewModel.selectedDays,
                        intervalHours: viewModel.selectedDays <= 7 ? 0.5 : 1.0
                    )
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Concentration (mcg)", point.concentration)
                        )
                        .foregroundStyle(color(for: peptide))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    .foregroundStyle(by: .value("Peptide", peptide.name))
                }

                // "Now" rule mark
                RuleMark(x: .value("Now", Date()))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel(format: .dateTime.month().day(), centered: true)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 200)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(red: 0.12, green: 0.14, blue: 0.2))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Build and verify chart compiles**

⌘B. If `Charts` module is not found, ensure the scheme targets iOS 16+: select target → General → Minimum Deployments → iOS 16.0.

- [ ] **Step 3: Run and verify chart renders**

⌘R. Log several injections across multiple peptides. Open History. Chart should show concentration curves per peptide. Toggle 7d/14d/30d.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add half-life concentration chart with Swift Charts"
```

---

## Task 15: Settings

**Files:**
- Create: `peptide tracker/Features/Settings/SettingsViewModel.swift`
- Create: `peptide tracker/Features/Settings/PeptideManagementView.swift`
- Create: `peptide tracker/Features/Settings/NotificationSettingsView.swift`
- Create: `peptide tracker/Features/Settings/SettingsView.swift`

Remove SettingsView and SettingsViewModel stubs from ContentView.swift.

- [ ] **Step 1: Create SettingsViewModel.swift**

```swift
import Foundation
import FirebaseFirestore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var peptides: [Peptide] = []
    @Published var schedules: [Schedule] = []
    @Published var profile: UserProfile?

    private let peptideRepo: PeptideRepository
    private let scheduleRepo: ScheduleRepository
    private let userRepo: UserRepository
    private var listeners: [ListenerRegistration] = []

    init(peptideRepo: PeptideRepository, scheduleRepo: ScheduleRepository, userRepo: UserRepository) {
        self.peptideRepo = peptideRepo
        self.scheduleRepo = scheduleRepo
        self.userRepo = userRepo
    }

    func startListening() {
        listeners.append(peptideRepo.listen { [weak self] in self?.peptides = $0 })
        listeners.append(scheduleRepo.listen { [weak self] in self?.schedules = $0 })
    }

    func stopListening() { listeners.forEach { $0.remove() }; listeners.removeAll() }

    func addPeptide(name: String, halfLifeHours: Double, defaultDose: Double, unit: DoseUnit) async throws {
        let peptide = Peptide(name: name, halfLifeHours: halfLifeHours, defaultDoseAmount: defaultDose, defaultDoseUnit: unit, createdAt: Date())
        try await peptideRepo.add(peptide)
    }

    func deletePeptide(_ peptide: Peptide) async throws {
        guard let id = peptide.id else { return }
        try await peptideRepo.delete(id: id)
    }

    func schedule(for peptide: Peptide) -> Schedule? {
        schedules.first { $0.peptideId == peptide.id && $0.isActive }
    }

    func addSchedule(for peptide: Peptide, doseAmount: Double, unit: DoseUnit, frequency: DoseFrequency, timeSeconds: Int) async throws {
        guard let peptideId = peptide.id else { return }
        let schedule = Schedule(
            peptideId: peptideId,
            doseAmount: doseAmount,
            doseUnit: unit,
            frequency: frequency,
            timeOfDaySeconds: timeSeconds,
            startDate: Date(),
            endDate: nil,
            isActive: true,
            notificationIds: []
        )
        let scheduleId = try await scheduleRepo.add(schedule)

        // Schedule notifications
        var saved = schedule
        saved.id = scheduleId
        let slots = NotificationService.slotsPerPeptide(activePeptideCount: schedules.count + 1)
        let ids = await NotificationService.schedule(for: saved, peptideName: peptide.name, slotsPerPeptide: slots)
        try await scheduleRepo.updateNotificationIds(ids, for: scheduleId)
    }

    func toggleNotifications(for schedule: Schedule) async throws {
        var updated = schedule
        updated.isActive = !schedule.isActive
        if !updated.isActive {
            NotificationService.cancel(ids: schedule.notificationIds)
            updated.notificationIds = []
        }
        try await scheduleRepo.update(updated)
    }
}
```

- [ ] **Step 2: Create PeptideManagementView.swift**

```swift
import SwiftUI

struct PeptideManagementView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAddPeptide = false

    var body: some View {
        List {
            ForEach(viewModel.peptides) { peptide in
                NavigationLink {
                    PeptideDetailSettingsView(peptide: peptide, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(peptide.name).font(.headline)
                        Text("t½ \(peptide.halfLifeHours, specifier: "%.1f")h · \(peptide.defaultDoseAmount, specifier: "%.0f") \(peptide.defaultDoseUnit.label)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                let toDelete = indexSet.map { viewModel.peptides[$0] }
                Task { for p in toDelete { try? await viewModel.deletePeptide(p) } }
            }
        }
        .navigationTitle("Peptides")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddPeptide = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showAddPeptide) {
            AddPeptideView(viewModel: viewModel)
        }
    }
}

struct AddPeptideView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var halfLife = ""
    @State private var defaultDose = ""
    @State private var unit: DoseUnit = .mcg
    // Schedule fields
    @State private var frequency: DoseFrequency = .daily
    @State private var doseTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!

    var body: some View {
        NavigationStack {
            Form {
                Section("Peptide") {
                    TextField("Name (e.g. BPC-157)", text: $name)
                    TextField("Half-life (hours)", text: $halfLife).keyboardType(.decimalPad)
                    TextField("Default dose", text: $defaultDose).keyboardType(.decimalPad)
                    Picker("Unit", selection: $unit) {
                        ForEach(DoseUnit.allCases) { u in Text(u.label).tag(u) }
                    }
                }
                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(DoseFrequency.allCases) { f in Text(f.label).tag(f) }
                    }
                    DatePicker("Time", selection: $doseTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("New Peptide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty,
                              let hl = Double(halfLife),
                              let dose = Double(defaultDose) else { return }
                        let cal = Calendar.current
                        let comps = cal.dateComponents([.hour, .minute], from: doseTime)
                        let seconds = (comps.hour ?? 8) * 3600 + (comps.minute ?? 0) * 60
                        Task {
                            try? await viewModel.addPeptide(name: name, halfLifeHours: hl, defaultDose: dose, unit: unit)
                            if let peptide = viewModel.peptides.first(where: { $0.name == name }) {
                                try? await viewModel.addSchedule(for: peptide, doseAmount: dose, unit: unit, frequency: frequency, timeSeconds: seconds)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || halfLife.isEmpty || defaultDose.isEmpty)
                }
            }
        }
    }
}

struct PeptideDetailSettingsView: View {
    let peptide: Peptide
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section("Info") {
                LabeledContent("Half-life", value: "\(peptide.halfLifeHours, specifier: "%.1f") hours")
                LabeledContent("Default dose", value: "\(peptide.defaultDoseAmount, specifier: "%.0f") \(peptide.defaultDoseUnit.label)")
            }
            if let schedule = viewModel.schedule(for: peptide) {
                Section("Schedule") {
                    LabeledContent("Frequency", value: schedule.frequency.label)
                    LabeledContent("Time", value: schedule.timeOfDay().shortTime)
                    Toggle("Notifications", isOn: Binding(
                        get: { schedule.isActive },
                        set: { _ in Task { try? await viewModel.toggleNotifications(for: schedule) } }
                    ))
                }
            }
        }
        .navigationTitle(peptide.name)
    }
}
```

- [ ] **Step 3: Create NotificationSettingsView.swift**

```swift
import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var permissionGranted = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Notification Permission")
                    Spacer()
                    Text(permissionGranted ? "Granted" : "Not granted")
                        .foregroundColor(permissionGranted ? .green : .red)
                }
                if !permissionGranted {
                    Button("Request Permission") {
                        Task {
                            permissionGranted = await NotificationService.requestPermission()
                        }
                    }
                }
            }

            Section("Active Schedules") {
                ForEach(viewModel.schedules) { schedule in
                    if let peptide = viewModel.peptides.first(where: { $0.id == schedule.peptideId }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(peptide.name).font(.subheadline)
                                Text("\(schedule.frequency.label) at \(schedule.timeOfDay().shortTime)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { schedule.isActive },
                                set: { _ in Task { try? await viewModel.toggleNotifications(for: schedule) } }
                            ))
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
        }
    }
}
```

- [ ] **Step 4: Create SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Peptides") {
                        PeptideManagementView(viewModel: viewModel)
                    }
                    NavigationLink("Notifications") {
                        NotificationSettingsView(viewModel: viewModel)
                    }
                }

                Section("Account") {
                    Text("Login & Premium — Coming Soon")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }
}
```

- [ ] **Step 5: Remove SettingsView and SettingsViewModel stubs from ContentView.swift**

- [ ] **Step 6: Build and run — end-to-end test**

Run ⌘R. Complete the full flow:
1. Settings → add a peptide (BPC-157, t½ = 1.5h, 250mcg, daily, 8:00 AM)
2. Inventory → Stock → add a vial (5mg, qty 1)
3. Inventory → Stock → tap vial → reconstitute (2mL) → confirm
4. Center Inject button → log injection
5. Dashboard → verify card shows doses left, stock days
6. History → verify log appears, chart renders

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Settings with peptide management and notification controls"
```

---

## Task 16: Polish + Notification Permission on First Launch

**Files:**
- Modify: `peptide tracker/peptide_trackerApp.swift`

- [ ] **Step 1: Request notification permission on first launch**

Update `peptide_trackerApp.swift` to request permission once after auth:

```swift
import SwiftUI

@main
struct peptide_trackerApp: App {
    @StateObject private var firebase = FirebaseManager.shared

    init() {
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let userId = firebase.userId {
                    ContentView(userId: userId)
                        .task {
                            _ = await NotificationService.requestPermission()
                        }
                } else {
                    ProgressView("Setting up...")
                        .task {
                            try? await FirebaseManager.shared.signInAnonymously()
                        }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add .gitignore for GoogleService-Info.plist (optional)**

If this repo is public or shared, add to `.gitignore`:
```
GoogleService-Info.plist
.superpowers/
```

```bash
cd "/Users/rsxing/peptide tracker/peptide tracker"
echo "GoogleService-Info.plist" >> .gitignore
echo ".superpowers/" >> .gitignore
git add .gitignore
```

- [ ] **Step 3: Final build and full regression**

⌘U to run all unit tests — expect all to pass.
⌘R — run through complete flow end-to-end one final time.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete peptide tracker v1 — notification permission on launch, gitignore"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Inventory — unconstituted stock (Task 9, StockTabView)
- ✅ Inventory — active vials / doses remaining (Task 10, ActiveVialsTabView)
- ✅ Reconstitution calculator with guided flow (Task 11)
- ✅ Injection logger (Task 12, InjectSheetView)
- ✅ Push notification reminders (Task 6 NotificationService, Task 12 scheduling on log)
- ✅ Half-life concentration graph per peptide (Tasks 5, 14)
- ✅ Days of supply / low stock alert logic (Task 8 DashboardViewModel)
- ✅ Firebase Firestore offline persistence (Task 1)
- ✅ Anonymous auth + upgrade path documented (Task 1)
- ✅ isPremium stub in UserProfile (Task 2)
- ✅ Slate Blue dark theme throughout
- ✅ 5-tab navigation with center inject FAB (Task 7)

**Out of scope (not in this plan, as agreed):**
- Sign in with Apple / email login UI
- RevenueCat paywall
- Apple Watch
- Web dashboard
