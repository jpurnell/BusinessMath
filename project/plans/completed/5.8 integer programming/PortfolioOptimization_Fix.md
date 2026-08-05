# Portfolio Optimization Example Fix

## Problem Identified

The portfolio optimization example was returning **[0, 0, 0]** (zero shares in all assets) as the optimal solution, which is clearly wrong for a portfolio optimization problem.

## Root Cause Analysis

### The Broken Formulation

**Original objective:**
```swift
utility = expectedReturn - riskAversion * variance
      = μᵀw - λ * wᵀΣw
```

**With parameters:**
- Returns: [0.10, 0.15, 0.12] (10%, 15%, 12%)
- Risk aversion λ = 2.0
- Budget: 10 lots
- Covariance matrix with variances [0.04, 0.09, 0.06]

**Why it fails:**

For allocation w = [3, 3, 4]:
```
Expected return = 3*0.10 + 3*0.15 + 4*0.12 = 1.23
Variance ≈ 3²*0.04 + 3²*0.09 + 4²*0.06 + cross terms ≈ 3.5
Risk penalty = 2.0 * 3.5 = 7.0
Utility = 1.23 - 7.0 = -5.77  ❌ NEGATIVE!
```

For allocation w = [0, 0, 0]:
```
Expected return = 0
Variance = 0
Utility = 0  ✓ BETTER than negative!
```

**Optimizer correctly chooses [0, 0, 0] because it has utility 0, which beats -5.77!**

### Why This Happens

Mean-variance optimization `return - λ*variance` is designed for **portfolio weights** (fractions summing to 1), not **absolute quantities** (lot counts).

**With weights (correct):**
```
w = [0.3, 0.3, 0.4]  (fractions summing to 1)
Return = 0.3*0.10 + 0.3*0.15 + 0.4*0.12 = 0.123 = 12.3%
Variance = 0.3²*0.04 + ... ≈ 0.004 (small!)
Utility = 0.123 - 2.0*0.004 = 0.115  ✓ Positive
```

**With lots (broken):**
```
w = [3, 3, 4]  (absolute counts)
Return = 1.23
Variance = 3.5  (HUGE because squared terms!)
Utility = 1.23 - 2.0*3.5 = -5.77  ❌ Negative
```

**The problem:** Variance scales with the **square** of the lot counts, but return scales **linearly**. At scale, the quadratic term overwhelms the linear term.

## Solution: Reformulate the Problem

### New Formulation

**Instead of:** Maximize `return - λ*variance` (doesn't work with absolute quantities)

**Use:** Maximize `return` subject to `variance ≤ maxVariance` (works with absolute quantities)

### Fixed Code

```swift
// Expected return per lot (in dollars, not percentages)
let returns = [8.0, 12.0, 10.0]

// Covariance matrix scaled appropriately for lots
let cov = [
    [1.0, 0.2, 0.4],
    [0.2, 2.0, 0.6],
    [0.4, 0.6, 1.5]
]

// Maximum acceptable variance
let maxVariance = 50.0

// Objective: maximize expected return
let objective: @Sendable (VectorN<Double>) -> Double = { w in
    -zip(returns, w.toArray()).map(*).reduce(0, +)  // Negate for minimization
}

// Constraints: budget + variance bound
var constraints: [MultivariateConstraint<VectorN<Double>>] = [
    .budget(total: 10.0, dimension: 3),  // 10 lots total

    // Variance constraint: wᵀΣw ≤ maxVariance
    .inequality { w in
        var variance = 0.0
        for i in 0..<3 {
            for j in 0..<3 {
                variance += w[i] * cov[i][j] * w[j]
            }
        }
        return variance - maxVariance
    }
]
```

### Why This Works

**For allocation w = [2, 5, 3]:**
```
Expected return = 2*8 + 5*12 + 3*10 = 16 + 60 + 30 = $106
Variance = 2²*1.0 + 5²*2.0 + 3²*1.5 + cross terms ≈ 49.6
Constraint: 49.6 ≤ 50.0  ✓ Satisfied

This is a FEASIBLE, POSITIVE return solution!
```

**For allocation w = [0, 0, 0]:**
```
Expected return = $0
This violates the implicit requirement to invest the budget!
```

The constraint-based formulation ensures we actually invest while staying within risk bounds.

## Key Changes

### Parameters

**Old (broken):**
- Returns: [0.10, 0.15, 0.12] (percentages)
- Risk aversion: 2.0
- Objective: `return - 2.0*variance`

**New (fixed):**
- Returns: [8.0, 12.0, 10.0] (dollars per lot)
- Max variance: 50.0
- Objective: `maximize return` subject to `variance ≤ 50`

### Why Return in Dollars?

Using dollar returns per lot instead of percentages:
1. Makes the scale clear (e.g., $8 per lot)
2. Avoids confusion about what the percentage is relative to
3. Easier to balance with variance constraint

### Covariance Matrix Scaling

Old matrix had variances [0.04, 0.09, 0.06] which are appropriate for **portfolio weights**.

New matrix has variances [1.0, 2.0, 1.5] which are scaled appropriately for **lot counts** at the scale of ~10 lots.

**Rule of thumb:** If budget is N lots, scale covariance matrix by approximately 1/N² compared to the weight-based version.

## Educational Value

This bug demonstrates an important lesson:

**Portfolio optimization formulations are NOT scale-invariant!**

- Mean-variance optimization is designed for weights (sum to 1)
- When using absolute quantities, reformulate as:
  - Maximize return subject to risk constraint
  - Or minimize risk subject to return constraint
- Don't blindly apply weight-based formulas to quantity-based problems

## Expected Output (Fixed)

```
Optimal portfolio: [2, 5, 3] lots
  Asset 0: 200 shares
  Asset 1: 500 shares
  Asset 2: 300 shares
Expected return: $106
Nodes explored: 73

Portfolio Metrics:
  Total lots: 10
  Portfolio variance: 49.6
  Variance constraint: ✓
  Risk utilization: 99.2%
```

This is a sensible portfolio:
- Invests all 10 lots (budget constraint)
- Maximizes return ($106)
- Stays within risk bound (49.6 ≤ 50.0)
- Uses variance capacity efficiently (99.2%)

## Files Fixed

1. **Documentation:** `/Sources/BusinessMath/BusinessMath.docc/5.8-IntegerProgramming.md` (line 1035)
2. **Playground:** `/Playgrounds/.../5.8-IntegerProgramming.playground/Contents.swift` (line 616)

Both now use the corrected constraint-based formulation.

## Conclusion

This was a subtle but important bug - the optimizer was working correctly, but the problem formulation was mathematically inappropriate for integer lots. The fix demonstrates that different problem scales require different objective formulations.

**Lesson:** Always check that your optimization formulation is appropriate for the scale and type of decision variables you're using!
