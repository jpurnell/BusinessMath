# Time Series Implementation - Master Plan

**Created:** October 15, 2025
**Project:** BusinessMath Library - Financial Projection Models
**Status:** Planning Phase

---

## Initial Request

> I have implemented this library to provide statistical support to business questions. This includes simulation and the ability to understand the results of a business process or test. I would like to be able to use these formulas to deliver full financial projection models - operational drivers that lead to profit and loss, balance sheet, and cash flow statements on a periodic - daily, quarterly, annual - basis. Typically, they would be done in excel, but I think I'd have more flexibility with a compiled program. This would be implemented in swift. Given what you see in this project, what steps would we need to implement. Provide a list of large topics, broken down into individual components that we can build together.

---

## Project Context

The BusinessMath library currently provides:
- **Statistics**: Descriptive statistics (mean, median, mode, variance, standard deviation, etc.)
- **Probability Distributions**: Normal, binomial, chi-squared, exponential, gamma, etc.
- **Simulation**: Box-Muller transform, various distribution generators
- **Correlation & Regression**: Covariance, correlation coefficients, linear regression
- **Inference**: Confidence intervals, p-values, t-statistics
- **Combinatorics**: Permutations, combinations, factorials
- **Bayesian Analysis**: Basic Bayes theorem implementation
- **Solvers**: Goal seek, derivatives
- **Preliminary Finance**: NPV (in process)

---

## Overall Roadmap (10 Topics)

### **1. TIME SERIES & TEMPORAL FRAMEWORK** ⬅️ **CURRENT FOCUS**
Foundation for period-based modeling

### 2. OPERATIONAL DRIVERS
Business metrics that feed financial statements

### 3. FINANCIAL STATEMENT MODELS
Income Statement, Balance Sheet, Cash Flow Statement

### 4. SCENARIO & SENSITIVITY ANALYSIS
Leverage simulation capabilities for uncertainty modeling

### 5. FINANCIAL RATIOS & METRICS
Profitability, efficiency, valuation, credit metrics

### 6. DEBT & FINANCING MODELS
Debt schedules, equity financing, capital structure

### 7. DATA STRUCTURES & ARCHITECTURE
Core model objects, formula engine, calculation graph

### 8. INPUT/OUTPUT & INTEGRATION
Data import/export, validation, auditing

### 9. ADVANCED FEATURES
ML integration, optimization, consolidation

### 10. USER EXPERIENCE & API DESIGN
Fluent APIs, model templates, documentation

---

## Time Series Implementation Plan

### **Phase 1: Core Temporal Structures**

#### 1.1 PeriodType Enum
**File:** `Sources/BusinessMath/Time Series/PeriodType.swift`

```swift
public enum PeriodType: String, Codable, Comparable {
    case daily
    case weekly
    case monthly
    case quarterly
    case annual

    // Conversion factors, ordering, etc.
}
```

**Design Decisions:**
- Make it `Comparable` to support period type comparisons
- Include computed properties: `daysApproximate`, `monthsEquivalent`
- Method to convert between period types

---

#### 1.2 Period Struct
**File:** `Sources/BusinessMath/Time Series/Period.swift`

```swift
public struct Period: Hashable, Comparable, Codable {
    public let type: PeriodType
    public let date: Date

    // Factory methods: Period.month(year: 2025, month: 1)
    // Computed properties: startDate, endDate, label, index
}
```

**Design Decisions:**
- Value type (struct) for immutability
- `Hashable` for use in dictionaries
- `Comparable` for sorting and ranges
- Date-based internally for precision
- Factory methods for ergonomic creation
- Support for period ranges: `Period.year(2025).quarters()` → `[Q1, Q2, Q3, Q4]`

---

#### 1.3 Period Arithmetic
**File:** `Sources/BusinessMath/Time Series/PeriodArithmetic.swift`

```swift
// Extensions on Period to support:
period + 3  // Add 3 periods
period - 1  // Subtract 1 period
period1...period10  // Range of periods
period1.distance(to: period2)  // Number of periods between
```

**Design Decisions:**
- Operator overloading for intuitive API
- Support for stride/range operations
- Respect fiscal calendar boundaries

---

#### 1.4 FiscalCalendar Struct
**File:** `Sources/BusinessMath/Time Series/FiscalCalendar.swift`

```swift
public struct FiscalCalendar {
    public let yearEnd: MonthDay  // e.g., December 31, or June 30

    func fiscalYear(for date: Date) -> Int
    func fiscalQuarter(for date: Date) -> Int
    func periodInFiscalYear(_ period: Period) -> Int
}
```

**Design Decisions:**
- Default to calendar year (Dec 31)
- Immutable configuration
- Methods to map calendar dates to fiscal periods

---

### **Phase 2: Time Series Container**

#### 2.1 TimeSeries Struct
**File:** `Sources/BusinessMath/Time Series/TimeSeries.swift`

```swift
public struct TimeSeries<T: Real> {
    public let periods: [Period]
    private let values: [Period: T]
    public let metadata: TimeSeriesMetadata

    // Subscript access: timeSeries[period]
    // Array-style: timeSeries.valuesArray
    // Filtering: timeSeries.range(from:to:)
}

public struct TimeSeriesMetadata {
    public let name: String
    public let units: String?
    public let category: String?
}
```

**Design Decisions:**
- Generic over `Real` for flexibility (Double, Float, etc.)
- Dictionary storage for O(1) lookup
- Sorted periods array for ordered iteration
- Metadata for reporting and debugging
- Support for missing values (return `nil` or default?)

---

#### 2.2 Time Series Operations
**File:** `Sources/BusinessMath/Time Series/TimeSeriesOperations.swift`

```swift
// Functional operations:
timeSeries.map { $0 * 1.1 }  // Apply transformation
timeSeries1.zip(timeSeries2) { $0 + $1 }  // Combine two series
timeSeries.fillForward()  // Forward-fill missing values
timeSeries.aggregate(by: .quarterly, method: .sum)  // Roll up to quarters
```

**Design Decisions:**
- Immutable operations (return new TimeSeries)
- Period alignment must match for binary operations
- Aggregation methods: sum, average, first, last, end-of-period
- Missing value strategies: forward-fill, backward-fill, interpolate, zero

---

#### 2.3 Time Series Analytics
**File:** `Sources/BusinessMath/Time Series/TimeSeriesAnalytics.swift`

```swift
// Growth calculations:
timeSeries.growthRate(lag: 1)  // Period-over-period
timeSeries.growthRate(lag: 4)  // Year-over-year (if quarterly)
timeSeries.cagr(from:to:)  // Compound annual growth rate
timeSeries.movingAverage(window: 3)  // 3-period moving average
timeSeries.seasonalIndices(periodsPerYear: 12)  // For monthly data
```

**Design Decisions:**
- Return new TimeSeries for transformations
- Leverage existing statistics functions (mean, stdDev)
- Handle edge cases (insufficient data, division by zero)

---

### **Phase 3: Time Value of Money**

#### 3.1 Present/Future Value
**File:** `Sources/BusinessMath/Time Series/TVM/PresentValue.swift`

```swift
/// Calculate present value of a future amount
public func presentValue<T: Real>(
    futureValue: T,
    rate: T,
    periods: Int
) -> T

/// Calculate future value of a present amount
public func futureValue<T: Real>(
    presentValue: T,
    rate: T,
    periods: Int
) -> T

/// PV of an annuity (equal periodic payments)
public func presentValueAnnuity<T: Real>(
    payment: T,
    rate: T,
    periods: Int,
    type: AnnuityType = .ordinary
) -> T

public enum AnnuityType {
    case ordinary  // Payments at end of period
    case due       // Payments at beginning of period
}
```

**Design Decisions:**
- Separate functions for single values vs. annuities
- Support both ordinary annuities and annuities due
- Follow Excel naming conventions where applicable

---

#### 3.2 Payment Calculations
**File:** `Sources/BusinessMath/Time Series/TVM/Payment.swift`

```swift
/// Calculate periodic payment for a loan
public func payment<T: Real>(
    presentValue: T,
    rate: T,
    periods: Int,
    futureValue: T = T(0),
    type: AnnuityType = .ordinary
) -> T

/// Calculate principal portion of payment
public func principalPayment<T: Real>(
    rate: T,
    period: Int,
    totalPeriods: Int,
    presentValue: T
) -> T

/// Calculate interest portion of payment
public func interestPayment<T: Real>(
    rate: T,
    period: Int,
    totalPeriods: Int,
    presentValue: T
) -> T
```

---

#### 3.3 Internal Rate of Return
**File:** `Sources/BusinessMath/Time Series/TVM/IRR.swift`

```swift
/// Calculate IRR for a series of cash flows
public func irr<T: Real>(
    cashFlows: [T],
    guess: T = T(0.1),
    tolerance: T = T(0.000001),
    maxIterations: Int = 100
) throws -> T

/// Calculate MIRR with separate financing and reinvestment rates
public func mirr<T: Real>(
    cashFlows: [T],
    financeRate: T,
    reinvestmentRate: T
) throws -> T
```

**Design Decisions:**
- Use Newton-Raphson method (leverage existing `goalSeek`)
- Throw errors for invalid inputs (all positive/negative flows)
- MIRR more realistic for most business cases

---

#### 3.4 NPV Refinement
**File:** `Sources/BusinessMath/Time Series/TVM/NPV.swift`

**Move from "zzz In Process" and enhance:**
- Remove debug `print()` statement
- Add variant that takes `TimeSeries` as input
- Add XNPV for irregular periods
- Comprehensive documentation
- Add related metrics: Profitability Index, Payback Period

---

### **Phase 4: Growth & Trend Models**

#### 4.1 Growth Calculations
**File:** `Sources/BusinessMath/Time Series/Growth/GrowthRate.swift`

```swift
/// Simple growth rate between two values
public func growthRate<T: Real>(from: T, to: T) -> T

/// Compound Annual Growth Rate
public func cagr<T: Real>(
    beginningValue: T,
    endingValue: T,
    years: T
) -> T

/// Apply growth rate forward
public func applyGrowth<T: Real>(
    baseValue: T,
    rate: T,
    periods: Int,
    compounding: CompoundingFrequency = .annual
) -> [T]

public enum CompoundingFrequency {
    case annual, semiannual, quarterly, monthly, daily, continuous
}
```

---

#### 4.2 Trend Models
**File:** `Sources/BusinessMath/Time Series/Growth/TrendModel.swift`

```swift
public protocol TrendModel {
    associatedtype T: Real

    func project(periods: Int) -> TimeSeries<T>
    func fit(to series: TimeSeries<T>)
}

public struct LinearTrend<T: Real>: TrendModel {
    // Uses existing linear regression
}

public struct ExponentialTrend<T: Real>: TrendModel {
    // Log-linear regression
}

public struct LogisticTrend<T: Real>: TrendModel {
    // S-curve growth (for market saturation)
}
```

**Design Decisions:**
- Protocol-based for extensibility
- Leverage existing regression functions
- Return TimeSeries for easy composition
- Support custom trend functions via closure

---

#### 4.3 Seasonality
**File:** `Sources/BusinessMath/Time Series/Growth/Seasonality.swift`

```swift
/// Calculate seasonal indices from historical data
public func seasonalIndices<T: Real>(
    _ series: TimeSeries<T>,
    periodsPerYear: Int
) -> [T]

/// Apply seasonal adjustment
public func seasonallyAdjust<T: Real>(
    _ series: TimeSeries<T>,
    indices: [T]
) -> TimeSeries<T>

/// Decompose series into trend + seasonal + residual
public func decomposeTimeSeries<T: Real>(
    _ series: TimeSeries<T>,
    periodsPerYear: Int,
    method: DecompositionMethod = .additive
) -> TimeSeriesDecomposition<T>

public enum DecompositionMethod {
    case additive      // Y = T + S + E
    case multiplicative // Y = T × S × E
}

public struct TimeSeriesDecomposition<T: Real> {
    public let trend: TimeSeries<T>
    public let seasonal: TimeSeries<T>
    public let residual: TimeSeries<T>
}
```

---

### **Phase 5: Testing & Documentation**

#### 5.1 Test Structure
```
Tests/BusinessMathTests/Time Series Tests/
├── Period Tests.swift
├── TimeSeries Tests.swift
├── TVM Tests.swift (PV, FV, PMT, IRR, MIRR, NPV)
├── Growth Tests.swift
└── Integration Tests.swift
```

**Test Coverage:**
- Edge cases: empty series, single period, missing values
- Known financial math results (Excel equivalents)
- Period arithmetic boundary conditions (month-end, leap years)
- Fiscal calendar scenarios
- Growth rate special cases (negative growth, zero values)

---

#### 5.2 Documentation Examples
Each module should include:
- Standalone usage examples
- Integration examples (combining multiple features)
- Real-world scenarios (loan amortization, revenue projection)
- Performance characteristics

---

## Directory Structure
```
Sources/BusinessMath/Time Series/
├── Period.swift
├── PeriodType.swift
├── PeriodArithmetic.swift
├── FiscalCalendar.swift
├── TimeSeries.swift
├── TimeSeriesOperations.swift
├── TimeSeriesAnalytics.swift
├── TVM/
│   ├── PresentValue.swift
│   ├── FutureValue.swift
│   ├── Payment.swift
│   ├── IRR.swift
│   ├── MIRR.swift
│   └── NPV.swift
└── Growth/
    ├── GrowthRate.swift
    ├── TrendModel.swift
    └── Seasonality.swift
```

---

## Key Design Principles

1. **Composability**: TimeSeries operations can be chained
2. **Immutability**: All operations return new values
3. **Type Safety**: Leverage Swift's type system and generics
4. **Excel Compatibility**: Match Excel function names/behavior where sensible
5. **Performance**: O(1) lookups, lazy evaluation where appropriate
6. **Testability**: Pure functions, dependency injection for dates

---

## Next Steps

1. Review and finalize coding rules (Swift Testing, DocC)
2. Create usage examples document
3. Create documentation guidelines
4. Begin implementation with Phase 1.1 (PeriodType)
5. Iterate through phases with testing at each step

---

## Related Documents

- [Coding Rules](01_CODING_RULES.md)
- [Usage Examples](02_USAGE_EXAMPLES.md)
- [DocC Guidelines](03_DOCC_GUIDELINES.md)
- [Implementation Checklist](04_IMPLEMENTATION_CHECKLIST.md)
