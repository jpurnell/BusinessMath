# Using the Optimizer protocol (and NewtonRaphsonOptimizer) effectively

This library’s Optimizer protocol defines a single entry point:
- optimize(objective:constraints:initialValue:bounds:) -> OptimizationResult

The provided NewtonRaphsonOptimizer<T: Real> is a 1D optimizer that minimizes a scalar function. You can use it to:
1) find a minimum,
2) find a maximum,
3) find an x such that f(x) ≈ target (goal seek),
4) restrict any of these to a bounded input range via bounds or constraints.

Below are clear patterns and convenience methods you can add to make the API ergonomic.

## Quick answers

- Minimum of f: call optimize(objective: f, …)
- Maximum of f: minimize the negative, i.e., optimize(objective: { -f($0) }, …). For ergonomics, expose a maximize(…) wrapper that fixes the sign and returns the true f(x*) in the result.
- Goal seek (solve f(x) = target): minimize the squared residual (f(x) − target)². For ergonomics, expose a goalSeek(…) wrapper.
- Limit to bounds: pass bounds: (lower, upper) to any of the above. You can also add simple constraints via the Constraint API.

## Minimal examples

### 1) Minimum

```swift
let opt = NewtonRaphsonOptimizer<Double>(tolerance: 1e-6, maxIterations: 100, stepSize: 1e-4)

let result = opt.optimize(
    objective: { x in (x - 5) * (x - 5) },
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)

print(result.optimalValue)   // ≈ 5.0
print(result.objectiveValue) // ≈ 0.0
```

### 2) Maximum

```swift
let F: (Double) -> Double = { x in 100*x - x*x } // concave, max at x=50

let resNeg = opt.optimize(
    objective: { x in -F(x) }, // minimize negative to maximize F
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 200.0)
)

let xStar = resNeg.optimalValue
let fMax  = F(xStar)

print(xStar) // ≈ 50
print(fMax)  // ≈ 2500
```

### 3) Goal seek (hit target value)

```swift
let g: (Double) -> Double = { x in x*x + 3*x + 2 }
let target = 42.0

let res = opt.optimize(
    objective: { x in
        let r = g(x) - target
        return r * r
    },
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)

// result.objectiveValue is the squared residual at the solution
let xStar = res.optimalValue
let residual = abs(g(xStar) - target)
```

### 4) Limit to a bounded range

Every example above can accept bounds: (lower, upper):

```swift
let bounded = opt.optimize(
    objective: { x in (x - 5) * (x - 5) },
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: -1.0, upper: 3.0) // forces solution into [-1, 3]
)
```

You can also use constraints for simple inequality conditions:

```swift
let nonNegative = Constraint<Double>(type: .greaterThanOrEqual, bound: 0.0)

let res = opt.optimize(
    objective: { x in (x - 1)*(x - 1) },
    constraints: [nonNegative],
    initialValue: -10.0,
    bounds: nil
)
```

## Recommended convenience methods

For better ergonomics and clarity at the call site, add these convenience wrappers to NewtonRaphsonOptimizer. They encapsulate the patterns above and return a consistent OptimizationResult.

Paste this extension into the same module (one concept per file if you prefer, e.g., NewtonRaphsonOptimizer+Convenience.swift).

```swift
public extension NewtonRaphsonOptimizer {
    /// Minimize `objective` with optional constraints and bounds.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize.
    ///   - initialValue: Starting point.
    ///   - bounds: Optional bounds (lower, upper).
    ///   - constraints: Optional constraints (defaults to empty).
    /// - Returns: OptimizationResult with the minimum found.
    @inline(__always)
    func minimize(
        objective: @escaping (T) -> T,
        initialValue: T,
        bounds: (lower: T, upper: T)? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T> {
        optimize(
            objective: objective,
            constraints: constraints,
            initialValue: initialValue,
            bounds: bounds
        )
    }

    /// Maximize `objective` by minimizing its negative, returning the true maximum value in `objectiveValue`.
    ///
    /// - Parameters:
    ///   - objective: Function to maximize.
    ///   - initialValue: Starting point.
    ///   - bounds: Optional bounds (lower, upper).
    ///   - constraints: Optional constraints (defaults to empty).
    /// - Returns: OptimizationResult where `objectiveValue` is the maximum of `objective` at `optimalValue`.
    func maximize(
        objective: @escaping (T) -> T,
        initialValue: T,
        bounds: (lower: T, upper: T)? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T> {
        let resNeg = optimize(
            objective: { x in -objective(x) },
            constraints: constraints,
            initialValue: initialValue,
            bounds: bounds
        )
        let xStar = resNeg.optimalValue
        // Re-wrap so the reported objectiveValue is the actual maximum, not the minimized negative.
        return OptimizationResult(
            optimalValue: xStar,
            objectiveValue: objective(xStar),
            iterations: resNeg.iterations,
            converged: resNeg.converged,
            history: resNeg.history
        )
    }

    /// Goal seek: find x such that `function(x) ≈ target` by minimizing `(function(x) - target)^2`.
    ///
    /// - Parameters:
    ///   - function: The function whose output should match `target`.
    ///   - target: Desired output value.
    ///   - initialValue: Starting point.
    ///   - bounds: Optional bounds (lower, upper).
    ///   - constraints: Optional constraints (defaults to empty).
    /// - Returns: OptimizationResult where `objectiveValue` is the squared residual at the solution.
    ///
    /// - Note: To read the absolute residual, compute `abs(function(result.optimalValue) - target)`.
    func goalSeek(
        function: @escaping (T) -> T,
        target: T,
        initialValue: T,
        bounds: (lower: T, upper: T)? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T> {
        minimize(
            objective: { x in
                let r = function(x) - target
                return r * r
            },
            initialValue: initialValue,
            bounds: bounds,
            constraints: constraints
        )
    }
}
```

### Why these methods?

- Clarity at point of use: minimize, maximize, goalSeek are self-explanatory.
- Safety: maximize returns the true f(x*) in objectiveValue (not the minimized negative).
- Consistency: all methods accept the same shape of arguments, with optional bounds and constraints.
- Defaults: constraints default to an empty array; bounds default to nil (unbounded).

## Usage with convenience methods

- Minimize:
```swift
let resMin = opt.minimize(objective: { x in (x - 5)*(x - 5) }, initialValue: 0.0)
```

- Maximize (bounded):
```swift
let resMax = opt.maximize(
    objective: { x in 100*x - x*x },
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 200.0)
)
```

- Goal seek (with bounds and a non-negativity constraint):
```swift
let nonNegative = Constraint<Double>(type: .greaterThanOrEqual, bound: 0.0)
let resGoal = opt.goalSeek(
    function: { x in x*x + 3*x + 2 },
    target: 42.0,
    initialValue: 1.0,
    bounds: (lower: 0.0, upper: 100.0),
    constraints: [nonNegative]
)
```

## Notes and tips

- 1D only: This optimizer handles scalar x. For multivariate problems, a different design is needed.
- Initialization matters: Newton-style methods prefer an initial value near the solution for fast, stable convergence.
- Bounds vs constraints:
  - Use bounds: (lower, upper) to clamp all iterates into an interval.
  - Use constraints for simple inequalities (e.g., x ≥ 0) or value-based rules. The current implementation projects simple value constraints and clamps to bounds.
- Maximization specifics: Internally, this is minimize(−f). The convenience maximize method fixes the reporting so objectiveValue equals f(x*).

## Should these be convenience methods?

Yes. They improve ergonomics and reduce user error:
- maximize ensures the reported objectiveValue is the actual maximum
- goalSeek encapsulates the “minimize squared residual” pattern cleanly
- minimize provides a clear, canonical entry point

They also align with the library’s API design principles (clarity at point of use, defaults, progressive disclosure) and documentation rules (DocC comments and examples).

Yes. Move the helpers into a protocol extension so every optimizer gets them “for free,” and (optionally) add a DifferentiableOptimizer refinement for derivative-driven methods like Newton–Raphson.

Below is a drop-in extension that provides:
- Minimize/maximize convenience wrappers
- Overloads for common parameter sets
- Bounds-to-constraints, feasibility, and clamping helpers
- A numerical derivative utility usable by derivative-based optimizers

File suggestion: Sources/BusinessMath/Optimization/Optimizer+Convenience.swift

```swift
//
//  Optimizer+Convenience.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/03/25.
//

import Foundation
import Numerics

public extension Optimizer {
    /// Common bounds tuple for scalar optimizers
    typealias Bounds = (lower: T, upper: T)

    // MARK: - Minimize / Optimize Overloads

    /// Alias for `optimize(...)` with named semantics.
    @inlinable
    func minimize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        constraints: [Constraint<T>] = [],
        bounds: Bounds? = nil
    ) -> OptimizationResult<T> {
        optimize(
            objective: objective,
            constraints: constraints,
            initialValue: initialValue,
            bounds: bounds
        )
    }

    /// Convenience overload: no constraints, no bounds.
    @inlinable
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T
    ) -> OptimizationResult<T> {
        optimize(
            objective: objective,
            constraints: [],
            initialValue: initialValue,
            bounds: nil
        )
    }

    /// Convenience overload: with bounds, no constraints.
    @inlinable
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T,
        bounds: Bounds
    ) -> OptimizationResult<T> {
        optimize(
            objective: objective,
            constraints: [],
            initialValue: initialValue,
            bounds: bounds
        )
    }

    // MARK: - Maximize

    /// Maximize by minimizing the negated objective.
    @inlinable
    func maximize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        constraints: [Constraint<T>] = [],
        bounds: Bounds? = nil
    ) -> OptimizationResult<T> {
        let result = optimize(
            objective: { -objective($0) },
            constraints: constraints,
            initialValue: initialValue,
            bounds: bounds
        )

        // Flip the sign of the objective (and derivative if present) in the returned result/history
        let flippedHistory = result.history.map {
            IterationHistory<T>(
                iteration: $0.iteration,
                value: $0.value,
                objective: -$0.objective,
                gradient: -$0.gradient
            )
        }

        return OptimizationResult(
            optimalValue: result.optimalValue,
            objectiveValue: -result.objectiveValue,
            iterations: result.iterations,
            converged: result.converged,
            history: flippedHistory
        )
    }

    // MARK: - Shared Helpers

    /// Convert bounds to hard inequality constraints.
    @inlinable
    func constraints(from bounds: Bounds) -> [Constraint<T>] {
        [
            .init(type: .greaterThanOrEqual, bound: bounds.lower),
            .init(type: .lessThanOrEqual,  bound: bounds.upper)
        ]
    }

    /// Clamp a value into optional bounds.
    @inlinable
    func clamp(_ value: T, to bounds: Bounds?) -> T {
        guard let b = bounds else { return value }
        return max(b.lower, min(value, b.upper))
    }

    /// Check whether a value satisfies both optional bounds and explicit constraints.
    @inlinable
    func isFeasible(
        _ value: T,
        constraints: [Constraint<T>] = [],
        within bounds: Bounds? = nil
    ) -> Bool {
        let withinBounds: Bool = {
            guard let b = bounds else { return true }
            return value >= b.lower && value <= b.upper
        }()
        return withinBounds && constraints.allSatisfy { $0.isSatisfied(value) }
    }

    /// Central-difference numerical derivative builder for derivative-based optimizers.
    @inlinable
    func numericalDerivative(h: T = T(1e-6)) -> (_ f: @escaping (T) -> T) -> (T) -> T {
        { f in { x in (f(x + h) - f(x - h)) / (T(2) * h) } }
    }
}
```

Optional: add a refinement protocol for derivative-based optimizers (e.g., Newton–Raphson). This keeps the base Optimizer simple while giving derivative algorithms a richer API and a safe default via numerical differentiation.

```swift
//
//  DifferentiableOptimizer.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Optimizers that use first derivatives (e.g., Newton–Raphson).
public protocol DifferentiableOptimizer: Optimizer {
    typealias Bounds = (lower: T, upper: T)

    /// Optimize using an explicit derivative.
    func optimize(
        objective: @escaping (T) -> T,
        derivative: @escaping (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: Bounds?
    ) -> OptimizationResult<T>
}

public extension DifferentiableOptimizer {
    /// Convenience: fall back to a numerical derivative if none is provided.
    @inlinable
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T,
        constraints: [Constraint<T>] = [],
        bounds: Bounds? = nil,
        step h: T = T(1e-6)
    ) -> OptimizationResult<T> {
        let d = numericalDerivative(h: h)(objective)
        return optimize(
            objective: objective,
            derivative: d,
            constraints: constraints,
            initialValue: initialValue,
            bounds: bounds
        )
    }
}
```

Usage example
- Any Optimizer gets:
  - optimize(objective:initialValue:)
  - optimize(objective:initialValue:bounds:)
  - minimize(_:from:constraints:bounds:)
  - maximize(_:from:constraints:bounds:)
  - clamp(_:to:), isFeasible(_:constraints:within:), constraints(from:)
  - numericalDerivative(h:)

- A Newton–Raphson type can conform to DifferentiableOptimizer and implement the derivative-aware entry point, while also inheriting the convenience that builds a numerical derivative automatically. This cleanly abstracts the convenience to the protocol layer without constraining non-derivative optimizers.
