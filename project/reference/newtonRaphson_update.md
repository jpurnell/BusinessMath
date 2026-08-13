/// Optimizes a 1D objective using a safeguarded Newton–Raphson method with backtracking line search.
///
/// Improves robustness over a raw Newton step by:
/// - Using central finite differences and reusing f(x) for f′′
/// - Adapting the finite-difference step to the scale of x
/// - Safeguarding curvature (falls back to gradient step when f″ is non-positive or too small)
/// - Applying Armijo backtracking line search
/// - Respecting bounds and simple value-based constraints via projection
///
/// - Parameters:
///   - objective: The objective function f(x) to minimize.
///   - constraints: Constraints the solution must satisfy. Simple value-based constraints
///     (where `constraint.function == nil`) are projected to their boundary if violated.
///   - initialValue: Starting point for the search.
///   - bounds: Optional bounds (lower, upper); iterates are clamped into this interval.
/// - Returns: An `OptimizationResult` with the best value found, its objective, iterations, convergence flag, and history.
///
/// - Important: Newton converges quickly near well-conditioned minima (f″ > 0). When curvature is
///   non-positive or ill-conditioned, this method switches to a gradient step and uses a line search.
///
/// - Complexity: O(k · m), where k is the number of iterations and m the number of backtracking steps.
///
/// ## Usage Example
/// ```swift
/// let optimizer = NewtonRaphsonOptimizer<Double>(tolerance: 1e-8, maxIterations: 100, stepSize: 1e-4)
/// let result = optimizer.optimize(
///     objective: { x in (x - 5) * (x - 5) },
///     constraints: [],
///     initialValue: 0.0,
///     bounds: nil
/// )
/// // result.optimalValue ≈ 5.0
/// ```
public func optimize(
    objective: @escaping (T) -> T,
    constraints: [Constraint<T>],
    initialValue: T,
    bounds: (lower: T, upper: T)?
) -> OptimizationResult<T> {
    // Local helpers kept within function scope.
    func clamp(_ value: T, lower: T, upper: T) -> T {
        max(lower, min(upper, value))
    }

    func allConstraintsSatisfied(_ value: T, constraints: [Constraint<T>]) -> Bool {
        for c in constraints {
            if !c.isSatisfied(value) { return false }
        }
        return true
    }

    func projectToFeasibleRegion(
        _ value: T,
        constraints: [Constraint<T>],
        bounds: (lower: T, upper: T)?
    ) -> T {
        var x = value
        if let b = bounds {
            x = clamp(x, lower: b.lower, upper: b.upper)
        }
        if allConstraintsSatisfied(x, constraints: constraints) {
            return x
        }
        for c in constraints where !c.isSatisfied(x) {
            if c.function == nil {
                switch c.type {
                case .greaterThan:
                    x = max(x, c.bound + tolerance)
                case .greaterThanOrEqual:
                    x = max(x, c.bound)
                case .lessThan:
                    x = min(x, c.bound - tolerance)
                case .lessThanOrEqual:
                    x = min(x, c.bound)
                case .equalTo:
                    x = c.bound
                }
            }
        }
        if let b = bounds {
            x = clamp(x, lower: b.lower, upper: b.upper)
        }
        return x
    }

    func finiteDifferences(
        f: @escaping (T) -> T,
        at x: T,
        baseH: T
    ) -> (fx: T, f1: T, f2: T) {
        // Adaptive central difference step based on x scale; avoids tiny literals.
        let h = max(baseH, baseH * (T(1) + abs(x)))
        let fx = f(x)
        let fph = f(x + h)
        let fmh = f(x - h)
        let f1 = (fph - fmh) / (T(2) * h)
        let f2 = (fph - T(2) * fx + fmh) / (h * h)
        return (fx, f1, f2)
    }

    // Initialize and project start to feasibility
    var x = initialValue
    if let b = bounds {
        x = clamp(x, lower: b.lower, upper: b.upper)
    }
    x = projectToFeasibleRegion(x, constraints: constraints, bounds: bounds)

    var history: [IterationHistory<T>] = []
    var converged = false

    // Line search parameters without float literals
    let c1: T = T(1) / T(10_000)         // 1e-4
    let backtrack: T = T(1) / T(2)       // 0.5
    let minLambda: T = tolerance / T(1_000)

    // Curvature safeguard tied to problem scales
    let curvatureEps = max(tolerance / T(1_000), stepSize / T(100))

    for iteration in 0..<maxIterations {
        let (fx, g, h2) = finiteDifferences(f: objective, at: x, baseH: stepSize)

        history.append(IterationHistory(iteration: iteration, value: x, objective: fx, gradient: g))

        // Converged if gradient is small
        if abs(g) <= tolerance {
            converged = true
            break
        }

        // Choose step "p" (to be subtracted): Newton if curvature is safe, else gradient
        let useNewton = h2 > curvatureEps
        let p = useNewton ? (g / h2) : g
        if abs(p) <= tolerance {
            converged = true
            break
        }

        // Backtracking Armijo line search on xNew = x - λ p
        var lambda: T = T(1)
        var accepted = false
        var xNew = x
        var fNew = fx

        // If g*p <= 0, force a descent-like step using gradient-scale
        let gp = g * p
        let effectiveP = gp > T(0) ? p : (g == T(0) ? T(0) : (g / T(10)))

        while lambda >= minLambda {
            let trial = x - lambda * effectiveP
            let projected = projectToFeasibleRegion(trial, constraints: constraints, bounds: bounds)

            if abs(projected - x) <= tolerance {
                xNew = projected
                fNew = objective(xNew)
                accepted = true
                break
            }

            let fTrial = objective(projected)
            if fTrial <= fx - c1 * lambda * g * effectiveP {
                xNew = projected
                fNew = fTrial
                accepted = true
                break
            }

            lambda *= backtrack
        }

        // If no acceptable step found, attempt a tiny feasibility/minimization move; otherwise stop
        if !accepted {
            let tiny = tolerance
            let direction: T = (g >= T(0)) ? T(1) : T(-1)
            let xTiny = projectToFeasibleRegion(x - tiny * direction, constraints: constraints, bounds: bounds)
            let fTiny = objective(xTiny)
            if fTiny < fx && abs(xTiny - x) > tolerance {
                x = xTiny
                continue
            }
            break
        }

        let movement = abs(xNew - x)
        let objChange = abs(fNew - fx)
        x = xNew

        if movement <= tolerance * (T(1) + abs(x)) { converged = true; break }
        if objChange <= tolerance * (T(1) + abs(fx)) { converged = true; break }
    }

    return OptimizationResult(
        optimalValue: x,
        objectiveValue: objective(x),
        iterations: history.count,
        converged: converged,
        history: history
    )
}
