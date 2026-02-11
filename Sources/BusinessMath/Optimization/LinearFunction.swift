import Foundation
import Numerics

/// Protocol representing an explicit linear function over a vector space
///
/// A linear function has the form:
/// ```
/// f(x) = c₁x₁ + c₂x₂ + ... + cₙxₙ + constant
/// ```
///
/// ## Benefits over closure-based models
///
/// - **Numerical accuracy**: Coefficients stored exactly (~1e-15 precision) vs finite-difference extraction (~1e-9 error)
/// - **Compile-time guarantees**: Type system enforces linearity
/// - **Performance**: Direct coefficient access eliminates finite-difference overhead
/// - **Debuggability**: Coefficients can be inspected directly
///
/// ## Example Usage
///
/// ```swift
/// // Create linear objective: minimize 3x + 2y + 1
/// let objective = StandardLinearFunction<VectorN<Double>>(
///     coefficients: [3.0, 2.0],
///     constant: 1.0
/// )
///
/// // Use with solver
/// let result = try solver.solve(
///     objective: objective,
///     from: VectorN([0.5, 0.5]),
///     subjectTo: constraints,
///     integerSpec: spec
/// )
/// ```
public protocol LinearFunction: Sendable {
    associatedtype V: VectorSpace where V.Scalar == Double

    /// Linear coefficients [c₁, c₂, ..., cₙ]
    var coefficients: [Double] { get }

    /// Constant term (default: 0)
    var constant: Double { get }

    /// Evaluate f(x) = c·x + constant
    func evaluate(at point: V) -> Double

    /// Gradient is constant for linear functions: ∇f = c
    func gradient(at point: V) -> V
}

// MARK: - Default Implementations

extension LinearFunction {
    /// Default constant is zero
    public var constant: Double { 0.0 }

    /// Default evaluation: dot product of coefficients and point, plus constant
    public func evaluate(at point: V) -> Double {
        let components = point.toArray()
        guard components.count == coefficients.count else {
            fatalError("Dimension mismatch: function has \(coefficients.count) coefficients, point has \(components.count) dimensions")
        }

        // Compute c·x + constant
        let dotProduct = zip(coefficients, components).reduce(0.0) { acc, pair in
            acc + pair.0 * pair.1
        }

        return dotProduct + constant
    }

    /// Default gradient: coefficients (constant for linear functions)
    public func gradient(at point: V) -> V {
        guard let gradient = V.fromArray(coefficients) else {
            fatalError("Failed to create gradient vector from coefficients")
        }
        return gradient
    }
}

// MARK: - Standard Implementation

/// Standard implementation of LinearFunction
///
/// Stores coefficients and constant explicitly for maximum precision.
///
/// ## Example
///
/// ```swift
/// // f(x, y) = 2x + 3y + 1
/// let f = StandardLinearFunction<VectorN<Double>>(
///     coefficients: [2.0, 3.0],
///     constant: 1.0
/// )
///
/// let result = f.evaluate(at: VectorN([5.0, 7.0]))  // 2*5 + 3*7 + 1 = 32
/// ```
public struct StandardLinearFunction<V: VectorSpace>: LinearFunction
    where V.Scalar == Double, V: Sendable
{
    /// Declare linear oefficients
    public let coefficients: [Double]
    /// Declare linear constant
    public let constant: Double

    /// Create a linear function with explicit coefficients
    ///
    /// - Parameters:
    ///   - coefficients: Linear coefficients [c₁, c₂, ..., cₙ]
    ///   - constant: Constant term (default: 0)
    public init(coefficients: [Double], constant: Double = 0.0) {
        self.coefficients = coefficients
        self.constant = constant
    }
}

// MARK: - Factory Methods

extension StandardLinearFunction {
    /// Extract linear function from closure using finite differences
    ///
    /// **Warning**: This method uses finite-difference approximation and has
    /// numerical error ~1e-9. For exact coefficients, construct directly.
    ///
    /// - Parameters:
    ///   - function: Closure to extract coefficients from
    ///   - dimension: Number of variables
    ///   - point: Point at which to evaluate (for constant term)
    /// - Returns: LinearFunction with extracted coefficients
    /// - Throws: If extraction fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let closure: (VectorN<Double>) -> Double = { v in
    ///     3.0 * v[0] + 2.0 * v[1] + 1.0
    /// }
    ///
    /// let f = try StandardLinearFunction.fromClosure(
    ///     closure,
    ///     dimension: 2,
    ///     at: VectorN([0.5, 0.5])
    /// )
    /// // f.coefficients ≈ [3.0, 2.0] (with ~1e-9 error)
    /// // f.constant ≈ 1.0
    /// ```
    public static func fromClosure(
        _ function: @escaping (V) -> Double,
        dimension: Int,
        at point: V
    ) throws -> StandardLinearFunction<V> {
        // Extract coefficients using finite differences
        var coeffs: [Double] = []
        let h = 1e-8

        for i in 0..<dimension {
            var pointPlus = point.toArray()
            pointPlus[i] += h

            guard let vecPlus = V.fromArray(pointPlus) else {
                throw OptimizationError.invalidInput(message: "Failed to create perturbed vector")
            }

            // Forward difference: df/dx_i ≈ (f(x + h*e_i) - f(x)) / h
            let derivative = (function(vecPlus) - function(point)) / h
            coeffs.append(derivative)
        }

        // Compute constant: d = f(x) - c·x
        let fx = function(point)
        let cx = zip(coeffs, point.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 }
        let constantTerm = fx - cx

        return StandardLinearFunction(coefficients: coeffs, constant: constantTerm)
    }
}

// MARK: - Convenience Constructors

extension StandardLinearFunction {
    /// Create linear function with only coefficients (zero constant)
    public init(_ coefficients: [Double]) {
        self.init(coefficients: coefficients, constant: 0.0)
    }

    /// Create single-variable linear function: f(x) = cx + d
    ///
    /// - Parameters:
    ///   - coefficient: Slope c
    ///   - constant: Intercept d (default: 0)
    public init(coefficient: Double, constant: Double = 0.0) {
        self.init(coefficients: [coefficient], constant: constant)
    }
}

// MARK: - CustomStringConvertible

extension StandardLinearFunction: CustomStringConvertible {
    // MARK: - LocalizedError Conformance

    /// A localized human-readable description of the error.
    ///
    /// Provides context-specific error messages with relevant details like
    /// values, ranges, and suggestions.
    public var description: String {
        var terms: [String] = []

        // Build terms for each coefficient
        for (i, coeff) in coefficients.enumerated() {
            if abs(coeff) < 1e-10 { continue }  // Skip near-zero coefficients

            let sign = coeff >= 0 ? "+" : "-"
            let absCoeff = abs(coeff)
            let coeffStr = abs(absCoeff - 1.0) < 1e-10 ? "" : "\(absCoeff)"
            let varStr = "x[\(i)]"

            if terms.isEmpty && coeff >= 0 {
                // First term, positive: no sign prefix
                terms.append("\(coeffStr)\(varStr)")
            } else {
                terms.append("\(sign) \(coeffStr)\(varStr)")
            }
        }

        // Add constant term if non-zero
        if abs(constant) > 1e-10 {
            let sign = constant >= 0 ? "+" : "-"
            terms.append("\(sign) \(abs(constant))")
        }

        // Handle all-zero case
        if terms.isEmpty {
            return "f(x) = 0"
        }

        return "f(x) = " + terms.joined(separator: " ")
    }
}
