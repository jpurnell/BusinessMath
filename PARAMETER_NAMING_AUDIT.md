# BusinessMath 2.0: Parameter Naming Audit

**Date:** 2025-12-26
**Purpose:** Document all parameter naming variations to inform 2.0 unification strategy

---

## Executive Summary

**Current State:** 3 different parameter naming conventions across 209 method/init signatures
**Goal:** Unified, consistent parameter naming for 2.0 release
**Breaking Change:** Yes - this is a major version bump opportunity

---

## Parameter Naming Variations

### 1. Scalar Optimizers (Optimizer protocol)
**Pattern:** `initialValue` (unlabeled parameter name)

```swift
// Protocol requirement
func optimize(
    objective: @escaping (T) -> T,
    constraints: [Constraint<T>],
    initialValue: T,  // ← UNLABELED PARAMETER NAME
    bounds: (lower: T, upper: T)?
) -> OptimizationResult<T>
```

**Used by:**
- `GradientDescentOptimizer`
- `NewtonRaphsonOptimizer`
- All conforming scalar optimizers

**Occurrences:** ~50 method signatures

---

### 2. Multivariate Optimizers (Old API)
**Pattern:** `initialGuess` (unlabeled parameter name)

```swift
// Legacy API (pre-protocol)
public func minimize(
    function: @escaping (V) -> V.Scalar,
    initialGuess: V  // ← UNLABELED PARAMETER NAME
) throws -> MultivariateOptimizationResult<V>
```

**Used by:**
- `MultivariateGradientDescent` (old methods)
- `MultivariateNewtonRaphson` (old methods)
- Algorithm variants (minimizeAdam, minimizeBFGS)

**Occurrences:** ~80 method signatures

---

### 3. Multivariate Optimizers (Protocol API)
**Pattern:** `from initialGuess:` (external label `from`)

```swift
// MultivariateOptimizer protocol requirement
func minimize(
    _ objective: @escaping (V) -> V.Scalar,
    from initialGuess: V,  // ← EXTERNAL LABEL "from"
    constraints: [MultivariateConstraint<V>]
) throws -> MultivariateOptimizationResult<V>
```

**Used by:**
- Protocol conformance methods
- `PortfolioOptimizer` (uses protocol)
- New constrained optimizer APIs

**Occurrences:** ~40 method signatures

---

### 4. Constrained Optimizer Variation
**Pattern:** `from: subjectTo:` (alternative labeling)

```swift
// ConstrainedOptimizer old API
public func minimize(
    _ objective: @escaping (V) -> V.Scalar,
    from initialGuess: V,
    subjectTo constraints: [MultivariateConstraint<V>]  // ← "subjectTo" label
) throws -> ConstrainedOptimizationResult<V>
```

**Used by:**
- `ConstrainedOptimizer` (old API, deprecated with protocol)
- Some legacy constrained optimization examples

**Occurrences:** ~10 method signatures

---

### 5. Other Parameter Name Variations

**`initialWeights`** - Portfolio optimization
```swift
let initialWeights = VectorN<Double>(Array(repeating: 1.0 / n, count: n))
optimizer.minimize(..., from: initialWeights, ...)
```

**`guess`** - Goal seek functions
```swift
public func goalSeek(
    function: @escaping (Double) -> Double,
    target: Double,
    guess: Double,  // ← "guess" without "initial"
    tolerance: Double,
    maxIterations: Int
) throws -> Double
```

**`x0`** or `initial` - Sparse solvers
```swift
func conjugateGradient(
    A: SparseMatrix,
    b: [Double],
    x0: [Double],  // ← Mathematical notation style
    tolerance: Double
) throws -> [Double]
```

---

## Constraint Parameter Naming

### Variation 1: `constraints` (protocol standard)
```swift
func minimize(
    _ objective: @escaping (V) -> V.Scalar,
    from initialGuess: V,
    constraints: [MultivariateConstraint<V>] = []
)
```

### Variation 2: `subjectTo constraints`
```swift
func minimize(
    _ objective: @escaping (V) -> V.Scalar,
    from initialGuess: V,
    subjectTo constraints: [MultivariateConstraint<V>]
)
```

**Recommendation:** Use `constraints:` consistently (mathematical "subject to" is implied by constraint type)

---

## 2.0 Unification Strategy

### Recommended Standard

**For ALL optimization methods:**

```swift
// ✅ UNIFIED STANDARD

// Scalar optimization (unlabeled)
func optimize(
    objective: @escaping (T) -> T,
    constraints: [Constraint<T>] = [],
    initialGuess: T,  // ← CHANGE from initialValue
    bounds: (lower: T, upper: T)? = nil
) -> OptimizationResult<T>

// Multivariate optimization (labeled with "from")
func minimize(
    _ objective: @escaping (V) -> V.Scalar,
    from initialGuess: V,  // ← KEEP from: label
    constraints: [MultivariateConstraint<V>] = []
) throws -> MultivariateOptimizationResult<V>
```

**Rationale:**
1. **`initialGuess`** - More intuitive than `initialValue` (it's a starting point, not a value to preserve)
2. **`from:`** external label - Reads naturally: `optimizer.minimize(objective, from: startPoint)`
3. **`constraints:`** - Direct, mathematical, no "subjectTo" verbosity
4. **Default parameters** - Makes unconstrained optimization cleaner

---

## Migration Impact Analysis

### Files Requiring Changes

**High Impact (Core Protocols):**
- `Sources/BusinessMath/Optimization/Optimizer.swift` - Protocol definition
- `Sources/BusinessMath/Optimization/MultivariateOptimizer.swift` - Protocol definition

**Medium Impact (Implementations):**
- `Sources/BusinessMath/Optimization/GradientDescentOptimizer.swift`
- `Sources/BusinessMath/Optimization/Algorithms/NewtonRaphsonOptimizer.swift`
- `Sources/BusinessMath/Optimization/Algorithms/MultivariateGradientDescent.swift`
- `Sources/BusinessMath/Optimization/Algorithms/MultivariateNewtonRaphson.swift`
- `Sources/BusinessMath/Optimization/Algorithms/ConstrainedOptimizer.swift`
- `Sources/BusinessMath/Optimization/Algorithms/InequalityOptimizer.swift`
- `Sources/BusinessMath/Optimization/AdaptiveOptimizer.swift`
- `Sources/BusinessMath/Optimization/ParallelOptimizer.swift`
- `Sources/BusinessMath/AdvancedOptimization/StochasticOptimizer.swift`
- `Sources/BusinessMath/AdvancedOptimization/RobustOptimizer.swift`
- `Sources/BusinessMath/AdvancedOptimization/ScenarioOptimizer.swift`

**Lower Impact (Usage Sites):**
- `Sources/BusinessMath/Finance/Portfolio/PortfolioOptimizer.swift` - Uses protocol (already correct)
- `Sources/BusinessMath/FinancialModel/DriverOptimization.swift`
- `Sources/BusinessMath/Statistics/Regression/NonlinearRegression.swift`
- All test files using optimizer APIs (~192 test files)
- All documentation examples (~52 tutorial files)

**Total Estimate:**
- ~20 source files (optimizer implementations)
- ~192 test files (update test call sites)
- ~52 documentation files (update examples)

---

## Testing Strategy

1. **Update protocol definitions** - Make breaking changes
2. **Update all implementations** - Fix compiler errors
3. **Run test suite** - Identify all call site failures
4. **Batch update tests** - Fix parameter names systematically
5. **Update documentation** - Fix all examples
6. **Full regression test** - Verify 100% pass rate

---

## Documentation Impact

### Tutorial Files Requiring Updates

**Part 1: Basics**
- `1.1-GettingStarted.md`
- `1.3-TimeValueOfMoney.md`

**Part 2: Analysis**
- `2.1-DataTableAnalysis.md` (goal seek examples)

**Part 3: Modeling**
- `3.2-ForecastingGuide.md` (optimization examples)
- `3.8-InvestmentAnalysis.md`

**Part 5: Optimization** (Heavy impact)
- `5.1-OptimizationGuide.md` ✅ Recently updated
- `5.1.5-MultivariateOptimizerGuide.md` ✅ Recently updated
- `5.2-PortfolioOptimizationGuide.md` ✅ Recently updated
- `5.3-CoreOptimization.md`
- `5.4-VectorOperations.md` ✅ Recently updated
- `5.5-MultivariateOptimization.md`
- `5.6-ConstrainedOptimization.md`
- `5.7-BusinessOptimization.md` ✅ Recently updated
- `5.8-IntegerProgramming.md`
- `5.9-AdaptiveSelection.md`
- `5.10-ParallelOptimization.md`
- `5.11-PerformanceBenchmarking.md` ✅ Recently updated
- `5.13-MultiPeriod.md`
- `5.14-RobustOptimization.md`
- `5.15-InequalityConstraints.md`

**Good news:** Recent documentation updates (Part5 overview, optimization guides) were already playground-tested, so examples are mostly correct. Just need parameter name updates.

---

## Timeline Estimate

**Day 1:** Protocol & implementation updates (compiler-driven)
**Day 2:** Test suite updates (batch search-replace)
**Day 3:** Documentation updates (systematic review)
**Day 4:** Full regression testing + fixes
**Day 5:** Polish, MIGRATION.md, final review

**Total:** 5 days (matches user's "this week" expectation)

---

## Next Steps

1. ✅ Complete this audit
2. Get user approval on naming strategy
3. Create detailed implementation plan
4. Execute parameter name unification
5. Update all tests and documentation
6. Tag 2.0.0 release

---

## Appendix: Search Patterns for Updates

```bash
# Find all initialValue usages
grep -r "initialValue:" Sources/BusinessMath --include="*.swift"

# Find all initialGuess usages (unlabeled)
grep -r "initialGuess:" Sources/BusinessMath --include="*.swift"

# Find all "from:" labels
grep -r "from initialGuess\|from:" Sources/BusinessMath --include="*.swift"

# Find all subjectTo labels
grep -r "subjectTo" Sources/BusinessMath --include="*.swift"
```
