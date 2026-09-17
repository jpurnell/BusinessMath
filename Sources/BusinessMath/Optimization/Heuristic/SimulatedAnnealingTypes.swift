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

    /// How many neighbours are proposed at each temperature before it drops.
    ///
    /// The inner Markov chain, and the thing that makes annealing annealing. The method works by
    /// letting the walker approach equilibrium *at* a temperature and only then cooling; with a
    /// single sample per level there is no equilibrium to approach, and the schedule degenerates
    /// into a random walk with a shrinking acceptance threshold.
    ///
    /// This loop ran one proposal per temperature until 2026-09-17, which capped a default run
    /// at roughly 224 proposals however large `maxIterations` was set.
    ///
    /// Defaults to 40. `maxIterations` still bounds the total, so raising this shortens the
    /// schedule rather than extending the run.
    public let movesPerTemperature: Int

    /// Optional random seed for reproducibility
    public let seed: UInt64?

    /// Weight on the constraint-violation penalty, when `constraints:` are supplied.
    ///
    /// The **starting** weight for the augmented-Lagrangian outer loop, and no longer what
    /// decides whether the answer is feasible.
    ///
    /// It used to be exactly that: constrained solves minimised
    /// `objective(x) + weight · Σ violation(x)²` once, and how far outside the feasible region
    /// the answer settled came down to how this compared with the objective's magnitude. A
    /// penalty of 100 against an objective measured in millions left a 91% constraint violation
    /// and nothing in the result said so.
    ///
    /// Feasibility is now a guarantee rather than a setting — see
    /// ``TerminationReason/infeasible`` — so this conditions the search and not the outcome. A
    /// smaller starting weight gives a gentler first subproblem, which is the better-conditioned
    /// place to begin on a badly scaled objective; the loop raises it only when the multipliers
    /// are closing the gap too slowly. Measured across 0.001 to 1e12 on a well-behaved problem,
    /// every value returns the same point in the same number of iterations.
    ///
    /// Defaults to `100`, unchanged. A non-positive or non-finite value falls back to that
    /// default rather than being honoured.
    public let constraintPenaltyWeight: Double

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
        ///   - constraintPenaltyWeight: Starting weight for the augmented-Lagrangian outer
        ///     loop on constrained solves (default: 100)
        ///   - movesPerTemperature: Proposals in the inner Markov chain at each temperature
        ///     before it drops (default: 40)
        public init(
        initialTemperature: Double = 100.0,
        finalTemperature: Double = 0.001,
        coolingRate: Double = 0.95,
        maxIterations: Int = 1000,
        perturbationScale: Double = 0.3,
        reheatInterval: Int? = nil,
        reheatTemperature: Double? = nil,
        seed: UInt64? = nil,
    	constraintPenaltyWeight: Double = 100,
    	movesPerTemperature: Int = 40
    ) {
        // A chain of fewer than one proposal per level is not a chain.
        self.movesPerTemperature = movesPerTemperature > 0 ? movesPerTemperature : 40
        let penaltyFallback: Double = 100
        let penaltyIsUsable = constraintPenaltyWeight > 0 && constraintPenaltyWeight.isFinite
        self.constraintPenaltyWeight = penaltyIsUsable ? constraintPenaltyWeight : penaltyFallback
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
/// let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in let a = 1.0 - v[0]; let b = v[1] - v[0] * v[0]; return a * a + 100.0 * b * b }
/// let optimizer = SimulatedAnnealing<VectorN<Double>>(config: .default, searchSpace: [(-10.0, 10.0), (-10.0, 10.0)])
/// let result = optimizer.optimizeDetailed(objective: rosenbrock, initialSolution: VectorN<Double>([-1.2, 1.0]))
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
