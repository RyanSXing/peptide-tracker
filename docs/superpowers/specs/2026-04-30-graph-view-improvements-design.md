# Graph View Improvements Design

## Overview
Enhance the peptide tracker's graph view in the history tab with consistent peptide colors and horizontal scrolling through time.

## Requirements

### Color Consistency
- Peptides must maintain consistent colors regardless of visibility state
- Users can customize peptide colors
- Default colors generated deterministically from peptide name
- Colors persist across app sessions

### Horizontal Scrolling
- Chart must support horizontal scrolling through time
- Configurable time range windows (7 days, 30 days, 90 days, all time)
- Scroll from earliest data up to current time
- "Now" marker always visible

## Architecture

### Data Model Changes

**Peptide Model**
- Add `color: String?` field (optional, stored as hex string)
- nil = use deterministic generated color
- Non-nil = user-customized color

**TimeRange Enum**
```swift
enum TimeRange: CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case allTime
    
    var startDate: Date { /* calculation */ }
    var endDate: Date { Date() }
}
```

### New Components

**ColorGenerator Utility**
- Deterministic color generation from peptide name
- Hash-based hue calculation (0-360)
- Fixed saturation (70%) and brightness (50%)
- Returns SwiftUI Color

**TimeRange Enum**
- Time range options with date calculations
- Start date computation for each range
- End date always current time

### Modified Components

**HalfLifeChartView**
- Add `@State var timeRange: TimeRange = .last90Days`
- Replace auto color assignment with explicit colors
- Add `.chartScrollableAxes(.horizontal)` modifier
- Add `.chartXScale(domain:)` modifier
- Add time range segmented picker UI

**PeptideManagementView**
- Add color picker for each peptide
- Color picker binds to peptide's color field
- "Reset to Default" button to clear custom color

**Peptide Model**
- Add `color: String?` field
- Firebase-compatible storage format

## Implementation Details

### Color Generation Algorithm
```swift
func color(for name: String) -> Color {
    let hash = name.hashValue
    let hue = Double(abs(hash) % 360)
    return Color(hue: hue/360, saturation: 0.7, brightness: 0.5)
}
```

### Time Range Calculations
- `last7Days`: Date() - 7 days ... Date()
- `last30Days`: Date() - 30 days ... Date()
- `last90Days`: Date() - 90 days ... Date()
- `allTime`: (earliest injection date) ... Date()

### Chart Modifications
1. Remove `.foregroundStyle(by: .value("Peptide", name))`
2. Add explicit `.foregroundStyle(peptideColor)` for each series
3. Add `.chartScrollableAxes(.horizontal)`
4. Add `.chartXScale(domain: timeRange.startDate...timeRange.endDate)`
5. Keep existing line styles and visual elements

### Color Picker UI
- Use SwiftUI `ColorPicker` component
- Display in peptide management settings
- Bind to peptide's color field
- Add "Reset to Default" button to clear custom color

## Data Flow

1. Peptide data loads from Firebase with optional color field
2. Chart requests color for each peptide (stored or generated)
3. User changes time range → chart updates domain
4. User customizes color → saves to Peptide model → Firebase sync
5. Chart re-renders with new colors/time range

## State Management

**HalfLifeChartView**
- `@State var timeRange: TimeRange = .last90Days`
- Manages its own time range state

**HistoryViewModel**
- No changes needed
- Continues to provide peptides and logs data

**Color Persistence**
- Handled by existing Firebase sync
- Peptide model changes automatically sync

## Edge Cases

- No injections: Show empty state message
- All data fits in window: Scrolling automatically disabled
- Timezone consistency: Use consistent timezone across all dates
- Single peptide visible: Prevent hiding last visible peptide (existing behavior)
- Custom color reset: Clear color field to return to generated color

## Testing Considerations

- Verify colors remain consistent when peptides are hidden/shown
- Test color customization and persistence
- Verify scrolling works across all time ranges
- Test "all time" range with various data volumes
- Verify "now" marker position accuracy
- Test color generation produces distinct colors
- Verify color picker UI functionality
