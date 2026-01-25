import Foundation
import Numerics

/// Relaxation solver using SimplexSolver for linear programming
///
/// Wraps the SimplexSolver to implement the RelaxationSolver protocol.
/// Used for fast LP relaxations in branch-and-bound.
///
/// ## How It Works
/// 1. Extract linear coefficients from objective function (finite differences)
/// 2. Convert MultivariateConstraint → SimplexConstraint
/// 3. Solve LP using SimplexSolver
/// 4. Convert SimplexResult → RelaxationResult
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
///     print("LP bound: \(result.objectiveValue)")
/// }
/// ```
public struct SimplexRelaxationSolver: RelaxationSolver {
    /// Tolerance for LP solver
    public let lpTolerance: Double

    /// Create SimplexRelaxationSolver
    ///
    /// - Parameter lpTolerance: Tolerance for simplex algorithm (default: 1e-8)
    public init(lpTolerance: Double = 1e-8) {
        self.lpTolerance = lpTolerance
    }

    public func solveRelaxation<V: VectorSpace>(
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        initialGuess: V,
        minimize: Bool
    ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {

        let dimension = initialGuess.toArray().count

        // Step 1: Extract linear coefficients from objective
        let objectiveCoeffs = try extractLinearCoefficients(objective, at: initialGuess, dimension: dimension)

        // Compute constant term in objective: f(x) = c·x + d
        // d = f(x) - c·x
        let fx = objective(initialGuess)
        let cx = zip(objectiveCoeffs, initialGuess.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 }
        let objectiveConstant = fx - cx

        // Step 2: Convert constraints to simplex form
        // First pass: collect all constraint info
        typealias ConstraintInfo = (coeffs: [Double], rhs: Double, relation: ConstraintRelation, isNonNegativity: Bool)

        var allConstraintInfo: [ConstraintInfo] = []

        for constraint in constraints {
            // Extract linear coefficients from constraint function
            let coeffs = try extractLinearCoefficients(constraint.function, at: initialGuess, dimension: dimension)

            // Compute constant term: For g(x) = c·x + d
            // d = g(x) - c·x
            let gx = constraint.evaluate(at: initialGuess)
            let cx = zip(coeffs, initialGuess.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 }
            let constantTerm = gx - cx

            // For g(x) ≤ 0: c·x + d ≤ 0  =>  c·x ≤ -d
            var rhs = -constantTerm

            // Clean up numerical noise
            let roundedRHS = round(rhs)
            if abs(rhs - roundedRHS) < lpTolerance * 10 {
                rhs = roundedRHS
            }
            if abs(rhs) < lpTolerance {
                rhs = 0.0
            }

            // Check if this is a non-negativity constraint
            // These are constraints like -x_i ≤ 0 (SimplexSolver assumes x ≥ 0)
            let nonzeroIndices = coeffs.enumerated().filter { abs($0.element) > lpTolerance }.map { $0.offset }
            var isNonNegativity = false
            if nonzeroIndices.count == 1 {
                let idx = nonzeroIndices[0]
                if coeffs[idx] < 0 && abs(rhs) < lpTolerance {
                    isNonNegativity = true
                }
            }

            // Determine relation type
            let relation: ConstraintRelation
            if constraint.isEquality {
                relation = .equal
            } else {
                relation = .lessOrEqual
            }

            allConstraintInfo.append((
                coeffs: coeffs,
                rhs: rhs,
                relation: relation,
                isNonNegativity: isNonNegativity
            ))
        }

        // Second pass: decide which constraints to keep
        // If ALL constraints are non-negativity, keep them (SimplexSolver needs at least one constraint)
        // Otherwise, skip non-negativity constraints as redundant (SimplexSolver assumes x ≥ 0)
        let nonNonNegativityCount = allConstraintInfo.filter { !$0.isNonNegativity }.count
        let shouldSkipNonNegativity = nonNonNegativityCount > 0

        var simplexConstraints: [SimplexConstraint] = []
        for info in allConstraintInfo {
            if info.isNonNegativity && shouldSkipNonNegativity {
                continue  // Skip redundant non-negativity
            }

            simplexConstraints.append(SimplexConstraint(
                coefficients: info.coeffs,
                relation: info.relation,
                rhs: info.rhs
            ))
        }

        // Step 3: Solve LP with SimplexSolver
        let solver = SimplexSolver(tolerance: lpTolerance)

        do {
            let result = minimize
                ? try solver.minimize(objective: objectiveCoeffs, subjectTo: simplexConstraints)
                : try solver.maximize(objective: objectiveCoeffs, subjectTo: simplexConstraints)

            // Step 4: Convert SimplexResult → RelaxationResult
            guard result.status == .optimal else {
                // Infeasible or unbounded
                let objValue: Double
                let status: RelaxationStatus

                if result.status == .unbounded {
                    objValue = minimize ? -Double.infinity : Double.infinity
                    status = .unbounded
                } else {
                    objValue = minimize ? Double.infinity : -Double.infinity
                    status = .infeasible
                }

                return RelaxationResult(
                    solution: nil,
                    objectiveValue: objValue,
                    status: status
                )
            }

            // Convert solution to VectorN<Double>
            let solution = VectorN(result.solution)

            // Add back the constant term to get true objective value
            let trueObjectiveValue = result.objectiveValue + objectiveConstant

            return RelaxationResult(
                solution: solution,
                objectiveValue: trueObjectiveValue,
                status: .optimal,
                simplexResult: result  // Include for cut generation
            )

        } catch {
            // Solver error - treat as infeasible
            return RelaxationResult(
                solution: nil,
                objectiveValue: minimize ? Double.infinity : -Double.infinity,
                status: .infeasible
            )
        }
    }

    /// Extract linear coefficients from a function using finite differences
    ///
    /// For a linear function f(x) = c₁x₁ + c₂x₂ + ... + cₙxₙ + b,
    /// this computes the gradient which gives the coefficients [c₁, c₂, ..., cₙ]
    ///
    /// - Parameters:
    ///   - function: Function to extract coefficients from
    ///   - point: Point at which to evaluate gradient
    ///   - dimension: Number of variables
    /// - Returns: Array of linear coefficients
    private func extractLinearCoefficients<V: VectorSpace>(
        _ function: @escaping (V) -> V.Scalar,
        at point: V,
        dimension: Int
    ) throws -> [Double] where V.Scalar == Double, V: Sendable {
        var coeffs: [Double] = []
        let h = V.Scalar(1e-8)

        for i in 0..<dimension {
            var pointPlus = point.toArray()
            pointPlus[i] += Double(h)
            let vecPlus = V.fromArray(pointPlus) ?? point

            var pointMinus = point.toArray()
            pointMinus[i] -= Double(h)
            let vecMinus = V.fromArray(pointMinus) ?? point

            let fPlus = function(vecPlus)
            let fMinus = function(vecMinus)
            let derivative = (fPlus - fMinus) / (2.0 * Double(h))

            coeffs.append(derivative)
        }

        return coeffs
    }
}
