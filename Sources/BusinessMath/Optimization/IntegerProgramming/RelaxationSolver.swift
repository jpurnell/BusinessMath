import Foundation
import Numerics

/// Status of a relaxation solver
///
/// Indicates the outcome of solving a continuous relaxation in branch-and-bound.
///
/// ## Cases
/// - `optimal`: Found continuous optimal solution (may be fractional)
/// - `infeasible`: No feasible solution exists for this relaxation
/// - `unbounded`: Objective is unbounded (no finite optimum)
public enum RelaxationStatus: Sendable, Equatable {
    /// Continuous relaxation solved successfully
    case optimal

    /// No feasible solution exists
    case infeasible

    /// Objective is unbounded (no finite optimum)
    case unbounded
}

/// Result from solving a continuous relaxation
///
/// Captures the solution, objective value, and status from a relaxation solver.
/// Used in branch-and-bound to obtain bounds for pruning.
///
/// ## Example
/// ```swift
/// let result = RelaxationResult(
///     solution: VectorN([1.5, 2.5]),
///     objectiveValue: 10.5,
///     status: .optimal
/// )
///
/// if result.status == .optimal, let solution = result.solution {
///     print("Optimal relaxation: \(solution)")
/// }
/// ```
public struct RelaxationResult: Sendable {
    /// Continuous optimal solution (may be fractional)
    ///
    /// `nil` if relaxation is infeasible or unbounded
    public let solution: VectorN<Double>?

    /// Objective value at solution
    ///
    /// - For optimal: finite objective value
    /// - For infeasible (minimization): +∞
    /// - For unbounded (minimization): -∞
    public let objectiveValue: Double

    /// Status of the relaxation solve
    public let status: RelaxationStatus

    /// Simplex tableau and basis (for cut generation)
    ///
    /// Only available when using SimplexRelaxationSolver with optimal solution.
    /// Used to generate Gomory cuts and other cutting planes.
    public let simplexResult: SimplexResult?

    /// Create a relaxation result
    ///
    /// - Parameters:
    ///   - solution: Continuous optimal solution (nil if infeasible/unbounded)
    ///   - objectiveValue: Objective value at solution
    ///   - status: Solver status (optimal/infeasible/unbounded)
    ///   - simplexResult: Optional SimplexResult for cut generation
    public init(
        solution: VectorN<Double>?,
        objectiveValue: Double,
        status: RelaxationStatus,
        simplexResult: SimplexResult? = nil
    ) {
        self.solution = solution
        self.objectiveValue = objectiveValue
        self.status = status
        self.simplexResult = simplexResult
    }
}

/// Protocol for solving continuous relaxations in branch-and-bound
///
/// Relaxation solvers compute continuous (non-integer) bounds for
/// integer programming problems by relaxing integrality constraints.
///
/// ## Implementations
/// - **SimplexRelaxationSolver**: Fast LP relaxations for linear problems
/// - **NonlinearRelaxationSolver**: NLP relaxations for nonlinear problems
///
/// ## Usage in Branch-and-Bound
/// At each node in the branch-and-bound tree:
/// 1. Solve continuous relaxation (ignore integer constraints)
/// 2. Use relaxation bound for pruning (fathoming)
/// 3. If relaxation solution is fractional, branch on a variable
///
/// ## Example
/// ```swift
/// let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)
///
/// let result = try solver.solveRelaxation(
///     objective: { v in 2.0 * v[0] + 3.0 * v[1] },
///     constraints: [
///         .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
///     ],
///     initialGuess: VectorN([0.5, 0.5]),
///     minimize: true
/// )
///
/// if result.status == .optimal {
///     print("Relaxation bound: \(result.objectiveValue)")
/// }
/// ```
public protocol RelaxationSolver: Sendable {
    /// Solve continuous relaxation of an optimization problem
    ///
    /// Ignores integrality constraints and solves the continuous problem:
    /// - **Minimization**: min f(x) subject to g(x) ≤ 0, x ∈ ℝⁿ
    /// - **Maximization**: max f(x) subject to g(x) ≤ 0, x ∈ ℝⁿ
    ///
    /// - Parameters:
    ///   - objective: Objective function f(x) to minimize or maximize
    ///   - constraints: Constraints g(x) ≤ 0 (linear or nonlinear)
    ///   - initialGuess: Starting point for continuous solver
    ///   - minimize: If `true`, minimize; if `false`, maximize
    ///
    /// - Returns: RelaxationResult with solution, objective value, and status
    ///
    /// - Throws: OptimizationError if solver encounters fatal error
    ///
    /// ## Status Interpretation
    /// - `.optimal`: Continuous optimum found (may be fractional)
    /// - `.infeasible`: No feasible solution exists
    /// - `.unbounded`: Objective is unbounded
    func solveRelaxation<V: VectorSpace>(
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        initialGuess: V,
        minimize: Bool
    ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable
}
