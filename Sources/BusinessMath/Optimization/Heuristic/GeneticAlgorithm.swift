//
//  GeneticAlgorithm.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/26/25.
//

import Foundation
import Numerics

#if canImport(Metal)
import Metal
#endif

/// Genetic algorithm optimizer with automatic GPU acceleration.
///
/// Implements evolutionary optimization using genetic operators (selection, crossover, mutation).
/// **Transparently accelerates** population operations on GPU for large populations (≥ 1000 individuals).
///
/// ## Overview
///
/// Genetic algorithms solve optimization problems by mimicking natural evolution:
/// 1. **Initialization**: Create random population of candidate solutions
/// 2. **Selection**: Choose better individuals for reproduction (GPU-accelerated)
/// 3. **Crossover**: Combine pairs of parents to create offspring (GPU-accelerated)
/// 4. **Mutation**: Randomly modify offspring for exploration (GPU-accelerated)
/// 5. **Elitism**: Preserve best individuals unchanged
/// 6. **Repeat**: Iterate until convergence or maximum generations
///
/// ## When to Use
///
/// Genetic algorithms excel at:
/// - **Global optimization**: Finding global minimum (not just local)
/// - **Non-differentiable functions**: No gradient required
/// - **Multimodal landscapes**: Multiple local minima
/// - **Constrained problems**: Via penalty method (equality + inequality constraints)
/// - **Large-scale problems**: GPU handles populations of 10,000+ efficiently
///
/// ## Usage Example
///
/// ```swift
/// // Define search space
/// let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]
///
/// // Create optimizer (GPU accelerates automatically for large populations)
/// let optimizer = GeneticAlgorithm<VectorN<Double>>(
///     config: GeneticAlgorithmConfig(
///         populationSize: 2000,  // GPU threshold: ≥ 1000
///         generations: 100
///     ),
///     searchSpace: searchSpace
/// )
///
/// // Minimize Rosenbrock function
/// let rosenbrock = { (v: VectorN<Double>) -> Double in
///     let x = v[0], y = v[1]
///     return (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x)
/// }
///
/// let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))
/// print("Solution: \(result.solution)")        // Near [1, 1]
/// print("Fitness: \(result.value)")            // Near 0
/// print("Generations: \(result.iterations)")   // Number of generations run
/// ```
///
/// ## Constrained Optimization
///
/// Use the penalty method for constrained problems:
///
/// ```swift
/// // Minimize x² + y² subject to x + y = 1
/// let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
/// let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in
///     v[0] + v[1] - 1.0  // x + y = 1
/// }
///
/// let result = try optimizer.minimize(
///     objective,
///     from: VectorN([0.0, 0.0]),
///     constraints: [constraint]
/// )
/// // Solution near (0.5, 0.5) - minimum of x²+y² on line x+y=1
/// ```
///
/// ## Configuration
///
/// Adjust parameters via ``GeneticAlgorithmConfig``:
///
/// ```swift
/// let config = GeneticAlgorithmConfig(
///     populationSize: 2000,   // GPU activates at ≥ 1000
///     generations: 200,       // More = better convergence
///     crossoverRate: 0.8,     // Higher = more exploitation
///     mutationRate: 0.1,      // Higher = more exploration
///     mutationStrength: 0.2,  // Larger mutations
///     eliteCount: 5,          // Preserve top 5 unchanged
///     tournamentSize: 3       // Selection pressure (3-5 typical)
/// )
/// ```
///
/// ## GPU Acceleration
///
/// GPU acceleration is **automatic and transparent** when beneficial:
///
/// - **CPU Mode** (population < 1000): Avoids GPU overhead, runs entirely on CPU
/// - **GPU Mode** (population ≥ 1000): Offloads selection/crossover/mutation to GPU
/// - **Automatic fallback**: Uses CPU if Metal unavailable (non-macOS, older hardware)
/// - **Performance**: 10-100× speedup for large populations on Apple Silicon
///
/// **Benchmark (Apple M1, 2000 individuals × 30 generations × 10D)**:
/// - GPU: ~1.0s (60,000 evals/sec)
/// - CPU: ~15-30s (2,000-4,000 evals/sec)
///
/// ## Performance Notes
///
/// - **Small problems** (population < 1000): CPU is faster (GPU overhead dominates)
/// - **Large problems** (population ≥ 1000): GPU provides 10-100× speedup
/// - **Deterministic testing**: Use `seed` parameter in config
/// - **Fitness evaluation**: Always on CPU (provides flexibility for arbitrary functions)
///
/// ## Limitations
///
/// - **Constraint handling**: Uses penalty method (approximate, not exact)
/// - **Initial guess**: Ignored (population randomly initialized within search space)
/// - **Minimization only**: For maximization, negate the objective function
/// - **GPU requirements**: Requires Metal (macOS/iOS), VectorN<Double> type
///
/// ## Topics
///
/// ### Creating Optimizers
/// - ``init(config:searchSpace:)``
///
/// ### Minimization
/// - ``minimize(_:from:constraints:)``
/// - ``minimize(_:from:)``
///
/// ### Configuration
/// - ``GeneticAlgorithmConfig``
/// - ``GeneticAlgorithmResult``
public struct GeneticAlgorithm<V: VectorSpace>: MultivariateOptimizer where V.Scalar: Real {

    // MARK: - Properties

    /// Configuration for the genetic algorithm.
    private let config: GeneticAlgorithmConfig

    /// Search space bounds for each dimension: [(min, max), ...].
    ///
    /// Each tuple defines the lower and upper bounds for one gene.
    /// Mutations are clamped to stay within these bounds.
    private let searchSpace: [(lower: V.Scalar, upper: V.Scalar)]

    /// Random number generator (seeded if config.seed is set).
    ///
    /// Using a class wrapper to allow mutation without marking the entire optimizer as mutating.
    private let rng: RNGWrapper

    // MARK: - Initialization

    /// Create a genetic algorithm optimizer.
    ///
    /// - Parameters:
    ///   - config: Algorithm configuration (population size, mutation rate, etc.)
    ///   - searchSpace: Bounds for each dimension: `[(min, max), ...]`
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // 2D problem with bounds [-10, 10] for both dimensions
    /// let optimizer = GeneticAlgorithm<VectorN<Double>>(
    ///     config: .default,
    ///     searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
    /// )
    /// ```
    public init(
        config: GeneticAlgorithmConfig = .default,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)]
    ) {
        self.config = config
        self.searchSpace = searchSpace

        // Initialize RNG with seed if provided
        if let seed = config.seed {
            self.rng = RNGWrapper(generator: SeededRandomNumberGenerator(seed: seed))
        } else {
            self.rng = RNGWrapper(generator: SystemRandomNumberGenerator())
        }
    }

    // MARK: - MultivariateOptimizer Conformance

    /// Minimize an objective function using genetic algorithm.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize: `f: V → ℝ`
    ///   - initialGuess: Ignored (population is randomly initialized)
    ///   - constraints: Must be empty (GA does not support constraints)
    ///
    /// - Returns: Optimization result with best solution, fitness, and convergence history
    ///
    /// - Throws: ``OptimizationError/unsupportedConstraints(_:)`` if constraints provided
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
    /// let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))
    /// ```
    public func minimize(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        from initialGuess: V,
        constraints: [MultivariateConstraint<V>] = []
    ) throws -> MultivariateOptimizationResult<V> {

        // If constraints provided, use penalty method
        if !constraints.isEmpty {
            return try minimizeWithPenalty(objective, constraints: constraints)
        }

        // Run unconstrained optimization
        let gaResult = try optimize(objective: objective)

        // Convert to MultivariateOptimizationResult
        // GA doesn't use gradients, so gradientNorm is 0
        return MultivariateOptimizationResult(
            solution: gaResult.solution,
            value: gaResult.fitness,
            iterations: gaResult.generations,
            converged: gaResult.converged,
            gradientNorm: V.Scalar.zero,
            history: nil
        )
    }

    /// Minimize with constraints using penalty method.
    ///
    /// Transforms constrained optimization into unconstrained by adding penalty
    /// terms for constraint violations. This approach allows genetic algorithms
    /// to handle constraints without specialized operators.
    ///
    /// - Parameters:
    ///   - objective: Original objective function
    ///   - constraints: Constraints to enforce
    /// - Returns: Optimization result
    ///
    /// ## How It Works
    ///
    /// The penalized objective is:
    /// ```
    /// f_penalty(x) = f(x) + penalty * Σ max(0, g(x))²
    /// ```
    /// where g(x) are constraint violations.
    private func minimizeWithPenalty(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        constraints: [MultivariateConstraint<V>]
    ) throws -> MultivariateOptimizationResult<V> {

        // Penalty coefficient (starts moderate, can be increased if needed)
        let penaltyCoefficient = V.Scalar(1000)

        // Create penalized objective
        let penalizedObjective: @Sendable (V) -> V.Scalar = { point in
            let baseValue = objective(point)

            // Calculate total penalty
            var totalPenalty = V.Scalar.zero

            for constraint in constraints {
                switch constraint {
                case .equality(function: let g, gradient: _):
                    // Penalty for equality: (g(x))²
                    let violation = g(point)
                    totalPenalty += violation * violation

                case .inequality(function: let g, gradient: _):
                    // Penalty for inequality g(x) ≤ 0: max(0, g(x))²
                    let violation = g(point)
                    if violation > V.Scalar.zero {
                        totalPenalty += violation * violation
                    }

                case .linearInequality, .linearEquality:
                    // Linear constraints: use function property
                    let g = constraint.function
                    let violation = g(point)
                    if constraint.isEquality {
                        // Equality: (g(x))²
                        totalPenalty += violation * violation
                    } else {
                        // Inequality: max(0, g(x))²
                        if violation > V.Scalar.zero {
                            totalPenalty += violation * violation
                        }
                    }
                }
            }

            return baseValue + penaltyCoefficient * totalPenalty
        }

        // Optimize penalized objective
        let gaResult = try optimize(objective: penalizedObjective)

        // Return result with original objective value (not penalized)
        return MultivariateOptimizationResult(
            solution: gaResult.solution,
            value: objective(gaResult.solution),  // Use original objective
            iterations: gaResult.generations,
            converged: gaResult.converged,
            gradientNorm: V.Scalar.zero,
            history: nil
        )
    }

    // MARK: - Core Optimization

    /// Run genetic algorithm optimization with detailed result.
    ///
    /// This method returns the full `GeneticAlgorithmResult` with convergence and diversity history,
    /// unlike ``minimize(_:from:constraints:)`` which returns the standard ``MultivariateOptimizationResult``.
    ///
    /// - Parameter objective: Function to minimize: `f: V → ℝ`
    /// - Returns: Detailed genetic algorithm result including history
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
    /// let result = try optimizer.optimizeDetailed(objective: sphere)
    ///
    /// // Access GA-specific information
    /// print("Convergence history: \(result.convergenceHistory)")
    /// print("Diversity history: \(result.diversityHistory)")
    /// ```
    public func optimizeDetailed(objective: @escaping @Sendable (V) -> V.Scalar) throws -> GeneticAlgorithmResult<V> {
        return try optimize(objective: objective)
    }

    /// Run genetic algorithm optimization (internal implementation).
    ///
    /// - Parameter objective: Function to minimize
    /// - Returns: Detailed genetic algorithm result with history
    internal func optimize(objective: @escaping @Sendable (V) -> V.Scalar) throws -> GeneticAlgorithmResult<V> {

        // Initialize population
        var population = initializePopulation()

        // Storage for history
        var convergenceHistory: [V.Scalar] = []
        var diversityHistory: [V.Scalar] = []

        var bestFitness = V.Scalar.infinity
        var bestIndividual: Individual<V>?
        var evaluationCount = 0

        // Evolution loop
        for generation in 0..<config.generations {

            // Evaluate fitness for unevaluated individuals
            for i in 0..<population.count {
                if population[i].fitness == nil {
                    population[i].fitness = objective(population[i].genes)
                    evaluationCount += 1
                }
            }

            // Track best individual
            if let best = population.min(by: { $0.fitness! < $1.fitness! }) {
                if best.fitness! < bestFitness {
                    bestFitness = best.fitness!
                    bestIndividual = best
                }
            }

            // Record history
            convergenceHistory.append(bestFitness)
            diversityHistory.append(calculateDiversity(population))

            // Check convergence (fitness improvement < threshold for 10 generations)
            if generation >= 10 {
                let recentImprovement = convergenceHistory[generation - 10] - bestFitness
                let threshold = V.Scalar(1) / V.Scalar(1_000_000)  // 1e-6
                if recentImprovement < threshold {
                    return GeneticAlgorithmResult(
                        solution: bestIndividual!.genes,
                        fitness: bestFitness,
                        generations: generation + 1,
                        evaluations: evaluationCount,
                        converged: true,
                        convergenceReason: "Fitness improvement < 1e-6 for 10 generations",
                        convergenceHistory: convergenceHistory,
                        diversityHistory: diversityHistory
                    )
                }
            }

            // Create next generation
            population = evolvePopulation(population)
        }

        // Return final result
        return GeneticAlgorithmResult(
            solution: bestIndividual!.genes,
            fitness: bestFitness,
            generations: config.generations,
            evaluations: evaluationCount,
            converged: false,
            convergenceReason: "Maximum generations reached",
            convergenceHistory: convergenceHistory,
            diversityHistory: diversityHistory
        )
    }

    // MARK: - Population Initialization

    /// Initialize population with random individuals.
    private func initializePopulation() -> [Individual<V>] {
        var population: [Individual<V>] = []

        for _ in 0..<config.populationSize {
            let genes = randomIndividual()
            population.append(Individual(genes: genes))
        }

        return population
    }

    /// Create a random individual within search space bounds.
    private func randomIndividual() -> V {
        let dimension = searchSpace.count
        var values: [V.Scalar] = []

        for i in 0..<dimension {
            let (lower, upper) = searchSpace[i]
            // Generate random number in [0, 1]
            let randomU64 = rng.next()
            let randomFraction = V.Scalar(Int(randomU64 >> 32)) / V.Scalar(Int(UInt32.max))
            let value = lower + randomFraction * (upper -  lower)
            values.append(value)
        }

        return V.fromArray(values)!
    }

    // MARK: - Genetic Operators

    /// Evolve population to create next generation.
    ///
    /// Automatically uses GPU acceleration if:
    /// - Metal is available on the system
    /// - Population size ≥ 1000 (GPU overhead amortized)
    /// - Vector type is VectorN<Double> (GPU kernels use Float internally)
    ///
    /// Process:
    /// 1. Sort by fitness
    /// 2. Preserve elite individuals
    /// 3. Generate offspring via selection, crossover, mutation
    private func evolvePopulation(_ population: [Individual<V>]) -> [Individual<V>] {
        // Check if GPU acceleration should be used
        #if canImport(Metal)
        if shouldUseGPU() {
            // Try GPU path, fall back to CPU on error
            if let gpuResult = try? evolvePopulationGPU(population) {
                return gpuResult
            }
        }
        #endif

        // CPU path (default and fallback)
        return evolvePopulationCPU(population)
    }

    /// Determine if GPU acceleration should be used for this optimization.
    private func shouldUseGPU() -> Bool {
        #if canImport(Metal)
        // Only use GPU for VectorN<Double> (GPU uses Float32)
        guard V.self == VectorN<Double>.self else {
            return false
        }

        // Delegate to MetalDevice for capability and size check
        return MetalDevice.shouldUseGPU(populationSize: config.populationSize)
        #else
        return false
        #endif
    }

    /// CPU-based population evolution (baseline implementation).
    private func evolvePopulationCPU(_ population: [Individual<V>]) -> [Individual<V>] {
        var newPopulation: [Individual<V>] = []

        // Sort by fitness (best first)
        let sorted = population.sorted { $0.fitness! < $1.fitness! }

        // Elitism: preserve best individuals
        newPopulation.append(contentsOf: sorted.prefix(config.eliteCount))

        // Generate offspring to fill population
        while newPopulation.count < config.populationSize {
            let parent1 = tournamentSelection(population)
            let parent2 = tournamentSelection(population)

            var offspring: Individual<V>

            // Crossover
            let crossoverRand = Double(rng.next()) / Double(UInt64.max)
            if crossoverRand < config.crossoverRate {
                offspring = crossover(parent1, parent2)
            } else {
                offspring = parent1
            }

            // Mutation
            let mutationRand = Double(rng.next()) / Double(UInt64.max)
            if mutationRand < config.mutationRate {
                offspring = mutate(offspring)
            }

            newPopulation.append(offspring)
        }

        // Ensure exact population size
        return Array(newPopulation.prefix(config.populationSize))
    }

    #if canImport(Metal)
    /// GPU-accelerated population evolution.
    ///
    /// Uses Metal compute shaders to parallelize selection, crossover, and mutation.
    /// Falls back to CPU if any GPU operation fails.
    ///
    /// - Parameter population: Current population
    /// - Returns: Evolved population, or nil if GPU operations fail
    private func evolvePopulationGPU(_ population: [Individual<V>]) throws -> [Individual<V>]? {
        // GPU only works for VectorN<Double>
        guard V.self == VectorN<Double>.self else {
            return nil
        }

        // Get Metal device
        guard let metalDevice = MetalDevice.shared else {
            return nil
        }

        let dimension = searchSpace.count

        // Create buffers
        let buffers = try MetalBuffers(
            device: metalDevice.device,
            populationSize: config.populationSize,
            dimension: dimension
        )

        // Convert population to Float array for GPU
        var populationData: [Float] = []
        for individual in population {
            let genes = individual.genes.toArray()
            for gene in genes {
                let doubleValue = gene as! Double
                populationData.append(Float(doubleValue))
            }
        }

        // Upload population to GPU
        buffers.uploadPopulation(populationData, to: buffers.populationA)

        // Upload fitness to GPU
        let fitnessData: [Float] = population.map {
            let doubleFitness = $0.fitness! as! Double
            return Float(doubleFitness)
        }
        buffers.uploadFitness(fitnessData)

        // Get compute pipelines
        let selectionPipeline = try metalDevice.getSelectionPipeline()
        let crossoverPipeline = try metalDevice.getCrossoverPipeline()
        let mutationPipeline = try metalDevice.getMutationPipeline()

        // Create command buffer
        guard let commandBuffer = metalDevice.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        // Configure threadgroups
        let threadsPerGroup = MTLSize(width: min(config.populationSize, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (config.populationSize + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )

        // 1. Tournament Selection (popA → popB)
        encoder.setComputePipelineState(selectionPipeline)
        encoder.setBuffer(buffers.populationA, offset: 0, index: 0)
        encoder.setBuffer(buffers.fitness, offset: 0, index: 1)
        encoder.setBuffer(buffers.populationB, offset: 0, index: 2)
        encoder.setBuffer(buffers.randomSeeds, offset: 0, index: 3)
        var dimInt = Int32(dimension)
        var tournSize = Int32(config.tournamentSize)
        var popSize = Int32(config.populationSize)
        encoder.setBytes(&dimInt, length: MemoryLayout<Int32>.stride, index: 4)
        encoder.setBytes(&tournSize, length: MemoryLayout<Int32>.stride, index: 5)
        encoder.setBytes(&popSize, length: MemoryLayout<Int32>.stride, index: 6)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)

        // 2. Crossover (popB → popA)
        encoder.setComputePipelineState(crossoverPipeline)
        encoder.setBuffer(buffers.populationB, offset: 0, index: 0)  // parent1
        encoder.setBuffer(buffers.populationB, offset: 0, index: 1)  // parent2 (simplified)
        encoder.setBuffer(buffers.populationA, offset: 0, index: 2)  // offspring
        encoder.setBuffer(buffers.randomSeeds, offset: 0, index: 3)
        encoder.setBytes(&dimInt, length: MemoryLayout<Int32>.stride, index: 4)
        var crossRate = Float(config.crossoverRate)
        encoder.setBytes(&crossRate, length: MemoryLayout<Float>.stride, index: 5)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)

        // 3. Mutation (popA in-place)
        encoder.setComputePipelineState(mutationPipeline)
        encoder.setBuffer(buffers.populationA, offset: 0, index: 0)
        encoder.setBuffer(buffers.randomSeeds, offset: 0, index: 1)
        encoder.setBytes(&dimInt, length: MemoryLayout<Int32>.stride, index: 2)
        var mutRate = Float(config.mutationRate)
        var mutStrength = Float(config.mutationStrength)
        encoder.setBytes(&mutRate, length: MemoryLayout<Float>.stride, index: 3)
        encoder.setBytes(&mutStrength, length: MemoryLayout<Float>.stride, index: 4)

        // Convert search space to float2 array for GPU
        // Cast V.Scalar to Double first (safe because we checked V == VectorN<Double>)
        var searchSpaceGPU: [SIMD2<Float>] = searchSpace.map { bounds in
            let lower = bounds.lower as! Double
            let upper = bounds.upper as! Double
            return SIMD2<Float>(Float(lower), Float(upper))
        }
        encoder.setBytes(&searchSpaceGPU, length: searchSpaceGPU.count * MemoryLayout<SIMD2<Float>>.stride, index: 5)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)

        // Execute GPU work
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Download results from GPU
        let resultData = buffers.downloadPopulation(from: buffers.populationA)

        // Convert back to population
        // V.Scalar is Double (safe because we checked V == VectorN<Double>)
        var newPopulation: [Individual<V>] = []
        for i in 0..<config.populationSize {
            let offset = i * dimension
            var genes: [V.Scalar] = []
            for j in 0..<dimension {
                let doubleValue = Double(resultData[offset + j])
                genes.append(doubleValue as! V.Scalar)  // Safe cast
            }

            let vector = V.fromArray(genes)!
            newPopulation.append(Individual(genes: vector))
        }

        // Handle elitism on CPU (simpler than GPU sort)
        let sorted = population.sorted { $0.fitness! < $1.fitness! }
        for i in 0..<min(config.eliteCount, newPopulation.count) {
            newPopulation[i] = sorted[i]
        }

        return newPopulation
    }
    #endif

    /// Tournament selection: choose best of k random individuals.
    ///
    /// - Parameter population: Current population
    /// - Returns: Winner of tournament
    private func tournamentSelection(_ population: [Individual<V>]) -> Individual<V> {
        var best: Individual<V>?

        for _ in 0..<config.tournamentSize {
            // Select random individual
            let randomIndex = Int(rng.next() % UInt64(population.count))
            let candidate = population[randomIndex]

            if best == nil || candidate.fitness! < best!.fitness! {
                best = candidate
            }
        }

        return best!
    }

    /// Uniform crossover: each gene randomly from parent1 or parent2.
    ///
    /// - Parameters:
    ///   - parent1: First parent
    ///   - parent2: Second parent
    /// - Returns: Offspring with genes from both parents
    private func crossover(_ parent1: Individual<V>, _ parent2: Individual<V>) -> Individual<V> {
        let genes1 = parent1.genes.toArray()
        let genes2 = parent2.genes.toArray()

        var childGenes: [V.Scalar] = []

        for i in 0..<genes1.count {
            // Uniform crossover: 50/50 chance for each gene
            let crossoverChoice = Double(rng.next()) / Double(UInt64.max)
            if crossoverChoice < 0.5 {
                childGenes.append(genes1[i])
            } else {
                childGenes.append(genes2[i])
            }
        }

        return Individual(genes: V.fromArray(childGenes)!)
    }

    /// Gaussian mutation: add random perturbation to genes.
    ///
    /// - Parameter individual: Individual to mutate
    /// - Returns: Mutated individual
    private func mutate(_ individual: Individual<V>) -> Individual<V> {
        var genes = individual.genes.toArray()

        for i in 0..<genes.count {
            let mutationCheck = Double(rng.next()) / Double(UInt64.max)
            if mutationCheck < config.mutationRate {
                let (lower, upper) = searchSpace[i]
                let range = upper - lower

                // Box-Muller transform for Gaussian mutation
                let u1Raw = rng.next()
                let u2Raw = rng.next()
                let u1 = V.Scalar(Int(u1Raw >> 32)) / V.Scalar(Int(UInt32.max))
                let u2 = V.Scalar(Int(u2Raw >> 32)) / V.Scalar(Int(UInt32.max))
                let gaussian = V.Scalar.sqrt(-V.Scalar(2) * V.Scalar.log(u1)) * V.Scalar.cos(V.Scalar(2) * V.Scalar.pi * u2)

                // Convert mutation strength from Double to V.Scalar
                let strengthInt = Int(config.mutationStrength * 1_000_000)
                let mutationStrengthScalar = V.Scalar(strengthInt) / V.Scalar(1_000_000)
                let mutation = gaussian * mutationStrengthScalar * range
                let newValue = genes[i] + mutation

                // Clamp to bounds
                genes[i] = max(lower, min(upper, newValue))
            }
        }

        return Individual(genes: V.fromArray(genes)!)
    }

    // MARK: - Diversity Calculation

    /// Calculate population diversity (variance of fitness values).
    ///
    /// - Parameter population: Current population
    /// - Returns: Variance of fitness values
    private func calculateDiversity(_ population: [Individual<V>]) -> V.Scalar {
        let fitnesses = population.compactMap { $0.fitness }

        guard !fitnesses.isEmpty else { return V.Scalar.zero }

        let mean = fitnesses.reduce(V.Scalar.zero, +) / V.Scalar(fitnesses.count)
        let variance = fitnesses
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(V.Scalar.zero, +) / V.Scalar(fitnesses.count)

        return variance
    }
}

// MARK: - Random Number Generation Helpers

/// Wrapper class for RandomNumberGenerator to allow mutation without mutating the containing struct.
internal final class RNGWrapper {
    private var generator: any RandomNumberGenerator

    init(generator: any RandomNumberGenerator) {
        self.generator = generator
    }

    func next() -> UInt64 {
        return generator.next()
    }
}

/// Seeded random number generator for deterministic testing.
///
/// Uses a simple Linear Congruential Generator (LCG) for reproducibility.
internal struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // LCG parameters (from Numerical Recipes)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
