# 2025-12-03T18:50:58    conversation: 01kbjgyf7w3yzz0n8r9j898qc1 id: 01kbjrvb5xq0hd9m8vcdsb74c5

Model: **deepseek-coder**

## Prompt

# Coding Rules for BusinessMath Library

**Updated:** December 2, 2025
**Purpose:** Establish consistent patterns across the codebase

---

## 1. File Organization

### Structure
- **One primary concept per file** (function, struct, enum, or protocol)
- **Directory structure reflects conceptual hierarchy**
  ```
  Sources/BusinessMath/
  ├── Time Series/
  │   ├── Period.swift
  │   ├── TimeSeries.swift
  │   └── TVM/
  │       ├── NPV.swift
  │       └── IRR.swift
  └── Statistics/
      └── Descriptors/
          └── Central Tendency/
              └── mean.swift
  ```
- **File naming**: camelCase for files, descriptive names
- **Work-in-progress**: Use `zzz In Process/` directory for incomplete code

### File Headers
```swift
//
//  FileName.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Foundation
import Numerics
```

---

## 2. Code Style

### Generic Programming
- Use `<T: Real>` for numeric functions (from swift-numerics)
- Enables flexibility across Float, Double, Float16, etc.

```swift
public func mean<T: Real>(_ x: [T]) -> T {
    guard x.count > 0 else { return T(0) }
    return (x.reduce(T(0), +) / T(x.count))
}
```

### Function Signatures
- **Public API**: All user-facing functions/types marked `public`
- **Descriptive parameter labels**: Use external labels for clarity
  ```swift
  public func npv<T: Real>(discountRate r: T, cashFlows c: [T]) -> T
  ```
- **Default parameters**: Provide sensible defaults where appropriate
  ```swift
  public func payment<T: Real>(
      presentValue: T,
      rate: T,
      periods: Int,
      futureValue: T = T(0),
      type: AnnuityType = .ordinary
  ) -> T
  ```

### Guard Clauses & Validation
- Use `guard` for input validation
- Return sensible defaults for empty inputs (e.g., `T(0)`)
- Throw errors for truly invalid cases

```swift
public func median<T: Real>(_ x: [T]) -> T {
    guard !x.isEmpty else { return T(0) }
    let sorted = x.sorted()
    // ... rest of implementation
}
```

### Functional Patterns
- Prefer functional patterns (`reduce`, `map`, `filter`) where readable
- Balance between functional style and clarity

```swift
// Good
return (x.reduce(T(0), +) / T(x.count))

// Also good when clarity demands it
var sum = T(0)
for value in x {
    sum += value
}
return sum / T(x.count)
```

### String Formatting
**Always use Swift native string formatting instead of C-style format strings.**

Swift's `String(format:)` uses Objective-C style format specifiers (`%@`, `%d`, `%f`), but **does not support C-style width and alignment specifiers** like `%-30s` or `%8d`. These will cause runtime crashes.

#### ❌ Avoid: C-Style Format Strings
```swift
// BAD - Will crash at runtime
let output = String(format: "%-30s %8s %12s\n",
                   "Operation", "Count", "Total")

// BAD - C-style format specifiers with width
let row = String(format: "%-30s %8d %10.3fs\n",
                operationName, count, totalTime)
```

#### ✅ Prefer: Swift Native String Formatting
```swift
// GOOD - Use Swift's padding method
let opHeader = "Operation".padding(toLength: 30, withPad: " ", startingAt: 0)
let countHeader = "Count".padding(toLength: 8, withPad: " ", startingAt: 0)
let totalHeader = "Total".padding(toLength: 12, withPad: " ", startingAt: 0)

output += "\(opHeader) \(countHeader) \(totalHeader)\n"

// GOOD - Format numbers first, then pad
let opName = String(operationName.prefix(30))
    .padding(toLength: 30, withPad: " ", startingAt: 0)
let count = String(executionCount)
    .padding(toLength: 8, withPad: " ", startingAt: 0)
let total = String(format: "%.3fs", totalTime)
    .padding(toLength: 12, withPad: " ", startingAt: 0)

output += "\(opName) \(count) \(total)\n"
```

#### Benefits of Swift Native Formatting
- **Type-safe**: Compile-time checking prevents type mismatches
- **No runtime crashes**: Invalid format strings cause compile errors, not crashes
- **More readable**: Intent is clear from method names
- **Consistent**: Works the same across all Swift platforms

#### Simple Cases: String Interpolation
For simple formatting without alignment, prefer string interpolation:

```swift
// GOOD - Simple string interpolation
let message = "Total: \(count) operations in \(String(format: "%.3f", time))s"

// GOOD - Multi-line interpolation for readability
let report = """
    Performance Report
    Total Operations: \(totalOps)
    Total Time: \(String(format: "%.3f", totalTime))s
    """
```

#### Migration Note
> **TODO**: Perform a pass on the existing codebase to replace any remaining C-style format strings with Swift native formatting. This will prevent potential runtime crashes and improve code safety.

---

## 3. Documentation (DocC Format)

### Triple-Slash Comments
All public APIs must have documentation using `///`.

### Standard Structure
```swift
/// Brief one-line summary of what the function does.
///
/// More detailed explanation of the function, including any important
/// context, mathematical background, or usage guidance.
///
/// - Parameters:
///   - paramName: Description of parameter. Include type information if it
///     adds clarity (e.g., "Must conform to `Real` protocol").
///   - anotherParam: Description of another parameter.
///
/// - Returns: Description of return value. Include type and any special
///   cases (e.g., "Returns `T(0)` if array is empty").
///
/// - Throws: Description of errors thrown, if applicable.
///   - `ErrorType.case1`: When this error occurs.
///   - `ErrorType.case2`: When this error occurs.
///
/// - Complexity: O(n) where n is the number of elements. Include only
///   for non-trivial complexity.
///
/// - Note: Additional notes, warnings, or important information.
///
/// - Important: Critical information that users must know.
///
/// - Warning: Potential pitfalls or common mistakes.
///
/// ## Excel Equivalent
/// Equivalent of Excel `AVERAGE(A1:A10)`
///
/// ## Usage Example
/// ```swift
/// let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
/// let result = mean(values)
/// print(result)  // Output: 3.0
/// ```
///
/// ## Mathematical Background
/// The arithmetic mean is calculated as:
/// ```
/// μ = (Σx) / n
/// ```
/// where n is the number of elements.
```

### DocC-Specific Features

#### Links
```swift
/// This function uses ``TimeSeries`` to store values.
/// See also <doc:GettingStarted> for usage patterns.
```

#### Code Listings
```swift
/// ## Usage Example
/// ```swift
/// let cashFlows = [-1000.0, 300.0, 300.0, 300.0, 300.0]
/// let npvValue = npv(discountRate: 0.1, cashFlows: cashFlows)
/// ```
```

#### Callouts
```swift
/// - Important: The first cash flow is typically negative (initial investment).
/// - Warning: IRR may not converge for certain cash flow patterns.
/// - Note: This implementation uses Newton-Raphson method.
/// - Tip: For irregular periods, use XNPV instead.
```

#### Organization with Topics
Add topics to organize documentation:
```swift
/// ## Topics
///
/// ### Creating Periods
/// - ``Period/month(year:month:)``
/// - ``Period/quarter(year:quarter:)``
/// - ``Period/year(_:)``
///
/// ### Period Arithmetic
/// - ``Period/+(_:_:)``
/// - ``Period/-(_:_:)``
/// - ``Period/distance(to:)``
```

---

## 4. Types & Protocols

### Protocols
- Define behavior contracts
- Use associated types for generic flexibility
- Document requirements clearly

```swift
/// A type that can generate random numbers from a distribution.
public protocol DistributionRandom {
    associatedtype T: Real

    /// Generate the next random value from this distribution.
    func next() -> T
}
```

### Structs
- **Prefer structs over classes** for value semantics
- Make them immutable when possible
- Conform to standard protocols: `Equatable`, `Hashable`, `Codable`

```swift
public struct Period: Hashable, Comparable, Codable {
    public let type: PeriodType
    public let date: Date
}
```

### Enums
- Use for configuration options and variants
- Add `String` raw values for serialization when appropriate
- Include computed properties and methods as needed

```swift
public enum Population: String {
    case population
    case sample
}

public enum PeriodType: String, Codable, Comparable {
    case daily
    case weekly
    case monthly
    case quarterly
    case annual

    var daysApproximate: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 91
        case .annual: return 365
        }
    }
}
```

---

## 5. Error Handling

### Custom Error Types
- Create dedicated error enums
- Place in separate files if used across multiple modules
- Use descriptive case names

```swift
/// Errors that can occur during goal seek operations.
enum GoalSeekError: Error {
    /// Function derivative is zero, causing division by zero.
    case divisionByZero

    /// Method failed to converge within maximum iterations.
    case convergenceFailed
}
```

### Throwing Functions
- Use `throws` for operations that can legitimately fail
- Document what errors can be thrown
- Provide clear context in error cases

```swift
/// Calculate IRR for a series of cash flows.
///
/// - Throws:
///   - `IRRError.allPositiveFlows`: When all cash flows are positive.
///   - `IRRError.allNegativeFlows`: When all cash flows are negative.
///   - `IRRError.convergenceFailed`: When iteration doesn't converge.
public func irr<T: Real>(
    cashFlows: [T],
    guess: T = T(0.1)
) throws -> T {
    // Implementation
}
```

### Mathematical Correctness and Invalid Inputs
**Never use default values that mask mathematically undefined operations.**

When a mathematical operation is undefined or invalid, return `NaN` or throw an error. Do not silently substitute default values that could hide bugs or produce incorrect results.

```swift
// Good - Returns NaN for mathematically undefined input
public func distributionChiSquared<T: Real>(degreesOfFreedom: Int, seeds: [Double]? = nil) -> T {
    guard degreesOfFreedom > 0 else {
        // Chi-squared distribution is undefined for df ≤ 0
        return T.nan
    }
    // ... implementation
}

// Bad - Silently uses default value, masking the error
public func distributionChiSquared<T: Real>(degreesOfFreedom: Int, seeds: [Double]? = nil) -> T {
    let df = max(1, degreesOfFreedom)  // Silently fixes invalid input
    // ... implementation
    // User never knows they passed invalid input!
}

// Also good - Throws error for invalid input (when appropriate)
public func distributionChiSquaredThrowing<T: Real>(degreesOfFreedom: Int, seeds: [Double]? = nil) throws -> T {
    guard degreesOfFreedom > 0 else {
        throw DistributionError.invalidDegreesOfFreedom(degreesOfFreedom)
    }
    return distributionChiSquared(degreesOfFreedom: degreesOfFreedom, seeds: seeds)
}
```

#### Guidelines for Invalid Inputs

1. **Return NaN** when:
   - The operation is mathematically undefined
   - You want to allow computations to continue (NaN propagates through calculations)
   - The function is used in numerical computations or simulations

2. **Throw an error** when:
   - The invalid input represents a programming error
   - The operation cannot proceed meaningfully
   - The caller needs to handle the error explicitly

3. **Never silently substitute defaults** when:
   - The default would produce mathematically incorrect results
   - The user needs to know their input was invalid
   - The default could mask bugs in calling code

4. **Document behavior clearly**:
   - State in documentation what inputs are invalid
   - Document what happens with invalid inputs (NaN, error, etc.)
   - Provide examples showing the behavior

```swift
/// Generates a random value from a Chi-squared distribution.
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
/// - Returns: A random value from χ²(df), or NaN if df ≤ 0
///
/// ## Example
///
/// ```swift
/// let valid: Double = distributionChiSquared(degreesOfFreedom: 10)
/// print(valid)  // e.g., 8.342
///
/// let invalid: Double = distributionChiSquared(degreesOfFreedom: 0)
/// print(invalid.isNaN)  // true - user is alerted to the error
/// ```
```

#### Testing Invalid Inputs

Always test that invalid inputs are handled correctly:

```swift
@Test("Chi-squared parameter validation")
func chiSquaredParameterValidation() {
    // Test that invalid degrees of freedom return NaN
    let invalidCases: [(df: Int, description: String)] = [
        (0, "zero degrees of freedom"),
        (-1, "negative degrees of freedom"),
        (-10, "large negative degrees of freedom")
    ]

    for testCase in invalidCases {
        let sample: Double = distributionChiSquared(degreesOfFreedom: testCase.df, seeds: [0.5])
        #expect(sample.isNaN, "Should return NaN for \(testCase.description)")
    }
}
```

---

## 6. Testing (Swift Testing Framework)

### Migration from XCTest
- **Use Swift Testing framework** (modern, cross-platform)
- Import with `import Testing`
- Use `@Test` attribute instead of `func test...`
- Use `#expect` instead of `XCTAssert`

### Test Structure
```swift
import Testing
import Numerics
@testable import BusinessMath

@Suite("Central Tendency Tests")
struct CentralTendencyTests {

    @Test("Mean calculates average correctly")
    func meanCalculation() {
        let values: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = mean(values)
        #expect(result == 2.0)
    }

    @Test("Mean handles empty array")
    func meanEmptyArray() {
        let values: [Double] = []
        let result = mean(values)
        #expect(result == 0.0)
    }

    @Test("Median with even count")
    func medianEvenCount() {
        let values: [Double] = [1.0, 2.0, 3.0, 4.0]
        let result = median(values)
        #expect(result == 2.5)
    }
}
```

### Test Organization
- Test files mirror source structure
  ```
  Tests/BusinessMathTests/
  ├── Time Series Tests/
  │   ├── PeriodTests.swift
  │   ├── TimeSeriesTests.swift
  │   └── TVM Tests/
  │       ├── NPVTests.swift
  │       └── IRRTests.swift
  └── Statistics Tests/
      └── Descriptor Tests/
          └── CentralTendencyTests.swift
  ```

### Test Naming
- Use descriptive test names with `@Test` attribute
- Group related tests with `@Suite`
- Use parameterized tests for multiple scenarios

```swift
@Suite("NPV Calculations")
struct NPVTests {

    @Test("NPV with positive discount rate")
    func positiveDiscountRate() {
        let cashFlows = [-1000.0, 300.0, 300.0, 300.0, 300.0]
        let result = npv(discountRate: 0.1, cashFlows: cashFlows)
        let expected = 146.87  // Known result
        #expect(abs(result - expected) < 0.01)
    }

    @Test("NPV with multiple scenarios",
          arguments: [
              (rate: 0.05, expected: 297.59),
              (rate: 0.10, expected: 146.87),
              (rate: 0.15, expected: 20.42)
          ])
    func multipleScenarios(rate: Double, expected: Double) {
        let cashFlows = [-1000.0, 300.0, 300.0, 300.0, 300.0]
        let result = npv(discountRate: rate, cashFlows: cashFlows)
        #expect(abs(result - expected) < 0.01)
    }
}
```

### Test Data
- Use realistic test values with known results
- Include edge cases (zero, negative, very large/small)
- Test against Excel or other reference implementations

### Deterministic Testing for Stochastic Functions
**Always prioritize deterministic, seeded tests over truly random tests.**

When testing functions that use random number generation (distributions, Monte Carlo simulations, etc.):

1. **Use Seeded Random Number Generators**
   - Create helper functions that generate deterministic seed sequences
   - Pass seeds explicitly to the function under test
   - This ensures tests are repeatable and won't flake in CI

```swift
// Good - Deterministic seeded test
@Test("Triangular distribution mean formula")
func triangularMeanFormula() {
    let seeds = Self.seedsForTriangular(count: 5000)
    var samples: [Double] = []
    for i in 0..<5000 {
        samples.append(triangularDistribution(low: 0, high: 10, base: 5, seeds[i]))
    }
    let empiricalMean = samples.reduce(0, +) / Double(samples.count)
    #expect(abs(empiricalMean - 5.0) < 0.1)
}

// Bad - Non-deterministic test (will occasionally fail)
@Test("Triangular distribution mean formula")
func triangularMeanFormula() {
    var samples: [Double] = []
    for _ in 0..<5000 {
        samples.append(triangularDistribution(low: 0, high: 10, base: 5))
    }
    let empiricalMean = samples.reduce(0, +) / Double(samples.count)
    #expect(abs(empiricalMean - 5.0) < 0.1)  // May fail occasionally
}
```

2. **Tolerance Calculation**
   - When testing statistical properties, calculate tolerances based on:
     - Standard error: σ/√n where σ is the theoretical standard deviation
     - Use at least 3-4 standard errors for test tolerance
     - For critical tests, use 5+ standard errors (< 0.0001% failure rate)

```swift
// Calculate appropriate tolerance
let theoreticalStdDev = 2.04
let sampleCount = 1000
let standardError = theoreticalStdDev / Double.sqrt(Double(sampleCount))
let tolerance = 4.0 * standardError  // 4 standard errors ≈ 99.99% confidence
#expect(abs(empiricalMean - expectedMean) < tolerance)
```

3. **Implementation Requirements**
   - All distribution functions should accept an optional seed parameter
   - Default to random generation when seed is not provided
   - Document the seed parameter clearly

```swift
public func triangularDistribution<T: Real>(
    low a: T,
    high b: T,
    base c: T,
    _ uSeed: Double = Double.random(in: 0...1)
) -> T {
    let u = T(uSeed)  // Don't truncate or modify the seed
    // ... implementation
}
```

4. **Testing Pattern Consistency**
   - All tests in a suite should follow the same pattern
   - If one test uses seeded values, all should use seeded values
   - This maintains predictability and debuggability

### Assertions
```swift
// Basic equality
#expect(result == 2.0)

// Approximate equality for floating point
#expect(abs(result - expected) < 0.001)

// Boolean conditions
#expect(result > 0)
#expect(!values.isEmpty)

// Throws checking
#expect(throws: IRRError.convergenceFailed) {
    try irr(cashFlows: badFlows)
}

// Nil checking
#expect(optionalValue != nil)
```

---

## 7. Dependencies

### Import Guidelines
- Import only what's needed
- Standard imports: `Foundation`, `Numerics`
- Testing imports: `Testing`, `@testable import BusinessMath`

```swift
// Production code
import Foundation
import Numerics

// Test code
import Testing
import Numerics
@testable import BusinessMath
```

### Package Dependencies
Defined in `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-numerics", from: "1.0.2"),
],
targets: [
    .target(
        name: "BusinessMath",
        dependencies: [
            .product(name: "Numerics", package: "swift-numerics")
        ],
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency")
        ]
    ),
]
```

---

## 8. Concurrency

### Strict Concurrency
- Enabled in package: `.enableUpcomingFeature("StrictConcurrency")`
- Mark types as `Sendable` when thread-safe
- Use `@MainActor` when needed for UI integration

```swift
public struct TimeSeries<T: Real>: Sendable where T: Sendable {
    // Thread-safe value type
}
```

---

## 9. API Design Principles

### Clarity at Point of Use
```swift
// Good
let result = npv(discountRate: 0.1, cashFlows: flows)

// Bad
let result = npv(0.1, flows)
```

### Fluent APIs
Support method chaining where appropriate:
```swift
let adjusted = timeSeries
    .fillForward()
    .map { $0 * 1.1 }
    .movingAverage(window: 3)
```

### Progressive Disclosure
- Simple cases should be simple
- Advanced features available but not required
- Use defaults liberally

```swift
// Simple case
let pv = presentValue(futureValue: 1000, rate: 0.05, periods: 10)

// Advanced case
let pv = presentValueAnnuity(
    payment: 100,
    rate: 0.05,
    periods: 10,
    type: .due
)
```

---

## 10. Performance Considerations

### Measurement
- Profile before optimizing
- Document complexity for non-trivial algorithms
- Consider lazy evaluation for large datasets

### Guidelines
- Prefer `O(1)` lookups (use dictionaries/sets)
- Avoid unnecessary allocations
- Use copy-on-write for collections
- Consider caching expensive computations

```swift
// Good - O(1) lookup
private let values: [Period: T]

// Less good - O(n) lookup
private let values: [(Period, T)]
```

---

## 11. Version Control

### Commits
- Clear, descriptive commit messages
- One logical change per commit
- Test before committing

### Branches
- Work in feature branches for significant changes
- Main branch should always build and pass tests

---

## Summary Checklist

For every public API:
- [ ] Public access modifier
- [ ] Complete DocC documentation with examples
- [ ] Descriptive parameter labels
- [ ] Appropriate error handling (return NaN or throw errors for mathematically undefined operations)
- [ ] Never use default values that mask mathematical errors
- [ ] Use Swift native string formatting (`.padding()`) instead of C-style format strings
- [ ] Generic over `Real` where applicable
- [ ] Comprehensive tests with `@Test` attributes
- [ ] Edge case handling
- [ ] Tests for invalid inputs verify NaN or error behavior
- [ ] Performance considerations documented

---

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

## Common DocC Pitfalls and Solutions

> **⚠️ CRITICAL CHECKLIST FOR NEW TUTORIALS**
>
> Before marking any tutorial as "done", verify ALL of these:
> 1. ✅ Ends with "Next Steps" section (article links using `<doc:...>`)
> 2. ✅ Ends with "See Also" section (API symbols using ` ``Symbol`` `)
> 3. ✅ Added to `BusinessMath.md` landing page
> 4. ✅ NO "Related Documentation" section
> 5. ✅ NO `## Topics` header in article body
> 6. ✅ Article appears in navigation when docs are built
>
> **If any item is unchecked, the tutorial will not display correctly!**

### Pitfall 1: Using `## Topics` in Narrative Articles

**Problem**: Adding a `## Topics` header in tutorial articles causes them to appear as "API Collections" instead of proper narrative articles in Xcode documentation viewer.

**Why it happens**: `## Topics` is a special reserved header in DocC used exclusively for organizing API documentation symbols. When DocC encounters this header in a file, it treats the file as API documentation rather than a narrative article.

**Solution**:
- For narrative articles and tutorials, use `## Content` or `## Overview` instead
- Use regular `##` headers for main sections without a `## Topics` wrapper
- Reserve `## Topics` only for API symbol documentation pages

**Example - Wrong**:
```markdown
# Building Financial Statements

Learn how to model complete financial statements.

## Topics

### Creating an Entity
Every financial model starts with an entity...

### Building an Income Statement
The Income Statement shows profitability...
```

**Example - Correct**:
```markdown
# Building Financial Statements

Learn how to model complete financial statements.

## Overview

BusinessMath provides a comprehensive framework...

## Creating an Entity
Every financial model starts with an entity...

## Building an Income Statement
The Income Statement shows profitability...
```

### Pitfall 2: Article Names Conflicting with Code Symbols

**Problem**: Tutorial articles with names matching code types or symbols can cause DocC to confuse the article with the API symbol, leading to incorrect content display.

**Why it happens**: DocC tries to resolve documentation references and may conflate article names with actual code symbol names, especially when they're identical.

**Solution**:
- Add descriptive suffixes to tutorial filenames (e.g., "Guide", "Tutorial", "Walkthrough")
- Example: `FinancialStatements.md` → `FinancialStatementsGuide.md`
- Update all cross-references to use the new filenames

**Example file naming**:
```
❌ Wrong:
- FinancialStatements.md (conflicts with FinancialStatements type)
- Simulation.md (conflicts with Simulation module)

✅ Correct:
- FinancialStatementsGuide.md
- SimulationTutorial.md
- MonteCarloWalkthrough.md
```

### Pitfall 3: Incorrect Header Hierarchy in Articles

**Problem**: Using `###` subsections under `## Topics` prevents content from displaying correctly in documentation viewer.

**Why it happens**: When combined with `## Topics`, DocC expects `###` headers to reference API symbols, not narrative content sections.

**Solution**:
- Use `##` for all main sections in narrative articles
- Don't nest content sections under `## Topics`
- Use `###` and deeper only for subsections within narrative content

**Example - Wrong**:
```markdown
## Topics

### Problem Overview
Let me explain the problem...

### Solution Approach
Here's how we solve it...
```

**Example - Correct**:
```markdown
## Problem Overview
Let me explain the problem...

### Key Considerations
When solving this...

## Solution Approach
Here's how we solve it...

### Implementation Steps
Follow these steps...
```

### Pitfall 4: Broken Cross-References After Renaming

**Problem**: After renaming tutorial files, existing cross-references break, causing documentation build warnings or broken links.

**Solution**:
- Update all `<doc:...>` references when renaming files
- Search the entire `.docc` directory for references to the old name
- Use command-line tools for batch updates:

```bash
# Example: Updating all references after renaming
cd Sources/BusinessMath/BusinessMath.docc
grep -r "<doc:FinancialStatements>" .
sed -i '' 's/<doc:FinancialStatements>/<doc:FinancialStatementsGuide>/g' *.md
```

### Quick Reference: Article vs API Documentation

| Feature | Narrative Article | API Documentation |
|---------|------------------|-------------------|
| Purpose | Tutorials, guides, walkthroughs | Type, function, property docs |
| `## Topics` | ❌ Don't use | ✅ Use for organizing symbols |
| Header structure | `##` for main sections | `## Topics` with `### ` groups |
| File location | `.docc/` directory | Inline or `.docc/` extension docs |
| File naming | Descriptive (e.g., `*Guide.md`) | Match symbol name |
| Cross-refs | `<doc:ArticleName>` | `<doc:SymbolName>` or ` ``SymbolName`` ` |

### Diagnostic Steps for Documentation Issues

If your tutorials appear as "API Collections" or show wrong content:

1. **Check for `## Topics` header** - Remove or change to `## Content`
2. **Verify header hierarchy** - Use `##` for main sections, not `###` under Topics
3. **Check filename conflicts** - Ensure article names don't match code symbols
4. **Validate cross-references** - Ensure all `<doc:...>` references are current
5. **Clean build** - Product → Clean Build Folder, then rebuild documentation
6. **Check DocC warnings** - Review build output for documentation warnings

### Pitfall 5: Incorrect "Related Documentation" Structure ⚠️ CRITICAL

**Problem**: Using "Related Documentation" as a section header with mixed article and API symbol links prevents tutorials from displaying correctly.

**Why it happens**: DocC expects two separate, properly structured sections at the end of tutorials:
1. "Next Steps" for article cross-references
2. "See Also" for API symbol references

Mixing both types in a single "Related Documentation" section or using incorrect link syntax causes parsing issues.

**Solution**: Always end narrative tutorials with these two separate sections in this exact order:

**Example - Wrong ❌**:
```markdown
## Related Documentation

- ``CapTable`` - Cap table modeling and financing rounds
- ``Shareholder`` - Shareholder with ownership details
- <doc:DebtAndFinancingGuide> for debt financing
- ``SAFETerm`` - Simple Agreement for Future Equity
```

**Example - Correct ✅**:
```markdown
## Next Steps

- Explore <doc:DebtAndFinancingGuide> for debt financing and capital structure
- Learn about <doc:FinancialStatementsGuide> for modeling complete financial statements
- Follow <doc:BuildingRevenueModel> to integrate equity financing into revenue models

## See Also

- ``CapTable``
- ``Shareholder``
- ``SAFETerm``
- ``ConvertibleNoteTerm``
```

**Key Rules**:
1. **"Next Steps" section**: Only use `<doc:ArticleName>` with descriptive text explaining why to visit that article
2. **"See Also" section**: Only use ` ``SymbolName`` ` with NO extra description text
3. **Never mix**: Keep article links and API symbol links completely separate
4. **Always have both**: Include both sections even if one is short
5. **Order matters**: "Next Steps" always comes before "See Also"

### Pitfall 6: Forgetting to Add New Tutorials to Landing Page ⚠️ CRITICAL

**Problem**: New tutorial articles are created but don't appear in the documentation's top-level navigation.

**Why it happens**: Creating a `.md` file in the `.docc` directory is not enough. The article must be explicitly referenced in the main landing page (`BusinessMath.md`) to appear in navigation.

**Solution**: After creating any new tutorial or guide, immediately add it to the `BusinessMath.md` landing page in the appropriate section.

**Steps**:
1. Create your tutorial file (e.g., `EquityFinancingGuide.md`)
2. Open `Sources/BusinessMath/BusinessMath.docc/BusinessMath.md`
3. Add reference to the appropriate `## Topics` section:

```markdown
## Topics

### Tutorials

- <doc:BuildingRevenueModel>
- <doc:FinancialStatementsGuide>
- <doc:EquityFinancingGuide>  ← Add your new guide here
- <doc:LeaseAccountingGuide>  ← And here
- <doc:InvestmentAnalysis>
```

**Checklist for every new tutorial**:
- [ ] Created `.md` file in `.docc` directory
- [ ] Added to appropriate section in `BusinessMath.md`
- [ ] Used exact filename (without `.md` extension) in `<doc:...>` reference
- [ ] Verified documentation builds without warnings
- [ ] Confirmed article appears in navigation when viewing docs

**Why this is critical**: Without the landing page reference, your tutorial exists but is "orphaned" - users can only access it through direct links or search, not through normal navigation. This defeats the purpose of creating comprehensive documentation.

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

**For every new tutorial/guide article** ⚠️ CRITICAL:
- [ ] File created in `.docc` directory with descriptive name ending in "Guide", "Tutorial", or "Walkthrough"
- [ ] Ends with "Next Steps" section (article links only using `<doc:...>`)
- [ ] Ends with "See Also" section (API symbols only using ` ``Symbol`` `)
- [ ] Added to `BusinessMath.md` landing page in appropriate `## Topics` section
- [ ] Documentation builds without warnings (`swift build`)
- [ ] Article appears in top-level navigation when viewing docs
- [ ] NO "Related Documentation" section mixing both types of links
- [ ] NO `## Topics` header in narrative article body

---

## 8. MCP Tool Documentation Guidelines

### Overview

Model Context Protocol (MCP) tools require exceptionally clear documentation because AI assistants must construct proper tool calls without human guidance. Poor documentation leads to malformed tool calls and frustrated users.

### Critical Principle: Show, Don't Just Tell

**AI models need explicit JSON examples, not just descriptions.** A description like "Array of objects with 'date' and 'amount' properties" leaves too much ambiguity about structure, nesting, and formatting.

### Documentation Structure for MCP Tools

Every MCP tool must have:
1. **REQUIRED STRUCTURE** section with minimal working example
2. **Complete examples** showing realistic use cases
3. **Explicit input schema** with detailed parameter descriptions
4. **Type information** for every field in nested structures

### Rule 1: Always Include REQUIRED STRUCTURE

At the start of every tool description, show the minimal JSON structure:

**Example - Good ✅**:
```swift
description: """
Calculate NPV for irregular cash flows with specific dates.

REQUIRED STRUCTURE:
{
  "rate": 0.10,
  "cashFlows": [
    {"date": "2024-01-15T00:00:00Z", "amount": -100000},
    {"date": "2024-06-15T00:00:00Z", "amount": 30000}
  ]
}

Example: Investment with quarterly payments
{
  "rate": 0.08,
  "cashFlows": [
    {"date": "2024-01-01T00:00:00Z", "amount": -50000},
    {"date": "2024-04-15T00:00:00Z", "amount": 15000}
  ]
}
"""
```

**Example - Poor ❌**:
```swift
description: "Calculate NPV for irregular cash flows"
```

### Rule 2: Document Nested Objects Explicitly

For any parameter that is an object or array of objects, show the complete structure:

**Example - Good ✅**:
```swift
"inputs": MCPSchemaProperty(
    type: "array",
    description: """
    Array of input variables. Each object must have:
    • name (string): Variable name (e.g., "Revenue")
    • distribution (string): "normal", "uniform", or "triangular"
    • parameters (object): Distribution parameters
      - normal: {mean: number, stdDev: number}
      - uniform: {min: number, max: number}

    Example: [{"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}}]
    """,
    items: MCPSchemaItems(type: "object")
)
```

**Example - Poor ❌**:
```swift
"inputs": MCPSchemaProperty(
    type: "array",
    description: "Array of input variables",
    items: MCPSchemaItems(type: "object")
)
```

### Rule 3: Show Multiple Examples for Complex Tools

Provide 2-3 complete examples showing different use cases:

```swift
description: """
Run Monte Carlo simulation.

REQUIRED STRUCTURE:
{
  "inputs": [{"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}}],
  "calculation": "{0}",
  "iterations": 10000
}

Example 1: Simple revenue model
{
  "inputs": [{"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}}],
  "calculation": "{0}",
  "iterations": 10000
}

Example 2: Profit model (Revenue - Costs)
{
  "inputs": [
    {"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}},
    {"name": "Costs", "distribution": "normal", "parameters": {"mean": 600000, "stdDev": 100000}}
  ],
  "calculation": "{0} - {1}",
  "iterations": 10000
}
"""
```

### Rule 4: Specify Format Requirements Explicitly

Don't assume AI models know formatting conventions:

**Example - Good ✅**:
```swift
description: """
• date (string): ISO 8601 format (e.g., "2024-01-15T00:00:00Z")
• type (string): "annual", "quarterly", "monthly", or "daily"
"""
```

**Example - Poor ❌**:
```swift
description: "Date string and type"
```

### Rule 5: Document Optional vs Required Fields

Clearly indicate which fields are required vs optional:

**Example - Good ✅**:
```swift
"variableRange": MCPSchemaProperty(
    type: "object",
    description: """
    Range to test. Use ONE of:
    • {"percentChange": 20} - test ±20% from base (optional: defaults to ±10%)
    • {"min": 80, "max": 120} - test explicit range (both required)
    """
)
```

### Rule 6: Provide Inline Examples in Schema Descriptions

Include example JSON directly in the schema description:

```swift
"cashFlows": MCPSchemaProperty(
    type: "array",
    description: """
    Array of cash flow objects. Each must have:
    • date (string): ISO 8601 format
    • amount (number): Cash flow amount

    Example: [{"date": "2024-01-01T00:00:00Z", "amount": -100000}, {"date": "2024-12-31T00:00:00Z", "amount": 110000}]
    """
)
```

### Common Patterns Requiring Special Attention

#### Arrays of Objects
Always show complete object structure with type annotations:
```swift
"variables": [
  {"name": "Revenue", "baseValue": 1000000, "lowValue": 800000, "highValue": 1200000},
  {"name": "Costs", "baseValue": 600000, "lowValue": 500000, "highValue": 700000}
]
```

#### Nested Objects with Variants
Show all variants clearly:
```swift
// Time period object - structure varies by type
{"year": 2024, "type": "annual"}                              // Annual
{"year": 2024, "month": 1, "type": "quarterly"}               // Quarterly
{"year": 2024, "month": 6, "type": "monthly"}                 // Monthly
{"year": 2024, "month": 3, "day": 15, "type": "daily"}       // Daily
```

#### Dates and Times
Always specify exact format:
```swift
// ISO 8601 format required
{"date": "2024-01-15T00:00:00Z", "amount": -100000}
```

#### Alternative Formats
When multiple formats are accepted, show examples of each:
```swift
// Option 1: Percent change
{"variableRange": {"percentChange": 20}}

// Option 2: Explicit range
{"variableRange": {"min": 800000, "max": 1200000}}
```

### MCP Tool Documentation Checklist

For every MCP tool:
- [ ] Includes "REQUIRED STRUCTURE" section with minimal example
- [ ] Has at least 2 complete usage examples
- [ ] Every nested object structure is fully documented
- [ ] All parameters have type information (string, number, object, array)
- [ ] Date/time formats explicitly specified (e.g., ISO 8601)
- [ ] Enum values listed explicitly
- [ ] Optional vs required fields clearly marked
- [ ] Example JSON included in schema descriptions
- [ ] Complex parameters have inline examples
- [ ] Alternative formats all shown with examples

### Testing Documentation Quality

To verify documentation quality, ask:
1. Could an AI generate a valid tool call from description alone?
2. Are all nested structures shown explicitly?
3. Are format requirements (dates, enums) specified?
4. Do examples cover common use cases?
5. Is the minimal working example truly minimal?

If the answer to any question is "no", improve the documentation.

### Why This Matters

**Without explicit examples**: AI models hallucinate incorrect structures, leading to "Missing or invalid 'inputs' array" errors and user frustration.

**With explicit examples**: AI models reliably construct correct tool calls, leading to successful executions and happy users.

**Investment**: 5-10 minutes of extra documentation per tool
**Payoff**: 90%+ reduction in malformed tool calls

---

## Related Documents

- [Master Plan](master_plan.md)
- [Coding Rules](coding_rules.md)
- [Usage Examples](usage_examples.md)
- [Implementation Checklist](implementation_checklist.md)

## External Resources

- [Swift-DocC Documentation](https://www.swift.org/documentation/docc/)
- [Apple DocC Guide](https://developer.apple.com/documentation/docc)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
# Understanding the Optimizer Type

Based on the provided code, here's a breakdown of how the `Optimizer` protocol works and how to address your questions:

## Current State Analysis

### 1. **How to Get the Minimum of a Function**
**Current Capability**: ✅ **Yes, but not ergonomic**
```swift
// Current way (not ideal)
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)
```

**Problem**: The method is called `optimize` which is ambiguous. Users might not know if it's minimizing or maximizing.

### 2. **How to Get the Maximum of a Function**
**Current Capability**: ❌ **Missing**
There's no built-in way to maximize. Users would need to manually negate the function:
```swift
// Workaround (not intuitive)
let result = optimizer.optimize(
    objective: { -myFunction($0) },
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)
let maximum = -result.objectiveValue
```

### 3. **How to Get a Certain Target Value of a Function**
**Current Capability**: ❌ **Missing**
This is a **goal-seeking** or **root-finding** problem (find x where f(x) = target), not optimization. The current API doesn't support this.

### 4. **How to Limit to a Bounded Range**
**Current Capability**: ✅ **Yes**
```swift
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 100.0)  // Search only in [0, 100]
)
```

## Proposed Enhanced API

Here's what the API **should** look for maximum ergonomics:

### 1. **Minimization** - Clear, Intuitive API
```swift
// Proposed
let result = optimizer.minimize(myFunction, from: 0.0)

// With bounds
let result = optimizer.minimize(myFunction, from: 0.0, in: 0.0...100.0)

// With constraints
let result = optimizer.minimize(myFunction, from: 0.0, subjectTo: [x >= 0, x <= 100])
```

### 2. **Maximization** - Mirror Minimization API
```swift
// Proposed
let result = optimizer.maximize(myFunction, from: 0.0)

// With bounds
let result = optimizer.maximize(myFunction, from: 0.0, in: 0.0...100.0)

// With constraints
let result = optimizer.maximize(myFunction, from: 0.0, subjectTo: [x >= 0, x <= 100])
```

### 3. **Goal Seeking** - New Capability
```swift
// Proposed (new method)
let result = optimizer.seek(
    function: myFunction,
    target: 42.0,           // Find x where f(x) = 42
    from: 0.0,
    in: 0.0...100.0
)

// Alternative: root-finding (find x where f(x) = 0)
let result = optimizer.findRoot(of: myFunction, from: 0.0, in: 0.0...100.0)
```

### 4. **Bounded Search** - Improved Syntax
```swift
// Current (verbose)
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 100.0)
)

// Proposed (cleaner)
let result = optimizer.minimize(myFunction, from: 0.0, in: 0.0...100.0)

// Or with constraints
let constraints = [
    Constraint(type: .greaterThanOrEqual, bound: 0.0),
    Constraint(type: .lessThanOrEqual, bound: 100.0)
]
let result = optimizer.minimize(myFunction, from: 0.0, subjectTo: constraints)
```

## Recommended Implementation

### Step 1: Add Convenience Methods to Optimizer Protocol Extension

```swift
public extension Optimizer {
    /// Minimize a function starting from an initial value.
    func minimize(
        _ function: @escaping (T) -> T,
        from initialValue: T,
        in bounds: ClosedRange<T>? = nil
    ) -> OptimizationResult<T> {
        let boundsTuple = bounds.map { (lower: $0.lowerBound, upper: $0.upperBound) }
        return optimize(
            objective: function,
            constraints: [],
            initialValue: initialValue,
            bounds: boundsTuple
        )
    }
    
    /// Maximize a function starting from an initial value.
    func maximize(
        _ function: @escaping (T) -> T,
        from initialValue: T,
        in bounds: ClosedRange<T>? = nil
    ) -> OptimizationResult<T> {
        let result = minimize({ -function($0) }, from: initialValue, in: bounds)
        
        // Flip the sign back for the result
        return OptimizationResult(
            optimalValue: result.optimalValue,
            objectiveValue: -result.objectiveValue,
            iterations: result.iterations,
            converged: result.converged,
            history: result.history.map {
                IterationHistory(
                    iteration: $0.iteration,
                    value: $0.value,
                    objective: -$0.objective,
                    gradient: -$0.gradient
                )
            }
        )
    }
}
```

### Step 2: Add Constraint Builders for Better Syntax

```swift
// Constraint operators for cleaner syntax
public func >= <T: Real>(lhs: T, rhs: T) -> Constraint<T> {
    Constraint(type: .greaterThanOrEqual, bound: rhs, function: { $0 })
}

public func <= <T: Real>(lhs: T, rhs: T) -> Constraint<T> {
    Constraint(type: .lessThanOrEqual, bound: rhs, function: { $0 })
}

public func == <T: Real>(lhs: T, rhs: T) -> Constraint<T> {
    Constraint(type: .equalTo, bound: rhs, function: { $0 })
}

// Usage
let constraints = [x >= 0, x <= 100, f(x) == 42]
```

### Step 3: Add Goal-Seeking Capability (New Protocol)

```swift
/// Protocol for algorithms that can find roots or target values
public protocol GoalSeeker {
    associatedtype T: Real & Sendable & Codable
    
    /// Find x such that f(x) = target
    func seek(
        function: @escaping (T) -> T,
        target: T,
        from initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T>
    
    /// Find root: f(x) = 0
    func findRoot(
        of function: @escaping (T) -> T,
        from initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {
        seek(function: function, target: T(0), from: initialValue, bounds: bounds)
    }
}
```

### Step 4: Create a Unified Solver Type

```swift
/// Unified solver that provides all optimization capabilities
public struct Solver<T: Real & Sendable & Codable> {
    let optimizer: any Optimizer<T>
    let goalSeeker: any GoalSeeker<T>
    
    public init(optimizer: any Optimizer<T>, goalSeeker: any GoalSeeker<T>) {
        self.optimizer = optimizer
        self.goalSeeker = goalSeeker
    }
    
    // Convenience methods that delegate to the appropriate algorithm
    public func minimize(_ f: @escaping (T) -> T, from x0: T, in bounds: ClosedRange<T>? = nil) -> OptimizationResult<T> {
        optimizer.minimize(f, from: x0, in: bounds)
    }
    
    public func maximize(_ f: @escaping (T) -> T, from x0: T, in bounds: ClosedRange<T>? = nil) -> OptimizationResult<T> {
        optimizer.maximize(f, from: x0, in: bounds)
    }
    
    public func seek(_ f: @escaping (T) -> T, target: T, from x0: T, in bounds: ClosedRange<T>? = nil) -> OptimizationResult<T> {
        let boundsTuple = bounds.map { (lower: $0.lowerBound, upper: $0.upperBound) }
        return goalSeeker.seek(function: f, target: target, from: x0, bounds: boundsTuple)
    }
}
```

## Usage Examples with Proposed API

```swift
// 1. Minimize a function
let parabola = { (x: Double) in x * x }
let minResult = solver.minimize(parabola, from: 5.0)
print("Minimum at x = \(minResult.optimalValue), f(x) = \(minResult.objectiveValue)")

// 2. Maximize a function (negated parabola)
let negParabola = { (x: Double) in -x * x }
let maxResult = solver.maximize(negParabola, from: -5.0, in: -10.0...10.0)
print("Maximum at x = \(maxResult.optimalValue), f(x) = \(maxResult.objectiveValue)")

// 3. Find where function equals a target value
let linear = { (x: Double) in 2 * x + 3 }
let targetResult = solver.seek(linear, target: 10.0, from: 0.0)
print("f(x) = 10 at x = \(targetResult.optimalValue)")

// 4. Bounded optimization
let boundedResult = solver.minimize(parabola, from: 5.0, in: 1.0...10.0)
print("Minimum in [1, 10] at x = \(boundedResult.optimalValue)")

// 5. With constraints
let constraints = [x >= 0, x <= 100, f(x) >= 50]
let constrainedResult = optimizer.minimize(
    parabola,
    from: 50.0,
    subjectTo: constraints
)
```

## Key Design Decisions

### 1. **Separate Protocols for Different Problems**
- `Optimizer` for min/max problems
- `GoalSeeker` for root-finding/target problems
- `Solver` as a unified facade

### 2. **Use ClosedRange for Bounds**
More Swift-idiomatic than tuples:
```swift
// Current: bounds: (lower: 0.0, upper: 100.0)
// Proposed: in: 0.0...100.0
```

### 3. **Clear Method Names**
- `minimize()` - obvious intent
- `maximize()` - obvious intent  
- `seek()` or `findTarget()` - for goal-seeking
- `findRoot()` - special case of seeking

### 4. **Constraint Builders**
Operator overloads make constraints readable:
```swift
// Instead of verbose Constraint initializers
[x >= 0, x <= 100, f(x) == 42]
```

### 5. **Preserve Backward Compatibility**
The original `optimize()` method remains for advanced use cases.

## Implementation Priority

1. **High Priority** (Essential for usability):
   - Add `minimize()` and `maximize()` convenience methods
   - Add `ClosedRange` support for bounds

2. **Medium Priority** (Greatly improves UX):
   - Add constraint builder operators
   - Create unified `Solver` type

3. **Lower Priority** (New capability):
   - Add `GoalSeeker` protocol for root-finding
   - Implement Newton-Raphson or bisection method

## Summary

The current `Optimizer` protocol provides a solid foundation but lacks ergonomics for common use cases. By adding convenience methods, better syntax for bounds and constraints, and separating optimization from goal-seeking, you can create a much more user-friendly API that directly addresses all four of your requirements.
# Analysis of the Optimizer Ergonomics Approach

Looking at both approaches (my analysis and your protocol extension), I see several considerations that weren't fully addressed. Let me sketch out the gaps and improvements:

## 1. **Missing Goal-Seeking/Root-Finding API**

Your protocol extension provides `minimize()` and `maximize()` but **omits goal-seeking**. This is a critical use case that users expect from optimization libraries. The pattern of minimizing `(f(x) - target)²` should be encapsulated.

**Proposal**: Add `goalSeek()` to the protocol extension:
```swift
func goalSeek(
    function: @escaping (T) -> T,
    target: T,
    from initialValue: T,
    constraints: [Constraint<T>] = [],
    bounds: Bounds? = nil
) -> OptimizationResult<T>
```

## 2. **Bounds vs ClosedRange Idiomatic Swift**

Your extension uses `Bounds = (lower: T, upper: T)` which is functional but not Swift-idiomatic. Swift prefers `ClosedRange<T>` for bounds.

**Proposal**: Add overloads with `ClosedRange<T>`:
```swift
func minimize(
    _ objective: @escaping (T) -> T,
    from initialValue: T,
    in range: ClosedRange<T>? = nil,
    constraints: [Constraint<T>] = []
) -> OptimizationResult<T>
```

## 3. **Constraint Builder Syntax Missing**

The current `Constraint` API is verbose. Users want something like:
```swift
let constraints = [x >= 0, x <= 100, f(x) == 42]
```

**Proposal**: Add constraint builder operators:
```swift
// Operator overloads
public func >= <T: Real>(lhs: T, rhs: T) -> Constraint<T>
public func <= <T: Real>(lhs: T, rhs: T) -> Constraint<T>
public func == <T: Real>(lhs: T, rhs: T) -> Constraint<T>

// Function constraints
public func constraint<T: Real>(
    _ function: @escaping (T) -> T,
    _ type: ConstraintType,
    _ bound: T
) -> Constraint<T>
```

## 4. **No Support for Multi-Dimensional Optimization**

The current design is strictly 1D. Many business/financial problems are multivariate (portfolio optimization, regression, etc.).

**Proposal**: Consider a separate `MultivariateOptimizer` protocol or extend the current design with vector support:
```swift
protocol MultivariateOptimizer {
    associatedtype Vector: RealVector
    
    func optimize(
        objective: @escaping (Vector) -> T,
        constraints: [Constraint<Vector>],
        initialValue: Vector,
        bounds: (lower: Vector, upper: Vector)?
    ) -> OptimizationResult<Vector>
}
```

## 5. **Missing Error Types for Common Failure Modes**

The current `OptimizationResult` has a `converged: Bool` but doesn't explain **why** it failed.

**Proposal**: Add optimization-specific errors:
```swift
enum OptimizationError<T: Real>: Error {
    case derivativeZero(at: T)
    case boundsViolated(value: T, bounds: (lower: T, upper: T))
    case constraintViolated(value: T, constraint: Constraint<T>)
    case maxIterationsReached(iterations: Int)
    case objectiveNaN(at: T)
    case gradientNaN(at: T)
}
```

## 6. **No Warm Start/Resume Capability**

For expensive objective functions, users want to resume from a previous result.

**Proposal**: Add warm start support:
```swift
extension Optimizer {
    func resume(
        from result: OptimizationResult<T>,
        objective: @escaping (T) -> T,
        constraints: [Constraint<T>] = [],
        bounds: Bounds? = nil
    ) -> OptimizationResult<T>
}
```

## 7. **Missing Callbacks for Progress Monitoring**

Users want to monitor optimization progress for long-running problems.

**Proposal**: Add callback support:
```swift
typealias OptimizationCallback<T> = (IterationHistory<T>) -> Bool  // Return false to stop

extension Optimizer {
    func optimize(
        objective: @escaping (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: Bounds?,
        callback: OptimizationCallback<T>? = nil
    ) -> OptimizationResult<T>
}
```

## 8. **No Support for Constraint Functions with Derivatives**

The current `Constraint` struct has a `function` parameter but no way to provide its derivative, which is needed for efficient constrained optimization.

**Proposal**: Extend `Constraint` with derivative support:
```swift
struct DifferentiableConstraint<T: Real> {
    let function: (T) -> T
    let derivative: (T) -> T
    let type: ConstraintType
    let bound: T
    let tolerance: T
}
```

## 9. **Missing Line Search/Step Size Control**

Newton-Raphson and other gradient methods need step size control to avoid overshooting.

**Proposal**: Add line search protocol:
```swift
protocol LineSearch {
    associatedtype T: Real
    
    func stepSize(
        objective: @escaping (T) -> T,
        derivative: @escaping (T) -> T,
        current: T,
        direction: T
    ) -> T
}

struct BacktrackingLineSearch<T: Real>: LineSearch {
    let alpha: T  // contraction factor
    let beta: T   // sufficient decrease factor
    
    func stepSize(...) -> T { ... }
}
```

## 10. **No Support for Stochastic/Noisy Objectives**

Many real-world objectives have noise (Monte Carlo simulations, etc.).

**Proposal**: Add stochastic optimization support:
```swift
protocol StochasticOptimizer: Optimizer {
    func optimizeStochastic(
        objective: @escaping (T) -> T,  // Returns different values each call
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: Bounds?,
        batchSize: Int = 1
    ) -> OptimizationResult<T>
}
```

## 11. **Missing Benchmarking/Performance Tracking**

Users want to compare different optimizers.

**Proposal**: Add performance metrics:
```swift
struct OptimizationMetrics {
    let functionEvaluations: Int
    let gradientEvaluations: Int
    let constraintEvaluations: Int
    let wallTime: TimeInterval
    let cpuTime: TimeInterval
}

extension OptimizationResult {
    var metrics: OptimizationMetrics { get }
}
```

## 12. **No Support for Parallel/Async Evaluation**

For expensive objectives, users want parallel evaluation.

**Proposal**: Add async support:
```swift
protocol AsyncOptimizer: Optimizer {
    func optimizeAsync(
        objective: @escaping (T) async -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: Bounds?
    ) async -> OptimizationResult<T>
}
```

## 13. **Missing Visualization/Diagnostic Tools**

Debugging optimization failures is hard without visualization.

**Proposal**: Add diagnostic utilities:
```swift
extension Optimizer {
    func trace(
        objective: @escaping (T) -> T,
        range: ClosedRange<T>,
        points: Int = 100
    ) -> [(x: T, y: T)]
    
    func plotConvergence(
        result: OptimizationResult<T>
    ) -> String  // ASCII or simple plot
}
```

## 14. **No Support for Multi-Objective Optimization**

Many business problems have multiple conflicting objectives (cost vs quality, risk vs return).

**Proposal**: Add multi-objective support:
```swift
struct MultiObjectiveResult<T: Real> {
    let paretoFront: [(T, T)]  // (objective1, objective2)
    let optimalTradeoffs: [T]
}

protocol MultiObjectiveOptimizer {
    func optimize(
        objectives: [(T) -> T],
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: Bounds?
    ) -> MultiObjectiveResult<T>
}
```

## 15. **Missing Integration with SwiftUI/Plotting**

For interactive applications.

**Proposal**: Add SwiftUI integration:
```swift
struct OptimizationPlot<T: Real>: View {
    let optimizer: any Optimizer<T>
    let objective: (T) -> T
    let range: ClosedRange<T>
    
    var body: some View { ... }
}
```

## Implementation Priority Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Goal-seeking API | High | Low | **P0** |
| ClosedRange bounds | Medium | Low | P1 |
| Constraint builders | High | Low | **P0** |
| Error types | Medium | Low | P1 |
| Callbacks | Medium | Medium | P2 |
| Warm start | Low | Medium | P3 |
| Line search | High | High | P2 |
| Multi-dimensional | High | Very High | P3 |
| Stochastic | Low | High | P4 |
| Async | Low | High | P4 |
| Visualization | Medium | Medium | P3 |
| Multi-objective | Low | Very High | P4 |

## Recommended Implementation Order

### Phase 1 (Essential Ergonomics - P0)
1. Add `goalSeek()` to protocol extension
2. Add constraint builder operators
3. Add `ClosedRange<T>` overloads

### Phase 2 (Quality of Life - P1)
1. Add optimization error types
2. Add progress callbacks
3. Add basic line search for Newton-Raphson

### Phase 3 (Advanced Features - P2/P3)
1. Add warm start capability
2. Add diagnostic utilities
3. Consider multi-dimensional design

## Key Design Questions to Answer

1. **Should goal-seeking be a separate protocol?** 
   - Yes: `GoalSeeker` protocol with `findRoot()` and `seekTarget()` methods
   - No: Just add `goalSeek()` to `Optimizer` extension

2. **How to handle multi-dimensional vs 1D?**
   - Option A: Separate protocols (`ScalarOptimizer` vs `VectorOptimizer`)
   - Option B: Generic over `VectorSpace` protocol
   - Option C: Keep 1D only for now, add multi-dimensional later

3. **How much to expose vs hide?**
   - Expose everything: Users can customize everything but API is complex
   - Sensible defaults: Hide complexity but allow override when needed
   - **Recommendation**: Progressive disclosure with good defaults

4. **Testing strategy?**
   - Test each convenience method independently
   - Test that convenience methods delegate correctly to base `optimize()`
   - Test edge cases (bounds at solution, constraints active, etc.)

## Summary of Missing Pieces

Your protocol extension is a **good start** but misses:
1. **Goal-seeking API** (critical for financial applications like IRR)
2. **Swift-idiomatic bounds** (`ClosedRange` instead of tuples)
3. **Constraint builder syntax** (essential for readability)
4. **Proper error handling** (not just `converged: Bool`)
5. **Progress monitoring** (callbacks for long-running optimizations)

The biggest gap is **goal-seeking** - this is arguably more important than maximization for financial applications (finding IRR, break-even points, etc.).

Would you like me to implement a comprehensive solution addressing these gaps, starting with Phase 1? I can provide:
1. Complete protocol extension with all convenience methods
2. Constraint builder operators
3. Goal-seeking API
4. Comprehensive tests for all new functionality

-----USER RESPONSE BELOW-----

1. **Should goal-seeking be a separate protocol?**
No, goal seeking should be a part of Optimization. Let's keep these things together, as they will often be used in conjunction.

2. **How to handle multi-dimensional vs 1D?**
I very much want to add a multi-dimensisional optimizer. I think that should be Generic over the VectorSpace protocol, that seems the most mathematically correct. Do you agree?

3. **How much to expose vs hide?**
The Swift way is progressive disclosure. Please make sure we obey that philosophy.

4. **Testing Strategy?**
We only use test-driven development. Refer to our Coding Rules document for any questions, but the basic philosophy is that we build our tests first, then once they are approved, we provide implementations that satisfy them. 

I will submit the following:
Coding Guidelines
DocC Documentation Guidelines
Existing Implementation for the 1D Optimizer Type
Existing Test Suite for Optimizers

Let's implement the entirety of your suggestions with my preferences indicated above. The first step will be implementing the required tests. After that, we will attempt implementations that satisfy those tests.
 These are great so far. Let's actually take a step back and provide a detailed implentation plan so that we can come back to this as necessary. Provide for each step in extensive detail, with proposed function signatures and tests for each function. I'd like for multiple coding LLMs to make an attempt at this and want a consistent test base for this work.

## Summary of Missing Pieces

Your protocol extension is a **good start** but misses:
1. **Goal-seeking API** (critical for financial applications like IRR)
2. **Swift-idiomatic bounds** (`ClosedRange` instead of tuples)
3. **Constraint builder syntax** (essential for readability)
4. **Proper error handling** (not just `converged: Bool`)
5. **Progress monitoring** (callbacks for long-running optimizations)

The biggest gap is **goal-seeking** - this is arguably more important than maximization for financial applications (finding IRR, break-even points, etc.).

Would you like me to implement a comprehensive solution addressing these gaps, starting with Phase 1? I can provide:
1. Complete protocol extension with all convenience methods
2. Constraint builder operators
3. Goal-seeking API
4. Comprehensive tests for all new functionality

-----USER RESPONSE BELOW-----

1. **Should goal-seeking be a separate protocol?**
No, goal seeking should be a part of Optimization. Let's keep these things together, as they will often be used in conjunction.

2. **How to handle multi-dimensional vs 1D?**
I very much want to add a multi-dimensisional optimizer. I think that should be Generic over the VectorSpace protocol, that seems the most mathematically correct. Do you agree?

3. **How much to expose vs hide?**
The Swift way is progressive disclosure. Please make sure we obey that philosophy.

4. **Testing Strategy?**
We only use test-driven development. Refer to our Coding Rules document for any questions, but the basic philosophy is that we build our tests first, then once they are approved, we provide implementations that satisfy them. 

I will submit the following:
Coding Guidelines
DocC Documentation Guidelines
Existing Implementation for the 1D Optimizer Type
Existing Test Suite for Optimizers

Let's implement the entirety of your suggestions with my preferences indicated above. The first step will be implementing the required tests. After that, we will attempt implementations that satisfy those tests.
# Comprehensive Optimizer Enhancement Implementation Plan

## Overview

This plan implements a complete, ergonomic optimization API for BusinessMath with:
1. **Goal-seeking** as part of the Optimizer protocol
2. **Multi-dimensional support** via VectorSpace protocol
3. **Progressive disclosure** API design
4. **Test-driven development** with comprehensive test suite

## Phase 1: Core Convenience Methods (Scalar Optimization)

### Step 1.1: Enhanced Optimizer Protocol Extension

**File:** `Sources/BusinessMath/Optimization/Optimizer+Convenience.swift`

```swift
/// Enhanced convenience methods for scalar optimization
public extension Optimizer {
    /// Common bounds tuple for scalar optimizers
    typealias Bounds = (lower: T, upper: T)
    
    // MARK: - Minimization Convenience
    
    /// Minimize a function starting from an initial value.
    ///
    /// - Parameters:
    ///   - objective: The function to minimize.
    ///   - initialValue: Starting point for optimization.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with minimum found.
    func minimize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Minimize a function within a Swift-idiomatic range.
    ///
    /// - Parameters:
    ///   - objective: The function to minimize.
    ///   - initialValue: Starting point for optimization.
    ///   - range: Optional closed range for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with minimum found.
    func minimize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        in range: ClosedRange<T>? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    // MARK: - Maximization Convenience
    
    /// Maximize a function starting from an initial value.
    ///
    /// - Parameters:
    ///   - objective: The function to maximize.
    ///   - initialValue: Starting point for optimization.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with maximum found.
    func maximize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Maximize a function within a Swift-idiomatic range.
    ///
    /// - Parameters:
    ///   - objective: The function to maximize.
    ///   - initialValue: Starting point for optimization.
    ///   - range: Optional closed range for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with maximum found.
    func maximize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        in range: ClosedRange<T>? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    // MARK: - Goal Seeking (Root Finding)
    
    /// Find where a function equals a target value.
    ///
    /// - Parameters:
    ///   - function: The function to evaluate.
    ///   - target: Desired output value.
    ///   - initialValue: Starting point for search.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with x where f(x) ≈ target.
    func goalSeek(
        function: @escaping (T) -> T,
        target: T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Find where a function equals a target value within a range.
    ///
    /// - Parameters:
    ///   - function: The function to evaluate.
    ///   - target: Desired output value.
    ///   - initialValue: Starting point for search.
    ///   - range: Optional closed range for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with x where f(x) ≈ target.
    func goalSeek(
        function: @escaping (T) -> T,
        target: T,
        from initialValue: T,
        in range: ClosedRange<T>? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Find root of a function (where f(x) = 0).
    ///
    /// - Parameters:
    ///   - function: The function to evaluate.
    ///   - initialValue: Starting point for search.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with x where f(x) ≈ 0.
    func findRoot(
        of function: @escaping (T) -> T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    // MARK: - Simplified Overloads
    
    /// Optimize with just objective and initial value.
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T
    ) -> OptimizationResult<T>
    
    /// Optimize with objective, initial value, and bounds.
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T,
        bounds: Bounds
    ) -> OptimizationResult<T>
    
    // MARK: - Helper Methods
    
    /// Convert bounds to constraints.
    func constraints(from bounds: Bounds) -> [Constraint<T>]
    
    /// Clamp value to bounds.
    func clamp(_ value: T, to bounds: Bounds?) -> T
    
    /// Check if value satisfies bounds and constraints.
    func isFeasible(
        _ value: T,
        constraints: [Constraint<T>] = [],
        within bounds: Bounds? = nil
    ) -> Bool
    
    /// Create numerical derivative function.
    func numericalDerivative(h: T) -> (_ f: @escaping (T) -> T) -> (T) -> T
}
```

### Step 1.2: Constraint Builder Syntax

**File:** `Sources/BusinessMath/Optimization/Constraint+Builders.swift`

```swift
/// Constraint builder operators for readable constraint syntax
public func >= <T: Real>(lhs: T, rhs: T) -> Constraint<T>
public func <= <T: Real>(lhs: T, rhs: T) -> Constraint<T>
public func == <T: Real>(lhs: T, rhs: T) -> Constraint<T>

/// Constraint on a function of the variable
public func constraint<T: Real>(
    _ function: @escaping (T) -> T,
    _ type: ConstraintType,
    _ bound: T,
    tolerance: T = 0.0001
) -> Constraint<T>

/// Constraint builder for common mathematical functions
public extension Constraint {
    /// Create constraint on squared value
    static func squared(_ type: ConstraintType, _ bound: T) -> Constraint<T>
    
    /// Create constraint on absolute value
    static func absolute(_ type: ConstraintType, _ bound: T) -> Constraint<T>
    
    /// Create constraint on exponential value
    static func exponential(_ type: ConstraintType, _ bound: T) -> Constraint<T>
}
```

### Step 1.3: Test Suite for Core Convenience Methods

**File:** `Tests/BusinessMathTests/OptimizationTests/OptimizerConvenienceTests.swift`

```swift
import Testing
import Numerics
@testable import BusinessMath

@Suite("Optimizer Convenience Methods")
struct OptimizerConvenienceTests {
    
    // MARK: - Test Fixtures
    
    struct MockOptimizer<T: Real>: Optimizer {
        var capturedCalls: [(
            objective: ((T) -> T)?,
            constraints: [Constraint<T>]?,
            initialValue: T?,
            bounds: (lower: T, upper: T)?
        )] = []
        
        mutating func optimize(
            objective: @escaping (T) -> T,
            constraints: [Constraint<T>],
            initialValue: T,
            bounds: (lower: T, upper: T)?
        ) -> OptimizationResult<T> {
            capturedCalls.append((objective, constraints, initialValue, bounds))
            return OptimizationResult(
                optimalValue: T(0),
                objectiveValue: T(0),
                iterations: 0,
                converged: true
            )
        }
    }
    
    // MARK: - Minimize Tests
    
    @Test("minimize() delegates to optimize()")
    func minimizeDelegates() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.minimize(objective, from: 5.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        #expect(optimizer.capturedCalls[0].initialValue == 5.0)
        #expect(optimizer.capturedCalls[0].constraints?.isEmpty == true)
    }
    
    @Test("minimize() with bounds passes bounds correctly")
    func minimizeWithBounds() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        _ = optimizer.minimize(objective, from: 5.0, bounds: bounds)
        
        #expect(optimizer.capturedCalls[0].bounds?.lower == 0.0)
        #expect(optimizer.capturedCalls[0].bounds?.upper == 10.0)
    }
    
    @Test("minimize() with ClosedRange converts correctly")
    func minimizeWithClosedRange() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let range: ClosedRange<Double> = 0.0...10.0
        
        _ = optimizer.minimize(objective, from: 5.0, in: range)
        
        #expect(optimizer.capturedCalls[0].bounds?.lower == 0.0)
        #expect(optimizer.capturedCalls[0].bounds?.upper == 10.0)
    }
    
    @Test("minimize() with constraints passes them through")
    func minimizeWithConstraints() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let constraints = [
            Constraint<Double>(type: .greaterThanOrEqual, bound: 0.0),
            Constraint<Double>(type: .lessThanOrEqual, bound: 100.0)
        ]
        
        _ = optimizer.minimize(objective, from: 5.0, constraints: constraints)
        
        #expect(optimizer.capturedCalls[0].constraints?.count == 2)
    }
    
    // MARK: - Maximize Tests
    
    @Test("maximize() minimizes negated function")
    func maximizeMinimizesNegated() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.maximize(objective, from: 5.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Test that objective is negated
        let testValue = 3.0
        let originalResult = objective(testValue)
        let capturedObjective = optimizer.capturedCalls[0].objective
        let negatedResult = capturedObjective?(testValue)
        
        #expect(negatedResult == -originalResult)
    }
    
    @Test("maximize() returns correct objective value")
    func maximizeReturnsCorrectObjective() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = -(x-5)² + 25, maximum at x=5, f(5)=25
        let objective: (Double) -> Double = { x in -(x - 5) * (x - 5) + 25 }
        
        let result = optimizer.maximize(objective, from: 0.0)
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 5.0) < 0.001)
        #expect(abs(result.objectiveValue - 25.0) < 0.001)
    }
    
    // MARK: - Goal Seek Tests
    
    @Test("goalSeek() minimizes squared residual")
    func goalSeekMinimizesSquaredResidual() {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in 2 * x + 3 }
        let target: Double = 10.0
        
        _ = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Test objective is (f(x) - target)²
        let testValue = 2.0
        let expectedResidual = function(testValue) - target
        let expectedObjective = expectedResidual * expectedResidual
        let capturedObjective = optimizer.capturedCalls[0].objective
        let actualObjective = capturedObjective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    @Test("goalSeek() finds correct solution for linear function")
    func goalSeekLinearFunction() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = 2x + 3, find x where f(x) = 10
        // Solution: x = (10 - 3) / 2 = 3.5
        let function: (Double) -> Double = { x in 2 * x + 3 }
        let target: Double = 10.0
        
        let result = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 3.5) < 1e-6)
        #expect(abs(function(result.optimalValue) - target) < 1e-6)
    }
    
    @Test("goalSeek() with bounds respects constraints")
    func goalSeekWithBounds() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = x², find x where f(x) = 4
        // Solutions: x = 2 or x = -2
        // With bounds [0, 10], should find x = 2
        let function: (Double) -> Double = { x in x * x }
        let target: Double = 4.0
        
        let result = optimizer.goalSeek(
            function: function,
            target: target,
            from: 1.0,
            in: 0.0...10.0
        )
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 2.0) < 1e-6)
        #expect(result.optimalValue >= 0.0)
        #expect(result.optimalValue <= 10.0)
    }
    
    @Test("findRoot() finds where function equals zero")
    func findRootFindsZero() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = x² - 4, roots at x = ±2
        let function: (Double) -> Double = { x in x * x - 4 }
        
        let result = optimizer.findRoot(of: function, from: 1.0)
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 2.0) < 1e-6)
        #expect(abs(function(result.optimalValue)) < 1e-6)
    }
    
    // MARK: - Helper Method Tests
    
    @Test("constraints(from:) creates correct constraints")
    func constraintsFromBoundsCreatesCorrectly() {
        let optimizer = MockOptimizer<Double>()
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        let constraints = optimizer.constraints(from: bounds)
        
        #expect(constraints.count == 2)
        #expect(constraints[0].type == .greaterThanOrEqual)
        #expect(constraints[0].bound == 0.0)
        #expect(constraints[1].type == .lessThanOrEqual)
        #expect(constraints[1].bound == 10.0)
    }
    
    @Test("clamp() respects bounds")
    func clampRespectsBounds() {
        let optimizer = MockOptimizer<Double>()
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        #expect(optimizer.clamp(-5.0, to: bounds) == 0.0)
        #expect(optimizer.clamp(5.0, to: bounds) == 5.0)
        #expect(optimizer.clamp(15.0, to: bounds) == 10.0)
        #expect(optimizer.clamp(5.0, to: nil) == 5.0)
    }
   
    @Test("isFeasible() checks bounds and constraints")
    func isFeasibleChecksBoth() {
        let optimizer = MockOptimizer<Double>()
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        let constraint = Constraint<Double>(type: .greaterThanOrEqual, bound: 5.0)
        
        #expect(optimizer.isFeasible(3.0, constraints: [], within: bounds) == true)
        #expect(optimizer.isFeasible(3.0, constraints: [constraint], within: bounds) == false)
        #expect(optimizer.isFeasible(7.0, constraints: [constraint], within: bounds) == true)
        #expect(optimizer.isFeasible(15.0, constraints: [], within: bounds) == false)
        #expect(optimizer.isFeasible(7.0, constraints: [], within: nil) == true)
    }
    
    @Test("numericalDerivative() approximates derivative correctly")
    func numericalDerivativeApproximation() {
        let optimizer = MockOptimizer<Double>()
        let derivativeBuilder = optimizer.numericalDerivative(h: 1e-6)
        
        // f(x) = x², f'(x) = 2x
        let f: (Double) -> Double = { x in x * x }
        let df = derivativeBuilder(f)
        
        #expect(abs(df(0.0) - 0.0) < 1e-6)
        #expect(abs(df(1.0) - 2.0) < 1e-6)
        #expect(abs(df(2.0) - 4.0) < 1e-6)
        #expect(abs(df(3.0) - 6.0) < 1e-6)
    }
    
    @Test("numericalDerivative() with custom step size")
    func numericalDerivativeCustomStep() {
        let optimizer = MockOptimizer<Double>()
        let derivativeBuilder = optimizer.numericalDerivative(h: 1e-4)
        
        // f(x) = x³, f'(x) = 3x²
        let f: (Double) -> Double = { x in x * x * x }
        let df = derivativeBuilder(f)
        
        #expect(abs(df(0.0) - 0.0) < 1e-4)
        #expect(abs(df(1.0) - 3.0) < 1e-4)
        #expect(abs(df(2.0) - 12.0) < 1e-4)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("minimize() with nil bounds passes nil correctly")
    func minimizeWithNilBounds() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.minimize(objective, from: 5.0, bounds: nil)
        
        #expect(optimizer.capturedCalls[0].bounds == nil)
    }
    
    @Test("maximize() with empty constraints array")
    func maximizeWithEmptyConstraints() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.maximize(objective, from: 5.0, constraints: [])
        
        #expect(optimizer.capturedCalls[0].constraints?.isEmpty == true)
    }
    
    @Test("goalSeek() with zero target finds root")
    func goalSeekWithZeroTarget() {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in x * x - 4 }
        
        _ = optimizer.goalSeek(function: function, target: 0.0, from: 1.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Should minimize (f(x) - 0)² = f(x)²
        let testValue = 2.0
        let expectedObjective = function(testValue) * function(testValue)
        let actualObjective = optimizer.capturedCalls[0].objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    @Test("findRoot() is equivalent to goalSeek with target zero")
    func findRootEquivalentToGoalSeekZero() {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in x * x - 4 }
        
        _ = optimizer.findRoot(of: function, from: 1.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Should minimize f(x)²
        let testValue = 2.0
        let expectedObjective = function(testValue) * function(testValue)
        let actualObjective = optimizer.capturedCalls[0].objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    // MARK: - Parameterized Tests
    
    @Test("minimize() with various bounds",
          arguments: [
            (lower: 0.0, upper: 10.0),
            (lower: -5.0, upper: 5.0),
            (lower: -100.0, upper: 100.0)
          ])
    func minimizeWithVariousBounds(bounds: (lower: Double, upper: Double)) {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.minimize(objective, from: 0.0, bounds: bounds)
        
        #expect(optimizer.capturedCalls[0].bounds?.lower == bounds.lower)
        #expect(optimizer.capturedCalls[0].bounds?.upper == bounds.upper)
    }
    
    @Test("goalSeek() with various targets",
          arguments: [
            (target: 0.0, description: "zero"),
            (target: 1.0, description: "positive"),
            (target: -1.0, description: "negative"),
            (target: 100.0, description: "large positive"),
            (target: -100.0, description: "large negative")
          ])
    func goalSeekWithVariousTargets(target: Double, description: String) {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in 2 * x + 3 }
        
        _ = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Verify objective is (f(x) - target)²
        let testValue = 5.0
        let expectedResidual = function(testValue) - target
        let expectedObjective = expectedResidual * expectedResidual
        let actualObjective = optimizer.capturedCalls[0].objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10,
               "Failed for target \(description)")
    }
}
```

### Step 1.4: Constraint Builder Tests

**File:** `Tests/BusinessMathTests/OptimizationTests/ConstraintBuilderTests.swift`

```swift
//
//  ConstraintBuilderTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Constraint Builder Syntax")
struct ConstraintBuilderTests {
    
    // MARK: - Operator Tests
    
    @Test(">= operator creates greaterThanOrEqual constraint")
    func greaterThanOrEqualOperator() {
        let constraint: Constraint<Double> = 5.0 >= 0.0
        
        #expect(constraint.type == .greaterThanOrEqual)
        #expect(constraint.bound == 0.0)
        #expect(constraint.function == nil)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(0.0) == true)
        #expect(constraint.isSatisfied(-1.0) == false)
    }
    
    @Test("<= operator creates lessThanOrEqual constraint")
    func lessThanOrEqualOperator() {
        let constraint: Constraint<Double> = 5.0 <= 10.0
        
        #expect(constraint.type == .lessThanOrEqual)
        #expect(constraint.bound == 10.0)
        #expect(constraint.function == nil)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(10.0) == true)
        #expect(constraint.isSatisfied(11.0) == false)
    }
    
    @Test("== operator creates equalTo constraint")
    func equalToOperator() {
        let constraint: Constraint<Double> = 5.0 == 5.0
        
        #expect(constraint.type == .equalTo)
        #expect(constraint.bound == 5.0)
        #expect(constraint.function == nil)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(5.00001) == false)
        #expect(constraint.isSatisfied(4.99999) == false)
    }
    
    @Test("== operator uses default tolerance")
    func equalToOperatorUsesDefaultTolerance() {
        let constraint: Constraint<Double> = 5.0 == 5.0
        
        #expect(constraint.tolerance == 0.0001)
        #expect(constraint.isSatisfied(5.00005) == true)  // Within tolerance
        #expect(constraint.isSatisfied(5.0002) == false)  // Outside tolerance
    }
    
    // MARK: - Function Constraint Tests
    
    @Test("constraint() with function creates constraint")
    func constraintWithFunction() {
        let constraint = constraint({ (x: Double) in x * x }, .lessThan, 100.0)
        
        #expect(constraint.type == .lessThan)
        #expect(constraint.bound == 100.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(9.0) == true)   // 81 < 100
        #expect(constraint.isSatisfied(10.0) == true)  // 100 == 100 (not <)
        #expect(constraint.isSatisfied(11.0) == false) // 121 > 100
    }
    
    @Test("constraint() with custom tolerance")
    func constraintWithCustomTolerance() {
        let constraint = constraint({ (x: Double) in x }, .equalTo, 5.0, tolerance: 0.1)
        
        #expect(constraint.tolerance == 0.1)
        #expect(constraint.isSatisfied(5.05) == true)
        #expect(constraint.isSatisfied(5.15) == false)
    }
    
    // MARK: - Constraint Extension Tests
    
    @Test("Constraint.squared() creates squared constraint")
    func constraintSquared() {
        let constraint = Constraint<Double>.squared(.lessThan, 100.0)
        
        #expect(constraint.type == .lessThan)
        #expect(constraint.bound == 100.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(9.0) == true)   // 81 < 100
        #expect(constraint.isSatisfied(10.0) == true)  // 100 == 100 (not <)
        #expect(constraint.isSatisfied(11.0) == false) // 121 > 100
    }
    
    @Test("Constraint.absolute() creates absolute value constraint")
    func constraintAbsolute() {
        let constraint = Constraint<Double>.absolute(.lessThanOrEqual, 5.0)
        
        #expect(constraint.type == .lessThanOrEqual)
        #expect(constraint.bound == 5.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(4.0) == true)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(-5.0) == true)
        #expect(constraint.isSatisfied(6.0) == false)
        #expect(constraint.isSatisfied(-6.0) == false)
    }
    
    @Test("Constraint.exponential() creates exponential constraint")
    func constraintExponential() {
        let constraint = Constraint<Double>.exponential(.greaterThan, 1.0)
        
        #expect(constraint.type == .greaterThan)
        #expect(constraint.bound == 1.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(0.0) == true)   // exp(0) = 1 > 1? (equal, not greater)
        #expect(constraint.isSatisfied(0.1) == true)   // exp(0.1) ≈ 1.105 > 1
        #expect(constraint.isSatisfied(-0.1) == false) // exp(-0.1) ≈ 0.905 < 1
    }
    
    // MARK: - Constraint Composition Tests
    
    @Test("Multiple constraints can be combined")
    func multipleConstraintsCombined() {
        let constraints = [
            0.0 <= 5.0,  // x ≥ 0
            5.0 <= 10.0, // x ≤ 10
            5.0 == 5.0   // x = 5 (within tolerance)
        ]
        
        #expect(constraints.count == 3)
        #expect(constraints[0].type == .greaterThanOrEqual)
        #expect(constraints[0].bound == 0.0)
        #expect(constraints[1].type == .lessThanOrEqual)
        #expect(constraints[1].bound == 10.0)
        #expect(constraints[2].type == .equalTo)
        #expect(constraints[2].bound == 5.0)
    }
    
    @Test("Constraint with function composition")
    func constraintWithFunctionComposition() {
        let squareConstraint = constraint({ (x: Double) in x * x }, .lessThan, 100.0)
        let linearConstraint = constraint({ (x: Double) in 2 * x + 3 }, .greaterThan, 0.0)
        
        #expect(squareConstraint.isSatisfied(9.0) == true)
        #expect(squareConstraint.isSatisfied(11.0) == false)
        #expect(linearConstraint.isSatisfied(0.0) == true)   // 3 > 0
        #expect(linearConstraint.isSatisfied(-2.0) == false) // -1 < 0
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Constraint with NaN bound returns false")
    func constraintWithNaNBound() {
        let constraint = Constraint<Double>(type: .greaterThanOrEqual, bound: .nan)
        
        #expect(constraint.isSatisfied(5.0) == false)
        #expect(constraint.isSatisfied(.nan) == false)
    }
    
    @Test("Constraint with infinity bound")
    func constraintWithInfinityBound() {
        let positiveInfConstraint = Constraint<Double>(type: .lessThan, bound: .infinity)
        let negativeInfConstraint = Constraint<Double>(type: .greaterThan, bound: -.infinity)
        
        #expect(positiveInfConstraint.isSatisfied(1e100) == true)
        #expect(negativeInfConstraint.isSatisfied(-1e100) == true)
    }
    
    @Test("Equality constraint with very small tolerance")
    func equalityConstraintSmallTolerance() {
        let constraint = Constraint<Double>(type: .equalTo, bound: 1.0, tolerance: 1e-10)
        
        #expect(constraint.isSatisfied(1.0) == true)
        #expect(constraint.isSatisfied(1.0 + 1e-11) == true)
        #expect(constraint.isSatisfied(1.0 + 1e-9) == false)
    }
}
```

## Phase 2: VectorSpace Foundation (Multi-Dimensional Optimization) - Continued

### Step 2.1: VectorSpace Protocol (Continued)

**File:** `Sources/BusinessMath/Optimization/Vector/VectorSpace.swift` (Continued)

```swift
    /// Vector addition.
    static func + (lhs: Self, rhs: Self) -> Self
    
    /// Vector subtraction.
    static func - (lhs: Self, rhs: Self) -> Self
    
    /// Scalar multiplication.
    static func * (lhs: Scalar, rhs: Self) -> Self
    
    /// Scalar division.
    static func / (lhs: Self, rhs: Scalar) -> Self
    
    /// Negation (unary minus).
    static prefix func - (vector: Self) -> Self
    
    /// Euclidean norm (length) of the vector.
    var norm: Scalar { get }
    
    /// Squared Euclidean norm (more efficient than norm for comparisons).
    var squaredNorm: Scalar { get }
    
    /// Dot product with another vector.
    func dot(_ other: Self) -> Scalar
    
    /// Distance to another vector.
    func distance(to other: Self) -> Scalar
    
    /// Create a vector from an array of scalars.
    static func fromArray(_ array: [Scalar]) -> Self?
    
    /// Convert to array of scalars.
    func toArray() -> [Scalar]
    
    /// Dimension of the vector space.
    static var dimension: Int { get }
    
    /// Check if vector contains NaN or infinite values.
    var isFinite: Bool { get }
    
    /// Linearly interpolate between two vectors.
    static func lerp(from start: Self, to end: Self, t: Scalar) -> Self
}

// MARK: - Default Implementations

public extension VectorSpace {
    /// Default implementation of vector subtraction.
    static func - (lhs: Self, rhs: Self) -> Self {
        lhs + (-rhs)
    }
    
    /// Default implementation of squared norm.
    var squaredNorm: Scalar {
        self.dot(self)
    }
    
    /// Default implementation of distance.
    func distance(to other: Self) -> Scalar {
        (self - other).norm
    }
    
    /// Default implementation of linear interpolation.
    static func lerp(from start: Self, to end: Self, t: Scalar) -> Self {
        start + t * (end - start)
    }
}

// MARK: - Common Vector Types

/// 2-dimensional vector.
public struct Vector2D<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T
    
    public var x: T
    public var y: T
    
    public init(x: T, y: T) {
        self.x = x
        self.y = y
    }
    
    public static var zero: Vector2D<T> {
        Vector2D(x: T(0), y: T(0))
    }
    
    public static func + (lhs: Vector2D<T>, rhs: Vector2D<T>) -> Vector2D<T> {
        Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func * (lhs: T, rhs: Vector2D<T>) -> Vector2D<T> {
        Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
    }
    
    public static prefix func - (vector: Vector2D<T>) -> Vector2D<T> {
        Vector2D(x: -vector.x, y: -vector.y)
    }
    
    public var norm: T {
        T.sqrt(x * x + y * y)
    }
    
    public func dot(_ other: Vector2D<T>) -> T {
        x * other.x + y * other.y
    }
    
    public static func fromArray(_ array: [T]) -> Vector2D<T>? {
        guard array.count == 2 else { return nil }
        return Vector2D(x: array[0], y: array[1])
    }
    
    public func toArray() -> [T] {
        [x, y]
    }
    
    public static var dimension: Int { 2 }
    
    public var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}

/// 3-dimensional vector.
public struct Vector3D<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T
    
    public var x: T
    public var y: T
    public var z: T
    
    public init(x: T, y: T, z: T) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public static var zero: Vector3D<T> {
        Vector3D(x: T(0), y: T(0), z: T(0))
    }
    
    public static func + (lhs: Vector3D<T>, rhs: Vector3D<T>) -> Vector3D<T> {
        Vector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
    
    public static func * (lhs: T, rhs: Vector3D<T>) -> Vector3D<T> {
        Vector3D(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }
    
    public static prefix func - (vector: Vector3D<T>) -> Vector3D<T> {
        Vector3D(x: -vector.x, y: -vector.y, z: -vector.z)
    }
    
    public var norm: T {
        T.sqrt(x * x + y * y + z * z)
    }
    
    public func dot(_ other: Vector3D<T>) -> T {
        x * other.x + y * other.y + z * other.z
    }
    
    public static func fromArray(_ array: [T]) -> Vector3D<T>? {
        guard array.count == 3 else { return nil }
        return Vector3D(x: array[0], y: array[1], z: array[2])
    }
    
    public func toArray() -> [T] {
        [x, y, z]
    }
    
    public static var dimension: Int { 3 }
    
    public var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}

/// N-dimensional vector (array-backed).
public struct VectorN<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T
    
    private var components: [T]
    
    public init(_ components: [T]) {
        self.components = components
    }
    
    public init(repeating value: T, count: Int) {
        self.components = Array(repeating: value, count: count)
    }
    
    public static var zero: VectorN<T> {
        VectorN([])
    }
    
    public static func + (lhs: VectorN<T>, rhs: VectorN<T>) -> VectorN<T> {
        guard lhs.components.count == rhs.components.count else {
            // Return zero vector for dimension mismatch
            return VectorN(repeating:

