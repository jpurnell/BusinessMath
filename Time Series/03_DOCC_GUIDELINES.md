# DocC Documentation Guidelines for BusinessMath

**Purpose:** Comprehensive guide to creating excellent DocC documentation
**Reference:** [Apple DocC Documentation](https://www.swift.org/documentation/docc/)

---

## Table of Contents

1. [DocC Basics](#1-docc-basics)
2. [Documentation Structure](#2-documentation-structure)
3. [Markdown Formatting](#3-markdown-formatting)
4. [Code Examples](#4-code-examples)
5. [Topics Organization](#5-topics-organization)
6. [Building Documentation](#6-building-documentation)
7. [Documentation Catalog](#7-documentation-catalog)

---

## 1. DocC Basics

### What is DocC?

DocC is Apple's documentation compiler that creates rich, interactive documentation from:
- Source code comments (triple-slash `///`)
- Standalone markdown files (articles, tutorials)
- Documentation catalogs (`.docc` bundles)

### Key Benefits
- **Interactive**: Live code examples in Xcode
- **Type-safe**: Links to symbols are validated at compile time
- **Cross-platform**: Web export for broader distribution
- **Integrated**: Built into Swift Package Manager and Xcode

---

## 2. Documentation Structure

### Source Code Comments

Every public API should have documentation:

```swift
/// Brief one-line summary describing what this does.
///
/// A more detailed explanation of the function, including:
/// - What problem it solves
/// - How it works (if non-obvious)
/// - When to use it
/// - Important caveats or considerations
///
/// - Parameters:
///   - discountRate: The rate used to discount future cash flows.
///     Should be expressed as a decimal (e.g., 0.10 for 10%).
///   - cashFlows: Array of cash flows by period. First element is
///     typically the initial investment (negative value).
///
/// - Returns: The net present value of the cash flows. A positive
///   NPV indicates the investment adds value.
///
/// - Throws: `NPVError.emptyCashFlows` if the cash flows array is empty.
///
/// - Complexity: O(n) where n is the number of cash flows.
///
/// - Note: The first cash flow occurs at time 0 (present).
///   Subsequent cash flows occur at the end of each period.
///
/// ## Excel Equivalent
/// Equivalent to Excel's `NPV(rate, value1, [value2], ...)` function.
///
/// ## Usage Example
/// ```swift
/// let cashFlows = [-100000.0, 30000.0, 30000.0, 30000.0, 30000.0]
/// let npvValue = npv(discountRate: 0.10, cashFlows: cashFlows)
/// print("NPV: $\(npvValue)")
/// // Output: NPV: $-4641.92
/// ```
///
/// ## Mathematical Formula
/// NPV is calculated as:
/// ```
/// NPV = Σ (CFₜ / (1 + r)ᵗ)
/// ```
/// where:
/// - CFₜ = cash flow at time t
/// - r = discount rate
/// - t = time period
///
/// - SeeAlso:
///   - ``irr(cashFlows:guess:)``
///   - ``mirr(cashFlows:financeRate:reinvestmentRate:)``
///   - ``xnpv(rate:dates:cashFlows:)``
public func npv<T: Real>(discountRate r: T, cashFlows c: [T]) -> T {
    // Implementation
}
```

### Documentation Sections

#### Required for All Public APIs
- **Summary**: First line, one sentence
- **Parameters**: All parameters documented
- **Returns**: What the function returns

#### Optional but Recommended
- **Throws**: Errors that can be thrown
- **Complexity**: Time/space complexity if non-trivial
- **Note**: Additional information
- **Important**: Critical information users must know
- **Warning**: Potential pitfalls
- **Tip**: Helpful suggestions

#### Enhanced Documentation
- **Excel Equivalent**: For financial functions
- **Usage Example**: Real-world code examples
- **Mathematical Formula**: For mathematical functions
- **SeeAlso**: Related functions

---

## 3. Markdown Formatting

### Headings

Use `##` for major sections, `###` for subsections:

```swift
/// Brief summary.
///
/// Detailed explanation.
///
/// ## Mathematical Background
///
/// The formula is based on...
///
/// ## Usage Patterns
///
/// ### Simple Cases
/// For basic usage...
///
/// ### Advanced Cases
/// For complex scenarios...
```

### Lists

Unordered lists:
```swift
/// This function handles:
/// - Present value calculations
/// - Future value calculations
/// - Annuity valuations
```

Ordered lists:
```swift
/// Follow these steps:
/// 1. Create a period range
/// 2. Populate with values
/// 3. Apply transformations
```

### Emphasis

```swift
/// Use *italics* for emphasis and **bold** for strong emphasis.
/// Use `monospace` for code, parameter names, or literal values.
```

### Links

#### Symbol Links
```swift
/// Uses ``TimeSeries`` to store values.
/// See ``Period/month(year:month:)`` for creating periods.
/// Related to ``npv(discountRate:cashFlows:)`` calculation.
```

#### Article Links
```swift
/// See <doc:GettingStarted> for an introduction.
/// For details, see <doc:TimeValueOfMoney>.
```

#### External Links
```swift
/// For more information, see [Swift Numerics](https://github.com/apple/swift-numerics).
```

### Code Blocks

Inline code:
```swift
/// The `discountRate` parameter should be between 0 and 1.
```

Code blocks:
```swift
/// Example usage:
/// ```swift
/// let result = npv(discountRate: 0.10, cashFlows: cashFlows)
/// ```
```

### Callouts

```swift
/// - Note: This is general information.
/// - Important: This is critical information.
/// - Warning: This warns about potential issues.
/// - Tip: This is a helpful suggestion.
/// - Experiment: Try modifying this example.
```

---

## 4. Code Examples

### Inline Examples

Short, focused examples within documentation:

```swift
/// Calculate the mean of an array.
///
/// ```swift
/// let values = [1.0, 2.0, 3.0, 4.0, 5.0]
/// let average = mean(values)  // 3.0
/// ```
public func mean<T: Real>(_ x: [T]) -> T {
    // Implementation
}
```

### Extended Examples

For complex workflows, use a dedicated section:

```swift
/// ## Extended Example
///
/// Here's a complete loan amortization scenario:
///
/// ```swift
/// // Loan parameters
/// let principal: Double = 250000
/// let annualRate: Double = 0.045
/// let years = 30
///
/// // Calculate monthly payment
/// let monthlyRate = annualRate / 12
/// let months = years * 12
/// let payment = payment(
///     presentValue: principal,
///     rate: monthlyRate,
///     periods: months
/// )
///
/// // Generate amortization schedule
/// for period in 1...12 {
///     let interest = interestPayment(
///         rate: monthlyRate,
///         period: period,
///         totalPeriods: months,
///         presentValue: principal
///     )
///     let principal = principalPayment(
///         rate: monthlyRate,
///         period: period,
///         totalPeriods: months,
///         presentValue: principal
///     )
///     print("Month \(period): Payment $\(payment), Principal $\(principal), Interest $\(interest)")
/// }
/// ```
```

### Multiple Scenarios

```swift
/// ## Usage Examples
///
/// ### Basic Calculation
/// ```swift
/// let pv = presentValue(futureValue: 1000, rate: 0.05, periods: 10)
/// // Result: 613.91
/// ```
///
/// ### Annuity Calculation
/// ```swift
/// let pv = presentValueAnnuity(
///     payment: 100,
///     rate: 0.05,
///     periods: 10,
///     type: .ordinary
/// )
/// // Result: 772.17
/// ```
///
/// ### Annuity Due
/// ```swift
/// let pv = presentValueAnnuity(
///     payment: 100,
///     rate: 0.05,
///     periods: 10,
///     type: .due
/// )
/// // Result: 810.78
/// ```
```

---

## 5. Topics Organization

### Automatic Topics

DocC automatically organizes symbols, but you can customize:

```swift
/// A period in a financial model.
///
/// ## Topics
///
/// ### Creating Periods
/// - ``month(year:month:)``
/// - ``quarter(year:quarter:)``
/// - ``year(_:)``
/// - ``day(_:)``
///
/// ### Period Properties
/// - ``type``
/// - ``date``
/// - ``startDate``
/// - ``endDate``
/// - ``label``
///
/// ### Period Arithmetic
/// - ``+(_:_:)``
/// - ``-(_:_:)``
/// - ``distance(to:)``
///
/// ### Period Ranges
/// - ``months()``
/// - ``quarters()``
/// - ``days()``
public struct Period {
    // Implementation
}
```

### Custom Topics in Articles

Create custom groupings in `.docc` articles:

```markdown
# Time Value of Money

## Overview

Calculate present value, future value, and internal rate of return.

## Topics

### Present Value
- ``presentValue(futureValue:rate:periods:)``
- ``presentValueAnnuity(payment:rate:periods:type:)``

### Future Value
- ``futureValue(presentValue:rate:periods:)``
- ``futureValueAnnuity(payment:rate:periods:)``

### Rate Calculations
- ``irr(cashFlows:guess:)``
- ``mirr(cashFlows:financeRate:reinvestmentRate:)``
- ``xirr(dates:cashFlows:)``

### Net Present Value
- ``npv(discountRate:cashFlows:)``
- ``xnpv(rate:dates:cashFlows:)``
```

---

## 6. Building Documentation

### Using Swift Package Manager

```bash
# Build documentation
swift package generate-documentation

# Preview documentation locally
swift package --disable-sandbox preview-documentation --target BusinessMath

# Build for web hosting
swift package generate-documentation --target BusinessMath \
    --output-path ./docs \
    --hosting-base-path BusinessMath
```

### Using Xcode

1. **Product → Build Documentation** (⌃⌘⇧D)
2. Documentation appears in Xcode's Developer Documentation window
3. Export for hosting: **Product → Archive → Distribute → Copy App → Documentation**

### Continuous Integration

Add to your CI workflow:

```yaml
- name: Build Documentation
  run: |
    swift package generate-documentation --target BusinessMath
```

---

## 7. Documentation Catalog

### Creating a .docc Catalog

Structure:
```
Sources/BusinessMath/BusinessMath.docc/
├── BusinessMath.md              # Landing page
├── GettingStarted.md            # Tutorial
├── TimeValueOfMoney.md          # Concept article
├── Resources/                   # Images, videos
│   ├── hero-image.png
│   └── diagram.svg
└── Extensions/                  # Extensions to organize docs
    ├── TimeSeries.md
    └── Period.md
```

### Landing Page

`BusinessMath.md`:
```markdown
# ``BusinessMath``

A comprehensive Swift library for business and financial mathematics.

## Overview

BusinessMath provides tools for:
- Statistical analysis
- Probability distributions
- Time series modeling
- Financial projections
- Time value of money calculations

Whether you're building financial models, conducting statistical analysis,
or creating business intelligence tools, BusinessMath offers a robust,
type-safe API built on Swift Numerics.

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:CoreConcepts>

### Time Series
- ``Period``
- ``TimeSeries``
- <doc:TimeValueOfMoney>

### Statistics
- <doc:DescriptiveStatistics>
- <doc:ProbabilityDistributions>

### Financial Functions
- <doc:TimeValueOfMoney>
- <doc:FinancialStatements>

### Examples
- <doc:SaaSRevenueModel>
- <doc:LoanAmortization>
- <doc:InvestmentAnalysis>
```

### Getting Started Tutorial

`GettingStarted.md`:
```markdown
# Getting Started with BusinessMath

Learn the basics of using BusinessMath for financial modeling.

## Overview

This tutorial covers:
- Installing BusinessMath
- Creating periods and time series
- Basic calculations
- Building a simple financial model

### Add BusinessMath to Your Project

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/username/BusinessMath", from: "1.0.0")
]
```

### Import the Library

```swift
import BusinessMath
```

### Create Your First Time Series

```swift
let periods = (1...12).map { Period.month(year: 2025, month: $0) }
let revenue: [Double] = [100, 110, 121, 133, 146, 161, 177, 195, 214, 236, 259, 285]

let timeSeries = TimeSeries(
    periods: periods,
    values: revenue,
    metadata: TimeSeriesMetadata(name: "Monthly Revenue", units: "USD")
)
```

### Calculate Growth

```swift
let momGrowth = timeSeries.growthRate(lag: 1)
let avgGrowth = mean(momGrowth.valuesArray)
print("Average monthly growth: \(avgGrowth * 100)%")
```

## Topics

### Next Steps
- <doc:TimeSeriesInDepth>
- <doc:FinancialProjections>
- <doc:StatisticalAnalysis>
```

### Concept Article

`TimeValueOfMoney.md`:
```markdown
# Time Value of Money

Understand and calculate present value, future value, and rates of return.

## Overview

The time value of money (TVM) is a fundamental concept in finance:
money available now is worth more than the same amount in the future
due to its potential earning capacity.

## Core Concepts

### Present Value

Present value (PV) is the current value of a future sum of money:

```swift
let futureValue: Double = 10000
let rate: Double = 0.08
let years = 5

let pv = presentValue(futureValue: futureValue, rate: rate, periods: years)
// Result: 6,805.83
```

### Future Value

Future value (FV) is the value of an investment at a future date:

```swift
let presentValue: Double = 5000
let rate: Double = 0.07
let years = 10

let fv = futureValue(presentValue: presentValue, rate: rate, periods: years)
// Result: 9,835.76
```

### Net Present Value

NPV evaluates the profitability of an investment:

```swift
let cashFlows = [-100000.0, 30000.0, 30000.0, 30000.0, 30000.0]
let npvValue = npv(discountRate: 0.10, cashFlows: cashFlows)
```

## Topics

### Functions
- ``presentValue(futureValue:rate:periods:)``
- ``futureValue(presentValue:rate:periods:)``
- ``npv(discountRate:cashFlows:)``
- ``irr(cashFlows:guess:)``

### Related Concepts
- <doc:DiscountingCashFlows>
- <doc:InternalRateOfReturn>
```

---

## Best Practices

### 1. Write Documentation First

Consider documentation as part of your API design:
- Write doc comments before implementation
- Helps clarify the API design
- Ensures documentation stays in sync

### 2. Use Consistent Terminology

```swift
// Good - consistent terminology
/// The discount rate used in NPV calculations.

// Less good - inconsistent
/// The rate of discount for present value.
```

### 3. Provide Context

```swift
// Good - explains why and when
/// Calculate the internal rate of return for a series of cash flows.
/// Use this to evaluate the profitability of investments and compare
/// different opportunities. IRR is the discount rate that makes NPV = 0.

// Less good - just states what
/// Calculates IRR.
```

### 4. Include Realistic Examples

```swift
// Good - complete, realistic example
/// ```swift
/// // Evaluate a $100,000 investment with annual returns
/// let cashFlows = [-100000.0, 30000.0, 35000.0, 40000.0, 45000.0]
/// let rate = try irr(cashFlows: cashFlows)
/// print("IRR: \(rate * 100)%")  // IRR: ~20.5%
/// ```

// Less good - trivial example
/// ```swift
/// let result = irr(cashFlows: flows)
/// ```
```

### 5. Cross-Reference Related APIs

```swift
/// - SeeAlso:
///   - ``presentValue(futureValue:rate:periods:)`` for single cash flows
///   - ``mirr(cashFlows:financeRate:reinvestmentRate:)`` for modified IRR
///   - ``xirr(dates:cashFlows:)`` for irregular periods
```

### 6. Document Edge Cases

```swift
/// - Parameters:
///   - x: An array of values. Returns `T(0)` if empty.
///
/// - Returns: The arithmetic mean, or `T(0)` for an empty array.
///
/// - Note: This function treats empty arrays as having a mean of zero
///   rather than being undefined. For stricter behavior, check
///   `x.isEmpty` before calling.
```

### 7. Explain Mathematical Concepts

```swift
/// ## Mathematical Background
///
/// The standard deviation measures dispersion around the mean:
/// ```
/// σ = √(Σ(x - μ)² / n)
/// ```
/// where:
/// - σ = standard deviation
/// - x = each value
/// - μ = mean
/// - n = number of values
///
/// For sample standard deviation, use `n - 1` (Bessel's correction).
```

### 8. Keep Examples Self-Contained

```swift
/// ## Usage Example
/// ```swift
/// import BusinessMath
///
/// let periods = (1...5).map { Period.year(2020 + $0 - 1) }
/// let cashFlows = [-100000.0, 30000.0, 30000.0, 30000.0, 30000.0]
///
/// let npvValue = npv(discountRate: 0.10, cashFlows: cashFlows)
/// print("NPV: $\(npvValue)")
/// ```
```

---

## Documentation Checklist

For every public type/function:
- [ ] Single-line summary
- [ ] Detailed description (2-3 sentences minimum)
- [ ] All parameters documented
- [ ] Return value documented
- [ ] Throws documented (if applicable)
- [ ] At least one usage example
- [ ] Related functions cross-referenced
- [ ] Edge cases explained
- [ ] Excel equivalent noted (for financial functions)
- [ ] Mathematical formula included (for math functions)

For modules:
- [ ] Overview article in `.docc`
- [ ] Getting started guide
- [ ] Core concepts explained
- [ ] Topics organized logically
- [ ] Real-world examples provided

---

## Related Documents

- [Master Plan](00_MASTER_PLAN.md)
- [Coding Rules](01_CODING_RULES.md)
- [Usage Examples](02_USAGE_EXAMPLES.md)
- [Implementation Checklist](04_IMPLEMENTATION_CHECKLIST.md)

## External Resources

- [Swift-DocC Documentation](https://www.swift.org/documentation/docc/)
- [Apple DocC Guide](https://developer.apple.com/documentation/docc)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
