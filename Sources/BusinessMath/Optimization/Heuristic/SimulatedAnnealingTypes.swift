//
//  SimulatedAnnealingTypes.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation
import Numerics

// MARK: - Simulated Annealing Configuration

/// Configuration for Simulated Annealing optimization.
///
/// Simulated Annealing (SA) is a probabilistic metaheuristic inspired by the annealing process in metallurgy.
/// It explores the search space by accepting both improving and (probabilistically) worsening solutions,
/// allowing escape from local minima.
///
/// ## Usage Example
///
/// ```swift
/// // Default configuration (good starting point)
/// let config = SimulatedAnnealingConfig.default
///
/// // Custom configuration for difficult problems
/// let customConfig = SimulatedAnnealingConfig(
///     initialTemperature: 100.0,
///     finalTemperature: 0.01,
///     coolingRate: 0.95,
///     maxIterations: 10000,
///     perturbationScale: 0.5
/// )
/// ```
///
/// ## Parameters Guide
///
/// - **initialTemperature**: Higher values allow more exploration (accept worse solutions)
/// - **finalTemperature**: Lower values ensure convergence to local minimum
/// - **coolingRate**: Slower cooling (closer to 1.0) = better quality, more iterations
/// - **perturbationScale**: Larger values = broader exploration
/// - **reheatInterval**: Optional periodic temperature increases to escape stagnation
public struct SimulatedAnnealingConfig: Sendable {

    /// Initial temperature (higher = more exploration)
    public let initialTemperature: Double

    /// Final temperature (stopping condition)
    public let finalTemperature: Double

    /// Cooling rate per iteration (T_new = coolingRate * T_old)
    /// Typical values: 0.85-0.99
    public let coolingRate: Double

    /// Maximum number of iterations
    public let maxIterations: Int

    /// Scale of random perturbations for generating neighbors
    /// Relative to search space range
    public let perturbationScale: Double

    /// Optional: Number of iterations between temperature reheats
    /// Reheating can help escape local minima
    public let reheatInterval: Int?

    /// Temperature to reheat to when interval is reached
    public let reheatTemperature: Double?

    /// Optional random seed for reproducibility
    public let seed: UInt64?

    /// Create a simulated annealing configuration.
    ///
    /// - Parameters:
    ///   - initialTemperature: Starting temperature (default: 100.0)
    ///   - finalTemperature: Stopping temperature (default: 0.001)
    ///   - coolingRate: Geometric cooling factor (default: 0.95)
    ///   - maxIterations: Maximum iterations (default: 1000)
    ///   - perturbationScale: Neighbor perturbation scale (default: 0.3)
    ///   - reheatInterval: Optional reheat interval (default: nil)
    ///   - reheatTemperature: Temperature for reheating (default: nil)
    ///   - seed: Optional RNG seed (default: nil)
    public init(
        initialTemperature: Double = 100.0,
        finalTemperature: Double = 0.001,
        coolingRate: Double = 0.95,
        maxIterations: Int = 1000,
        perturbationScale: Double = 0.3,
        reheatInterval: Int? = nil,
        reheatTemperature: Double? = nil,
        seed: UInt64? = nil
    ) {
        self.initialTemperature = initialTemperature
        self.finalTemperature = finalTemperature
        self.coolingRate = coolingRate
        self.maxIterations = maxIterations
        self.perturbationScale = perturbationScale
        self.reheatInterval = reheatInterval
        self.reheatTemperature = reheatTemperature
        self.seed = seed
    }

    /// Default configuration suitable for most problems.
    ///
    /// ## Parameters
    ///
    /// - Initial temperature: 100.0
    /// - Final temperature: 0.001
    /// - Cooling rate: 0.95 (geometric cooling)
    /// - Max iterations: 1000
    /// - Perturbation scale: 0.3
    /// - No reheating
    public static let `default` = SimulatedAnnealingConfig()
	
	/// Default configuration suitable for most problems.
	///
	/// ## Parameters
	///
	/// - Initial temperature: 100.0
	/// - Final temperature: 0.001
	/// - Cooling rate: 0.95 (geometric cooling)
	/// - Max iterations: 1000
	/// - Perturbation scale: 0.3
	/// - No reheating
	/// - seed: consistentAt 42 for testsing
	public static let `seededDefault` = SimulatedAnnealingConfig(
		initialTemperature: 100.0,
		finalTemperature: 0.001,
		coolingRate: 0.95,
		maxIterations: 1000,
		perturbationScale: 0.3,
		seed: 42
)

    /// Fast cooling configuration for quick exploration.
    ///
    /// ## Parameters
    ///
    /// - Initial temperature: 50.0
    /// - Final temperature: 0.01
    /// - Cooling rate: 0.85 (faster cooling)
    /// - Max iterations: 500
    /// - Perturbation scale: 0.5
    public static let fast = SimulatedAnnealingConfig(
        initialTemperature: 50.0,
        finalTemperature: 0.01,
        coolingRate: 0.85,
        maxIterations: 500,
        perturbationScale: 0.5
    )

    /// Slow cooling configuration for high-quality solutions.
    ///
    /// ## Parameters
    ///
    /// - Initial temperature: 200.0
    /// - Final temperature: 0.0001
    /// - Cooling rate: 0.98 (slow cooling)
    /// - Max iterations: 5000
    /// - Perturbation scale: 0.2
    public static let thorough = SimulatedAnnealingConfig(
        initialTemperature: 200.0,
        finalTemperature: 0.0001,
        coolingRate: 0.98,
        maxIterations: 5000,
        perturbationScale: 0.2
    )
}

// MARK: - Simulated Annealing Result

/// Result of simulated annealing optimization.
///
/// Contains the best solution found, fitness value, and convergence information.
///
/// ## Usage Example
///
/// ```swift
/// let result = optimizer.optimizeDetailed(objective: rosenbrock)
///
/// print("Solution: \(result.solution)")
/// print("Fitness: \(result.fitness)")
/// print("Converged: \(result.converged)")
/// print("Reason: \(result.convergenceReason)")
/// print("Final temp: \(result.finalTemperature)")
/// ```
public struct SimulatedAnnealingResult<V: VectorSpace> where V.Scalar: Real {

    /// Best solution found
    public let solution: V

    /// Objective function value at solution
    public let fitness: V.Scalar

    /// Number of iterations performed
    public let iterations: Int

    /// Number of objective function evaluations
    public let evaluations: Int

    /// Whether optimization converged
    public let converged: Bool

    /// Reason for convergence or termination
    public let convergenceReason: String

    /// Final temperature when optimization stopped
    public let finalTemperature: Double

    /// Number of accepted moves
    public let acceptedMoves: Int

    /// Number of rejected moves
    public let rejectedMoves: Int

    /// Acceptance rate (accepted / total)
    public var acceptanceRate: Double {
        let total = acceptedMoves + rejectedMoves
        return total > 0 ? Double(acceptedMoves) / Double(total) : 0.0
    }

    /// Optional history of best fitness over iterations
    public let convergenceHistory: [V.Scalar]?

    /// Create a simulated annealing result.
    ///
    /// - Parameters:
    ///   - solution: Best solution found
    ///   - fitness: Objective value at solution
    ///   - iterations: Number of iterations
    ///   - evaluations: Number of evaluations
    ///   - converged: Convergence flag
    ///   - convergenceReason: Reason for stopping
    ///   - finalTemperature: Final temperature
    ///   - acceptedMoves: Count of accepted moves
    ///   - rejectedMoves: Count of rejected moves
    ///   - convergenceHistory: Optional fitness history
    public init(
        solution: V,
        fitness: V.Scalar,
        iterations: Int,
        evaluations: Int,
        converged: Bool,
        convergenceReason: String,
        finalTemperature: Double,
        acceptedMoves: Int,
        rejectedMoves: Int,
        convergenceHistory: [V.Scalar]? = nil
    ) {
        self.solution = solution
        self.fitness = fitness
        self.iterations = iterations
        self.evaluations = evaluations
        self.converged = converged
        self.convergenceReason = convergenceReason
        self.finalTemperature = finalTemperature
        self.acceptedMoves = acceptedMoves
        self.rejectedMoves = rejectedMoves
        self.convergenceHistory = convergenceHistory
    }
}
