# Testing (Swift Testing Framework)

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
