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
