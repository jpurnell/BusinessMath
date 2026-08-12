import Foundation
import Numerics

/// Relaxation solver using InequalityOptimizer for nonlinear programming
///
/// Wraps the InequalityOptimizer to implement the RelaxationSolver protocol.
/// Used for NLP relaxations in MINLP (Mixed-Integer Nonlinear Programming).
///
/// ## How It Works
/// 1. Use InequalityOptimizer to solve continuous NLP
/// 2. Check feasibility via maximum constraint violation
/// 3. Convert ConstrainedOptimizationResult → RelaxationResult
/// 4. Handle solver failures gracefully (treat as infeasible)
///
/// ## Example
/// ```swift
/// let solver = NonlinearRelaxationSolver()
///
/// // Quadratic objective with nonlinear constraint
/// let result = try solver.solveRelaxation(
///     objective: { v in v[0]*v[0] + v[1]*v[1] },
///     constraints: [
///         .inequality { v in v[0]*v[0] + v[1]*v[1] - 1.0 }  // Circle
///     ],
///     initialGuess: VectorN([0.5, 0.5]),
///     minimize: true
/// )
///
/// if result.status == .optimal {
///     print("NLP bound: \(result.objectiveValue)")
/// }
/// ```
public struct NonlinearRelaxationSolver: RelaxationSolver {
    /// Maximum iterations for inner NLP solver
    public let maxIterations: Int

    /// Tolerance for constraint satisfaction
    public let tolerance: Double

    /// Create NonlinearRelaxationSolver
    ///
    /// - Parameters:
    ///   - maxIterations: Maximum iterations for NLP solver (default: 1000)
    ///   - tolerance: Constraint feasibility tolerance (default: 1e-6)
    public init(maxIterations: Int = 1000, tolerance: Double = 1e-6) {
        self.maxIterations = maxIterations
        self.tolerance = tolerance
    }

    /// Solve the continuous relaxation of an integer programming problem using nonlinear optimization.
    ///
    /// This method solves the continuous relaxation of a Mixed-Integer Nonlinear Programming (MINLP)
    /// problem by removing integer constraints and solving the resulting Nonlinear Programming (NLP)
    /// problem. The solution provides a bound for branch-and-bound algorithms.
    ///
    /// Uses `InequalityOptimizer` to handle nonlinear objectives and constraints through interior-point
    /// methods. If the optimizer fails to converge or produces an infeasible solution, the result is
    /// marked as infeasible.
    ///
    /// - Parameters:
    ///   - objective: The objective function to optimize. Takes a vector and returns a scalar value.
    ///     Can be nonlinear (quadratic, exponential, etc.).
    ///   - constraints: Array of multivariate constraints (inequalities or equalities). Each constraint
    ///     function should evaluate to ≤ 0 for feasibility.
    ///   - initialGuess: Starting point for the optimization algorithm. Should be in the interior of
    ///     the feasible region when possible for better convergence.
    ///   - minimize: `true` to minimize the objective, `false` to maximize.
    ///
    /// - Returns: A `RelaxationResult` containing:
    ///   - `solution`: The optimal continuous solution (as `VectorN<Double>`), or `nil` if infeasible
    ///   - `objectiveValue`: The optimal objective value, or ±∞ if infeasible
    ///   - `status`: `.optimal` if solution found, `.infeasible` if no feasible solution exists
    ///
    /// - Throws: Does not throw. Optimization failures are returned as infeasible results.
    ///
    /// - Complexity: Depends on the problem structure. For smooth convex problems, typically O(n³)
    ///   per iteration where n is the dimension. Non-convex problems may require many iterations.
    ///
    /// ## Algorithm Details
    ///
    /// 1. **Interior-Point Method**: Uses `InequalityOptimizer` with barrier functions
    /// 2. **Feasibility Check**: Evaluates all constraints at the solution with tolerance checking
    /// 3. **Error Handling**: Treats optimizer failures as infeasibility rather than throwing errors
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // Portfolio optimization with risk constraint
    /// let solver = NonlinearRelaxationSolver(maxIterations: 1000, tolerance: 1e-6)
    ///
    /// // Minimize portfolio variance
    /// let result = try solver.solveRelaxation(
    ///     objective: { weights in
    ///         // Quadratic form: wᵀΣw
    ///         let w = weights.toArray()
    ///         var variance = 0.0
    ///         for i in 0..<w.count {
    ///             for j in 0..<w.count {
    ///                 variance += w[i] * covariance[i][j] * w[j]
    ///             }
    ///         }
    ///         return variance
    ///     },
    ///     constraints: [
    ///         // Weights sum to 1
    ///         .equality { w in w.toArray().reduce(0, +) - 1.0 },
    ///         // Minimum expected return
    ///         .inequality { w in 0.08 - dot(expectedReturns, w.toArray()) }
    ///     ],
    ///     initialGuess: VectorN(Array(repeating: 1.0 / n, count: n)),
    ///     minimize: true
    /// )
    ///
    /// if result.status == .optimal, let solution = result.solution {
    ///     print("Optimal weights: \(solution)")
    ///     print("Minimum variance: \(result.objectiveValue)")
    /// } else {
    ///     print("No feasible solution found")
    /// }
    /// ```
    ///
    /// ## When to Use
    ///
    /// - **Nonlinear problems**: Quadratic objectives, exponential constraints, etc.
    /// - **MINLP relaxations**: Computing bounds for branch-and-cut algorithms
    /// - **Portfolio optimization**: Variance minimization with nonlinear constraints
    /// - **Engineering design**: Problems with physical laws (heat transfer, fluid dynamics)
    ///
    /// - Important: For linear problems, use ``SimplexRelaxationSolver`` instead for much better
    ///   performance (O(n²) vs O(n³)). Only use this solver when nonlinearity is essential.
    ///
    /// - Note: Feasibility is judged *relative* to the size of each constraint, not against an
    ///   absolute residual. A solution is rejected only when some constraint is violated by more
    ///   than `tolerance` times that constraint's own characteristic magnitude. Equality
    ///   constraints are measured as `|h(x)|` and inequalities as `max(0, g(x))`.
    ///
    /// - SeeAlso:
    ///   - ``SimplexRelaxationSolver``
    ///   - ``InequalityOptimizer``
    ///   - ``RelaxationResult``
    ///   - ``MultivariateConstraint``
    public func solveRelaxation<V: VectorSpace>(
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        initialGuess: V,
        minimize: Bool
    ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {

        // Create InequalityOptimizer for continuous NLP.
        //
        // Both tolerances come from the caller. Leaving `gradientTolerance` at its
        // default silently held the stationarity half of the KKT test at 1e-6 no
        // matter what accuracy the caller asked for — a caller loosening `tolerance`
        // to 1e-3 for speed still paid for 1e-6 stationarity, and a caller tightening
        // it never got the tighter test it asked for.
        let optimizer = InequalityOptimizer<V>(
            constraintTolerance: V.Scalar(tolerance),
            gradientTolerance: V.Scalar(tolerance),
            maxIterations: 100,  // Outer iterations
            maxInnerIterations: maxIterations  // Inner iterations
        )

        do {
            // Solve continuous NLP (respecting minimize flag)
            let result = minimize
                ? try optimizer.minimize(objective, from: initialGuess, subjectTo: constraints)
                : try optimizer.maximize(objective, from: initialGuess, subjectTo: constraints)

            // Check feasibility by evaluating constraints at solution
            let maxViolation = Self.maxRelativeViolation(
                at: result.solution,
                constraints: constraints
            )

            guard maxViolation <= tolerance else {
                // Solution violates constraints - treat as infeasible
                return RelaxationResult(
                    solution: nil,
                    objectiveValue: minimize ? Double.infinity : -Double.infinity,
                    status: .infeasible
                )
            }

            // Convert solution to VectorN<Double>
            let solution: VectorN<Double>
            if let vectorN = result.solution as? VectorN<Double> {
                solution = vectorN
            } else {
                // Convert from generic VectorSpace to VectorN
                solution = VectorN(result.solution.toArray())
            }

            // `result.converged` is deliberately not used as a rejection criterion.
            // ``RelaxationStatus`` has no "feasible but unproven" case, so the only
            // thing this method could do with a non-converged solve is call it
            // `.infeasible` — which would throw away a point that is in the feasible
            // set and delete the whole subtree hanging off this node. A feasible
            // point with a soft bound is strictly more information than none.
            return RelaxationResult(
                solution: solution,
                objectiveValue: result.objectiveValue,
                status: .optimal
            )

        } catch { // logging: InequalityOptimizer failed — treat as infeasible relaxation
            // This can happen if:
            // - Initial guess is infeasible and optimizer can't recover
            // - Problem is truly infeasible
            // - Numerical issues prevent convergence
            return RelaxationResult(
                solution: nil,
                objectiveValue: minimize ? Double.infinity : -Double.infinity,
                status: .infeasible
            )
        }
    }

    // MARK: - Feasibility

    /// The largest constraint violation at `point`, measured relative to the size of the
    /// constraint that was violated.
    ///
    /// Two things were wrong with the absolute `max(0, g(x))` test this replaces, and each
    /// one on its own produced a wrong answer rather than a slow one.
    ///
    /// **Equalities are not inequalities.** `max(0, ·)` is the violation rule for `g(x) ≤ 0`.
    /// Applied to an equality `h(x) = 0` it reads every *negative* residual as no violation at
    /// all, so a point that misses the equality on the low side passed the gate and was
    /// certified `.optimal`. On `minimize xy subject to x + y = 4` that is the difference
    /// between reporting the optimum and reporting a point that is not in the feasible set.
    /// The rule is `|h(x)|` for an equality and `max(0, g(x))` for an inequality — the same
    /// split ``MultivariateConstraint/isSatisfied(at:tolerance:)`` already makes.
    ///
    /// **The tolerance has units.** ``InequalityOptimizer`` solves in equilibrated
    /// coordinates: it divides each constraint by its own characteristic magnitude and judges
    /// `constraintTolerance` there. What it guarantees on return is therefore
    /// `violation ≤ tolerance · scale`, not `violation ≤ tolerance`. Re-testing the raw
    /// residual against the raw tolerance demands an accuracy the optimizer never promised and
    /// cannot deliver, and the penalty for missing it is not a warning — the node is discarded
    /// as infeasible. `minimize x² subject to 2 ≤ x ≤ 5` converged to `x = 1.9999986`, a
    /// residual of 1.35e-6 against a constraint of magnitude 2; the absolute test called the
    /// root relaxation of a trivially feasible problem infeasible, and branch-and-bound
    /// returned the caller's initial guess with an objective of infinity.
    ///
    /// The scale used here is `‖∇g(x)‖∞ · ‖x‖∞`, floored at 1 so that a constraint which is
    /// genuinely O(1) is still held to an absolute tolerance and so that the divisor can never
    /// be zero. Where the gradient cannot be taken the scale falls back to 1, which is the
    /// conservative direction: it makes the test stricter, never laxer.
    ///
    /// - Parameters:
    ///   - point: Point at which to measure feasibility.
    ///   - constraints: Constraints defining the feasible region.
    /// - Returns: The largest relative violation over all constraints; 0 when every constraint
    ///   is satisfied.
    static func maxRelativeViolation<V: VectorSpace>(
        at point: V,
        constraints: [MultivariateConstraint<V>]
    ) -> Double where V.Scalar == Double, V: Sendable {

        let components = point.toArray()
        let largestComponent = components.reduce(0.0) { max($0, abs($1)) }
        let pointScale = max(1.0, largestComponent)

        var worst = 0.0

        for constraint in constraints {
            let residual = constraint.evaluate(at: point)
            let violation = constraint.isEquality ? abs(residual) : max(0.0, residual)

            // Satisfied constraints cost nothing and need no gradient.
            guard violation > 0.0 else { continue }

            let gradientNorm: Double
            if let gradient = try? constraint.gradient(at: point) {
                let norm = gradient.toArray().reduce(0.0) { max($0, abs($1)) }
                gradientNorm = norm.isFinite ? norm : 1.0
            } else {
                gradientNorm = 1.0
            }

            // Floored at 1, so the division below is always by a value ≥ 1.
            let magnitude: Double = gradientNorm * pointScale
            let scale = max(1.0, magnitude)
            let relative = violation / scale

            worst = max(worst, relative)
        }

        return worst
    }
}
