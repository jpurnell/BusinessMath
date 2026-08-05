# Fluent API Documentation Audit Report
**Date**: December 17, 2025
**Files Analyzed**:
- Documentation: `Sources/BusinessMath/BusinessMath.docc/1.4-FluentAPIGuide.md`
- Implementation: `ModelBuilder.swift`, `ScenarioBuilder.swift`, `TimeSeriesBuilder.swift`

---

## Executive Summary

The Fluent API Guide contains **extensive documentation for APIs that don't exist** or work completely differently than documented. This will cause significant confusion for users attempting to use the fluent builders.

### Critical Issues Found:
1. ❌ **InvestmentBuilder**: Entire section (120+ lines) documents non-existent API
2. ⚠️ **ModelBuilder**: API signatures completely different from documentation
3. ⚠️ **ScenarioBuilder**: Different builder pattern and component names
4. ⚠️ **TimeSeriesBuilder**: Partially matching but missing documented features

---

## 1. InvestmentBuilder - COMPLETELY MISSING ❌

### Documentation Shows (Lines 206-326):
```swift
let investment = buildInvestment {
    Name("Warehouse Expansion")
    InitialInvestment(100_000)

    CashFlow(year: 1, amount: 30_000)
    CashFlow(year: 2, amount: 35_000)
    CashFlow(year: 3, amount: 40_000)

    DiscountRate(0.10)
}

// Access metrics
print("NPV: $\(investment.npv)")
print("IRR: \(investment.irr * 100)%")
print("Payback: \(investment.paybackPeriod) years")
```

### Reality:
**FILE DOES NOT EXIST**: No `InvestmentBuilder.swift` file found anywhere in the codebase.

### Components Documented But Missing:
- ❌ `buildInvestment()` function
- ❌ `Name()` component
- ❌ `InitialInvestment()` component
- ❌ `CashFlow(year:, amount:)` component
- ❌ `CashFlow(date:, amount:)` component
- ❌ `DiscountRate()` component
- ❌ `Category()` component
- ❌ `CashFlowCategory()` component
- ❌ Investment properties: `.npv`, `.irr`, `.paybackPeriod`, `.roi`

### Impact:
**SEVERE** - 120+ lines of documentation teaching users to use an API that will fail at compile time.

---

## 2. ModelBuilder - MAJOR API DIFFERENCES ⚠️

### A. Top-Level Function Mismatch

**Documentation (Line 47, 74):**
```swift
let model = buildModel(for: company) {
    Revenue("Product Sales", periods: periods, values: [100_000, 110_000])
}
```

**Actual API:**
```swift
let model = FinancialModel {
    Revenue {
        // Revenue components go here
    }
}
```

❌ No `buildModel(for:)` function exists
❌ No entity/company parameter support
✅ `FinancialModel(@ModelBuilder)` initializer exists

---

### B. Revenue Component Mismatch

**Documentation (Line 75):**
```swift
Revenue("Product Revenue", periods: periods, values: revenueValues)
```

**Actual API:**
```swift
Revenue {
    Product("Product Revenue")
        .price(50)
        .quantity(1000)
}
```

**Differences:**
- Documentation: `Revenue` is a direct component with name, periods, values
- Reality: `Revenue` is a container that takes a `@RevenueBuilder` closure
- Documentation shows time series support (periods/values arrays)
- Reality has no time series support in Product

---

### C. Expense vs Costs Mismatch

**Documentation (Lines 49, 77-80):**
```swift
Expense("Cost of Goods Sold",
       periods: periods,
       values: cogsValues,
       type: .costOfGoodsSold)

Expense("Operating Expenses",
       periods: periods,
       values: [20_000, 20_000],
       type: .operatingExpense)
```

**Actual API:**
```swift
Costs {
    Fixed("Overhead", 10_000)
    Variable("Materials", 0.25)
}
```

**Differences:**
- ❌ No `Expense()` component exists
- ✅ `Costs { ... }` container exists instead
- ❌ No expense type parameter (`.costOfGoodsSold`, `.operatingExpense`)
- ❌ No periods/values support for time series

---

### D. Product Component Mismatch

**Documentation (Lines 101-103):**
```swift
Product("Widget")
    .price(periods: periods, values: [10.0, 10.0, 10.5, 10.5])
    .quantity(periods: periods, values: [10_000, 11_000, 11_500, 12_000])
```

**Actual API (ModelBuilder.swift:254-266):**
```swift
Product("Widget")
    .price(50)         // Single value, not time series
    .quantity(1000)    // Single value, not time series
    .customers(500)    // Alternative to quantity
```

**Differences:**
- Documentation: `.price(periods:, values:)` - time series support
- Reality: `.price(Double)` - single value only
- Documentation: `.quantity(periods:, values:)` - time series support
- Reality: `.quantity(Double)` - single value only

---

### E. Fixed/Variable Cost Name Mismatch

**Documentation (Lines 110-115):**
```swift
FixedCost("Rent", periods: periods, value: 5_000)
FixedCost("Salaries", periods: periods, value: 15_000)
VariableCost("Materials", rate: 0.40)
VariableCost("Shipping", rate: 0.05)
```

**Actual API (ModelBuilder.swift:351-357):**
```swift
Fixed("Rent", 5_000)       // Not FixedCost
Variable("Materials", 0.40) // Not VariableCost
```

**Differences:**
- Documentation: `FixedCost()` component
- Reality: `Fixed()` function
- Documentation: `VariableCost()` component
- Reality: `Variable()` function
- Documentation: `periods:` parameter support
- Reality: No time series support

---

### F. ForEach Support Claims

**Documentation (Lines 195-203):**
```swift
ForEach(products) { name, price, quantity in
    Product(name)
        .price(periods: periods, values: Array(repeating: price, count: 4))
        .quantity(periods: periods, values: Array(repeating: quantity, count: 4))
}
```

**Reality:**
❌ No `ForEach` support in `ModelBuilder`
⚠️ Result builders support array iteration via `buildArray`, but no `ForEach` helper

---

## 3. ScenarioBuilder - COMPLETELY DIFFERENT PATTERN ⚠️

### A. Top-Level Function Mismatch

**Documentation (Line 338):**
```swift
let baseCase = buildScenario {
    Name("Base Case")
    Description("Expected performance")
    Driver("Revenue Growth", value: 0.15)
}
```

**Actual API:**
```swift
let scenarios = ScenarioSet {
    Baseline {
        revenue(1_000_000)
        growth(0.10)
    }
}
```

**Differences:**
- ❌ No `buildScenario()` function
- ✅ `ScenarioSet { ... }` builder exists
- ❌ No `Name()`, `Description()` components
- ❌ No generic `Driver()` component

---

### B. Scenario Types

**Documentation (Lines 338-368):**
```swift
let baseCase = buildScenario { ... }
let bestCase = buildScenario { ... }
let worstCase = buildScenario { ... }
```

**Actual API (ScenarioBuilder.swift:166-184):**
```swift
ScenarioSet {
    Baseline { ... }          // Predefined scenario type
    Pessimistic { ... }       // Predefined scenario type
    Optimistic { ... }        // Predefined scenario type
    ScenarioNamed("Custom") { ... }  // Custom name
}
```

**Differences:**
- Documentation: Freeform scenario creation with `buildScenario()`
- Reality: Predefined scenario types (Baseline, Pessimistic, Optimistic)
- Documentation: Scenarios are individual objects
- Reality: Scenarios are grouped in a `ScenarioSet`

---

### C. Driver vs Parameter Functions

**Documentation (Lines 342-345):**
```swift
Driver("Revenue Growth", value: 0.15)
Driver("Gross Margin", value: 0.60)
Driver("Operating Expenses", value: 200_000)
Driver("Tax Rate", value: 0.25)
```

**Actual API (ScenarioBuilder.swift:206-233):**
```swift
revenue(1_000_000)        // Specific function, not Driver()
growth(0.10)              // Specific function
costs(200_000)            // Specific function
margin(0.60)              // Specific function
discountRate(0.08)        // Specific function
parameter("custom", value: 100)  // Generic function
```

**Differences:**
- Documentation: Generic `Driver(name, value)` component
- Reality: Specific functions per parameter type + generic `parameter()`

---

### D. Adjustments

**Documentation (Lines 385-389):**
```swift
Adjustment("Add International Revenue") {
    AddDriver("International Revenue", value: 300_000)
    AdjustDriver("Operating Expenses", increase: 50_000)
    AdjustDriver("Cost of Goods Sold", multiplyBy: 1.10)
}
```

**Actual API (ScenarioBuilder.swift:236-252):**
```swift
adjustRevenue(by: 0.10)      // Percentage adjustment
adjustCosts(by: 0.05)        // Percentage adjustment
adjustGrowth(by: 0.02)       // Percentage adjustment
adjust("custom", by: 0.15)   // Generic percentage adjustment
```

**Differences:**
- ❌ No `Adjustment()` container component
- ❌ No `AddDriver()` component
- ❌ No `AdjustDriver(increase:)` component
- ❌ No `multiplyBy:` parameter
- ✅ Percentage adjustments via `adjustRevenue(by:)`, etc.
- Reality: All adjustments are percentage-based, no absolute increases

---

## 4. TimeSeriesBuilder - PARTIALLY MATCHING ⚠️

### A. Top-Level Function Mismatch

**Documentation (Line 484):**
```swift
let revenue = buildTimeSeries(startingAt: jan) {
    Entry(100)
    Entry(105)
    Entry(110)
}
```

**Actual API:**
```swift
let series = TimeSeries {
    Period.year(2023) => 1_000_000
    Period.year(2024) => 1_100_000
}

// OR

let projected = TimeSeries(from: 2023, to: 2030) {
    starting(at: 1_000_000)
    growing(by: 0.10)
}
```

**Differences:**
- ❌ No `buildTimeSeries(startingAt:)` function
- ✅ `TimeSeries(@TimeSeriesBuilder)` initializer exists
- ✅ `TimeSeries(from:, to:, @ProjectionBuilder)` exists
- ❌ No automatic period sequencing from start period
- ✅ Arrow operator `=>` for period/value pairs

---

### B. Entry Component

**Documentation (Lines 486-496, 506-517):**
```swift
Entry(100)
Entry(105, label: "February")
Entry(110, label: "March")
```

**Actual API:**
```swift
Period.year(2023) => 1_000_000  // No Entry() component
```

**Differences:**
- ❌ No `Entry()` component
- ✅ Arrow operator `=>` for entries
- ❌ No label support in builder syntax
- ⚠️ Must specify period explicitly, not inferred

---

### C. Growth Component

**Documentation (Lines 577-579):**
```swift
Entry(100, label: "Base")
Growth(rate: 0.05, periods: 11)  // 11 more months
```

**Actual API:**
```swift
TimeSeries(from: 2023, to: 2030) {
    starting(at: 100)
    growing(by: 0.05)
}
```

**Differences:**
- ❌ No `Growth(rate:, periods:)` component
- ✅ `growing(by:)` exists but works differently
- Documentation: `Growth` creates N new entries
- Reality: `growing` sets rate for entire projection

---

### D. ForEach Support

**Documentation (Lines 534-545):**
```swift
ForEach(historicalData) { value in
    Entry(value)
}

ForEach(Array(historicalData.enumerated())) { index, value in
    Entry(value, label: "Month \(index + 1)")
}
```

**Reality:**
⚠️ Result builder supports `buildArray()` for loops, but:
- ❌ No `ForEach` helper function
- Users must use standard Swift `for` loops or `map()`

---

## 5. Summary of Missing Components

### InvestmentBuilder (ENTIRE FILE MISSING):
- `buildInvestment()`
- `Name()`
- `InitialInvestment()`
- `CashFlow(year:, amount:)`
- `CashFlow(date:, amount:)`
- `DiscountRate()`
- `Category()`
- `CashFlowCategory()`

### ModelBuilder:
- `buildModel(for:)` function
- `Revenue(name, periods:, values:)` direct component
- `Expense()` component
- `FixedCost()` component (has `Fixed()` instead)
- `VariableCost()` component (has `Variable()` instead)
- Time series support in Product (periods/values)
- `ForEach()` helper
- Entity/company association

### ScenarioBuilder:
- `buildScenario()` function
- `Name()` component
- `Description()` component
- `Driver()` component
- `Adjustment()` container
- `AddDriver()` component
- `AdjustDriver(increase:)` component
- `multiplyBy:` parameter

### TimeSeriesBuilder:
- `buildTimeSeries(startingAt:)` function
- `Entry()` component
- `Entry(label:)` with labels
- `Growth(rate:, periods:)` component
- `ForEach()` helper
- Automatic period sequencing

---

## 6. Recommendations

### Option A: Update Documentation to Match Implementation ✅ RECOMMENDED
**Effort**: Medium
**Timeline**: 1-2 days
**Pros**:
- Users can use the library immediately
- No breaking changes to existing code
- Documents what actually works

**Cons**:
- Current implementation may be less user-friendly
- Missing features users might expect (InvestmentBuilder)

### Option B: Update Implementation to Match Documentation
**Effort**: High
**Timeline**: 1-2 weeks
**Pros**:
- More intuitive API as originally envisioned
- Better feature parity across builders
- Investment analysis support

**Cons**:
- Significant development work
- May introduce breaking changes
- Need to implement InvestmentBuilder from scratch

### Option C: Hybrid Approach
**Effort**: High
**Timeline**: 1-2 weeks
**Details**:
1. Update ModelBuilder/ScenarioBuilder docs to match reality (quick fix)
2. Implement InvestmentBuilder as documented (new feature)
3. Add missing TimeSeriesBuilder features incrementally

---

## 7. Specific Actions Needed

### Immediate (Update Documentation):

1. **Remove InvestmentBuilder Section** (Lines 206-326)
   - Or mark as "Coming Soon" with note that it's not implemented

2. **Fix ModelBuilder Examples**:
   - Change `buildModel(for:)` → `FinancialModel { ... }`
   - Change `Revenue("name", periods:, values:)` → `Revenue { Product("name").price().quantity() }`
   - Change `Expense()` → `Costs { Fixed() / Variable() }`
   - Change `FixedCost()` → `Fixed()`
   - Change `VariableCost()` → `Variable()`
   - Remove time series support from Product examples
   - Remove or clarify ForEach usage

3. **Fix ScenarioBuilder Examples**:
   - Change `buildScenario()` → `ScenarioSet { Baseline/Pessimistic/Optimistic }`
   - Change `Driver()` → specific functions (`revenue()`, `growth()`, etc.)
   - Change `Adjustment()` → individual `adjust*()` functions
   - Update adjustment syntax to percentage-based only

4. **Fix TimeSeriesBuilder Examples**:
   - Change `buildTimeSeries(startingAt:)` → `TimeSeries { ... }` or `TimeSeries(from:, to:) { ... }`
   - Change `Entry()` → `Period => value` arrow operator
   - Change `Growth(rate:, periods:)` → `growing(by:)` in projection
   - Clarify ForEach usage or remove examples

### Future Enhancements:
1. Implement InvestmentBuilder as documented
2. Add time series support to ModelBuilder
3. Add ForEach convenience functions to builders
4. Consider adding `buildModel(for:)` convenience function

---

## 8. Testing Requirements

After fixing documentation:
1. ✅ Verify all code examples compile
2. ✅ Run example code to confirm it produces expected output
3. ✅ Add unit tests for documented examples
4. ✅ Update example files to use correct API

---

**Report Generated**: December 17, 2025
**Audit Status**: Complete
**Priority**: HIGH - Blocks user adoption of Fluent APIs
