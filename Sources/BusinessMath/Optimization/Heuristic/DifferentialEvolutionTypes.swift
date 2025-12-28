//
//  DifferentialEvolutionTypes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

import Foundation
import Numerics

// MARK: - Differential Evolution Strategy

/// Mutation strategy for differential evolution.
///
/// Different strategies control how trial vectors are generated through
/// vector differences. Each strategy balances exploration vs exploitation differently.
///
/// ## Strategy Descriptions
///
/// - **rand/1**: `V_mutant = V_r1 + F × (V_r2 - V_r3)`
///   - Uses random base vector
///   - Good exploration, slower convergence
///   - Most robust for multimodal problems
///
/// - **best/1**: `V_mutant = V_best + F × (V_r1 - V_r2)`
///   - Uses best individual as base
///   - Faster convergence, greedy
///   - Risk of premature convergence
///
/// - **currentToBest1**: `V_mutant = V_i + F × (V_best - V_i) + F × (V_r1 - V_r2)`
///   - Hybrid approach combining current and best
///   - Balances exploration and exploitation
///   - Good for continuous optimization
///
/// ## Usage Example
///
/// ```swift
/// let config = DifferentialEvolutionConfig(
///     populationSize: 50,
///     generations: 100,
///     strategy: .rand1  // Choose strategy
/// )
/// ```
public enum DifferentialEvolutionStrategy: Sendable {
    /// rand/1 strategy: mutant = r1 + F × (r2 - r3)
    ///
    /// Uses three random vectors. Most exploratory, robust for multimodal problems.
    case rand1

    /// best/1 strategy: mutant = best + F × (r1 - r2)
    ///
    /// Uses best individual as base. Fast convergence but may get stuck in local optima.
    case best1

    /// current-to-best/1 strategy: mutant = current + F × (best - current) + F × (r1 - r2)
    ///
    /// Hybrid combining current and best vectors. Balances exploration/exploitation.
    case currentToBest1
}

// MARK: - Differential Evolution Configuration

/// Configuration for differential evolution optimization.
///
/// Differential Evolution (DE) is a population-based optimizer that uses vector differences
/// to create trial solutions. It's particularly effective for continuous optimization and
/// often outperforms genetic algorithms on numerical problems.
///
/// ## Key Parameters
///
/// - **populationSize**: Number of candidate solutions (typical: 5× to 10× problem dimension)
/// - **mutationFactor (F)**: Scaling factor for vector differences (typical: 0.5-1.0)
/// - **crossoverRate (CR)**: Probability of using mutant component (typical: 0.5-0.95)
/// - **strategy**: Mutation strategy (rand/1, best/1, currentToBest1)
///
/// ## Usage Example
///
/// ```swift
/// // Default configuration
/// let config = DifferentialEvolutionConfig.default
///
/// // Custom configuration for tough problem
/// let customConfig = DifferentialEvolutionConfig(
///     populationSize: 100,
///     generations: 300,
///     mutationFactor: 0.8,
///     crossoverRate: 0.9,
///     strategy: .rand1
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Configurations
/// - ``init(populationSize:generations:mutationFactor:crossoverRate:strategy:seed:)``
/// - ``default``
/// - ``highPerformance``
///
/// ### Configuration Properties
/// - ``populationSize``
/// - ``generations``
/// - ``mutationFactor``
/// - ``crossoverRate``
/// - ``strategy``
/// - ``seed``
public struct DifferentialEvolutionConfig: Sendable {
    // MARK: - Properties

    /// Population size (number of candidate solutions).
    ///
    /// Larger populations explore more thoroughly but require more evaluations.
    /// Rule of thumb: 5× to 10× the problem dimension.
    /// Typical values: 50-200.
    public let populationSize: Int

    /// Number of generations to evolve.
    ///
    /// More generations allow better convergence but increase computation time.
    /// The algorithm may converge early if improvement stalls.
    public let generations: Int

    /// Mutation factor F ∈ [0.0, 2.0].
    ///
    /// Scaling factor for vector differences in mutation.
    /// - Lower values (0.4-0.6): More conservative, slower exploration
    /// - Higher values (0.8-1.2): More aggressive, faster exploration
    /// Typical values: 0.5-1.0.
    public let mutationFactor: Double

    /// Crossover rate CR ∈ [0.0, 1.0].
    ///
    /// Probability of using each component from the mutant vector.
    /// - Lower values (<0.5): More conservative recombination
    /// - Higher values (>0.8): More aggressive mixing
    /// Typical values: 0.7-0.95.
    public let crossoverRate: Double

    /// Mutation strategy.
    ///
    /// Controls how trial vectors are generated:
    /// - `.rand1`: Random base, good exploration
    /// - `.best1`: Best individual base, faster convergence
    /// - `.currentToBest1`: Hybrid approach
    ///
    /// See ``DifferentialEvolutionStrategy`` for details.
    public let strategy: DifferentialEvolutionStrategy

    /// Random seed for reproducibility (optional).
    ///
    /// When set, produces deterministic results for testing.
    /// When nil, uses non-deterministic random seed.
    public let seed: UInt64?

    // MARK: - Initialization

    /// Create a differential evolution configuration.
    ///
    /// - Parameters:
    ///   - populationSize: Number of candidate solutions (default: 100)
    ///   - generations: Number of generations to evolve (default: 200)
    ///   - mutationFactor: F parameter for vector differences (default: 0.8)
    ///   - crossoverRate: CR parameter for recombination (default: 0.9)
    ///   - strategy: Mutation strategy (default: .rand1)
    ///   - seed: Random seed for reproducibility (default: nil)
    public init(
        populationSize: Int = 100,
        generations: Int = 200,
        mutationFactor: Double = 0.8,
        crossoverRate: Double = 0.9,
        strategy: DifferentialEvolutionStrategy = .rand1,
        seed: UInt64? = nil
    ) {
        self.populationSize = populationSize
        self.generations = generations
        self.mutationFactor = mutationFactor
        self.crossoverRate = crossoverRate
        self.strategy = strategy
        self.seed = seed
    }

    // MARK: - Presets

    /// Default configuration optimized for typical use cases.
    ///
    /// Balanced settings suitable for most optimization problems:
    /// - Population: 100 individuals
    /// - Generations: 200
    /// - Mutation factor: 0.8
    /// - Crossover rate: 0.9
    /// - Strategy: rand/1
    public static let `default` = DifferentialEvolutionConfig()

    /// High-performance configuration for large-scale problems.
    ///
    /// Optimized for complex optimization tasks:
    /// - Population: 1000 individuals
    /// - Generations: 500
    /// - Mutation factor: 0.7 (slightly more conservative)
    /// - Crossover rate: 0.95 (aggressive recombination)
    public static let highPerformance = DifferentialEvolutionConfig(
        populationSize: 1000,
        generations: 500,
        mutationFactor: 0.7,
        crossoverRate: 0.95
    )
}

// MARK: - Differential Evolution Result

/// Result of differential evolution optimization.
///
/// Contains the best solution found, convergence information, and historical data
/// for analysis and visualization.
///
/// ## Usage Example
///
/// ```swift
/// let optimizer = DifferentialEvolution<VectorN<Double>>(
///     config: .default,
///     searchSpace: [(-10, 10), (-10, 10)]
/// )
///
/// let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
/// let result = try optimizer.optimizeDetailed(objective: sphere)
///
/// print("Solution: \(result.solution)")
/// print("Fitness: \(result.fitness)")
/// print("Converged: \(result.converged)")
/// print("Generations: \(result.generations)")
/// ```
///
/// ## Topics
///
/// ### Solution
/// - ``solution``
/// - ``fitness``
///
/// ### Convergence
/// - ``converged``
/// - ``convergenceReason``
/// - ``generations``
/// - ``evaluations``
///
/// ### History
/// - ``convergenceHistory``
public struct DifferentialEvolutionResult<V: VectorSpace> where V.Scalar: Real {
    // MARK: - Solution

    /// Best solution found by the differential evolution algorithm.
    ///
    /// This is the individual with the lowest fitness (objective value) across
    /// all generations.
    public let solution: V

    /// Fitness of the best solution (objective function value).
    ///
    /// Lower values are better (minimization problem).
    public let fitness: V.Scalar

    // MARK: - Convergence

    /// Number of generations evolved.
    ///
    /// May be less than the configured maximum if early convergence was detected.
    public let generations: Int

    /// Total number of fitness evaluations performed.
    ///
    /// Typically `populationSize × generations` for standard DE.
    public let evaluations: Int

    /// Whether the algorithm converged before reaching maximum generations.
    ///
    /// Convergence is detected when the best fitness stops improving
    /// (improvement < 1e-6 for 10 consecutive generations).
    public let converged: Bool

    /// Human-readable explanation of why optimization stopped.
    ///
    /// Examples:
    /// - "Fitness improvement < 1e-6 for 10 generations"
    /// - "Maximum generations reached"
    public let convergenceReason: String

    // MARK: - History

    /// Best fitness value at each generation.
    ///
    /// This array has length equal to ``generations``. The first element is the
    /// best fitness in the initial population, and the last element is the final
    /// ``fitness``.
    ///
    /// ## Usage
    ///
    /// Use this to visualize convergence:
    /// ```swift
    /// for (gen, bestFitness) in result.convergenceHistory.enumerated() {
    ///     print("Generation \(gen): Best = \(bestFitness)")
    /// }
    /// ```
    public let convergenceHistory: [V.Scalar]
}
