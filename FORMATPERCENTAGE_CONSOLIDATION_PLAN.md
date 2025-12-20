# formatPercentage Consolidation Plan

## Problem Summary

The BusinessMath library has **18 duplicate implementations** of percentage formatting functions across the codebase:
- 183 usage sites calling these local functions
- Only 1 usage of the global `.percent()` extension (and it's buggy!)
- Multiple implementation patterns causing inconsistency

## Global Function (Target)

**Location**: `/Sources/BusinessMath/Extensions/extensionFormatted.swift:30-47`

```swift
extension BinaryFloatingPoint {
    public func percent(_ decimals: Int = 2) -> String {
        let value = Double(self)

        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = decimals
            formatter.minimumFractionDigits = decimals
            return value.formatted(.percent)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }
}
```

**Expected Usage**:
- Input: `0.10` (decimal form)
- Output: `"10%"` (multiplies by 100 automatically)

## Duplicate Implementations Found

### Group 1: BusinessMathMCP Tools (16 files)
All in `/Sources/BusinessMathMCP/Tools/`

1. **FinancialRatiosToolsExtensions.swift:23** - `formatPercent`
2. **ValuationCalculatorsTools.swift:43** - `formatPercent`
3. **AdvancedRatioTools.swift:23** - `formatPercent`
4. **BondValuationTools.swift:923** - `formatPercent`
5. **LoanPaymentAnalysisTools.swift:33** - `formatPercentage`
6. **LeaseAndCovenantTools.swift:19** - `formatPercent`
7. **MonteCarloTools.swift:36** - `formatPercent`
8. **CreditDerivativesTools.swift:541** - `formatPercent`
9. **FinancingTools.swift:19** - `formatPercent`
10. **DebtToolsExtensions.swift:23** - `formatPercent`
11. **WorkingCapitalTools.swift:23** - `formatPercent`
12. **UtilityTools.swift:19** - `formatPercent`
13. **StatisticalTools.swift:36** - `formatPercent`
14. **FinancialRatiosTools.swift:43** - `formatPercent`
15. **EquityValuationTools.swift:645** - `formatPercent`
16. **SeasonalityTools.swift:32** - `formatPercentage`

**Pattern**: `formatNumber(value * 100, decimals: decimals) + "%"`
- Simple string concatenation
- Manually multiplies by 100

### Group 2: TypeMarshalling (1 file)
17. **TypeMarshalling.swift:336** - `formatPercentage` (public method on Double extension)

**Pattern**: Uses NumberFormatter (similar to global)
```swift
let formatter = NumberFormatter()
formatter.numberStyle = .percent
formatter.maximumFractionDigits = decimals
formatter.minimumFractionDigits = decimals
return formatter.string(from: NSNumber(value: self)) ?? "\(self * 100)%"
```

### Group 3: CalculationTrace (1 file)
18. **CalculationTrace.swift:209** - `formatPercentage` (private)

**Pattern**: String.format
```swift
let percentage = value * 100
return String(format: "%.1f%%", percentage)
```

## Critical Bug Found

**InvestmentBuilder.swift:609**
```swift
result += "  Discount Rate: \((discountRate * 100).percent())\n"
```

**Problem**: Pre-multiplies by 100, then calls `.percent()` which multiplies by 100 again!
- Input: `discountRate = 0.10`
- Current: `(0.10 * 100).percent()` = `10.percent()` = `"1000%"` ❌
- Should be: `discountRate.percent()` = `0.10.percent()` = `"10%"` ✓

## Implementation Variations

| Implementation | Multiplies by 100? | Uses NumberFormatter? | Configurable decimals? |
|----------------|--------------------|-----------------------|------------------------|
| Global `.percent()` | ✓ (automatic) | ✓ | ✓ (default 2) |
| Group 1 (MCP Tools) | ✓ (manual) | ✗ | ✓ |
| Group 2 (TypeMarshalling) | ✓ (automatic) | ✓ | ✓ |
| Group 3 (CalculationTrace) | ✓ (manual) | ✗ | ✗ (hardcoded 1) |

## Consolidation Strategy

### Phase 1: Fix the Bug (Immediate)
**File**: InvestmentBuilder.swift:609
**Change**:
```swift
// Before
result += "  Discount Rate: \((discountRate * 100).percent())\n"

// After
result += "  Discount Rate: \(discountRate.percent())\n"
```

### Phase 2: Add Import to MCP Tools (Preparation)
All 16 MCP tool files need to import BusinessMath to access the global function:
```swift
import BusinessMath  // Add if not present
```

### Phase 3: Replace Local Functions (Systematic)

#### Step 1: Delete local function definitions (18 files)
Remove all `private func formatPercent/formatPercentage` definitions

#### Step 2: Update call sites (183 usages)
Search and replace pattern:
```swift
// Before (manual multiplication)
formatPercent(value, decimals: 2)
formatPercentage(value, decimals: 1)

// After (automatic multiplication already in value)
value.percent(2)
value.percent(1)
```

**Critical**: The local functions expect decimal values (0.10) and multiply by 100.
The global `.percent()` ALSO multiplies by 100. So usage doesn't need to change!

### Phase 4: Special Case - TypeMarshalling
**TypeMarshalling.swift:336** is a **public** method on Double extension.

**Options**:
1. **Delete** if not used outside the module
2. **Deprecate** with forwarding to global function:
   ```swift
   @available(*, deprecated, message: "Use .percent() instead")
   public func formatPercentage(decimals: Int = 2) -> String {
       return self.percent(decimals)
   }
   ```
3. **Keep** if it's part of a public API contract

**Recommendation**: Check usage, then deprecate with forwarding.

### Phase 5: Testing Strategy

1. **Unit tests**: Verify percentage formatting
   ```swift
   @Test("Percentage formatting")
   func percentFormatting() {
       #expect(0.10.percent() == "10%")
       #expect(0.1234.percent() == "12.34%")
       #expect(0.1234.percent(1) == "12.3%")
       #expect(1.5.percent() == "150%")
   }
   ```

2. **Integration tests**: Run all MCP tool tests to ensure output hasn't changed

3. **Visual verification**: Compare before/after output for key tools

## Automation Script

```bash
#!/bin/bash

# Phase 1: Fix InvestmentBuilder bug
sed -i '' 's/(discountRate \* 100)\.percent()/discountRate.percent()/g' \
  "Sources/BusinessMath/Fluent API/InvestmentBuilder.swift"

# Phase 2: Add import to MCP tools (if not present)
for file in Sources/BusinessMathMCP/Tools/*.swift; do
  if ! grep -q "^import BusinessMath$" "$file"; then
    sed -i '' '1i\
import BusinessMath
' "$file"
  fi
done

# Phase 3: Delete local formatPercent functions in MCP tools
for file in Sources/BusinessMathMCP/Tools/*.swift; do
  # Delete the function definition (3 lines: func, implementation, closing brace)
  sed -i '' '/^private func formatPercent.*{$/,/^}$/d' "$file"
  sed -i '' '/^private func formatPercentage.*{$/,/^}$/d' "$file"
done

# Phase 4: Replace formatPercent calls with .percent()
find Sources -name "*.swift" -type f -exec sed -i '' \
  's/formatPercent(\([^,]*\), decimals: \([0-9]*\))/\1.percent(\2)/g' {} \;
find Sources -name "*.swift" -type f -exec sed -i '' \
  's/formatPercent(\([^)]*\))/\1.percent()/g' {} \;
find Sources -name "*.swift" -type f -exec sed -i '' \
  's/formatPercentage(\([^,]*\), decimals: \([0-9]*\))/\1.percent(\2)/g' {} \;
find Sources -name "*.swift" -type f -exec sed -i '' \
  's/formatPercentage(\([^)]*\))/\1.percent()/g' {} \;
```

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Output format changes | Low | NumberFormatter ensures consistency |
| TypeMarshalling public API | Medium | Deprecate instead of delete |
| Import missing | Low | Add imports in Phase 2 |
| Call site errors | Medium | Comprehensive sed replacement + testing |
| InvestmentBuilder bug | High | Fix immediately in Phase 1 |

## Expected Benefits

1. **Code reduction**: ~90 lines deleted (18 × 5 lines average)
2. **Consistency**: All percentage formatting uses same logic
3. **Maintainability**: Single place to update formatting
4. **Bug fixes**: Fixes InvestmentBuilder 1000% bug
5. **Localization**: Global function has proper NumberFormatter support

## Rollback Plan

If issues arise:
1. Git revert to commit before consolidation
2. Or: Keep backup of all 18 files with formatPercent functions
3. Manual restoration takes ~10 minutes

## Timeline Estimate

- **Phase 1** (Bug fix): 5 minutes
- **Phase 2** (Add imports): 10 minutes
- **Phase 3** (Delete + replace): 30 minutes
- **Phase 4** (TypeMarshalling): 10 minutes
- **Phase 5** (Testing): 30 minutes
- **Total**: ~1.5 hours

## Success Criteria

- ✅ All 18 local formatPercent functions deleted
- ✅ All 183 call sites updated to use `.percent()`
- ✅ InvestmentBuilder bug fixed (no more 1000%)
- ✅ All tests pass
- ✅ Build succeeds without warnings
- ✅ MCP tool output unchanged (verified by spot checks)
