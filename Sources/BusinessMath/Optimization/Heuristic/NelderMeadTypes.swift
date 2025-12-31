//
//  NelderMeadTypes.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation
import Numerics

// MARK: - Nelder-Mead Configuration

/// Configuration for Nelder-Mead simplex optimization.
///
/// The Nelder-Mead method is a derivative-free optimization algorithm that maintains a simplex
/// (n+1 vertices in n dimensions) and iteratively transforms it to find the minimum.
///
/// ## Usage Example
///
/// ```swift
/// // Default configuration
/// let config = NelderMeadConfig.default
///
/// // High precision configuration
/// let preciseCon fig = NelderMeadConfig.highPrecision
///
/// // Custom configuration
/// let customConfig = NelderMeadConfig(
///     reflectionCoefficient: 1.0,
///     expansionCoefficient: 2.0,
///     contractionCoefficient: 0.5,
///     shrinkCoefficient: 0.5,
///     tolerance: 1e-8,
///     maxIterations: 1000
/// )
/// ```
///
/// ## Simplex Operations
///
/// - **Reflection** (α = 1.0): Reflect worst point through centroid
/// - **Expansion** (γ = 2.0): Extend reflection if promising
/// - **Contraction** (ρ = 0.5): Contract toward better point
/// - **Shrink** (σ = 0.5): Shrink entire simplex toward best
public struct NelderMeadConfig: Sendable {

    /// Reflection coefficient (typical: 1.0)
    public let reflectionCoefficient: Double

    /// Expansion coefficient (typical: 2.0)
    public let expansionCoefficient: Double

    /// Contraction coefficient (typical: 0.5)
    public let contractionCoefficient: Double

    /// Shrink coefficient (typical: 0.5)
    public let shrinkCoefficient: Double

    /// Initial simplex size relative to starting point
    public let initialSimplexSize: Double

    /// Convergence tolerance for simplex size
    public let tolerance: Double

    /// Maximum number of iterations
    public let maxIterations: Int

    /// Create a Nelder-Mead configuration.
    ///
    /// - Parameters:
    ///   - reflectionCoefficient: Reflection factor (default: 1.0)
    ///   - expansionCoefficient: Expansion factor (default: 2.0)
    ///   - contractionCoefficient: Contraction factor (default: 0.5)
    ///   - shrinkCoefficient: Shrink factor (default: 0.5)
    ///   - initialSimplexSize: Initial simplex size (default: 1.0)
    ///   - tolerance: Convergence tolerance (default: 1e-6)
    ///   - maxIterations: Maximum iterations (default: 500)
    public init(
        reflectionCoefficient: Double = 1.0,
        expansionCoefficient: Double = 2.0,
        contractionCoefficient: Double = 0.5,
        shrinkCoefficient: Double = 0.5,
        initialSimplexSize: Double = 1.0,
        tolerance: Double = 1e-6,
        maxIterations: Int = 500
    ) {
        self.reflectionCoefficient = reflectionCoefficient
        self.expansionCoefficient = expansionCoefficient
        self.contractionCoefficient = contractionCoefficient
        self.shrinkCoefficient = shrinkCoefficient
        self.initialSimplexSize = initialSimplexSize
        self.tolerance = tolerance
        self.maxIterations = maxIterations
    }

    /// Default configuration suitable for most problems.
    ///
    /// ## Parameters
    ///
    /// - Reflection: 1.0
    /// - Expansion: 2.0
    /// - Contraction: 0.5
    /// - Shrink: 0.5
    /// - Initial simplex: 1.0
    /// - Tolerance: 1e-6
    /// - Max iterations: 500
    public static let `default` = NelderMeadConfig()

    /// High precision configuration for demanding problems.
    ///
    /// ## Parameters
    ///
    /// - Reflection: 1.0
    /// - Expansion: 2.0
    /// - Contraction: 0.5
    /// - Shrink: 0.5
    /// - Initial simplex: 0.5
    /// - Tolerance: 1e-10
    /// - Max iterations: 2000
    public static let highPrecision = NelderMeadConfig(
        initialSimplexSize: 0.5,
        tolerance: 1e-10,
        maxIterations: 2000
    )

    /// Fast configuration for quick exploration.
    ///
    /// ## Parameters
    ///
    /// - Reflection: 1.0
    /// - Expansion: 2.5
    /// - Contraction: 0.5
    /// - Shrink: 0.5
    /// - Initial simplex: 1.5
    /// - Tolerance: 1e-4
    /// - Max iterations: 200
    public static let fast = NelderMeadConfig(
        expansionCoefficient: 2.5,
        initialSimplexSize: 1.5,
        tolerance: 1e-4,
        maxIterations: 200
    )
}

// MARK: - Nelder-Mead Result

/// Result of Nelder-Mead simplex optimization.
///
/// Contains the best solution found, function value, and convergence information.
///
/// ## Usage Example
///
/// ```swift
/// let result = optimizer.optimizeDetailed(objective: rosenbrock, initialGuess: guess)
///
/// print("Solution: \(result.solution)")
/// print("Value: \(result.value)")
/// print("Converged: \(result.converged)")
/// print("Reason: \(result.convergenceReason)")
/// print("Simplex size: \(result.finalSimplexSize)")
/// ```
public struct NelderMeadResult<V: VectorSpace> where V.Scalar: Real {

    /// Best solution found
    public let solution: V

    /// Objective function value at solution
    public let value: V.Scalar

    /// Number of iterations performed
    public let iterations: Int

    /// Number of objective function evaluations
    public let evaluations: Int

    /// Whether optimization converged
    public let converged: Bool

    /// Reason for convergence or termination
    public let convergenceReason: String

    /// Final simplex size at termination
    public let finalSimplexSize: V.Scalar

    /// Optional history of best value over iterations
    public let convergenceHistory: [V.Scalar]?

    /// Create a Nelder-Mead result.
    ///
    /// - Parameters:
    ///   - solution: Best solution found
    ///   - value: Objective value at solution
    ///   - iterations: Number of iterations
    ///   - evaluations: Number of evaluations
    ///   - converged: Convergence flag
    ///   - convergenceReason: Reason for stopping
    ///   - finalSimplexSize: Final simplex diameter
    ///   - convergenceHistory: Optional value history
    public init(
        solution: V,
        value: V.Scalar,
        iterations: Int,
        evaluations: Int,
        converged: Bool,
        convergenceReason: String,
        finalSimplexSize: V.Scalar,
        convergenceHistory: [V.Scalar]? = nil
    ) {
        self.solution = solution
        self.value = value
        self.iterations = iterations
        self.evaluations = evaluations
        self.converged = converged
        self.convergenceReason = convergenceReason
        self.finalSimplexSize = finalSimplexSize
        self.convergenceHistory = convergenceHistory
    }
}
