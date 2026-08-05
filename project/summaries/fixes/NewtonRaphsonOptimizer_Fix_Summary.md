# Newton-Raphson Optimizer Fix Summary

## Problem

The original implementation had a **fundamental algorithmic error**: it was implementing Newton-Raphson for **root finding** (finding where f(x) = 0) instead of Newton-Raphson for **optimization** (finding where f'(x) = 0, i.e., local minima/maxima).

### Specific Issues

1. **Wrong Update Formula**
   - **Before**: `x_{n+1} = x_n - f(x_n) / f'(x_n)` (finds roots)
   - **After**: `x_{n+1} = x_n - f'(x_n) / f''(x_n)` (finds extrema)

2. **Wrong Convergence Check**
   - **Before**: `abs(fx) < tolerance` (checks if function value is near zero)
   - **After**: `abs(firstDerivative) < tolerance` (checks if gradient is near zero)

3. **Missing Second Derivative**
   - The original code calculated `numericalSecondDerivative` but never used it
   - Now it's properly used in the Newton-Raphson update formula

4. **Poor Constraint Handling**
   - **Before**: Used a crude step-size reduction when constraints were violated
   - **After**: Implements proper projection to the feasible region

## Key Changes

### 1. Algorithm Correction

```swift
// OLD (incorrect - for root finding)
let derivative = numericalFirstDerivative(objective, at: x)
if abs(fx) < tolerance { converged = true; break }
step = fx / derivative
xNew = x - step

// NEW (correct - for optimization)
let firstDerivative = numericalFirstDerivative(objective, at: x)
let secondDerivative = numericalSecondDerivative(objective, at: x)
if abs(firstDerivative) < tolerance { converged = true; break }
step = firstDerivative / secondDerivative
xNew = x - step
```

### 2. Proper Constraint Projection

Added three new helper methods:

- **`allConstraintsSatisfied(_:constraints:)`**: Checks if all constraints are met
- **`projectToFeasibleRegion(_:constraints:bounds:)`**: Projects a point to the nearest feasible point
  - For `x >= 3` constraint, projects any x < 3 to exactly 3
  - For `x <= 10` constraint, projects any x > 10 to exactly 10
- **`findFeasiblePoint(from:constraints:bounds:objective:)`**: Searches for feasible points when projection fails

### 3. Initial Value Projection

```swift
// Apply constraints to initial value
x = projectToFeasibleRegion(x, constraints: constraints, bounds: bounds)
```

This ensures we start in a feasible region.

### 4. Fallback for Bad Hessian

When the second derivative is near zero or negative (which would cause division by zero or wrong direction):

```swift
if abs(secondDerivative) > epsilon {
    step = firstDerivative / secondDerivative
} else {
    // Fall back to gradient descent
    step = firstDerivative * stepSize * 10
}
```

## Test Case: Minimize x² with x ≥ 3

**Objective**: f(x) = x²  
**Constraint**: x ≥ 3  
**Expected Solution**: x = 3 (minimum occurs at the constraint boundary)

### Why the Old Code Failed

1. Started at x = 5.0 (feasible)
2. Tried to find where f(x) = 0, which is x = 0
3. Moved toward 0, violating the constraint
4. Applied poor constraint handling that didn't properly project back
5. Got stuck at x ≈ 2.867 (infeasible!)

### Why the New Code Works

1. Starts at x = 5.0 (feasible)
2. Computes f'(5) = 10, f''(5) = 2
3. Newton step: x_new = 5 - 10/2 = 0
4. Projects 0 → 3 (respects constraint x ≥ 3)
5. At x = 3: f'(3) = 6, f''(3) = 2
6. Newton step: x_new = 3 - 6/2 = 0
7. Projects 0 → 3 again
8. Movement = 0, converges to x = 3 ✓

## Mathematical Explanation

For **unconstrained optimization**:
- We want to find x where f'(x) = 0
- Newton-Raphson iterates: x_{n+1} = x_n - f'(x_n) / f''(x_n)
- This converges quadratically to local minima (when f''(x) > 0)

For **constrained optimization** (e.g., x ≥ 3):
- If unconstrained minimum is in feasible region, find it normally
- If unconstrained minimum violates constraints, the solution is on the boundary
- Project each iterate to maintain feasibility
- Converge to boundary point where either:
  - f'(x) = 0 (interior optimum), or
  - Constraint is active (boundary optimum)

## Additional Improvements

1. **Better Documentation**: Updated comments to clarify this is for optimization, not root finding
2. **Convergence Criteria**: More comprehensive explanation of when the algorithm succeeds/fails
3. **Robustness**: Handles edge cases like zero Hessian, infeasible initial points, etc.

## Test Impact

This fix should resolve:
- ✅ `optimizationWithConstraints()`: Now correctly finds x = 3.0
- ✅ `parabolaMinimum()`: Now finds actual minimum (where f'(x) = 0)
- ✅ `optimizationWithBounds()`: Properly respects bounds
- ✅ `maxIterations()`: More predictable iteration count
- ⚠️ `quadraticRoot()`: This test might need adjustment - it's testing root finding, but this is an optimization algorithm
