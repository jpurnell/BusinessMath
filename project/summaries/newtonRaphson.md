# NewtonRaphsonOptimizer analysis, and how to use it for goals and maximization

This implementation is a 1D Newton–Raphson optimizer that minimizes a smooth scalar function f(x). It uses finite differences to approximate f′ and f′′, and optionally enforces bounds and simple constraints via projection.

Below is a concise analysis, followed by how to use it to:
- minimize an objective,
- hit a target (inverse problem),
- maximize a function.

## What it does

- Iteration: x_{k+1} = x_k − f′(x_k)/f′′(x_k)
- If f′′ is too small, it falls back to a simple gradient descent step.
- Uses central differences for f′ and f′′ with a fixed step size h.
- Applies optional bounds by clamping, and attempts to project to a feasible region for constraints.

## Strengths

- Simple, fast near a well-behaved minimum (quadratic convergence).
- Handles bounds by clamping.
- Has a primitive fallback when f′′ is near zero.

## Important limitations and caveats

- 1D only. Not a general multivariate optimizer.
- No line search/damping: steps may be too aggressive and cause divergence or oscillation.
- Negative curvature: if f′′(x) < 0 (concave region), the Newton step can move toward a maximum. The code currently only checks “too small” magnitude; it should also handle negative curvature explicitly.
- Fixed finite-difference step h: may be too small (roundoff) or too large (truncation). Consider tuning per problem.
- Constraint handling is simplistic. Only simple bound-like constraints are projected; function-based constraints aren’t robustly enforced.
- Potentially redundant f(x) evaluations; could reuse fx to compute f′′ more efficiently.
- No NaN/Inf safeguards.

## How to use it

### 1) Minimize an objective (default use)

Example: minimize f(x) = (x − 5)^2.

```swift
let optimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 1e-6,
    maxIterations: 100,
    stepSize: 1e-4
)

let result = optimizer.optimize(
    objective: { x in
        let d = x - 5.0
        return d*d
    },
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)

print("x* =", result.optimalValue)           // ≈ 5.0
print("f(x*) =", result.objectiveValue)      // ≈ 0.0
print("converged =", result.converged)
print("iterations =", result.iterations)
```

Tips:
- Choose an initialValue near where you expect the minimum for best convergence.
- Tune stepSize (finite difference h) and tolerance to match the scale of your function.

### 2) Hit a target value (inverse problem)

Goal: find x such that g(x) = yTarget.

Approach: minimize the squared residual R(x) = (g(x) − yTarget)^2. Its minimum occurs where the residual is zero (or as close as possible), i.e., g(x) ≈ yTarget.

```swift
let g: (Double) -> Double = { x in x*x + 3*x + 2 } // example
let yTarget = 42.0

let optimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 1e-8,
    maxIterations: 100,
    stepSize: 1e-4
)

let result = optimizer.optimize(
    objective: { x in
        let r = g(x) - yTarget
        return r*r
    },
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)

// The residual at the solution:
let residual = sqrt(result.objectiveValue)
print("x s.t. g(x) ≈ yTarget:", result.optimalValue)
print("|g(x) - yTarget| ≈", residual)
```

Notes:
- If g is not injective (has multiple x for the same y), the initial guess determines which solution you reach.
- The residual sqrt(result.objectiveValue) is a direct measure of how close you got to the target.

### 3) Maximize a function

Maximization = minimization of the negative. If you want to maximize F(x), pass objective = −F(x). The optimizer will find a minimum of −F, which corresponds to a maximum of F.

Example: maximize F(x) = 100x − x^2 on [0, 200], whose maximum is at x = 50.

```swift
let F: (Double) -> Double = { x in
    100*x - x*x
}

let optimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 1e-8,
    maxIterations: 100,
    stepSize: 1e-4
)

let result = optimizer.optimize(
    objective: { x in -F(x) },         // minimize negative to maximize F
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 200.0) // optional bounds
)

let xArgMax = result.optimalValue
let fMax = F(xArgMax)

print("argmax x* =", xArgMax)  // ≈ 50
print("max F(x*) =", fMax)     // ≈ 2500
```

Notes:
- For concave F near the maximum, −F is convex near its minimum, which plays nicely with Newton for minimization.
- If you don’t negate F, the raw Newton step may drive you toward maxima unintentionally—don’t rely on that; negate F explicitly.

## Constraints and bounds

- Bounds: pass bounds: (lower, upper); the code clamps iterates into [lower, upper].
- Constraints array: only simple “value-based” constraints appear to be projected (greaterThan, lessThan, etc. when constraint.function == nil). Arbitrary function-based constraints are not robustly handled here.

If you must honor complex constraints, consider:
- Expressing them as simple bounds where possible, or
- Using a penalty/barrier formulation in the objective (e.g., add large penalties when constraints are violated), or
- Extending this implementation to a proper constrained method (e.g., barrier method, projected line search).

## Practical tips for stability

- Initial guess: Start near a plausible solution.
- Scale and step size:
  - If your function varies on a large scale, increase stepSize (h) for derivative approximation.
  - If it’s very sharp or noisy, reduce h.
- Tolerance:
  - Use a tolerance that matches your application’s precision needs and the scale of x and f′.
- Add a maximum step or damping:
  - If you see oscillation/divergence, introduce a step damping factor λ ∈ (0, 1], i.e., x_{k+1} = x_k − λ f′/f′′ with a simple backtracking line search.
- Handle negative curvature:
  - If f′′ ≤ 0, fall back to a gradient step or switch to a safeguarded variant (trust region/line search).
- Guard against NaN/Inf:
  - Bail out if the objective or derivatives become non-finite.

## Possible code improvements (high-value)

- Safeguard curvature and add damping:
  - If f′′ ≤ 0 or |f′′| is very small, use a gradient descent step and potentially a backtracking line search.
- Reuse f(x):
  - numericalSecondDerivative currently calls f(x) again; reuse the already-computed fx to save one evaluation:
    - f′′ ≈ (f(x+h) − 2·fx + f(x−h)) / h²
- Adaptive finite-difference h:
  - Adjust h relative to |x| (e.g., h = max(ε, c·|x|)) to balance truncation/roundoff.
- Better convergence checks:
  - Combine gradient norm, step size, and objective decrease tests.
- Better constraint handling:
  - Implement proper projection for supported constraint types and/or a penalty/barrier approach for function constraints.

That’s it—you can minimize directly, hit a target by minimizing a squared residual, and maximize by minimizing the negative. For production use, consider adding curvature safeguards and damping for robustness.
