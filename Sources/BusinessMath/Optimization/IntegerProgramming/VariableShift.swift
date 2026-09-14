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
/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
/// let originalPoint = VectorN<Double>([1.0, 2.0])
///
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
///     let shiftedSolution = shiftedPoint
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

    /// `y + offsets`, the same mapping ``unshiftPoint(_:)`` performs, as a static so a
    /// `@Sendable` closure can capture the offsets by value rather than capturing `self`.
    static func translate(_ point: VectorN<Double>, by offsets: [Double]) -> VectorN<Double> {
        let components = point.toArray()
        let moved = zip(components, offsets).map { $0 + $1 }
        return VectorN(moved)
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

        case .inequality(let g, let gradient):
            // A closure needs no inspection to shift — only composition. The substitution
            // is `x = y + shift`, so the constraint in shifted coordinates is
            // `g(y + shift) <= 0`, which is `g` applied to the unshifted point.
            //
            // This used to throw, which made `enableVariableShifting` refuse any model
            // carrying a closure constraint — including the one whose bound the extractor
            // had just recovered. `unshiftPoint` already performs exactly this mapping for
            // the solution vector; the constraint needs the same treatment.
            let offsets = shifts
            let shiftedFunction: @Sendable (VectorN<Double>) -> Double = { y in
                g(VariableShift.translate(y, by: offsets))
            }
            // The gradient keeps its direction — a translation has the identity as its
            // Jacobian — but must be evaluated at the unshifted point.
            var shiftedGradient: (@Sendable (VectorN<Double>) -> VectorN<Double>)? = nil
            if let grad = gradient {
                shiftedGradient = { y in grad(VariableShift.translate(y, by: offsets)) }
            }
            return .inequality(function: shiftedFunction, gradient: shiftedGradient)

        case .equality(let h, let gradient):
            let offsets = shifts
            let shiftedFunction: @Sendable (VectorN<Double>) -> Double = { y in
                h(VariableShift.translate(y, by: offsets))
            }
            var shiftedGradient: (@Sendable (VectorN<Double>) -> VectorN<Double>)? = nil
            if let grad = gradient {
                shiftedGradient = { y in grad(VariableShift.translate(y, by: offsets)) }
            }
            return .equality(function: shiftedFunction, gradient: shiftedGradient)
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

        case .inequality(let g, _):
            // A bound written as a closure is still a bound.
            //
            // This used to `continue`, on the reasoning that a closure is opaque and so
            // cannot yield a bound. The consequence was a wrong answer rather than a
            // missed optimisation: with no shift applied, the simplex's implicit `x >= 0`
            // truncates, so `minimize x` subject to `x >= -3` returned **0** — silently,
            // with no error, which is the shape this package's fail-silent principle
            // exists to forbid. The identical bound written as `.linearInequality`
            // returned -3 correctly, so the answer depended on how the caller spelled it.
            //
            // A closure is opaque to *inspection*, not to *evaluation*. The same probe
            // `validateLinearModel` already uses recovers an affine function's
            // coefficients exactly: the constant from the origin, each coefficient from a
            // unit step, and affinity confirmed at points away from both.
            if let bound = singleVariableLowerBound(of: g, dimension: dimension),
               bound.value < 0 {
                shifts[bound.index] = Swift.min(shifts[bound.index], bound.value)
            }

        case .equality:
            // An equality pins a variable rather than bounding it from below, and the
            // `.linearEquality` case above declines it for the same reason.
            continue
        }
    }

    // Check if any shifts are non-zero
    let needsShift = shifts.contains { abs($0) > 1e-10 }

    return VariableShift(shifts: shifts, needsShift: needsShift)
}


// MARK: - Recovering a bound from a closure

/// Recovers `x_i >= b` from an inequality closure, when that is what it says.
///
/// `MultivariateConstraint.inequality` carries `g(x) <= 0`. When `g` is affine and depends
/// on exactly one variable, that is a bound on that variable, and which end it bounds is
/// decided by the sign of the coefficient:
///
/// ```
/// c·x_i + d <= 0     with c < 0   =>   x_i >= -d/c      (a lower bound)
///                    with c > 0   =>   x_i <= -d/c      (an upper bound, not ours)
/// ```
///
/// The coefficients come from evaluation rather than inspection: `d = g(0)`, and
/// `c_i = g(e_i) - d`. That is exact for an affine function and meaningless for anything
/// else, so affinity is **confirmed before the result is trusted** — at points away from
/// both the origin and the unit vectors, where a quadratic or a product term disagrees.
///
/// - Returns: The variable index and its lower bound, or `nil` when `g` is not affine,
///   depends on more than one variable, bounds from above, or evaluates to a non-finite
///   value anywhere it is probed.
private func singleVariableLowerBound(
    of g: @Sendable (VectorN<Double>) -> Double,
    dimension: Int
) -> (index: Int, value: Double)? {
    guard dimension > 0 else { return nil }

    let origin = VectorN<Double>(Array(repeating: 0.0, count: dimension))
    let constant = g(origin)
    guard constant.isFinite else { return nil }

    var coefficients = Array(repeating: 0.0, count: dimension)
    for index in 0..<dimension {
        var components = Array(repeating: 0.0, count: dimension)
        components[index] = 1.0
        let stepped = g(VectorN<Double>(components))
        guard stepped.isFinite else { return nil }
        coefficients[index] = stepped - constant
    }

    // Confirm affinity away from the probes. A quadratic agrees at 0 and at every unit
    // vector and disagrees here, which is exactly the case that must not be trusted.
    let witnesses: [[Double]] = [
        (0..<dimension).map { Double($0 % 5) * 0.5 + 0.25 },
        (0..<dimension).map { -(Double($0 % 3) + 1.5) },
        Array(repeating: 2.75, count: dimension),
    ]
    for components in witnesses {
        let actual = g(VectorN<Double>(components))
        guard actual.isFinite else { return nil }
        var predicted = constant
        for (index, component) in components.enumerated() {
            predicted += coefficients[index] * component
        }
        let scale = Swift.max(1.0, Swift.abs(actual), Swift.abs(predicted))
        guard Swift.abs(actual - predicted) <= 1e-9 * scale else { return nil }
    }

    // Exactly one variable, or this is not a bound on a variable.
    var candidate: Int? = nil
    for (index, coefficient) in coefficients.enumerated() where Swift.abs(coefficient) > 1e-10 {
        if candidate != nil { return nil }
        candidate = index
    }
    guard let index = candidate else { return nil }

    let coefficient = coefficients[index]
    guard coefficient < 0 else { return nil }   // positive coefficient bounds from above
    return (index, -constant / coefficient)
}
