import Foundation
import Numerics

/// Validates that a function is linear (specialized for Double)
///
/// ## Algorithm
///
/// 1. Extract linear coefficients at initial point using finite differences
/// 2. Compute constant term: d = f(x₀) - c·x₀
/// 3. Sample function at multiple random points
/// 4. Verify f(x) = c·x + d for all samples (within tolerance)
/// 5. Throw `OptimizationError.nonlinearModel` if validation fails
///
/// ## Usage
///
/// ```swift
/// let closure: (VectorN<Double>) -> Double = { v in
///     3.0 * v[0] + 2.0 * v[1] + 1.0
/// }
///
/// let (coeffs, constant) = try validateLinearModel(
///     closure,
///     dimension: 2,
///     at: VectorN([0.5, 0.5])
/// )
/// // coeffs ≈ [3.0, 2.0], constant ≈ 1.0
/// ```
///
/// - Parameters:
///   - function: Function to validate
///   - dimension: Number of variables
///   - initialPoint: Point for coefficient extraction
///   - numSamples: Number of random points to test (default: 10)
///   - tolerance: Maximum deviation from linear model (default: 1e-4)
/// - Returns: Tuple of (coefficients, constant) if function is linear
/// - Throws: `OptimizationError.nonlinearModel` if validation fails
public func validateLinearModel<V: VectorSpace>(
    _ function: @escaping (V) -> Double,
    dimension: Int,
    at initialPoint: V,
    numSamples: Int = 10,
    tolerance: Double = 1e-4
) throws -> (coefficients: [Double], constant: Double)
    where V.Scalar == Double
{
    guard dimension > 0 else {
        throw OptimizationError.invalidInput(message: "Dimension must be positive")
    }

    guard numSamples > 0 else {
        throw OptimizationError.invalidInput(message: "Number of samples must be positive")
    }

    // Step 1: Extract coefficients using finite differences
    var coeffs: [Double] = []
    let h = 1e-8  // Step size for finite differences

    for i in 0..<dimension {
        var pointPlus = initialPoint.toArray()
        guard i < pointPlus.count else {
            throw OptimizationError.invalidInput(
                message: "Initial point has \(pointPlus.count) dimensions, expected \(dimension)"
            )
        }

        pointPlus[i] += h

        guard let vecPlus = V.fromArray(pointPlus) else {
            throw OptimizationError.invalidInput(message: "Failed to create perturbed vector")
        }

        // Forward difference: df/dx_i ≈ (f(x + h*e_i) - f(x)) / h
        let derivative = (function(vecPlus) - function(initialPoint)) / h
        coeffs.append(derivative)
    }

    // Step 2: Compute constant term: d = f(x₀) - c·x₀
    let fx = function(initialPoint)
    let initialComponents = initialPoint.toArray()
    let cx = zip(coeffs, initialComponents).reduce(0.0) { acc, pair in
        acc + pair.0 * pair.1
    }
    let constantTerm = fx - cx

    // Step 3: Validate at multiple random points
    for _ in 0..<numSamples {
        // Generate random point in reasonable range [-10, 10]
        var randomComponents: [Double] = []
        for _ in 0..<dimension {
            let randomValue = Double.random(in: -10.0...10.0)
            randomComponents.append(randomValue)
        }

        guard let randomPoint = V.fromArray(randomComponents) else {
            throw OptimizationError.invalidInput(message: "Failed to create random point")
        }

        // Evaluate actual function
        let actualValue = function(randomPoint)

        // Compute expected linear value: f(x) = c·x + d
        let expectedValue = zip(coeffs, randomComponents).reduce(constantTerm) { acc, pair in
            acc + pair.0 * pair.1
        }

        // Check if within tolerance
        let error = abs(actualValue - expectedValue)

        if error > tolerance {
            // Function is nonlinear - construct helpful error message
            let pointStr = randomComponents.map { String(format: "%.4f", $0) }.joined(separator: ", ")
            let message = """
            Function is nonlinear.
            At point [\(pointStr)]:
              Actual f(x) = \(actualValue)
              Linear model predicts = \(expectedValue)
              Error = \(error) (tolerance = \(tolerance))

            This function cannot be used with MILP solvers that require linear objectives and constraints.
            Consider using:
              - StandardLinearFunction for explicit linear coefficients
              - Nonlinear optimization methods for nonlinear problems
            """

            throw OptimizationError.nonlinearModel(message: message)
        }
    }

    // All samples passed - function is linear
    return (coefficients: coeffs, constant: constantTerm)
}
