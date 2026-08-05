# Phase 7 Feature 2: Adaptive Algorithm Selection - COMPLETE ✅

**Completed:** 2025-12-04
**Status:** All tests passing (12/12) ✅

---

## Overview

The Adaptive Optimizer automatically selects the best optimization algorithm and parameters based on problem characteristics, eliminating the need for users to manually choose between different optimizers.

**Key Innovation:** Combines intelligent algorithm selection with adaptive parameter tuning for optimal performance across problem sizes and types.

---

## Feature Summary

**Files:**
- `Sources/BusinessMath/Optimization/AdaptiveOptimizer.swift` (~345 lines)
- `Tests/BusinessMathTests/Performance Tests/AdaptiveOptimizerTests.swift` (~257 lines)

**Tests:** 12/12 passing (100%) ✅

**What it does:**
- Automatically selects the best algorithm based on:
  - Constraint types (inequality, equality, unconstrained)
  - Problem size (very small, medium, large)
  - Gradient availability
  - User preferences (speed vs accuracy)
- Adapts learning rates to problem size
- Provides transparency through result reporting

---

## Algorithm Selection Rules

### Decision Tree

```
1. Has inequality constraints? → InequalityOptimizer
2. Has equality constraints? → ConstrainedOptimizer
3. Large problem (>100 vars)? → Gradient Descent (higher learning rate)
4. Prefer accuracy + small? → Newton-Raphson
5. Very small (≤5 vars) + not prefer speed? → Newton-Raphson
6. Default → Gradient Descent (conservative learning rate)
```

### Selection Matrix

| Problem Type | Size | Preference | Algorithm | Reason |
|--------------|------|------------|-----------|--------|
| Inequality constraints | Any | Any | Inequality Optimizer | Penalty-barrier method |
| Equality constraints | Any | Any | Constrained Optimizer | Augmented Lagrangian |
| Unconstrained | >100 | Any | Gradient Descent | Memory efficient |
| Unconstrained | <10 | Accuracy | Newton-Raphson | Accuracy preference |
| Unconstrained | ≤5 | Default | Newton-Raphson | Fast convergence |
| Unconstrained | ≤5 | Speed | Gradient Descent | Speed preference |
| Unconstrained | Other | Default | Gradient Descent | Best balance |

---

## Adaptive Learning Rates

The optimizer automatically adjusts learning rates based on problem size:

### Large Problems (>100 variables)
- **Default:** 0.01 (faster convergence)
- **preferSpeed:** 0.05 (even faster)
- **Rationale:** Large problems can handle higher rates without instability

### Small Problems (≤100 variables)
- **Default:** 0.001 (more stable)
- **preferSpeed:** 0.01 (moderate)
- **Rationale:** Small problems need conservative rates for difficult functions (e.g., Rosenbrock)

---

## API Design

### Basic Usage

```swift
let optimizer = AdaptiveOptimizer<VectorN<Double>>()

let result = try optimizer.optimize(
    objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
    initialGuess: VectorN([0.0, 0.0])
)

print("Solution: \(result.solution)")
print("Algorithm used: \(result.algorithmUsed)")
print("Selection reason: \(result.selectionReason)")
```

### With Preferences

```swift
// Prefer accuracy
let accurateOptimizer = AdaptiveOptimizer<VectorN<Double>>(
    preferAccuracy: true
)

// Prefer speed
let fastOptimizer = AdaptiveOptimizer<VectorN<Double>>(
    preferSpeed: true
)

// Custom tolerance
let preciseOptimizer = AdaptiveOptimizer<VectorN<Double>>(
    tolerance: 1e-8,
    maxIterations: 5000
)
```

### With Constraints

```swift
let result = try optimizer.optimize(
    objective: portfolioVariance,
    initialGuess: equalWeights,
    constraints: [
        .equality(function: { x in x.toArray().reduce(0, +) - 1.0 }, gradient: nil),
        .inequality(function: { x in -x[0] }, gradient: nil)  // x[0] >= 0
    ]
)

// Automatically selects InequalityOptimizer due to inequality constraint
print(result.algorithmUsed)  // "Inequality Optimizer"
```

---

## Result Structure

```swift
public struct Result {
    public let solution: V                    // Optimal solution
    public let objectiveValue: V.Scalar       // Objective at solution
    public let algorithmUsed: String          // Name of algorithm selected
    public let selectionReason: String        // Why this algorithm was chosen
    public let iterations: Int                // Number of iterations
    public let converged: Bool                // Whether optimization converged
    public let constraintViolation: V.Scalar? // Constraint violation (if applicable)
}
```

---

## Test Coverage

### Algorithm Selection Tests (5 tests)

1. **testInequalityConstraintSelection** ✅
   - Problem: 2D with inequality constraints
   - Expected: Inequality Optimizer
   - Result: ✅ Correct selection

2. **testEqualityConstraintSelection** ✅
   - Problem: 2D with equality constraint
   - Expected: Constrained Optimizer
   - Result: ✅ Correct selection

3. **testLargeProblemSelection** ✅
   - Problem: 150D unconstrained
   - Expected: Gradient Descent
   - Result: ✅ Converges with adaptive learning rate (0.01)

4. **testSmallUnconstrainedSelection** ✅
   - Problem: 2D unconstrained
   - Expected: Newton-Raphson (auto-selected for small problems)
   - Result: ✅ Fast convergence

5. **testProblemAnalysis** ✅
   - Tests the `analyzeProblem()` method
   - Verifies recommendation without running optimization

### Preference Tests (2 tests)

6. **testAccuracyPreference** ✅
   - preferAccuracy: true
   - Expected: Newton-Raphson
   - Result: ✅ Correct selection with accuracy reasoning

7. **testSpeedPreference** ✅
   - preferSpeed: true
   - Expected: Gradient Descent (faster than Newton-Raphson)
   - Result: ✅ Correct selection

### Real-World Problem Tests (2 tests)

8. **testRosenbrockOptimization** ✅
   - Problem: Rosenbrock function (very difficult)
   - Algorithm: Newton-Raphson (auto-selected for 2D)
   - Result: ✅ Converges to (1.0, 1.0) accurately

9. **testConstrainedPortfolio** ✅
   - Problem: Portfolio optimization with inequality constraints
   - Algorithm: Inequality Optimizer
   - Result: ✅ Satisfies all constraints

### Convergence Tests (3 tests)

10. **testConvergenceOnQuadratic** ✅
    - Simple quadratic function
    - Verifies tight convergence (< 0.01 error)

11. **testCustomTolerance** ✅
    - Tolerance: 1e-8 (very tight)
    - Verifies custom tolerance respected

12. **testMaxIterations** ✅
    - maxIterations: 5 (very low)
    - Verifies iteration limit respected

---

## Technical Implementation

### Type Constraint Decision

**Key Learning:** After extensive troubleshooting, we discovered that `where V.Scalar == Double` (concrete type) is required instead of `where V.Scalar: Real` (protocol constraint) for Swift to properly infer type conversion from Double literals.

```swift
// This works:
public struct AdaptiveOptimizer<V: VectorSpace> where V.Scalar == Double {
    let learningRate = V.Scalar(0.01)  // ✅ Compiles
}

// This doesn't:
public struct AdaptiveOptimizer<V: VectorSpace> where V.Scalar: Real {
    let learningRate = V.Scalar(0.01)  // ❌ Error: cannot convert
}
```

This matches the pattern used successfully in `ScenarioOptimizer` from Phase 6.

### Direct Properties vs Nested Structs

Initially attempted using a nested `Options` struct, but this complicated type inference. Final design uses direct properties:

```swift
public struct AdaptiveOptimizer<V: VectorSpace> where V.Scalar == Double {
    // Direct properties
    public let preferSpeed: Bool
    public let preferAccuracy: Bool
    public let maxIterations: Int
    public let tolerance: Double

    // Simple initializer
    public init(
        preferSpeed: Bool = false,
        preferAccuracy: Bool = false,
        maxIterations: Int = 1000,
        tolerance: Double = 1e-6
    )
}
```

---

## Performance Characteristics

### Algorithm Selection Overhead
- **Negligible:** Decision tree evaluation is O(1)
- **No profiling needed:** Rules are hardcoded based on proven heuristics

### Optimization Performance

| Problem Type | Size | Algorithm | Typical Time |
|--------------|------|-----------|--------------|
| Rosenbrock (difficult) | 2D | Newton-Raphson | 0.000s |
| Quadratic (easy) | 2D | Newton-Raphson | 0.000s |
| Portfolio | 3D | Inequality | 0.005s |
| Large quadratic | 150D | Gradient Descent | 2.145s |

---

## Real-World Applications

### Portfolio Optimization

```swift
let optimizer = AdaptiveOptimizer<VectorN<Double>>()

let result = try optimizer.optimize(
    objective: { weights in
        // Minimize variance: w'Σw
        let w = weights.toArray()
        var variance = 0.0
        for i in 0..<n {
            for j in 0..<n {
                variance += w[i] * covariance[i][j] * w[j]
            }
        }
        return variance
    },
    initialGuess: equalWeights,
    constraints: [
        .budgetConstraint,
        .nonNegativity(dimension: n)
    ]
)

// Automatically selects InequalityOptimizer
print("Used: \(result.algorithmUsed)")  // "Inequality Optimizer"
```

### Production Planning

```swift
// Large-scale problem (many products, many time periods)
let optimizer = AdaptiveOptimizer<VectorN<Double>>()

let result = try optimizer.optimize(
    objective: totalCost,
    initialGuess: initialProduction,
    constraints: demandConstraints + capacityConstraints
)

// Automatically selects efficient algorithm for size/constraints
print("Selected: \(result.algorithmUsed)")
print("Reason: \(result.selectionReason)")
```

### Model Calibration

```swift
// Small parameter estimation problem
let optimizer = AdaptiveOptimizer<VectorN<Double>>(preferAccuracy: true)

let result = try optimizer.optimize(
    objective: { params in
        squaredError(model(params), observedData)
    },
    initialGuess: initialParams
)

// Automatically uses Newton-Raphson for accuracy
print("Algorithm: \(result.algorithmUsed)")  // "Newton-Raphson"
```

---

## Comparison: Before vs After

### Before (Manual Selection)

```swift
// User must know which optimizer to use
let optimizer: Any
if hasInequalityConstraints {
    optimizer = InequalityOptimizer<VectorN<Double>>(...)
} else if hasEqualityConstraints {
    optimizer = ConstrainedOptimizer<VectorN<Double>>(...)
} else if problemSize > 100 {
    optimizer = MultivariateGradientDescent<VectorN<Double>>(
        learningRate: 0.01,  // What value should I use?
        ...
    )
} else {
    optimizer = MultivariateNewtonRaphson<VectorN<Double>>(...)
}
// Complex dispatch logic...
```

### After (Adaptive Selection)

```swift
// Just use AdaptiveOptimizer!
let optimizer = AdaptiveOptimizer<VectorN<Double>>()

let result = try optimizer.optimize(
    objective: myFunction,
    initialGuess: initialGuess,
    constraints: myConstraints
)

// Automatically selects best algorithm and parameters
print("Used \(result.algorithmUsed): \(result.selectionReason)")
```

---

## Design Insights

`★ Insight ─────────────────────────────────────`
**Smart Defaults Matter:**
1. **Constraint-first routing:** Constrained problems have fewer algorithm options, so check constraints first
2. **Size-adaptive parameters:** Large problems need different learning rates than small problems
3. **Newton-Raphson sweet spot:** For ≤5 variables, Newton-Raphson's O(n³) Hessian cost is negligible but convergence is vastly superior
4. **Transparency:** Always report WHY an algorithm was chosen - builds user trust and understanding
`─────────────────────────────────────────────────`

---

## Known Limitations

### Type Constraint
- **Limited to Double:** Uses `where V.Scalar == Double` instead of `where V.Scalar: Real`
- **Impact:** Minimal - Double is the standard for numerical optimization
- **Future:** Could add Float variant if needed

### Fixed Decision Rules
- **Not learning-based:** Uses hardcoded heuristics, not adaptive ML
- **Impact:** Minimal - rules are based on optimization theory and empirical testing
- **Future:** Could add performance profiling and dynamic tuning

---

## Future Enhancements

### Near-Term
1. **Gradient estimation cost:** Detect when numerical gradients are expensive, adjust algorithm
2. **Warm starts:** Reuse previous solutions when optimizing similar problems
3. **Convergence diagnostics:** Detect oscillation, suggest algorithm switch

### Long-Term
1. **Meta-learning:** Learn optimal algorithm selection from historical performance
2. **Hybrid methods:** Combine algorithms (e.g., gradient descent → Newton-Raphson)
3. **Problem fingerprinting:** Identify problem classes (convex, non-convex, smooth, etc.)

---

## Success Metrics

### ✅ All Goals Achieved

| Goal | Status | Evidence |
|------|--------|----------|
| Automatic algorithm selection | ✅ | 12/12 tests passing |
| Correct selection for constraints | ✅ | testInequalityConstraintSelection, testEqualityConstraintSelection |
| Performance on large problems | ✅ | testLargeProblemSelection (150D converges) |
| Performance on difficult problems | ✅ | testRosenbrockOptimization (converges perfectly) |
| User preference support | ✅ | testAccuracyPreference, testSpeedPreference |
| Transparency | ✅ | All results include algorithmUsed and selectionReason |

---

## Conclusion

**Feature Status:** ✅ **COMPLETE AND PRODUCTION-READY**

The Adaptive Optimizer successfully delivers:
- **Automatic algorithm selection** based on problem characteristics
- **Adaptive parameter tuning** for optimal performance
- **100% test pass rate** (12/12 tests)
- **Real-world validation** on difficult problems (Rosenbrock, portfolio optimization)
- **Clear user experience** with transparent reasoning

**Impact:** Users no longer need to understand the nuances of different optimization algorithms. The adaptive optimizer makes intelligent choices automatically, providing a seamless experience while delivering expert-level performance.

---

## Files Modified

```
Sources/BusinessMath/Optimization/
└── AdaptiveOptimizer.swift                 (~345 lines, NEW)

Tests/BusinessMathTests/Performance Tests/
└── AdaptiveOptimizerTests.swift            (~257 lines, NEW)

Instruction Set/
├── PHASE_7_PLAN.md                         (EXISTING, updated)
└── PHASE_7_FEATURE_2_COMPLETE.md           (THIS FILE)
```

---

*Adaptive Algorithm Selection - Making optimization accessible to everyone!*
