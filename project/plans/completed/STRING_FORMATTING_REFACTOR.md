# String Formatting Refactoring Task

**Created:** December 2, 2025  
**Status:** Planned for future implementation  
**Priority:** Medium (prevents runtime crashes, improves code safety)

## Background

During Phase 3 of Topic 10 (UX Polish), we discovered that C-style format strings with width specifiers (e.g., `%-30s`, `%8d`) cause runtime crashes in Swift. Swift's `String(format:)` uses Objective-C format specifiers and does not support C-style width and alignment.

## Fixed

- ✅ `ModelProfiler.swift:formatted()` - Fixed report formatting (Dec 2, 2025)

## Remaining Work

The following files contain C-style format strings that should be refactored to use Swift native formatting:

### Files to Update (12 instances across 5 files)

1. **Sources/BusinessMath/Time Series/Period.swift** (2 instances)
   - Date formatting strings

2. **Sources/BusinessMath/Visualization/CommandLineVisualization.swift** (3 instances)
   - Histogram formatting

3. **Sources/BusinessMath/Scenario Analysis/SensitivityAnalysis.swift** (3 instances)
   - Table formatting in comments/examples

4. **Sources/BusinessMathMCP/Tools/MonteCarloTools.swift** (1 instance)
   - Histogram text formatting

5. **Sources/BusinessMathMCP/Tools/PortfolioTools.swift** (1 instance)
   - Portfolio table formatting

## Recommended Approach

### For Date Formatting (Period.swift)
```swift
// Current (C-style)
String(format: "%04d-%02d-%02d", year, month, day)

// Replace with DateFormatter or custom padding
let yearStr = String(year).padding(toLength: 4, withPad: "0", startingAt: 0)
let monthStr = String(month).padding(toLength: 2, withPad: "0", startingAt: 0)
let dayStr = String(day).padding(toLength: 2, withPad: "0", startingAt: 0)
return "\(yearStr)-\(monthStr)-\(dayStr)"

// Or use DateFormatter for ISO 8601
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withFullDate]
return formatter.string(from: date)
```

### For Table/Histogram Formatting
```swift
// Current (C-style)
String(format: "[%8.2f - %8.2f): %s %d (%.1f%%)", min, max, bar, count, pct)

// Replace with Swift padding
let minStr = String(format: "%.2f", min).padding(toLength: 8, withPad: " ", startingAt: 0)
let maxStr = String(format: "%.2f", max).padding(toLength: 8, withPad: " ", startingAt: 0)
let countStr = String(count).padding(toLength: 4, withPad: " ", startingAt: 0)
let pctStr = String(format: "%.1f", pct).padding(toLength: 5, withPad: " ", startingAt: 0)
return "[\(minStr) - \(maxStr): \(bar) \(countStr) (\(pctStr)%)"
```

## Benefits of Refactoring

1. **Prevents Runtime Crashes**: C-style width specifiers crash in Swift
2. **Type Safety**: Compile-time checking instead of runtime failures
3. **Consistency**: All formatting uses the same Swift native approach
4. **Maintainability**: Clear intent from method names
5. **Cross-Platform**: Works consistently across all Swift platforms

## Testing Strategy

For each file updated:
1. Run existing tests to ensure behavior is preserved
2. Verify formatting output matches original (character for character where possible)
3. Test edge cases (very large/small numbers, empty strings, etc.)
4. Visual inspection of formatted output

## Coding Rule Added

This guideline has been added to `coding_rules.md` (Section 2.5 - String Formatting):

> **Always use Swift native string formatting instead of C-style format strings.**
> - Use `.padding(toLength:withPad:startingAt:)` for alignment
> - Use `String(format: "%.3f", value)` for number precision only (no width specifiers)
> - Use string interpolation for simple cases

## Related Documents

- [Coding Rules](coding_rules.md) - Section 2.5: String Formatting
- [Topic 10 UX Polish Plan](TOPIC_10_UX_POLISH_PLAN.md) - Phase 3: Enhanced Error Handling

## Estimated Effort

- **Low**: Date formatting (Period.swift) - 30 minutes
- **Medium**: Visualization/Tools (4 files) - 2-3 hours total
- **Testing**: 1 hour
- **Total**: ~4 hours

## Notes

The most critical updates are in visualization code (CommandLineVisualization, histogram formatting) since these are likely to be executed frequently. Period.swift date formatting is also important but may use DateFormatter instead.

All existing instances appear to be in output/display code, not in core calculation logic, which reduces risk.
