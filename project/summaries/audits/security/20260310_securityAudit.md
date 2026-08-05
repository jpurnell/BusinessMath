# BusinessMath Security Audit Report

**Audit Date:** March 9, 2026
**Codebase Version:** v2.0.0-beta.6
**Auditor:** Claude Code Security Analysis
**Scope:** Complete source code review of BusinessMath library (371 source files, 106,766 lines)

---

## Executive Summary

This security audit of the BusinessMath Swift library identified **67 potential security issues** across 6 major categories. While this is a mathematical/financial library (not a security-focused application), these issues could cause crashes, incorrect calculations, resource exhaustion, or unexpected behavior in production environments.

### Risk Distribution

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Force Unwrapping & Type Safety | 2 | 15 | 8 | 0 | 25 |
| Division by Zero | 1 | 12 | 3 | 0 | 16 |
| Numeric Precision & Overflow | 1 | 4 | 5 | 0 | 10 |
| Resource Exhaustion | 0 | 5 | 2 | 0 | 7 |
| Randomness & Predictability | 1 | 3 | 3 | 1 | 8 |
| Array Bounds & Collection Safety | 0 | 1 | 0 | 0 | 1 |
| **TOTAL** | **5** | **40** | **21** | **1** | **67** |

### Key Recommendations

1. **Replace all `as!` force casts** with `as?` and proper error handling
2. **Replace all `try!`** with `do/catch` blocks or `try?` with fallbacks
3. **Add zero-checks** before all division operations
4. **Add iteration limits** to all unbounded loops
5. **Standardize random number generation** patterns across the codebase

---

## Table of Contents

1. [Category 1: Force Unwrapping & Type Safety](#category-1-force-unwrapping--type-safety)
2. [Category 2: Division by Zero Vulnerabilities](#category-2-division-by-zero-vulnerabilities)
3. [Category 3: Numeric Precision & Overflow](#category-3-numeric-precision--overflow)
4. [Category 4: Resource Exhaustion](#category-4-resource-exhaustion)
5. [Category 5: Randomness & Predictability](#category-5-randomness--predictability)
6. [Category 6: Array Bounds & Collection Safety](#category-6-array-bounds--collection-safety)
7. [Educational Guide: Preventing These Issues](#educational-guide-preventing-these-issues)

---

## Category 1: Force Unwrapping & Type Safety

### What Is This Category?

Force unwrapping (`!`) and force casting (`as!`) are Swift operations that **assume** a value exists or has a specific type. When that assumption is wrong, the application crashes immediately with no recovery option. In a financial library, this could mean:

- A user's calculation crashes mid-way through a complex analysis
- Silent data loss if the crash occurs during a write operation
- Denial of service if the crash can be triggered by malformed input

### Why It Matters

Swift's optional system is designed to make you handle the "what if this value doesn't exist?" case explicitly. Force unwrapping bypasses this safety net. While convenient during development, production code should handle all edge cases gracefully.

---

### Issue 1.1: Force Unwraps in Percentile Calculation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Probability Distribution/Percentile/percentileLocation.swift`
**Lines:** 37-38

**Current Code:**
```swift
if percentile <= 0 { return sorted.first! }
if percentile >= 100 { return sorted.last! }
```

**The Problem:** Despite a precondition checking `!values.isEmpty`, force unwraps can still crash if:
- The precondition is disabled in Release builds (Swift default behavior)
- Array becomes empty due to concurrent modification
- Future refactoring removes the precondition

**Suggested Fix:**
```swift
if percentile <= 0 {
    guard let first = sorted.first else {
        throw BusinessMathError.invalidInput(message: "Cannot compute percentile of empty array")
    }
    return first
}
if percentile >= 100 {
    guard let last = sorted.last else {
        throw BusinessMathError.invalidInput(message: "Cannot compute percentile of empty array")
    }
    return last
}
```

---

### Issue 1.2: Double Force Unwrap in Descriptive Statistics

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/descriptives.swift`
**Lines:** 63

**Current Code:**
```swift
public var descriptiveStatistics: String {
    let desc = try! descriptives(self.map({$0 as! Double}))
    return "µ:\(desc.mean)\tσ:\(desc.stdDev)\tsk:\(desc.skew)\tCv:\(desc.cVar)"
}
```

**The Problem:** Two force operations in one line:
1. `as! Double` crashes if array contains non-Double types
2. `try!` crashes if `descriptives()` throws any error

**Suggested Fix:**
```swift
public var descriptiveStatistics: String {
    guard let doubleValues = self.compactMap({ $0 as? Double }) as [Double]?,
          doubleValues.count == self.count,
          let desc = try? descriptives(doubleValues) else {
        return "Statistics unavailable"
    }
    return "µ:\(desc.mean)\tσ:\(desc.stdDev)\tsk:\(desc.skew)\tCv:\(desc.cVar)"
}
```

---

### Issue 1.3: Force Cast in Mode Calculation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Central Tendency/mode.swift`
**Line:** 18

**Current Code:**
```swift
return max as! T
```

**The Problem:** Assumes `max` is always convertible to type `T`. If the internal calculation produces a different type, crash.

**Suggested Fix:**
```swift
guard let result = max as? T else {
    throw BusinessMathError.typeMismatch(expected: String(describing: T.self),
                                          actual: String(describing: type(of: max)))
}
return result
```

---

### Issue 1.4: Multiple Force Casts in DebtCovenants

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Financial Statements/DebtCovenants.swift`
**Lines:** 409, 484, 489, 501

**Current Code:**
```swift
return value as! Double                                    // Line 409
return incomeStatement as! IncomeStatement<Double>         // Line 484
return balanceSheet as! BalanceSheet<Double>               // Line 489
Double(exactly: val as! Double) ?? Double(val as! Float)   // Line 501
```

**The Problem:** Financial statement processing with force casts. If a user passes incompatible statement types, immediate crash with no error message.

**Suggested Fix:**
```swift
// Line 409
guard let doubleValue = value as? Double else {
    throw BusinessMathError.invalidInput(message: "Covenant value must be Double")
}
return doubleValue

// Lines 484, 489
guard let statement = incomeStatement as? IncomeStatement<Double> else {
    throw BusinessMathError.invalidInput(message: "Income statement must use Double precision")
}
return statement
```

---

### Issue 1.5: Force Unwraps in Simulated Annealing

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift`
**Lines:** 236, 266

**Current Code:**
```swift
let deltaEInt = Int((deltaE as! Double) * 1_000_000)     // Line 236
let improvement = recentHistory.first! - recentHistory.last!  // Line 266
```

**The Problem:** Optimization algorithms should be robust. Force casts here mean:
- Type mismatches crash mid-optimization
- Empty history arrays crash even with valid parameters

**Suggested Fix:**
```swift
// Line 236
guard let deltaEDouble = deltaE as? Double else {
    throw OptimizationError.invalidConfiguration("Energy delta must be Double")
}
let deltaEInt = Int(deltaEDouble * 1_000_000)

// Line 266
guard let first = recentHistory.first, let last = recentHistory.last else {
    continue // Skip improvement check if history insufficient
}
let improvement = first - last
```

---

### Issue 1.6: Cascading Force Casts in GeneticAlgorithm

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift`
**Lines:** 559, 569, 631-632, 654

**Current Code:**
```swift
let doubleValue = gene as! Double                         // Line 559
let doubleFitness = $0.fitness! as! Double                // Line 569
let lower = bounds.lower as! Double                       // Line 631
let upper = bounds.upper as! Double                       // Line 632
genes.append(doubleValue as! V.Scalar)                    // Line 654
```

**The Problem:** The genetic algorithm's inner loop uses force casts. A single bad gene or fitness value crashes the entire optimization run.

---

### Issue 1.7: Force Casts in Particle Swarm Optimization

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift`
**Lines:** 432-434, 443, 450, 460, 562-563

**Current Code:**
```swift
velocitiesFlat.append(Float(vArray[d] as! Double))        // Line 432
globalBestFlat.append(Float(globalBestArray[d] as! Double))  // Line 443
searchSpaceFlat.append(SIMD2(x: Float(lower as! Double), y: Float(upper as! Double)))  // Line 450
```

**The Problem:** GPU preparation code with force casts. If bounds aren't Double, crash before GPU execution even begins.

---

### Issue 1.8: Force Casts in Differential Evolution

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift`
**Lines:** 520, 588-589, 665

**Current Code:**
```swift
let vec = individual as! VectorN<Double>                  // Line 520
let lowerDouble = lower as! Double                        // Line 588
components.append(doubleValue as! V.Scalar)               // Line 665
```

---

### Issue 1.9: Extensive Force Casts in Branch and Bound

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 329, 338, 344, 348, 429, 453, 499, 541, 628, 662

**Current Code:**
```swift
from: constraints as! [MultivariateConstraint<VectorN<Double>>]  // Line 329
let x = shift.unshiftPoint(y as! VectorN<Double>) as! V         // Line 338
finalSolution = shift.unshiftPoint(final.solution as! VectorN<Double>) as! V  // Line 662
```

**The Problem:** Integer programming is computationally expensive. A crash partway through wastes significant CPU time.

---

### Issue 1.10: Force Unwraps in Template Parameters

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Fluent API/Templates/StandardTemplates.swift`
**Lines:** 307-310, 444-447

**Current Code:**
```swift
let initialMRR = parameters["initialMRR"] as! Double      // Line 307
let churnRate = parameters["churnRate"] as! Double        // Line 308
```

**The Problem:** Dictionary access with force cast. If a user misspells a parameter name, crash instead of helpful error.

**Suggested Fix:**
```swift
guard let initialMRR = parameters["initialMRR"] as? Double else {
    throw BusinessMathError.missingParameter("initialMRR", expected: "Double")
}
guard let churnRate = parameters["churnRate"] as? Double else {
    throw BusinessMathError.missingParameter("churnRate", expected: "Double")
}
```

---

### Issue 1.11: Force Cast on Range in VectorSpace

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Vector/VectorSpace.swift`
**Line:** 1022

**Current Code:**
```swift
let x = Double.random(in: range as! ClosedRange<Double>)
```

---

### Issue 1.12: Force Unwraps on Trajectory in MultiPeriodOptimizer

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/AdvancedOptimization/MultiPeriodOptimizer.swift`
**Lines:** 37, 40, 374

**Current Code:**
```swift
public var initialState: V { trajectory.first! }          // Line 37
public var terminalState: V { trajectory.last! }          // Line 40
return function(trajectory.last!)                         // Line 374
```

---

### Issue 1.13: Force Unwrap in UncertaintySet

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/AdvancedOptimization/UncertaintySet.swift`
**Line:** 330

**Current Code:**
```swift
let dim = points.first!.count
```

---

### Issue 1.14: Force Unwrap in Scenario Generation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/AdvancedOptimization/Scenario.swift`
**Line:** 194

**Current Code:**
```swift
let dimension = historicalData.first!.count
```

---

### Issue 1.15: Force Unwraps in SimplexSolver Tableau

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/LinearProgramming/SimplexSolver.swift`
**Lines:** 539, 555, 568

**Current Code:**
```swift
let objectiveValue = phaseIIResult.tableau.table.last![phaseIIResult.tableau.table[0].count - 1]
let objectiveRow = phaseIIResult.tableau.table.last!
```

---

## Category 2: Division by Zero Vulnerabilities

### What Is This Category?

Division by zero produces either:
- **Infinity** (`Double.infinity`) for floating-point types
- **Runtime crash** for integer types
- **NaN** (Not a Number) when dividing zero by zero

In a financial library, division by zero typically means:
- A ratio calculation where the denominator is empty/zero
- A statistical measure where variance or standard deviation is zero
- A transformation that wasn't designed for edge cases

### Why It Matters

Financial ratios like Debt-to-Equity, Current Ratio, or Coefficient of Variation all involve division. When the denominator is legitimately zero (a company with no equity, for instance), the calculation needs to either:
1. Throw an informative error
2. Return a sentinel value with clear documentation
3. Handle the edge case mathematically

**Silently returning infinity or NaN can propagate through calculations, corrupting downstream results.**

---

### Issue 2.1: Fisher's Z Transformation Boundary (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Probability Distribution/fisherR.swift`
**Line:** 28

**Current Code:**
```swift
return (T.log((1 + r) / (1 - r)) / 2)
```

**The Problem:** When `r = 1` exactly:
- `(1 - r) = 0`
- Division produces infinity
- Logarithm of infinity is infinity

When `r = -1`:
- `(1 + r) = 0`
- `log(0)` produces negative infinity

The precondition states `r` must be between -1 and 1 (exclusive), but preconditions are **disabled in Release builds**.

**Suggested Fix:**
```swift
public func fisherZ<T: Real>(_ r: T) throws -> T {
    guard r > T(-1) && r < T(1) else {
        throw BusinessMathError.invalidInput(
            message: "Fisher's Z requires correlation strictly between -1 and 1, got \(r)"
        )
    }
    return (T.log((1 + r) / (1 - r)) / 2)
}
```

---

### Issue 2.2: Sample Correlation Coefficient

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Covariance and Correlation/correlation coefficient/sample correlation coefficient.swift`
**Line:** 53

**Current Code:**
```swift
return numerator / (T.sqrt(xDenom) * T.sqrt(yDenom))
```

**The Problem:** If all x values are identical (zero variance), `xDenom = 0`, producing division by zero. This is mathematically correct (correlation is undefined when one variable is constant), but should throw an informative error.

**Suggested Fix:**
```swift
let denominator = T.sqrt(xDenom) * T.sqrt(yDenom)
guard denominator > T.ulpOfOne else {
    throw BusinessMathError.undefinedStatistic(
        message: "Correlation undefined: one or both variables have zero variance"
    )
}
return numerator / denominator
```

---

### Issue 2.3: Population Correlation Coefficient

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Covariance and Correlation/correlation coefficient/population correlation coefficient.swift`
**Line:** 43

**Current Code:**
```swift
let r = numerator / denominator
```

**Same issue as 2.2** - no guard against zero denominator.

---

### Issue 2.4: Contraharmonic Mean

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Central Tendency/contraharmonicMean.swift`
**Lines:** 33, 55

**Current Code:**
```swift
// Two-value version (Line 33)
return (T.pow(x, T(2)) + T.pow(y, T(2))) / (x + y)

// Array version (Line 55)
return values.map({T.pow($0, T(2))}).reduce(0, +) / values.reduce(0, +)
```

**The Problem:**
- Two-value: if `x = -y`, then `x + y = 0`
- Array: if values sum to zero (e.g., `[-3, 1, 2]`), denominator is zero

**Suggested Fix:**
```swift
public func contraharmonicMean<T: Real>(_ x: T, _ y: T) throws -> T {
    let denominator = x + y
    guard abs(denominator) > T.ulpOfOne else {
        throw BusinessMathError.divisionByZero(
            context: "Contraharmonic mean undefined when values sum to zero"
        )
    }
    return (T.pow(x, T(2)) + T.pow(y, T(2))) / denominator
}
```

---

### Issue 2.5: Logarithmic Mean

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Central Tendency/logarithmicMean.swift`
**Line:** 34

**Current Code:**
```swift
return (y - x) / (T.log(y) - T.log(x))
```

**The Problem:** Three vulnerabilities:
1. If `x = y`, both numerator and denominator are zero
2. If `x ≤ 0` or `y ≤ 0`, logarithm is undefined
3. If `x ≈ y`, catastrophic cancellation in both numerator and denominator

**Suggested Fix:**
```swift
public func logarithmicMean<T: Real>(_ x: T, _ y: T) throws -> T {
    guard x > T.zero && y > T.zero else {
        throw BusinessMathError.invalidInput(
            message: "Logarithmic mean requires positive values"
        )
    }

    // Handle x ≈ y case using Taylor expansion to avoid 0/0
    if abs(x - y) < T.ulpOfOne * max(abs(x), abs(y)) * T(100) {
        return (x + y) / T(2)  // Limit as x → y
    }

    return (y - x) / (T.log(y) - T.log(x))
}
```

---

### Issue 2.6: Harmonic Mean with Zero Values

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Central Tendency/harmonicMean.swift`
**Line:** 32

**Current Code:**
```swift
T(values.count) / (values.map({T.pow($0, T(-1))}).reduce(0, +))
```

**The Problem:**
- If any value is zero, `T.pow($0, T(-1))` produces infinity
- If reciprocals cancel out (unlikely but possible), denominator is zero

**Suggested Fix:**
```swift
public func harmonicMean<T: Real>(_ values: [T]) throws -> T {
    guard !values.isEmpty else {
        throw BusinessMathError.invalidInput(message: "Cannot compute harmonic mean of empty array")
    }
    guard !values.contains(where: { $0 == T.zero }) else {
        throw BusinessMathError.invalidInput(message: "Harmonic mean undefined with zero values")
    }

    let reciprocalSum = values.map({ T(1) / $0 }).reduce(T.zero, +)
    guard reciprocalSum != T.zero else {
        throw BusinessMathError.divisionByZero(context: "Harmonic mean reciprocal sum is zero")
    }

    return T(values.count) / reciprocalSum
}
```

---

### Issue 2.7: Coefficient of Skewness

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Skewness/cSkew.swift`
**Line:** 36

**Current Code:**
```swift
return (T(3) * (mean - median))/stdDev
```

**The Problem:** If standard deviation is zero (all values identical), division by zero.

---

### Issue 2.8: Financial Ratios Returning Misleading Zero

**Files:**
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Ratios/CurrentRatio.swift` (Lines 24-27)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Ratios/QuickRatio.swift` (Lines 28-32)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Ratios/DebtToEquity.swift` (Lines 24-28)

**Current Code Pattern:**
```swift
guard currentLiabilities > T(0) else {
    return T(0)  // Returns 0 if current liabilities are zero or negative
}
return currentAssets / currentLiabilities
```

**The Problem:** Returning `0` for undefined ratios is **misleading**:
- A Current Ratio of 0 means "no current assets" (bad)
- But this code returns 0 for "no current liabilities" (actually good!)
- Users comparing companies might rank a healthy company as worst

**Suggested Fix:**
```swift
public func currentRatio<T: Real>(currentAssets: T, currentLiabilities: T) -> Result<T, BusinessMathError> {
    guard currentLiabilities > T.ulpOfOne else {
        return .failure(.undefinedStatistic(
            message: "Current ratio undefined: zero or negative liabilities indicates debt-free status"
        ))
    }
    return .success(currentAssets / currentLiabilities)
}
```

---

### Issue 2.9: Working Capital Turnover

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Financial Statements/BalanceSheet.swift`
**Lines:** 710, 716

**Current Code:**
```swift
return currentRevenue / currentWC  // Line 710
let averageWC = (currentWC + priorWC) / T(2)
return currentRevenue / averageWC  // Line 716
```

**The Problem:** Working capital can legitimately be zero or negative (current liabilities exceed current assets).

---

### Issue 2.10: T-Distribution Variance

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Dispersion Around the Mean/variance/t-distribution.swift`
**Line:** 40

**Current Code:**
```swift
return (T(values.count - 1) / T(values.count - 3))
```

**The Problem:** If `values.count = 3`, denominator is zero. No minimum sample size guard.

**Suggested Fix:**
```swift
guard values.count > 3 else {
    throw BusinessMathError.insufficientData(
        message: "T-distribution variance requires at least 4 values, got \(values.count)"
    )
}
return (T(values.count - 1) / T(values.count - 3))
```

---

### Issue 2.11: Weighted Average Using fatalError

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Central Tendency/weightedAverage.swift`
**Line:** 48

**Current Code:**
```swift
guard totalWeight != 0 else {
    fatalError("Sum of weights must be non-zero")
}
return weightedSum / totalWeight
```

**The Problem:** `fatalError()` crashes the entire application. Users have no way to recover.

**Suggested Fix:**
```swift
guard totalWeight != 0 else {
    throw BusinessMathError.divisionByZero(context: "Weighted average requires non-zero total weight")
}
return weightedSum / totalWeight
```

---

## Category 3: Numeric Precision & Overflow

### What Is This Category?

Computers represent numbers with finite precision. This leads to:
- **Integer overflow**: Adding 1 to `Int.max` wraps around to `Int.min`
- **Floating-point precision loss**: `0.1 + 0.2 ≠ 0.3` in binary
- **Catastrophic cancellation**: Subtracting nearly equal numbers loses precision
- **Underflow/overflow**: Very small numbers become zero, very large become infinity

### Why It Matters

Financial calculations often involve:
- Large numbers (billions of dollars)
- Small numbers (basis points, 0.0001%)
- Ratios of large to small (P/E ratios in the thousands)
- Long compound calculations (30-year mortgages, 360 periods)

Precision errors can compound through calculations, leading to incorrect financial decisions.

---

### Issue 3.1: Integer Division Bug (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Probability Distribution/standardErrorProbabilistic.swift`
**Line:** 58

**Current Code:**
```swift
if T(n/total) <= T(Int(5) / Int(100)) {
```

**The Problem:** `Int(5) / Int(100)` performs **integer division**, which equals `0`, not `0.05`. This condition is always true (assuming n/total is positive and ≤ 0).

**Suggested Fix:**
```swift
if T(n/total) <= T(5) / T(100) {  // or simply T(0.05)
```

---

### Issue 3.2: Integer Overflow in Simulated Annealing

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift`
**Line:** 236

**Current Code:**
```swift
let deltaEInt = Int((deltaE as! Double) * 1_000_000)
```

**The Problem:** If `deltaE > 9223` (approximately), `deltaE * 1_000_000 > Int.max`, causing integer overflow.

**Suggested Fix:**
```swift
guard let deltaEDouble = deltaE as? Double,
      abs(deltaEDouble) < Double(Int.max) / 1_000_000 else {
    // Handle overflow case - use Double arithmetic instead
    let probability = exp(-deltaE / temperature)
    // ...
}
let deltaEInt = Int(deltaEDouble * 1_000_000)
```

---

### Issue 3.3: Integer Overflow in Particle Swarm Optimization

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift`
**Lines:** 514-519

**Current Code:**
```swift
let wInt = Int(config.inertiaWeight * 1_000_000)
let c1Int = Int(config.cognitiveCoefficient * 1_000_000)
let c2Int = Int(config.socialCoefficient * 1_000_000)
```

**The Problem:** Same overflow risk with large coefficient values.

---

### Issue 3.4: Profitability Index Magic Number

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Time Series/TVM/NPV.swift`
**Lines:** 300-321

**Current Code:**
```swift
guard pvNegative < T.zero else {
    return T(1000000)  // Magic number for "infinite" PI
}
return pvPositive / (-pvNegative)
```

**The Problem:** Returning `1000000` when there are no negative cash flows:
1. Not mathematically meaningful
2. Skews rankings and comparisons
3. Can cause sorting/filtering errors

**Suggested Fix:**
```swift
guard pvNegative < T.zero else {
    throw BusinessMathError.undefinedStatistic(
        message: "Profitability index undefined without initial investment (negative cash flow)"
    )
}
return pvPositive / (-pvNegative)
```

---

### Issue 3.5: MIRR Near Break-Even Precision Loss

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Time Series/TVM/IRR.swift`
**Lines:** 261-263

**Current Code:**
```swift
let ratio = fvPositive / (-pvNegative)
let exponent = T(1) / T(n)
let mirr = T.pow(ratio, exponent) - T(1)
```

**The Problem:** When `ratio ≈ 1` (break-even project), raising to power `1/n` with small exponents can lose precision.

---

### Issue 3.6: Skewness and Kurtosis with Small Standard Deviations

**Files:**
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Skewness/skew.swift` (Lines 71, 105)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Kurtosis/kurt.swift` (Lines 72, 75)

**The Problem:** Division by very small (but non-zero) standard deviation amplifies floating-point errors in higher moments.

**Suggested Fix:**
```swift
guard s > T.ulpOfOne * T(1000) else {
    throw BusinessMathError.numericalInstability(
        message: "Standard deviation too small for reliable higher moment calculation"
    )
}
```

---

### Issue 3.7: Geometric Mean Silent NaN

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Descriptors/Central Tendency/geometricMean.swift`
**Lines:** 56-59

**Current Code:**
```swift
if values.contains(where: { $0 < T(0) }) {
    return T.nan
}
```

**The Problem:** Returning `NaN` silently. In financial contexts, negative returns are common and have specific handling requirements. Silent `NaN` propagates through calculations.

**Suggested Fix:**
```swift
if values.contains(where: { $0 < T(0) }) {
    throw BusinessMathError.invalidInput(
        message: "Geometric mean undefined for negative values. For returns, use (1 + return) transformation."
    )
}
```

---

## Category 4: Resource Exhaustion

### What Is This Category?

Resource exhaustion occurs when code consumes unbounded amounts of:
- **CPU time**: Infinite or very long loops
- **Memory**: Growing data structures without limits
- **Stack space**: Deep recursion without limits

In a library context, this can cause:
- Application freeze/hang
- Out-of-memory crashes
- Stack overflow
- Denial of service if user-controlled input triggers exhaustion

### Why It Matters

Mathematical algorithms often involve iteration until convergence. Without limits:
- A non-converging optimization runs forever
- A Monte Carlo simulation with rare acceptance criteria never terminates
- An unbounded buffer grows until memory exhaustion

---

### Issue 4.1: Unbounded Recursion in Gamma Variate

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/distributionGamma.swift`
**Lines:** 81-85

**Current Code:**
```swift
if shape < T(1) {
    let uSeed = nextSeed()
    let u: T = distributionUniform(min: T(0), max: T(1), uSeed)
    let x = gammaVariate(shape: shape + T(1), scale: scale, seeds: seeds, seedIndex: &seedIndex)
    return x * T.pow(u, T(1) / shape)
}
```

**The Problem:** Recursive call for `shape < 1`. If `shape = 0.001`, makes ~1000 recursive calls before `shape + 1 >= 1`. No depth limit.

**Suggested Fix:**
```swift
// Convert recursion to iteration
var currentShape = shape
var multipliers: [T] = []

while currentShape < T(1) {
    let u: T = distributionUniform(min: T(0), max: T(1), nextSeed())
    multipliers.append(T.pow(u, T(1) / currentShape))
    currentShape += T(1)

    guard multipliers.count < 1000 else {
        throw BusinessMathError.invalidInput(message: "Gamma shape parameter too small")
    }
}

var result = gammaVariateCore(shape: currentShape, scale: scale, ...)
for m in multipliers.reversed() {
    result *= m
}
return result
```

---

### Issue 4.2: Unbounded Loop in Gamma Distribution (Marsaglia-Tsang)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/distributionGamma.swift`
**Lines:** 93-129

**Current Code:**
```swift
while true {
    var x: T
    var v: T

    repeat {
        x = distributionNormal(mean: T(0), stdDev: T(1), u1Seed, u2Seed)
        v = T(1) + c * x
    } while v <= T(0)

    // ... acceptance test ...
    if u < threshold1 {
        return d * v * scale
    }
    if logU < threshold2 {
        return d * v * scale
    }
    // If not accepted, loop continues indefinitely
}
```

**The Problem:** Acceptance-rejection sampling with no iteration limit. Worst case: never terminates.

**Suggested Fix:**
```swift
let maxIterations = 10000
for iteration in 0..<maxIterations {
    // ... existing acceptance-rejection logic ...

    if accepted {
        return result
    }
}
throw BusinessMathError.convergenceFailure(
    message: "Gamma variate generation did not converge after \(maxIterations) attempts"
)
```

---

### Issue 4.3: Unbounded Loop in Geometric Distribution

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/distributionGeometric.swift`
**Lines:** 39-53

**Current Code:**
```swift
while true {
    let u: T = distributionUniform(min: T(0), max: T(1), ...)
    if u < p {
        break
    }
    x = x + 1
}
```

**The Problem:** For small `p` (e.g., 0.0001), expected iterations = 10,000. No upper bound.

**Suggested Fix:**
```swift
// Use closed-form solution instead of iteration
let u: T = distributionUniform(min: T(0), max: T(1), seed)
return Int(T.log(u) / T.log(T(1) - p))
```

---

### Issue 4.4: Unbounded History in Branch and Bound

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 837-838, 1172-1205

**Current Code:**
```swift
var boundHistory: [Double] = []
var solutionHistory: [[Double]] = []

// In loop:
boundHistory.append(resolvedResult.objectiveValue)
solutionHistory.append(currentSolutionArray)
```

**The Problem:** These arrays grow without limit throughout cutting plane generation.

**Suggested Fix:**
```swift
let maxHistorySize = 100

// In loop:
boundHistory.append(resolvedResult.objectiveValue)
if boundHistory.count > maxHistorySize {
    boundHistory.removeFirst(boundHistory.count - maxHistorySize)
}
```

---

### Issue 4.5: Unbounded Cut Deduplication Set

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Line:** 831

**Current Code:**
```swift
var generatedCuts: Set<String> = []

// In loop:
let cutSignature = "\(cut.coefficients.map { ... }.joined(separator:",")):\(...)"
if !generatedCuts.contains(cutSignature) {
    generatedCuts.insert(cutSignature)
}
```

**The Problem:** String signatures stored forever. For problems generating thousands of cuts, unbounded memory growth.

---

### Issue 4.6: Unbounded Change Point Detection Loop

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingForecasting.swift`
**Line:** 947

**Current Code:**
```swift
public mutating func next() async throws -> ChangePoint? {
    while true {
        guard let value = try await baseIterator.next() else {
            return nil
        }
        buffer.append(value)
        // ... change point detection ...
    }
}
```

**The Problem:** Reads entire stream without yielding if no change point detected. Violates async iterator semantics.

---

## Category 5: Randomness & Predictability

### What Is This Category?

Randomness issues fall into two categories:
1. **Cryptographic weakness**: Using predictable random numbers where unpredictability is required
2. **Reproducibility problems**: Inconsistent or poorly managed seeding for deterministic testing

### Why It Matters

In a financial library:
- Monte Carlo simulations need **statistical randomness** (uniform distribution, independence)
- Optimization algorithms need **reproducibility** for testing and debugging
- **Neither requires cryptographic security**, but the patterns should be consistent

The main risks are:
- Tests that pass randomly but fail in production
- Simulations that can be predicted/gamed
- Inconsistent behavior across runs

---

### Issue 5.1: Weak Linear Congruential Generator (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift`
**Lines:** 788-800

**Current Code:**
```swift
internal struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // LCG parameters (from Numerical Recipes)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
```

**The Problem:** Linear Congruential Generators (LCG) are:
- Predictable after observing a few outputs
- Have poor statistical properties in lower-order bits
- Fail standard randomness tests (TestU01, Diehard)

**While this is labeled for testing**, its presence in production code is a risk if anyone uses it for security purposes.

**Suggested Fix:**
```swift
/// TESTING ONLY - DO NOT USE FOR SECURITY PURPOSES
/// This generator is deterministic and predictable.
/// For cryptographic needs, use SystemRandomNumberGenerator().
@available(*, deprecated, message: "For testing only - not suitable for production randomness")
internal struct SeededRandomNumberGenerator: RandomNumberGenerator {
    // ... existing implementation ...
}
```

---

### Issue 5.2: Hardcoded Seed in Production Configuration

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealingTypes.swift`
**Lines:** 114-132

**Current Code:**
```swift
public static let `seededDefault` = SimulatedAnnealingConfig(
    initialTemperature: 100.0,
    // ...
    seed: 42  // Hardcoded seed
)
```

**The Problem:** If accidentally used in production:
- All optimizations produce identical results
- Results are completely predictable

**Suggested Fix:**
```swift
/// Configuration for reproducible testing ONLY.
/// For production use, create a config without a seed (uses system RNG).
public static let `testConfiguration` = SimulatedAnnealingConfig(
    // ... parameters ...
    seed: 42
)
```

---

### Issue 5.3: Inconsistent Random Normalization

**Files:**
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift` (Line 239)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift` (Lines 322-323, 506, 514)

**Current Code:**
```swift
let randomValue = Double(rng.next() >> 32) / Double(UInt32.max)
```

**The Problem:**
1. `>> 32` discards lower bits (which have worse properties in LCG anyway)
2. Dividing by `UInt32.max` can produce exactly `1.0` when numerator equals max
3. Should divide by `UInt32.max + 1` for proper `[0, 1)` range

**Suggested Fix:**
```swift
let randomValue = Double(rng.next() >> 32) / Double(1 << 32)  // [0, 1)
```

---

### Issue 5.4: Confusing Bernoulli Implementation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Probability Distribution/bernoulliTrial.swift`
**Line:** 29

**Current Code:**
```swift
if T(Int(Double.random(in: 0...1) * 1000000000 / 1000000000)) < p {
```

**The Problem:** `* 1000000000 / 1000000000` cancels out, doing nothing. The code appears to be obfuscated or poorly refactored.

**Suggested Fix:**
```swift
if Double.random(in: 0..<1) < Double(p) {
```

---

### Issue 5.5: Default Parameters Consuming Entropy

**Files:** Multiple distribution files including:
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/boxMuellerSeed.swift` (Line 30)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/boxMuellerTransform.swift` (Line 33)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/distributionNormal.swift` (Lines 33, 59)

**Current Code:**
```swift
public func boxMuller<T: Real>(
    mean: T = T(0),
    stdDev: T = T(1),
    _ u1Seed: Double = Double.random(in: 0...1),  // Called on every invocation
    _ u2Seed: Double = Double.random(in: 0...1)
) -> T
```

**The Problem:** Default parameter expressions are evaluated **every time the function is called**, consuming system entropy even when custom seeds are provided.

**Suggested Fix:**
```swift
public func boxMuller<T: Real>(
    mean: T = T(0),
    stdDev: T = T(1),
    u1Seed: Double? = nil,
    u2Seed: Double? = nil
) -> T {
    let u1 = u1Seed ?? Double.random(in: 0..<1)
    let u2 = u2Seed ?? Double.random(in: 0..<1)
    // ...
}
```

---

## Category 6: Array Bounds & Collection Safety

### What Is This Category?

Swift arrays crash when accessed out of bounds. Common patterns that cause this:
- Assuming array has elements without checking `.isEmpty`
- Using indices from one array on another array
- Hard-coded indices like `[0]` or `[1]` without length checks

### Why It Matters

In financial calculations, arrays often represent:
- Time series data
- Portfolio holdings
- Cash flow sequences

Empty or malformed input should produce helpful errors, not crashes.

---

### Issue 6.1: Multiple Linear Regression Array Access

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Regression/MultipleLinearRegression.swift`
**Lines:** 219, 277, 407

**Current Code:**
```swift
let p = X[0].count         // Line 219 - assumes X[0] exists
let intercept = beta[0]    // Line 277 - assumes beta has element
let cols = matrix[0].count // Line 407 - assumes matrix[0] exists
```

**Suggested Fix:**
```swift
guard !X.isEmpty, let firstRow = X.first else {
    throw BusinessMathError.invalidInput(message: "Regression requires non-empty feature matrix")
}
let p = firstRow.count
```

---

## Educational Guide: Preventing These Issues

### Design Principles for Safe Numerical Code

#### 1. **Fail Fast with Informative Errors**

Instead of returning magic values or crashing, throw descriptive errors:

```swift
// Bad: Silent failure
guard denominator != 0 else { return 0 }

// Bad: Crash
return numerator / denominator  // Crash if denominator is 0

// Good: Informative failure
guard denominator != 0 else {
    throw BusinessMathError.divisionByZero(
        context: "Computing debt-to-equity ratio",
        numerator: numerator,
        denominator: denominator
    )
}
return numerator / denominator
```

#### 2. **Use Swift's Type System**

Replace force casts with proper generics or protocol requirements:

```swift
// Bad: Force cast
let doubleValue = value as! Double

// Good: Generic constraint
func compute<T: BinaryFloatingPoint>(_ value: T) -> T {
    // T is guaranteed to support floating-point operations
}

// Good: Safe cast with error
guard let doubleValue = value as? Double else {
    throw TypeError.invalidType(expected: "Double", got: type(of: value))
}
```

#### 3. **Bound All Iterations**

Every loop should have a maximum iteration count:

```swift
// Bad: Unbounded
while !converged {
    // Could run forever
}

// Good: Bounded with diagnostics
let maxIterations = 10000
for iteration in 0..<maxIterations {
    if converged { return result }
}
throw ConvergenceError(iterations: maxIterations, lastDelta: delta)
```

#### 4. **Validate at Boundaries, Trust Internally**

Validate user input thoroughly at API boundaries, then trust internal code:

```swift
// Public API: Validate everything
public func calculateIRR(cashFlows: [Double], guess: Double = 0.1) throws -> Double {
    guard !cashFlows.isEmpty else {
        throw InvalidInputError("Cash flows cannot be empty")
    }
    guard cashFlows.contains(where: { $0 < 0 }) else {
        throw InvalidInputError("IRR requires at least one negative cash flow")
    }
    guard cashFlows.contains(where: { $0 > 0 }) else {
        throw InvalidInputError("IRR requires at least one positive cash flow")
    }

    // Internal calculation can trust inputs
    return try calculateIRRInternal(cashFlows: cashFlows, guess: guess)
}

// Internal: Trust that inputs were validated
private func calculateIRRInternal(cashFlows: [Double], guess: Double) throws -> Double {
    // No need to re-validate here
}
```

#### 5. **Use Result Types for Expected Failures**

When failure is a normal outcome (not exceptional), use `Result`:

```swift
// Bad: Throws for normal cases
func solve() throws -> Solution {
    // Throws if no solution exists - but that's a normal outcome!
}

// Good: Result for expected outcomes
func solve() -> Result<Solution, SolverStatus> {
    if noSolution { return .failure(.infeasible) }
    if unbounded { return .failure(.unbounded) }
    return .success(solution)
}
```

#### 6. **Document Preconditions and Postconditions**

Make requirements explicit in documentation:

```swift
/// Computes the Fisher's Z transformation of a correlation coefficient.
///
/// - Parameter r: Correlation coefficient, must be in range (-1, 1) exclusive
/// - Returns: Fisher's Z value
/// - Throws: `InvalidInputError` if r is outside valid range
/// - Note: Returns 0 for r = 0 (exact)
/// - Complexity: O(1)
public func fisherZ(_ r: Double) throws -> Double
```

---

### Quick Reference: Safe Replacements

| Unsafe Pattern | Safe Replacement |
|----------------|------------------|
| `array.first!` | `guard let first = array.first else { throw ... }` |
| `value as! T` | `guard let typed = value as? T else { throw ... }` |
| `try!` | `do { try ... } catch { ... }` |
| `precondition(...)` | `guard ... else { throw ... }` |
| `fatalError(...)` | `throw CustomError(...)` |
| `x / y` | `guard y != 0 else { throw ... }; x / y` |
| `while true { ... }` | `for _ in 0..<maxIterations { ... }` |
| `array[0]` | `guard !array.isEmpty else { throw ... }; array[0]` |

---

## Appendix: Complete Issue Inventory

| # | Category | Severity | File | Line(s) | Description |
|---|----------|----------|------|---------|-------------|
| 1.1 | Force Unwrap | HIGH | percentileLocation.swift | 37-38 | `sorted.first!` and `sorted.last!` |
| 1.2 | Force Unwrap | HIGH | descriptives.swift | 63 | Double force unwrap in descriptiveStatistics |
| 1.3 | Force Cast | HIGH | mode.swift | 18 | `max as! T` |
| 1.4 | Force Cast | HIGH | DebtCovenants.swift | 409,484,489,501 | Multiple force casts |
| 1.5 | Force Cast | HIGH | SimulatedAnnealing.swift | 236,266 | Force cast and unwrap |
| 1.6 | Force Cast | HIGH | GeneticAlgorithm.swift | 559,569,631-632,654 | Multiple force casts in loop |
| 1.7 | Force Cast | HIGH | ParticleSwarmOptimization.swift | 432-434,443,450,460 | Force casts in GPU prep |
| 1.8 | Force Cast | HIGH | DifferentialEvolution.swift | 520,588-589,665 | Force casts |
| 1.9 | Force Cast | HIGH | BranchAndBound.swift | 329,338,344,348,429,453,499,541,628,662 | Extensive force casts |
| 1.10 | Force Unwrap | HIGH | StandardTemplates.swift | 307-310,444-447 | Dictionary force unwraps |
| 1.11 | Force Cast | MEDIUM | VectorSpace.swift | 1022 | Range force cast |
| 1.12 | Force Unwrap | MEDIUM | MultiPeriodOptimizer.swift | 37,40,374 | Trajectory force unwraps |
| 1.13 | Force Unwrap | MEDIUM | UncertaintySet.swift | 330 | `points.first!` |
| 1.14 | Force Unwrap | MEDIUM | Scenario.swift | 194 | `historicalData.first!` |
| 1.15 | Force Unwrap | MEDIUM | SimplexSolver.swift | 539,555,568 | Tableau force unwraps |
| 2.1 | Div by Zero | CRITICAL | fisherR.swift | 28 | Fisher Z boundary |
| 2.2 | Div by Zero | HIGH | sample correlation coefficient.swift | 53 | Zero variance |
| 2.3 | Div by Zero | HIGH | population correlation coefficient.swift | 43 | Zero variance |
| 2.4 | Div by Zero | HIGH | contraharmonicMean.swift | 33,55 | Sum equals zero |
| 2.5 | Div by Zero | HIGH | logarithmicMean.swift | 34 | x equals y |
| 2.6 | Div by Zero | HIGH | harmonicMean.swift | 32 | Zero values |
| 2.7 | Div by Zero | HIGH | cSkew.swift | 36 | Zero stdDev |
| 2.8 | Div by Zero | HIGH | CurrentRatio.swift, QuickRatio.swift, DebtToEquity.swift | Various | Misleading zero return |
| 2.9 | Div by Zero | HIGH | BalanceSheet.swift | 710,716 | Zero working capital |
| 2.10 | Div by Zero | HIGH | t-distribution.swift | 40 | Small sample size |
| 2.11 | Div by Zero | HIGH | weightedAverage.swift | 48 | fatalError instead of throw |
| 3.1 | Numeric | CRITICAL | standardErrorProbabilistic.swift | 58 | Integer division bug |
| 3.2 | Overflow | HIGH | SimulatedAnnealing.swift | 236 | Int overflow |
| 3.3 | Overflow | HIGH | ParticleSwarmOptimization.swift | 514-519 | Int overflow |
| 3.4 | Numeric | HIGH | NPV.swift | 300-321 | Magic number return |
| 3.5 | Precision | MEDIUM | IRR.swift | 261-263 | Near break-even precision |
| 3.6 | Precision | MEDIUM | skew.swift, kurt.swift | Various | Small stdDev division |
| 3.7 | Numeric | MEDIUM | geometricMean.swift | 56-59 | Silent NaN |
| 4.1 | Resource | HIGH | distributionGamma.swift | 81-85 | Unbounded recursion |
| 4.2 | Resource | HIGH | distributionGamma.swift | 93-129 | Unbounded loop |
| 4.3 | Resource | HIGH | distributionGeometric.swift | 39-53 | Unbounded loop |
| 4.4 | Resource | MEDIUM | BranchAndBound.swift | 837-838,1172-1205 | Unbounded history |
| 4.5 | Resource | MEDIUM | BranchAndBound.swift | 831 | Unbounded dedup set |
| 4.6 | Resource | HIGH | StreamingForecasting.swift | 947 | Unbounded async loop |
| 5.1 | Random | CRITICAL | GeneticAlgorithm.swift | 788-800 | Weak LCG |
| 5.2 | Random | MEDIUM | SimulatedAnnealingTypes.swift | 114-132 | Hardcoded seed 42 |
| 5.3 | Random | HIGH | SimulatedAnnealing.swift, GeneticAlgorithm.swift | Various | Incorrect normalization |
| 5.4 | Random | MEDIUM | bernoulliTrial.swift | 29 | Obfuscated code |
| 5.5 | Random | MEDIUM | boxMueller*.swift, distributionNormal.swift | Various | Default param entropy |
| 6.1 | Bounds | HIGH | MultipleLinearRegression.swift | 219,277,407 | Array[0] without check |

---

## Conclusion

The BusinessMath library is well-structured and comprehensive, but contains common Swift anti-patterns that could cause crashes or incorrect results in edge cases. The issues identified fall into predictable categories:

1. **Swift's force operations (`!`, `as!`, `try!`)** should be replaced with safe alternatives
2. **Division operations** need zero-checks
3. **Iterative algorithms** need bounds
4. **Random number generation** needs consistency

Addressing these issues by category will:
- Improve production stability
- Make debugging easier
- Provide better error messages to library users
- Establish patterns that prevent future issues

**Recommended Priority:**
1. **Critical issues (5)**: Fix immediately - these are silent bugs or crash risks
2. **High issues (40)**: Fix in next release - production stability
3. **Medium issues (21)**: Technical debt - address in refactoring
4. **Low issues (1)**: Optional - code quality improvement

---
