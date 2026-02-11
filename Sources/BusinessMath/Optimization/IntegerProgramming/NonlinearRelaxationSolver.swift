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
    /// - Note: The solution may violate constraints by up to `tolerance` due to numerical precision.
    ///   Solutions with violation > tolerance are automatically rejected as infeasible.
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

        // Create InequalityOptimizer for continuous NLP
        let optimizer = InequalityOptimizer<V>(
            constraintTolerance: V.Scalar(tolerance),
            maxIterations: 100,  // Outer iterations
            maxInnerIterations: maxIterations  // Inner iterations
        )

        do {
            // Solve continuous NLP (respecting minimize flag)
            let result = minimize
                ? try optimizer.minimize(objective, from: initialGuess, subjectTo: constraints)
                : try optimizer.maximize(objective, from: initialGuess, subjectTo: constraints)

            // Check feasibility by evaluating constraints at solution
            var maxViolation = 0.0
            for constraint in constraints {
                let violation = max(0.0, constraint.evaluate(at: result.solution))
                maxViolation = max(maxViolation, violation)
            }

            guard maxViolation < tolerance else {
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

            return RelaxationResult(
                solution: solution,
                objectiveValue: result.objectiveValue,
                status: .optimal
            )

        } catch {
            // InequalityOptimizer failed - treat as infeasible
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
}
