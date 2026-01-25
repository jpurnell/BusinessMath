import Foundation
import Numerics

/// Represents a variable transformation to handle negative lower bounds
///
/// The SimplexSolver requires x ≥ 0, but users want to write constraints like x ≥ -3.
/// Variable shifting transforms the problem:
///
/// ## Example
/// ```
/// Original problem:  minimize f(x) where x ∈ [-3, 5]
/// Shifted problem:   minimize f(y - 3) where y ∈ [0, 8]
/// ```
///
/// After solving for y, we transform back: x = y - 3
///
/// ## Usage
/// ```swift
/// // Extract shifts from constraints
/// let shift = try extractVariableShift(from: constraints, dimension: 2)
///
/// if shift.needsShift {
///     // Transform problem
///     let shiftedPoint = shift.shiftPoint(originalPoint)
///     let shiftedConstraints = try constraints.map { try shift.transformConstraint($0) }
///
///     // Solve shifted problem...
///
///     // Transform solution back
///     let originalSolution = shift.unshiftPoint(shiftedSolution)
/// }
/// ```
public struct VariableShift: Sendable {
    /// Shift amount for each variable (negative of lower bound)
    ///
    /// For each variable i: y_i = x_i - shifts[i]
    /// - If x_i ≥ -3, then shifts[i] = -3 and y_i = x_i + 3
    /// - If x_i ≥ 0, then shifts[i] = 0 and y_i = x_i
    public let shifts: [Double]

    /// Whether any variable needs shifting
    public let needsShift: Bool

    /// Create variable shift
    ///
    /// - Parameters:
    ///   - shifts: Shift amount for each variable
    ///   - needsShift: Whether shifting is required
    public init(shifts: [Double], needsShift: Bool) {
        self.shifts = shifts
        self.needsShift = needsShift
    }

    /// Transform point from original to shifted space
    ///
    /// Computes: y_i = x_i - shifts[i] for each variable
    ///
    /// - Parameter original: Point in original space
    /// - Returns: Point in shifted space
    public func shiftPoint(_ original: VectorN<Double>) -> VectorN<Double> {
        guard needsShift else { return original }

        let components = original.toArray()
        let shifted = zip(components, shifts).map { $0 - $1 }
        return VectorN(shifted)
    }

    /// Transform point from shifted back to original space
    ///
    /// Computes: x_i = y_i + shifts[i] for each variable
    ///
    /// - Parameter shifted: Point in shifted space
    /// - Returns: Point in original space
    public func unshiftPoint(_ shifted: VectorN<Double>) -> VectorN<Double> {
        guard needsShift else { return shifted }

        let components = shifted.toArray()
        let original = zip(components, shifts).map { $0 + $1 }
        return VectorN(original)
    }

    /// Transform objective coefficients
    ///
    /// For linear objectives f(x) = c·x + d, the coefficients don't change:
    /// f(y) = c·(y + shift) = c·y + c·shift
    /// The constant term changes but doesn't affect the optimal y.
    ///
    /// - Parameter coefficients: Original objective coefficients
    /// - Returns: Transformed coefficients (unchanged for linear objectives)
    public func transformObjectiveCoefficients(_ coefficients: [Double]) -> [Double] {
        // Linear objective coefficients don't change
        return coefficients
    }

    /// Transform constraint to shifted variable space
    ///
    /// For a linear constraint c·x {≤, ≥, =} b, we substitute x = y + shift:
    /// c·(y + shift) {≤, ≥, =} b
    /// c·y + c·shift {≤, ≥, =} b
    /// c·y {≤, ≥, =} b - c·shift
    ///
    /// - Parameter constraint: Original constraint
    /// - Returns: Transformed constraint
    /// - Throws: If constraint is not a linear constraint
    public func transformConstraint(_ constraint: MultivariateConstraint<VectorN<Double>>) throws -> MultivariateConstraint<VectorN<Double>> {
        guard needsShift else { return constraint }

        switch constraint {
        case .linearInequality(let coeffs, let rhs, let sense):
            // Compute c·shift
            let cDotShift = zip(coeffs, shifts).reduce(0.0) { $0 + $1.0 * $1.1 }

            // New RHS: b - c·shift
            let newRHS = rhs - cDotShift

            return .linearInequality(
                coefficients: coeffs,  // Coefficients unchanged
                rhs: newRHS,
                sense: sense
            )

        case .linearEquality(let coeffs, let rhs):
            // Same transformation for equality
            let cDotShift = zip(coeffs, shifts).reduce(0.0) { $0 + $1.0 * $1.1 }
            let newRHS = rhs - cDotShift

            return .linearEquality(
                coefficients: coeffs,
                rhs: newRHS
            )

        case .equality, .inequality:
            // Non-linear constraints: would need to wrap the function
            // For now, throw an error
            throw OptimizationError.invalidInput(
                message: "Variable shifting only supports linear constraints. Convert closure-based constraints to linear form first."
            )
        }
    }
}

/// Extract variable shifts from constraints
///
/// Analyzes constraints to find lower bounds for each variable.
/// If any variable has a negative lower bound, shifting is needed.
///
/// ## Algorithm
/// 1. Initialize all shifts to 0 (assumes x ≥ 0 by default)
/// 2. Scan linear inequality constraints for lower bounds (x_i ≥ b)
/// 3. If b < 0, set shifts[i] = b
/// 4. Return VariableShift with needsShift = true if any shift is non-zero
///
/// ## Example
/// ```swift
/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
///     .linearInequality(coefficients: [1.0, 0.0], rhs: -3.0, sense: .greaterOrEqual), // x ≥ -3
///     .linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual)   // y ≥ 0
/// ]
///
/// let shift = try extractVariableShift(from: constraints, dimension: 2)
/// // shift.shifts == [-3.0, 0.0]
/// // shift.needsShift == true
/// ```
///
/// - Parameters:
///   - constraints: Constraints to analyze
///   - dimension: Number of variables
/// - Returns: VariableShift structure with detected shifts
/// - Throws: If constraints have incompatible forms
public func extractVariableShift(
    from constraints: [MultivariateConstraint<VectorN<Double>>],
    dimension: Int
) throws -> VariableShift {
    // Initialize all shifts to 0 (default: x ≥ 0)
    var shifts = Array(repeating: 0.0, count: dimension)

    // Scan constraints for lower bounds
    for constraint in constraints {
        switch constraint {
        case .linearInequality(let coeffs, let rhs, let sense):
            guard coeffs.count == dimension else {
                throw OptimizationError.invalidInput(
                    message: "Constraint has \(coeffs.count) coefficients, expected \(dimension)"
                )
            }

            // Look for constraints of form: x_i ≥ b (single variable lower bound)
            // Check if this is a single-variable constraint
            var nonZeroIndex: Int? = nil
            var nonZeroCount = 0

            for (i, coeff) in coeffs.enumerated() {
                if abs(coeff) > 1e-10 {
                    nonZeroCount += 1
                    nonZeroIndex = i
                }
            }

            // Single variable constraint
            if nonZeroCount == 1, let i = nonZeroIndex {
                let coeff = coeffs[i]

                if sense == .greaterOrEqual {
                    // coeff[i] * x_i ≥ rhs
                    if abs(coeff - 1.0) < 1e-10 {
                        // x_i ≥ rhs
                        if rhs < 0 {
                            // Negative lower bound - need to shift
                            shifts[i] = rhs
                        }
                    } else if abs(coeff + 1.0) < 1e-10 {
                        // -x_i ≥ rhs  →  x_i ≤ -rhs
                        // This is an upper bound, not a lower bound
                    } else {
                        // General form: c*x_i ≥ rhs  →  x_i ≥ rhs/c (if c > 0)
                        if coeff > 0 {
                            let lowerBound = rhs / coeff
                            if lowerBound < 0 {
                                shifts[i] = lowerBound
                            }
                        }
                    }
                } else if sense == .lessOrEqual {
                    // coeff[i] * x_i ≤ rhs
                    if abs(coeff + 1.0) < 1e-10 {
                        // -x_i ≤ rhs  →  x_i ≥ -rhs
                        let lowerBound = -rhs
                        if lowerBound < 0 {
                            // Negative lower bound - need to shift
                            shifts[i] = lowerBound
                        }
                    } else if abs(coeff - 1.0) < 1e-10 {
                        // x_i ≤ rhs
                        // This is an upper bound, not a lower bound
                    } else {
                        // General form: c*x_i ≤ rhs  →  x_i ≥ rhs/c (if c < 0)
                        if coeff < 0 {
                            let lowerBound = rhs / coeff
                            if lowerBound < 0 {
                                shifts[i] = lowerBound
                            }
                        }
                    }
                }
            }

        case .linearEquality:
            // Equality constraints don't provide bounds
            continue

        case .equality, .inequality:
            // Non-linear constraints: can't extract bounds
            continue
        }
    }

    // Check if any shifts are non-zero
    let needsShift = shifts.contains { abs($0) > 1e-10 }

    return VariableShift(shifts: shifts, needsShift: needsShift)
}
