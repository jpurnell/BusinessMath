import Foundation
import Numerics

/// The seed behind ``validateLinearModel(_:dimension:at:numSamples:tolerance:)``'s sample points.
///
/// Fixed so that the same function gets the same verdict on every run. Changing it changes
/// which functions the validator happens to catch, so treat it as part of the observable
/// behaviour rather than as an implementation detail.
private let linearityValidationSeed: UInt64 = 0x5EED_11EA_2_ADD

/// Validates that a function is linear (specialized for Double)
///
/// ## Algorithm
///
/// 1. Extract linear coefficients at initial point using finite differences
/// 2. Compute constant term: d = f(x₀) - c·x₀
/// 3. Sample function at a fixed set of points spanning [-10, 10]
/// 4. Verify f(x) = c·x + d for all samples (within tolerance)
/// 5. Throw `OptimizationError.nonlinearModel` if validation fails
///
/// ## Why the sample points are fixed
///
/// The verdict has to be the same on every run. This function is a gate — ``BranchAndBound``
/// calls it before it will accept a closure as a MILP objective or constraint — and a gate
/// that samples afresh each time can wave through, on one run, a model it rejected on the
/// last. `f(x) = |x|` is the case that showed it: coefficients extracted at x = 0.5 describe
/// the right-hand branch only, so the model is refuted by a negative sample and by nothing
/// else. Ten independent uniform draws from [-10, 10] miss every one about once in a
/// thousand attempts, and that run gets a linear approximation of a function that is not
/// linear, silently.
///
/// So the points come from a seeded ``DeterministicRNG`` rather than the system generator,
/// and they are drawn in **reflected pairs**: sample 2k+1 is the componentwise negation of
/// sample 2k. That costs nothing in coverage — the marginal distribution of each point is
/// still uniform over [-10, 10] — and it guarantees what the uniform draws only made likely,
/// that every variable is tested on both sides of zero. Any kink at the origin, in any
/// coordinate, is now caught on every run rather than on most of them.
///
/// This is still sampling, and sampling can be fooled: a function that agrees with its
/// linearisation at exactly these points passes. Fixing the points makes that failure
/// reproducible instead of intermittent, which is the property worth having.
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
            throw OptimizationError.dimensionMismatch(
                message: "Initial point has \(pointPlus.count) dimensions, expected \(dimension)"
            )
        }

        pointPlus[i] += h

        guard let vecPlus = V.fromArray(pointPlus) else {
            throw OptimizationError.invalidInput(message: "Failed to create perturbed vector")
        }

        // Forward difference: df/dx_i ≈ (f(x + h*e_i) - f(x)) / h
        let derivative = (function(vecPlus) - function(initialPoint)) / h // fp-safety:disable — h = 1e-8 (constant)
        coeffs.append(derivative)
    }

    // Step 2: Compute constant term: d = f(x₀) - c·x₀
    let fx = function(initialPoint)
    let initialComponents = initialPoint.toArray()
    let cx = zip(coeffs, initialComponents).reduce(0.0) { acc, pair in
        acc + pair.0 * pair.1
    }
    let constantTerm = fx - cx

    // Step 3: Build the sample points. Seeded, so the set is the same on every run, and
    // reflected in pairs, so every variable is seen on both sides of zero.
    var rng = DeterministicRNG(seed: linearityValidationSeed)
    var samplePoints: [[Double]] = []
    samplePoints.reserveCapacity(numSamples)

    while samplePoints.count < numSamples {
        var components: [Double] = []
        components.reserveCapacity(dimension)
        for _ in 0..<dimension {
            components.append(Double.random(in: -10.0...10.0, using: &rng))
        }
        samplePoints.append(components)

        if samplePoints.count < numSamples {
            samplePoints.append(components.map { -$0 })
        }
    }

    // Step 4: Validate at every sample point
    for randomComponents in samplePoints {
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
            let pointStr = randomComponents.map { $0.number(4) }.joined(separator: ", ")
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
