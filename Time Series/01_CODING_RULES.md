# Coding Rules for BusinessMath Library

**Updated:** October 15, 2025
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
- [ ] Appropriate error handling
- [ ] Generic over `Real` where applicable
- [ ] Comprehensive tests with `@Test` attributes
- [ ] Edge case handling
- [ ] Performance considerations documented

---

## Related Documents

- [Master Plan](00_MASTER_PLAN.md)
- [Usage Examples](02_USAGE_EXAMPLES.md)
- [DocC Guidelines](03_DOCC_GUIDELINES.md)
- [Implementation Checklist](04_IMPLEMENTATION_CHECKLIST.md)
