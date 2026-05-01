# Graph View Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add consistent peptide colors and horizontal scrolling to the history tab's graph view

**Architecture:** Add deterministic color generation utility, time range enum, update chart to use fixed colors and scrollable time axis, add color picker UI for peptide customization

**Tech Stack:** SwiftUI, Swift Charts, Firebase Firestore

---

## File Structure

**New Files:**
- `peptide tracker/Utilities/ColorGenerator.swift` - Deterministic color generation from peptide names
- `peptide tracker/Models/TimeRange.swift` - Time range options with date calculations

**Modified Files:**
- `peptide tracker/Models/Peptide.swift` - Add optional color field
- `peptide tracker/Features/History/HalfLifeChartView.swift` - Use fixed colors, add scrolling and time range selector
- `peptide tracker/Features/Settings/PeptideManagementView.swift` - Add color picker for each peptide

---

### Task 1: Create ColorGenerator Utility

**Files:**
- Create: `peptide tracker/Utilities/ColorGenerator.swift`
- Test: `peptide trackerTests/ColorGeneratorTests.swift`

- [ ] **Step 1: Write failing test for color generation**

```swift
import XCTest
@testable import peptide_tracker

final class ColorGeneratorTests: XCTestCase {
    func testColorGenerationIsDeterministic() {
        let name = "TestPeptide"
        let color1 = ColorGenerator.color(for: name)
        let color2 = ColorGenerator.color(for: name)

        // Colors should be identical for same name
        XCTAssertEqual(color1, color2)
    }

    func testDifferentNamesProduceDifferentColors() {
        let color1 = ColorGenerator.color(for: "PeptideA")
        let color2 = ColorGenerator.color(for: "PeptideB")

        // Different names should produce different colors
        XCTAssertNotEqual(color1, color2)
    }

    func testColorGenerationIsCaseSensitive() {
        let color1 = ColorGenerator.color(for: "peptide")
        let color2 = ColorGenerator.color(for: "Peptide")

        // Case should affect color
        XCTAssertNotEqual(color1, color2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL with "ColorGenerator not defined"

- [ ] **Step 3: Create ColorGenerator utility**

```swift
import SwiftUI

struct ColorGenerator {
    static func color(for name: String) -> Color {
        let hash = name.hashValue
        let hue = Double(abs(hash) % 360)
        return Color(
            hue: hue / 360.0,
            saturation: 0.7,
            brightness: 0.5
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "peptide tracker/Utilities/ColorGenerator.swift" "peptide trackerTests/ColorGeneratorTests.swift"
git commit -m "feat: add ColorGenerator utility for deterministic peptide colors"
```

---

### Task 2: Create TimeRange Enum

**Files:**
- Create: `peptide tracker/Models/TimeRange.swift`
- Test: `peptide trackerTests/TimeRangeTests.swift`

- [ ] **Step 1: Write failing test for time range calculations**

```swift
import XCTest
@testable import peptide_tracker

final class TimeRangeTests: XCTestCase {
    func testLast7DaysRange() {
        let range = TimeRange.last7Days
        let now = Date()
        let expectedStart = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        // Should be approximately 7 days ago (within 1 second tolerance)
        let timeDiff = range.startDate.timeIntervalSince(expectedStart)
        XCTAssertLessThan(abs(timeDiff), 1.0)

        // End date should be now
        let endDiff = range.endDate.timeIntervalSince(now)
        XCTAssertLessThan(abs(endDiff), 1.0)
    }

    func testLast30DaysRange() {
        let range = TimeRange.last30Days
        let now = Date()
        let expectedStart = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        let timeDiff = range.startDate.timeIntervalSince(expectedStart)
        XCTAssertLessThan(abs(timeDiff), 1.0)
    }

    func testLast90DaysRange() {
        let range = TimeRange.last90Days
        let now = Date()
        let expectedStart = Calendar.current.date(byAdding: .day, value: -90, to: now)!

        let timeDiff = range.startDate.timeIntervalSince(expectedStart)
        XCTAssertLessThan(abs(timeDiff), 1.0)
    }

    func testAllTimeRange() {
        let range = TimeRange.allTime
        let now = Date()

        // End date should be now
        let endDiff = range.endDate.timeIntervalSince(now)
        XCTAssertLessThan(abs(endDiff), 1.0)

        // Start date should be far in the past (before any reasonable data)
        let farPast = Calendar.current.date(byAdding: .year, value: -10, to: now)!
        XCTAssertLessThan(range.startDate, farPast)
    }

    func testCaseIterable() {
        // Verify all cases are accessible
        let allRanges = TimeRange.allCases
        XCTAssertEqual(allRanges.count, 4)
        XCTAssertTrue(allRanges.contains(.last7Days))
        XCTAssertTrue(allRanges.contains(.last30Days))
        XCTAssertTrue(allRanges.contains(.last90Days))
        XCTAssertTrue(allRanges.contains(.allTime))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL with "TimeRange not defined"

- [ ] **Step 3: Create TimeRange enum**

```swift
import Foundation

enum TimeRange: CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case allTime

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: now) ?? now
        case .allTime:
            // Return a date far in the past
            return calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
    }

    var endDate: Date {
        return Date()
    }

    var displayName: String {
        switch self {
        case .last7Days:
            return "7 Days"
        case .last30Days:
            return "30 Days"
        case .last90Days:
            return "90 Days"
        case .allTime:
            return "All Time"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "peptide tracker/Models/TimeRange.swift" "peptide trackerTests/TimeRangeTests.swift"
git commit -m "feat: add TimeRange enum for configurable chart time windows"
```

---

### Task 3: Add Color Field to Peptide Model

**Files:**
- Modify: `peptide tracker/Models/Peptide.swift`

- [ ] **Step 1: Read current Peptide model**

```bash
cat "peptide tracker/Models/Peptide.swift"
```

- [ ] **Step 2: Add color field to Peptide struct**

Add this property to the Peptide struct:
```swift
var color: String?  // Hex color string, nil = use generated color
```

Add this helper method to Peptide struct:
```swift
var displayColor: Color {
    if let colorHex = color {
        return Color(hex: colorHex) ?? ColorGenerator.color(for: name)
    }
    return ColorGenerator.color(for: name)
}
```

- [ ] **Step 3: Add Color hex initializer extension**

Create extension at end of file:
```swift
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

- [ ] **Step 4: Build to verify no compilation errors**

Run: `xcodebuild build -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: SUCCESS

- [ ] **Step 5: Commit**

```bash
git add "peptide tracker/Models/Peptide.swift"
git commit -m "feat: add optional color field to Peptide model"
```

---

### Task 4: Update HalfLifeChartView with Fixed Colors

**Files:**
- Modify: `peptide tracker/Features/History/HalfLifeChartView.swift`

- [ ] **Step 1: Read current HalfLifeChartView**

```bash
cat "peptide tracker/Features/History/HalfLifeChartView.swift"
```

- [ ] **Step 2: Add timeRange state variable**

Add after line 16 (after `@State private var hiddenPeptides: Set<String> = []`):
```swift
@State private var timeRange: TimeRange = .last90Days
```

- [ ] **Step 3: Add helper method to get peptide color**

Add after line 73 (after `peptideSeries` method):
```swift
private func colorForPeptide(named name: String) -> Color {
    if let peptide = peptides.first(where: { $0.name == name }) {
        return peptide.displayColor
    }
    return ColorGenerator.color(for: name)
}
```

- [ ] **Step 4: Update peptideSeries to use explicit color**

Replace line 70 (`.foregroundStyle(by: .value("Peptide", name))`) with:
```swift
.foregroundStyle(colorForPeptide(named: name))
```

- [ ] **Step 5: Add time range picker UI**

Add after line 90 (after scale toggle picker):
```swift
// Time range picker
Picker("Time Range", selection: $timeRange) {
    ForEach(TimeRange.allCases, id: \.self) { range in
        Text(range.displayName).tag(range)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal)
```

- [ ] **Step 6: Add chart scrolling and x-axis scale**

Add after line 147 (after `.if(normalized) { $0.chartYScale(domain: 0.0...105.0) }`):
```swift
.chartScrollableAxes(.horizontal)
.chartXScale(domain: timeRange.startDate...timeRange.endDate)
```

- [ ] **Step 7: Build to verify no compilation errors**

Run: `xcodebuild build -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: SUCCESS

- [ ] **Step 8: Commit**

```bash
git add "peptide tracker/Features/History/HalfLifeChartView.swift"
git commit -m "feat: add fixed colors and horizontal scrolling to chart"
```

---

### Task 5: Add Color Picker to PeptideManagementView

**Files:**
- Modify: `peptide tracker/Features/Settings/PeptideManagementView.swift`

- [ ] **Step 1: Read current PeptideManagementView**

```bash
cat "peptide tracker/Features/Settings/PeptideManagementView.swift"
```

- [ ] **Step 2: Add color picker to each peptide row**

Find the peptide row rendering code and add color picker UI. Add this inside the peptide row VStack:
```swift
HStack {
    Text("Color")
        .foregroundColor(.secondary)
    Spacer()

    if let colorHex = peptide.color {
        ColorPicker("", selection: Binding(
            get: { Color(hex: colorHex) ?? .gray },
            set: { newColor in
                // Convert Color to hex string
                let uiColor = UIColor(newColor)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                let hex = String(
                    format: "#%02X%02X%02X",
                    Int(red * 255),
                    Int(green * 255),
                    Int(blue * 255)
                )

                var updatedPeptide = peptide
                updatedPeptide.color = hex
                viewModel.updatePeptide(updatedPeptide)
            }
        ))
        .labelsHidden()

        Button(action: {
            var updatedPeptide = peptide
            updatedPeptide.color = nil
            viewModel.updatePeptide(updatedPeptide)
        }) {
            Image(systemName: "arrow.counterclockwise")
                .foregroundColor(.secondary)
        }
    } else {
        ColorPicker("", selection: Binding(
            get: { peptide.displayColor },
            set: { newColor in
                let uiColor = UIColor(newColor)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                let hex = String(
                    format: "#%02X%02X%02X",
                    Int(red * 255),
                    Int(green * 255),
                    Int(blue * 255)
                )

                var updatedPeptide = peptide
                updatedPeptide.color = hex
                viewModel.updatePeptide(updatedPeptide)
            }
        ))
        .labelsHidden()
    }
}
.padding(.vertical, 4)
```

- [ ] **Step 3: Build to verify no compilation errors**

Run: `xcodebuild build -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: SUCCESS

- [ ] **Step 4: Commit**

```bash
git add "peptide tracker/Features/Settings/PeptideManagementView.swift"
git commit -m "feat: add color picker to peptide management UI"
```

---

### Task 6: Integration Testing

**Files:**
- Test: Manual testing in iOS Simulator

- [ ] **Step 1: Build and run app**

Run: `xcodebuild -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: SUCCESS

- [ ] **Step 2: Test color consistency**

1. Open History tab
2. Observe peptide colors in chart
3. Toggle peptide visibility using filter chips
4. Verify colors remain consistent for each peptide
5. Hide and show different peptides
6. Confirm colors don't change

- [ ] **Step 3: Test color customization**

1. Open Settings tab
2. Navigate to Peptide Management
3. Select a peptide
4. Use color picker to change color
5. Return to History tab
6. Verify chart uses new color
7. Reset color using arrow button
8. Verify chart returns to generated color

- [ ] **Step 4: Test time range selection**

1. Open History tab
2. Tap different time range options (7d, 30d, 90d, all time)
3. Verify chart updates time window
4. Scroll horizontally within chart
5. Verify "now" marker remains visible
6. Test with various data volumes

- [ ] **Step 5: Test edge cases**

1. Test with no injections - verify empty state
2. Test with single peptide - verify color consistency
3. Test with many peptides - verify distinct colors
4. Test scrolling with all time range - verify performance
5. Test color picker with various colors - verify hex conversion

- [ ] **Step 6: Commit final integration fixes**

```bash
git add .
git commit -m "test: complete integration testing for graph improvements"
```

---

### Task 7: Documentation and Cleanup

**Files:**
- Modify: `README.md` (if needed)

- [ ] **Step 1: Update README with new features**

Add section to README:
```markdown
## Graph View Features

### Color Consistency
- Peptides maintain consistent colors regardless of visibility
- Colors generated deterministically from peptide names
- Customizable colors via Settings > Peptide Management

### Time Range Selection
- Choose from 7 days, 30 days, 90 days, or all time
- Horizontal scrolling through time range
- "Now" marker shows current time position
```

- [ ] **Step 2: Verify all tests pass**

Run: `xcodebuild test -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: All tests PASS

- [ ] **Step 3: Final build verification**

Run: `xcodebuild build -scheme "peptide tracker" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: SUCCESS

- [ ] **Step 4: Commit documentation**

```bash
git add README.md
git commit -m "docs: update README with graph view features"
```

---

## Self-Review Checklist

**Spec Coverage:**
- ✅ Color consistency with deterministic generation
- ✅ User color customization
- ✅ Horizontal scrolling
- ✅ Configurable time ranges
- ✅ Color persistence
- ✅ "Now" marker visibility

**Placeholder Scan:**
- ✅ No TBD or TODO placeholders
- ✅ All code blocks complete
- ✅ All test cases fully defined
- ✅ No "implement similar to" references

**Type Consistency:**
- ✅ ColorGenerator.color(for:) consistent across tasks
- ✅ TimeRange enum cases match spec
- ✅ Peptide.color field type consistent (String?)
- ✅ Method signatures consistent

**Edge Cases Covered:**
- ✅ No injections scenario
- ✅ Single peptide visibility
- ✅ Color hex conversion
- ✅ Timezone handling (using Calendar.current)
- ✅ Color reset functionality
