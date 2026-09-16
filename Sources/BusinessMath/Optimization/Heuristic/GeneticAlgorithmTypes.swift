//
//  GeneticAlgorithmTypes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/26/25.
//

import Foundation
import Numerics

/// Configuration for genetic algorithm optimization.
///
/// Genetic algorithms evolve a population of candidate solutions over multiple generations
/// using selection, crossover, and mutation operations. This configuration controls all
/// parameters of the evolutionary process.
///
/// ## Usage Example
///
/// ```swift
/// // Simple configuration
/// let config = GeneticAlgorithmConfig.default
///
/// // Custom configuration for large-scale problem
/// let customConfig = GeneticAlgorithmConfig(
///     populationSize: 1000,
///     generations: 500,
///     crossoverRate: 0.9,
///     mutationRate: 0.05,
///     eliteCount: 10
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Configurations
/// - ``init(populationSize:generations:crossoverRate:mutationRate:mutationStrength:eliteCount:tournamentSize:seed:constraintPenaltyWeight:)``
/// - ``default``
/// - ``highPerformance``
///
/// ### Configuration Properties
/// - ``populationSize``
/// - ``generations``
/// - ``crossoverRate``
/// - ``mutationRate``
/// - ``mutationStrength``
/// - ``eliteCount``
/// - ``tournamentSize``
/// - ``seed``
public struct GeneticAlgorithmConfig: Sendable {
    // MARK: - Properties

    /// Population size (number of individuals per generation).
    ///
    /// Larger populations explore the search space more thoroughly but require more
    /// fitness evaluations per generation. Typical values: 50-1000.
    ///
    /// - Note: For GPU acceleration (if enabled), populations of 1000+ are recommended.
    public let populationSize: Int

    /// Number of generations to evolve.
    ///
    /// More generations allow for better convergence but increase computation time.
    /// The algorithm may converge early if fitness improvement stalls.
    public let generations: Int

    /// Crossover probability [0.0, 1.0].
    ///
    /// Probability that two parents will produce offspring via crossover.
    /// Higher values favor exploitation of good solutions.
    /// Typical values: 0.7-0.95.
    public let crossoverRate: Double

    /// Mutation probability per gene [0.0, 1.0].
    ///
    /// Probability that each gene in an individual will mutate.
    /// Higher values increase exploration but may prevent convergence.
    /// Typical values: 0.01-0.2.
    public let mutationRate: Double

    /// Mutation strength (standard deviation of Gaussian mutation).
    ///
    /// Controls the magnitude of mutations relative to the search space.
    /// A value of 0.1 means mutations are ±10% of the range on average.
    /// Typical values: 0.05-0.2.
    public let mutationStrength: Double

    /// Number of elite individuals preserved each generation.
    ///
    /// Elite individuals (best performers) are automatically passed to the next
    /// generation without modification. This ensures monotonic improvement of the
    /// best solution. Typical values: 1-5% of population size.
    public let eliteCount: Int

    /// Tournament size for selection.
    ///
    /// Number of individuals randomly chosen for each tournament selection.
    /// Larger tournaments increase selection pressure (favor better solutions).
    /// Typical values: 2-5.
    public let tournamentSize: Int

    /// Random seed for reproducibility (optional).
    ///
    /// When set, the algorithm produces deterministic results for testing.
    /// When nil, uses a non-deterministic random seed.
    public let seed: UInt64?

    /// Weight applied to constraint violations in a constrained solve.
    ///
    /// A constrained run minimises `objective(x) + weight · Σ violation(x)²`, so this number
    /// decides how far outside the feasible region an answer is allowed to settle.
    ///
    /// **It has to be commensurate with the objective's scale, which is why it is a
    /// parameter.** A penalty that is small beside the objective is negligible, and the
    /// solve returns an infeasible point without saying so.
    ///
    /// **This default is `1000`, not the `100` the other constrained heuristics use.** When
    /// 2.17.0 turned that literal into a parameter across Nelder-Mead, differential
    /// evolution, particle swarm, simulated annealing and the island model, the genetic
    /// algorithm was missed — it had never used `100`, so it did not match the literal being
    /// searched for. Its own literal was `1000`, and that is preserved here so no existing
    /// caller's results move. There is no principled reason for the two defaults to differ;
    /// unifying them is a behaviour change and belongs to whoever decides which is right.
    ///
    /// A non-positive or non-finite value falls back to the default rather than being
    /// honoured: a weight of zero deletes the constraint silently, which is worse than any
    /// badly chosen weight.
    public let constraintPenaltyWeight: Double

    // MARK: - Initialization

    /// Create a genetic algorithm configuration.
    ///
    /// - Parameters:
    ///   - populationSize: Number of individuals per generation (default: 100)
    ///   - generations: Number of generations to evolve (default: 100)
    ///   - crossoverRate: Crossover probability [0.0, 1.0] (default: 0.8)
    ///   - mutationRate: Mutation probability per gene [0.0, 1.0] (default: 0.1)
    ///   - mutationStrength: Gaussian mutation standard deviation (default: 0.1)
    ///   - eliteCount: Number of elite individuals preserved (default: 2)
    ///   - tournamentSize: Tournament selection size (default: 3)
    ///   - seed: Random seed for reproducibility (default: nil)
    ///   - constraintPenaltyWeight: Penalty weight for constrained solves (default: 1000 —
    ///     see the property, which explains why this differs from the other heuristics)
    public init(
        populationSize: Int = 100,
        generations: Int = 100,
        crossoverRate: Double = 0.8,
        mutationRate: Double = 0.1,
        mutationStrength: Double = 0.1,
        eliteCount: Int = 2,
        tournamentSize: Int = 3,
        seed: UInt64? = nil,
        constraintPenaltyWeight: Double = 1000
    ) {
        let penaltyFallback: Double = 1000
        let penaltyIsUsable = constraintPenaltyWeight > 0 && constraintPenaltyWeight.isFinite
        self.constraintPenaltyWeight = penaltyIsUsable ? constraintPenaltyWeight : penaltyFallback
        self.populationSize = populationSize
        self.generations = generations
        self.crossoverRate = crossoverRate
        self.mutationRate = mutationRate
        self.mutationStrength = mutationStrength
        self.eliteCount = eliteCount
        self.tournamentSize = tournamentSize
        self.seed = seed
    }

    // MARK: - Presets

    /// Default configuration optimized for typical use cases.
    ///
    /// Balanced settings suitable for most optimization problems:
    /// - Population: 100 individuals
    /// - Generations: 100
    /// - Crossover rate: 80%
    /// - Mutation rate: 10%
    /// - Tournament size: 3
    public static let `default` = GeneticAlgorithmConfig()

    /// High-performance configuration for large-scale problems.
    ///
    /// Optimized for complex optimization tasks:
    /// - Population: 1000 individuals (enables GPU acceleration if available)
    /// - Generations: 500
    /// - Elite count: 10
    /// - Tournament size: 5 (higher selection pressure)
    ///
    /// ## Performance Note
    ///
    /// On systems with Metal support, this configuration automatically enables
    /// GPU acceleration for 10-100× speedup.
    public static let highPerformance = GeneticAlgorithmConfig(
        populationSize: 1000,
        generations: 500,
        eliteCount: 10,
        tournamentSize: 5
    )
}

// MARK: - Genetic Algorithm Result

/// Result of genetic algorithm optimization.
///
/// Contains the best solution found, convergence information, and historical data
/// for analysis and visualization.
///
/// ## Usage Example
///
/// ```swift
/// let optimizer = GeneticAlgorithm<VectorN<Double>>(
///     config: .default,
///     searchSpace: [(-10, 10), (-10, 10)]
/// )
///
/// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
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
/// - ``diversityHistory``
public struct GeneticAlgorithmResult<V: VectorSpace> where V.Scalar: Real {
    // MARK: - Solution

    /// Best solution found by the genetic algorithm.
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
    /// Typically `populationSize × generations` for standard genetic algorithms.
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
    /// let optimizer = GeneticAlgorithm<VectorN<Double>>(
    ///     config: .default,
    ///     searchSpace: [(-10, 10), (-10, 10)]
    /// )
    /// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
    /// let result = try optimizer.optimizeDetailed(objective: sphere)
    ///
    /// for (gen, bestFitness) in result.convergenceHistory.enumerated() {
    ///     print("Generation \(gen): Best = \(bestFitness)")
    /// }
    /// ```
    public let convergenceHistory: [V.Scalar]

    /// Population diversity (fitness variance) at each generation.
    ///
    /// This array has length equal to ``generations``. Higher values indicate
    /// a diverse population (exploration), while lower values indicate convergence
    /// (exploitation).
    ///
    /// ## Usage
    ///
    /// Use this to diagnose premature convergence:
    /// ```swift
    /// let optimizer = GeneticAlgorithm<VectorN<Double>>(
    ///     config: .default,
    ///     searchSpace: [(-10, 10), (-10, 10)]
    /// )
    /// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
    /// let result = try optimizer.optimizeDetailed(objective: sphere)
    ///
    /// if let diversity = result.diversityHistory.last, diversity < 0.001 {
    ///     print("Population may have converged prematurely")
    /// }
    /// ```
    public let diversityHistory: [V.Scalar]
}

// MARK: - Internal Types

/// Individual in genetic algorithm population (internal use).
internal struct Individual<V: VectorSpace> where V.Scalar: Real {
    /// Genetic representation (solution candidate).
    var genes: V

    /// Cached fitness value (objective function value).
    ///
    /// nil until evaluated, then cached to avoid redundant evaluations.
    var fitness: V.Scalar?

    /// Create an individual with uneval uated fitness.
    /// - Parameter genes: Genetic representation
    init(genes: V) {
        self.genes = genes
        self.fitness = nil
    }
}
