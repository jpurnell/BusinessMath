# Newton-Raphson Tests Corrections

## Problem

Several tests were written for **root finding** (finding where f(x) = 0) instead of **optimization** (finding where f'(x) = 0). After correcting the optimizer to properly do optimization, these tests failed because they had incorrect expectations.

## Test Corrections

### 1. `convergenceTolerance()` - FIXED ✅

**Original (Incorrect)**:
```swift
let objective = { (x: Double) -> Double in
    return x * x - 16.0
}
// Expected: result.objectiveValue ≈ 0 (root finding)
```

**Problem**:
- f(x) = x² - 16
- For optimization: f'(x) = 2x = 0 → x = 0
- At x = 0: f(0) = 0 - 16 = **-16** ❌
- Test expected `abs(objectiveValue) < 0.001` but got 16.0!

**Corrected**:
```swift
let objective = { (x: Double) -> Double in
    return (x - 4.0) * (x - 4.0)
}
// Expected: minimum at x = 4, f(4) = 0
```

- f(x) = (x - 4)²
- f'(x) = 2(x - 4) = 0 → x = 4
- At x = 4: f(4) = 0 ✅
- Test now properly validates optimization

### 2. `shiftedParabolaMinimum()` (formerly `quadraticRoot()`) - FIXED ✅

**Original (Incorrect)**:
```swift
// Comment said: "root at x = 2"
let objective = { (x: Double) -> Double in
    return x * x - 4.0
}
#expect(abs(result.optimalValue - 2.0) < 0.01)  // Expected x = 2
#expect(abs(result.objectiveValue) < 0.01)      // Expected f(x) ≈ 0
```

**Problem**:
- Test was looking for root (x = 2 where f(2) = 0)
- But optimizer finds minimum (x = 0 where f'(x) = 0)

**Corrected**:
```swift
// Minimize f(x) = x^2 - 4 (minimum at x = 0, f(0) = -4)
let objective = { (x: Double) -> Double in
    return x * x - 4.0
}
#expect(abs(result.optimalValue - 0.0) < 0.01)  // x = 0
#expect(abs(result.objectiveValue - (-4.0)) < 0.01)  // f(0) = -4
```

### 3. `maxIterations()` - IMPROVED ✅

**Original (Problematic)**:
```swift
let objective = { (x: Double) -> Double in
    return sin(x) - 0.5
}
```

**Issues**:
- sin(x) - 0.5 is periodic with multiple minima
- Starting at x = 0 might converge quickly to nearest minimum
- Unpredictable iteration count

**Corrected**:
```swift
// Minimize f(x) = x^4 - 2x^2 + 1 (double-well potential)
let objective = { (x: Double) -> Double in
    let x2 = x * x
    return x2 * x2 - 2.0 * x2 + 1.0
}
// Start at x = 10.0 (far from minimum)
```

**Improvements**:
- More predictable behavior
- Starting far from minimum ensures it takes multiple iterations
- Better test of iteration limit functionality

### 4. Tests That Were Already Correct ✅

These tests were properly written for optimization:

- **`parabolaMinimum()`**: Minimizes (x - 5)² → finds x = 5 ✓
- **`optimizationWithBounds()`**: Minimizes x² with bounds [2, 10] → finds x = 2 ✓
- **`optimizationWithConstraints()`**: Minimizes x² with x ≥ 3 → finds x = 3 ✓
- **`numericalDerivative()`**: Tests derivative calculation (not optimization) ✓

## Key Differences: Root Finding vs Optimization

| Aspect | Root Finding | Optimization |
|--------|-------------|--------------|
| **Goal** | Find where f(x) = 0 | Find where f'(x) = 0 |
| **Update** | x ← x - f(x)/f'(x) | x ← x - f'(x)/f''(x) |
| **Convergence** | \|f(x)\| < ε | \|f'(x)\| < ε |
| **Result** | f(x) ≈ 0 | f'(x) ≈ 0 (min/max) |

## Example

For f(x) = x² - 16:

**Root Finding** (old, incorrect):
- Finds: x = ±4 (where x² - 16 = 0)
- At x = 4: f(4) = 0 ✓

**Optimization** (new, correct):
- Finds: x = 0 (where f'(x) = 2x = 0)
- At x = 0: f(0) = -16
- This is the **minimum** of the parabola ✓

## Summary

All test failures were due to tests being written for the **wrong algorithm**. The tests expected root-finding behavior, but the corrected optimizer properly performs optimization. The tests are now aligned with the actual algorithm implementation.
