//
//  IslandModelTypes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

import Foundation
import Numerics

// MARK: - Migration Topology

/// Migration topology for island model genetic algorithm.
///
/// The topology determines how individuals migrate between islands:
///
/// - **Ring**: Each island exchanges with its immediate neighbors in a circular pattern.
///   Island 0 ↔ Island 1 ↔ Island 2 ↔ ... ↔ Island N-1 ↔ Island 0
///
/// - **Fully Connected**: All islands can exchange individuals with all other islands.
///   Promotes faster information sharing but may reduce diversity.
///
/// - **Random**: Each migration randomly selects target islands.
///   Maintains diversity while allowing information flow.
///
/// ## Usage Example
///
/// ```swift
/// // Ring topology for gradual information diffusion
/// let ringConfig = IslandModelConfig(
///     numberOfIslands: 4,
///     topology: .ring
/// )
///
/// // Fully connected for aggressive information sharing
/// let fullyConnectedConfig = IslandModelConfig(
///     numberOfIslands: 8,
///     topology: .fullyConnected
/// )
/// ```
public enum MigrationTopology: Sendable, Equatable {
    /// Ring topology: each island connects to neighbors
    case ring

    /// Fully connected: all islands connect to each other
    case fullyConnected

    /// Random topology: random connections each migration
    case random
}

// MARK: - Island Model Configuration

/// Configuration for island model genetic algorithm.
///
/// The Island Model is a distributed GA variant that maintains multiple independent
/// populations (islands) that occasionally exchange elite individuals. This approach:
///
/// - **Maintains diversity**: Different islands explore different regions
/// - **Escapes local optima**: Migration introduces new genetic material
/// - **Parallelizes naturally**: Islands can evolve independently
/// - **Improves robustness**: Less likely to converge prematurely
///
/// ## Key Parameters
///
/// - **numberOfIslands**: How many independent populations to maintain (typical: 3-10)
/// - **migrationInterval**: How often islands exchange individuals (typical: 5-20 generations)
/// - **migrationSize**: How many elite individuals migrate (typical: 1-5)
/// - **topology**: How islands are connected (ring, fullyConnected, random)
///
/// ## Performance Characteristics
///
/// | Islands | Migration | Best For |
/// |---------|-----------|----------|
/// | 1 | N/A | Standard GA (baseline) |
/// | 3-5 | Frequent (5-10) | Smooth landscapes, fast convergence |
/// | 5-10 | Moderate (10-20) | Multimodal problems, exploration |
/// | 10+ | Infrequent (20+) | Maximum diversity, difficult problems |
///
/// ## Usage Example
///
/// ```swift
/// // Default configuration (4 islands, ring topology)
/// let config = IslandModelConfig.default
///
/// // Custom configuration for difficult multimodal problem
/// let customConfig = IslandModelConfig(
///     numberOfIslands: 8,
///     migrationInterval: 15,
///     migrationSize: 3,
///     topology: .fullyConnected
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Configurations
/// - ``init(numberOfIslands:migrationInterval:migrationSize:topology:)``
/// - ``default``
/// - ``highPerformance``
///
/// ### Configuration Properties
/// - ``numberOfIslands``
/// - ``migrationInterval``
/// - ``migrationSize``
/// - ``topology``
public struct IslandModelConfig: Sendable {
    // MARK: - Properties

    /// Number of independent islands (populations).
    ///
    /// Each island maintains its own population and evolves independently
    /// between migrations. More islands increase diversity and exploration
    /// but require more computational resources.
    ///
    /// Typical values: 3-10. For GPU acceleration (populations ≥ 1000 per island),
    /// 3-5 islands are optimal.
    public let numberOfIslands: Int

    /// Number of generations between migrations.
    ///
    /// Controls how often islands exchange individuals:
    /// - **Frequent (5-10)**: Fast information sharing, quicker convergence
    /// - **Moderate (10-20)**: Balanced exploration and exploitation
    /// - **Infrequent (20+)**: Maximum diversity, slower convergence
    ///
    /// Typical values: 5-20.
    public let migrationInterval: Int

    /// Number of elite individuals migrating from each island.
    ///
    /// During migration, the top `migrationSize` individuals from each island
    /// are sent to connected islands. Larger values accelerate information
    /// sharing but may reduce diversity.
    ///
    /// Typical values: 1-5 (1-10% of population size).
    public let migrationSize: Int

    /// Migration topology determining island connectivity.
    ///
    /// See ``MigrationTopology`` for available options:
    /// - `.ring`: Gradual diffusion through neighbors
    /// - `.fullyConnected`: Fast global information sharing
    /// - `.random`: Stochastic connectivity for diversity
    public let topology: MigrationTopology

    // MARK: - Initialization

    /// Create an island model configuration.
    ///
    /// - Parameters:
    ///   - numberOfIslands: Number of independent islands (default: 4)
    ///   - migrationInterval: Generations between migrations (default: 10)
    ///   - migrationSize: Number of elite migrants (default: 2)
    ///   - topology: Migration connectivity pattern (default: .ring)
    public init(
        numberOfIslands: Int = 4,
        migrationInterval: Int = 10,
        migrationSize: Int = 2,
        topology: MigrationTopology = .ring
    ) {
        self.numberOfIslands = numberOfIslands
        self.migrationInterval = migrationInterval
        self.migrationSize = migrationSize
        self.topology = topology
    }

    // MARK: - Presets

    /// Default island model configuration.
    ///
    /// Balanced settings suitable for most optimization problems:
    /// - 4 islands (good diversity without excessive overhead)
    /// - Migration every 10 generations (moderate information sharing)
    /// - 2 elite migrants (1-4% of typical population)
    /// - Ring topology (gradual information diffusion)
    public static let `default` = IslandModelConfig()

    /// High-performance configuration for large-scale problems.
    ///
    /// Optimized for difficult optimization tasks:
    /// - 5 islands (strong diversity)
    /// - Migration every 20 generations (preserve exploration)
    /// - 5 elite migrants (accelerate convergence when beneficial)
    /// - Fully connected topology (efficient information sharing)
    ///
    /// ## GPU Acceleration
    ///
    /// Pair with `GeneticAlgorithmConfig.highPerformance` to enable GPU
    /// acceleration on each island for maximum performance:
    ///
    /// ```swift
    /// let gaConfig = GeneticAlgorithmConfig.highPerformance  // 1000 pop/island
    /// let islandConfig = IslandModelConfig.highPerformance   // 5 islands
    ///
    /// let optimizer = IslandModel<VectorN<Double>>(
    ///     gaConfig: gaConfig,
    ///     islandConfig: islandConfig,
    ///     searchSpace: bounds
    /// )
    /// // Total: 5 islands × 1000 individuals = 5000 individuals
    /// // Each island runs GPU-accelerated GA independently
    /// // Typical speedup: 10-20× vs CPU-only
    /// ```
    public static let highPerformance = IslandModelConfig(
        numberOfIslands: 5,
        migrationInterval: 20,
        migrationSize: 5,
        topology: .fullyConnected
    )
}

// MARK: - Island Model Result

/// Result of island model genetic algorithm optimization.
///
/// Contains the best solution found across all islands, along with detailed
/// information about each island's performance and migration statistics.
///
/// ## Usage Example
///
/// ```swift
/// let optimizer = IslandModel<VectorN<Double>>(
///     gaConfig: .default,
///     islandConfig: .default,
///     searchSpace: bounds
/// )
///
/// let result = try optimizer.optimizeDetailed(objective: myFunction)
///
/// print("Best solution: \(result.solution)")
/// print("Best fitness: \(result.bestFitness)")
/// print("Island fitnesses: \(result.islandFitnesses)")
/// print("Migrations performed: \(result.migrationCount)")
/// ```
///
/// ## Topics
///
/// ### Solution
/// - ``solution``
/// - ``bestFitness``
///
/// ### Island Information
/// - ``islandFitnesses``
/// - ``bestIslandIndex``
///
/// ### Execution Statistics
/// - ``generations``
/// - ``totalEvaluations``
/// - ``migrationCount``
public struct IslandModelResult<V: VectorSpace> where V.Scalar: Real {
    // MARK: - Solution

    /// Best solution found across all islands.
    ///
    /// This is the individual with the best fitness from any island
    /// at the end of the optimization run.
    public let solution: V

    /// Fitness of the best solution (objective function value).
    ///
    /// Lower values are better (minimization problem).
    public let bestFitness: V.Scalar

    // MARK: - Island Information

    /// Final best fitness of each island.
    ///
    /// Array of length `numberOfIslands` containing the best fitness
    /// found by each island. Useful for analyzing island diversity
    /// and convergence patterns.
    ///
    /// Example:
    /// ```swift
    /// for (i, fitness) in result.islandFitnesses.enumerated() {
    ///     print("Island \(i): fitness = \(fitness)")
    /// }
    /// ```
    public let islandFitnesses: [V.Scalar]

    /// Index of the island that found the best solution.
    ///
    /// Useful for understanding which island configuration or random
    /// initialization led to the best result.
    public let bestIslandIndex: Int

    // MARK: - Execution Statistics

    /// Number of generations performed.
    ///
    /// All islands run for the same number of generations (synchronous evolution).
    public let generations: Int

    /// Total number of fitness evaluations across all islands.
    ///
    /// Typically `numberOfIslands × populationSize × (generations + 1)`.
    public let totalEvaluations: Int

    /// Number of migrations performed.
    ///
    /// Calculated as `generations / migrationInterval`.
    /// Useful for understanding information flow between islands.
    public let migrationCount: Int
}
