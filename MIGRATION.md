# Migration Guide: BusinessMath 1.x → 2.0

This guide helps you migrate your code from BusinessMath 1.x to 2.0.

---

## Overview

BusinessMath 2.0 represents a major milestone with unified parameter naming across all optimization APIs. This is a **breaking change** release that improves API consistency and developer experience.

**Key Changes:**
- ✅ Unified parameter naming: `initialGuess` everywhere
- ✅ Consistent external labels: `from:` for multivariate optimizers
- ✅ No functional changes - all algorithms work identically
- ✅ Enhanced documentation with validated examples

---

## Breaking Changes

### 1. Optimizer Parameter Renaming

**All scalar optimizers** (conforming to `Optimizer` protocol):

```swift
// ❌ 1.x (OLD)
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 10.0,  // OLD NAME
    bounds: nil
)

// ✅ 2.0 (NEW)
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialGuess: 10.0,  // NEW NAME
    bounds: nil
)
```

**Affected Types:**
- `GradientDescentOptimizer`
- `NewtonRaphsonOptimizer`
- `GoalSeekOptimizer`
- Any custom types conforming to `Optimizer`

---

### 2. Multivariate Optimizers (No Changes Needed)

**Good news:** If you're already using the protocol-based API, no changes needed!

```swift
// ✅ Already correct in both 1.x and 2.0
let result = try optimizer.minimize(
    objective,
    from initialGuess: vector,  // This was always correct
    constraints: []
)
```

**Note:** Old methods using unlabeled `function:` and `initialGuess:` still work but are deprecated. Migrate to protocol-based API:

```swift
// ⚠️ Deprecated (still works but not recommended)
let result = try optimizer.minimize(
    function: objective,
    initialGuess: vector
)

// ✅ Preferred (protocol-based)
let result = try optimizer.minimize(
    objective,
    from: vector
)
```

---

## Migration Steps

### Step 1: Update Optimizer Calls

**Find and replace** in your codebase:

```bash
# Find all usages
grep -r "initialValue:" . --include="*.swift"

# Replace (be careful with context!)
sed -i '' 's/initialValue:/initialGuess:/g' YourFile.swift
```

**⚠️ Important:** Only replace in optimization contexts! Don't replace:
- `TimeSeriesBuilder` initial values
- Factory methods like `VectorN.withDimension(_:initialValue:)`
- Other non-optimization parameters

### Step 2: Update Protocol Conformances

If you have custom optimizers conforming to `Optimizer`:

```swift
// ❌ 1.x (OLD)
struct MyOptimizer<T: Real>: Optimizer {
    func optimize(
        objective: @escaping (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,  // OLD
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {
        // Implementation
    }
}

// ✅ 2.0 (NEW)
struct MyOptimizer<T: Real>: Optimizer {
    func optimize(
        objective: @escaping (T) -> T,
        constraints: [Constraint<T>],
        initialGuess: T,  // NEW
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {
        // Implementation (update internal usage too)
    }
}
```

### Step 3: Update Tests

Test files will need the same parameter rename:

```swift
// ❌ 1.x (OLD)
@Test func optimizerFindsMinimum() {
    let result = optimizer.optimize(
        objective: { x in x * x },
        constraints: [],
        initialValue: 5.0,
        bounds: nil
    )
    #expect(abs(result.optimalValue) < 0.01)
}

// ✅ 2.0 (NEW)
@Test func optimizerFindsMinimum() {
    let result = optimizer.optimize(
        objective: { x in x * x },
        constraints: [],
        initialGuess: 5.0,  // CHANGED
        bounds: nil
    )
    #expect(abs(result.optimalValue) < 0.01)
}
```

### Step 4: Verify Compilation

After making changes:

```bash
swift build
swift test
```

The compiler will identify any remaining parameter mismatches.

---

## Example Migrations

### Portfolio Optimization

```swift
// ✅ No changes needed - already using protocol API
let optimizer = PortfolioOptimizer()
let portfolio = try optimizer.maximumSharpePortfolio(
    expectedReturns: returns,
    covariance: covariance,
    riskFreeRate: 0.02
)
```

### Goal Seeking

```swift
// ❌ 1.x (OLD)
let optimizer = GoalSeekOptimizer<Double>(
    tolerance: 0.0001,
    maxIterations: 1000
)
let result = optimizer.optimize(
    objective: profitFunction,
    constraints: [],
    initialValue: 0.30,  // OLD
    bounds: (0.0, 1.0)
)

// ✅ 2.0 (NEW)
let optimizer = GoalSeekOptimizer<Double>(
    tolerance: 0.0001,
    maxIterations: 1000
)
let result = optimizer.optimize(
    objective: profitFunction,
    constraints: [],
    initialGuess: 0.30,  // NEW
    bounds: (0.0, 1.0)
)
```

### Gradient Descent

```swift
// ❌ 1.x (OLD)
let optimizer = GradientDescentOptimizer<Double>(
    learningRate: 0.1,
    maxIterations: 1000
)
let result = optimizer.optimize(
    objective: { x in (x - 5) * (x - 5) },
    constraints: [],
    initialValue: 10.0,  // OLD
    bounds: nil
)

// ✅ 2.0 (NEW)
let optimizer = GradientDescentOptimizer<Double>(
    learningRate: 0.1,
    maxIterations: 1000
)
let result = optimizer.optimize(
    objective: { x in (x - 5) * (x - 5) },
    constraints: [],
    initialGuess: 10.0,  // NEW
    bounds: nil
)
```

### Newton-Raphson

```swift
// ❌ 1.x (OLD)
let optimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 1e-8,
    maxIterations: 100
)
let result = optimizer.optimize(
    objective: { x in x * x - 25 },
    constraints: [],
    initialValue: 3.0,  // OLD
    bounds: nil
)

// ✅ 2.0 (NEW)
let optimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 1e-8,
    maxIterations: 100
)
let result = optimizer.optimize(
    objective: { x in x * x - 25 },
    constraints: [],
    initialGuess: 3.0,  // NEW
    bounds: nil
)
```

---

## What Hasn't Changed

### Algorithm Behavior
All optimization algorithms work **identically** to 1.x:
- Same convergence properties
- Same numerical results
- Same performance characteristics

### Return Types
All result types are unchanged:
- `OptimizationResult<T>`
- `MultivariateOptimizationResult<V>`
- `ConstrainedOptimizationResult<V>`

### Other APIs
Everything outside optimization is unchanged:
- Time Value of Money
- Time Series Analysis
- Forecasting
- Statistical functions
- Monte Carlo simulation
- Financial ratios
- Valuation models
- All MCP tools

---

## Troubleshooting

### Compiler Error: "incorrect argument label"

```
error: incorrect argument label in call (have 'objective:constraints:initialValue:bounds:',
                                          expected 'objective:constraints:initialGuess:bounds:')
```

**Fix:** Replace `initialValue:` with `initialGuess:` at the error location.

### My Custom Optimizer Won't Compile

If you have a custom optimizer conforming to `Optimizer`, update the protocol method:

1. Change parameter name from `initialValue` to `initialGuess`
2. Update internal usage of the parameter
3. Update documentation comments

### VectorN.withDimension Error

If you see an error with `VectorN.withDimension`, you may have incorrectly replaced `initialValue:`:

```swift
// ✅ Correct - this is NOT an optimization parameter
let vector = VectorN<Double>.withDimension(4, initialValue: 7.0)

// ❌ Wrong - don't change this to initialGuess
let vector = VectorN<Double>.withDimension(4, initialGuess: 7.0)  // ERROR!
```

---

## Getting Help

- **GitHub Issues**: [BusinessMath Issues](https://github.com/jpurnell/BusinessMath/issues)
- **Documentation**: Full API documentation available in Xcode or via `swift package generate-documentation`
- **Examples**: See `Examples/` directory for complete working examples

---

## Version Timeline

- **1.x** - Parameter naming varies (`initialValue` vs `initialGuess`)
- **2.0** - Unified naming (`initialGuess` everywhere)
- **2.x** - Future enhancements (shadow prices, anti-dilution, etc.)

---

## Benefits of Migrating

1. **Consistency** - One parameter name to remember
2. **Clarity** - `initialGuess` better conveys iterative nature
3. **Future-proof** - All future APIs will follow 2.0 conventions
4. **Better IDE support** - Autocomplete works more intuitively
5. **Validated examples** - All documentation examples tested in playgrounds

---

**Questions?** Open an issue or discussion on GitHub!
