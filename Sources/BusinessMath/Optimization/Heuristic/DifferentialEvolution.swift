//
//  DifferentialEvolution.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

import Foundation
import Numerics

#if canImport(Metal)
import Metal
#endif

/// Differential Evolution optimizer for continuous optimization problems with automatic GPU acceleration.
///
/// Differential Evolution (DE) is a population-based metaheuristic that uses vector differences
/// to create trial solutions. It's particularly effective for continuous numerical optimization
/// and often outperforms genetic algorithms on such problems.
///
/// ## Algorithm Overview
///
/// DE evolves a population through three operations:
/// 1. **Mutation**: Create trial vector using vector differences
/// 2. **Crossover**: Mix components from trial and target vectors
/// 3. **Selection**: Keep better of trial vs target
///
/// ## GPU Acceleration
///
/// GPU acceleration is **automatic and transparent**:
///
/// - **CPU Mode** (population < 1000): Avoids GPU overhead, runs entirely on CPU
/// - **GPU Mode** (population ≥ 1000): Offloads mutation/crossover to GPU for 10-50× speedup
/// - **Automatic fallback**: Falls back to CPU if GPU unavailable or fails
///
/// **Benchmark (Apple M1, 2000 individuals × 100 generations × 10D)**:
/// - GPU: ~2-3s (60,000-80,000 evals/sec)
/// - CPU: ~20-40s (5,000-10,000 evals/sec)
///
/// See ``DifferentialEvolutionConfig/highPerformance`` for GPU-optimized settings.
///
/// ## Usage Example
///
/// ```swift
/// // Minimize Rosenbrock function
/// let optimizer = DifferentialEvolution<VectorN<Double>>(
///     config: .default,
///     searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
/// )
///
/// let rosenbrock = { @Sendable (v: VectorN<Double>) -> Double in
///     let x = v[0], y = v[1]
///     return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
/// }
///
/// let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))
/// // result.solution ≈ [1.0, 1.0]
/// ```
///
/// ## Features
///
/// - **GPU-accelerated**: Automatic Metal acceleration for populations ≥ 1000
/// - **Multiple strategies**: rand/1, best/1, currentToBest1
/// - **Constraint handling**: Equality and inequality constraints via penalty method
/// - **Early convergence**: Stops when improvement stalls
/// - **Deterministic**: Reproducible results with seed parameter
///
/// ## Performance
///
/// - Typically outperforms GA on continuous problems
/// - Good for multimodal functions
/// - Scales well to 10-100 dimensions
/// - GPU provides 10-50× speedup for large populations
///
/// ## Topics
///
/// ### Creating Optimizers
/// - ``init(config:searchSpace:)``
///
/// ### Optimization Methods
/// - ``minimize(_:from:constraints:)``
/// - ``optimizeDetailed(objective:)``
///
/// ### Related Types
/// - ``DifferentialEvolutionConfig``
/// - ``DifferentialEvolutionStrategy``
/// - ``DifferentialEvolutionResult``
public struct DifferentialEvolution<V: VectorSpace>: MultivariateOptimizer where V.Scalar: Real {

    // MARK: - Properties

    /// Configuration for the differential evolution algorithm.
    private let config: DifferentialEvolutionConfig

    /// Search space bounds for each dimension: [(min, max), ...].
    ///
    /// Each tuple defines the lower and upper bounds for one component.
    /// Trial vectors are clamped to stay within these bounds.
    private let searchSpace: [(lower: V.Scalar, upper: V.Scalar)]

    /// Random number generator (seeded if config.seed is set).
    ///
    /// Using a class wrapper to allow mutation without marking the entire optimizer as mutating.
    private let rng: RNGWrapper

    // MARK: - Initialization

    /// Create a differential evolution optimizer.
    ///
    /// - Parameters:
    ///   - config: Algorithm configuration (population size, mutation factor, etc.)
    ///   - searchSpace: Bounds for each dimension: `[(min, max), ...]`
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // 2D problem with bounds [-10, 10] for both dimensions
    /// let optimizer = DifferentialEvolution<VectorN<Double>>(
    ///     config: .default,
    ///     searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
    /// )
    /// ```
    public init(
        config: DifferentialEvolutionConfig = .default,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)]
    ) {
        self.config = config
        self.searchSpace = searchSpace

        // Initialize RNG with seed if provided
        if let seed = config.seed {
            self.rng = RNGWrapper(generator: SeededRandomNumberGenerator(seed: seed))
        } else {
            self.rng = RNGWrapper(generator: SystemRandomNumberGenerator()) // stochastic:exempt — the documented unseeded path; set `config.seed` for reproducibility
        }
    }

    // MARK: - MultivariateOptimizer Conformance

    /// Minimize an objective function using differential evolution.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize: `f: V → ℝ`
    ///   - initialGuess: Ignored (population is randomly initialized)
    ///   - constraints: Optional equality/inequality constraints (handled via penalty method)
    ///
    /// - Returns: Optimization result with best solution and fitness
    ///
    /// - Throws: ``OptimizationError/invalidInput(message:)`` if a seeded run's GPU attempt
    ///   is abandoned — see ``optimizeDetailed(objective:)``. Constraints themselves never
    ///   throw; they are handled by the penalty method.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let optimizer = DifferentialEvolution<VectorN<Double>>(config: .default, searchSpace: [(-10.0, 10.0), (-10.0, 10.0)])
    /// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
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
        let detailedResult = try optimizeDetailed(objective: objective)

        // Convert to MultivariateOptimizationResult
        return MultivariateOptimizationResult(
            solution: detailedResult.solution,
            value: detailedResult.fitness,
            iterations: detailedResult.generations,
            converged: detailedResult.converged,
            gradientNorm: V.Scalar.zero,  // Not gradient-based
            history: nil
        )
    }

    // MARK: - Detailed Optimization

    /// Run differential evolution with detailed result tracking.
    ///
    /// This method provides more information than ``minimize(_:from:constraints:)``,
    /// including convergence history and evaluation counts.
    ///
    /// - Parameter objective: Function to minimize: `f: V → ℝ`
    ///
    /// - Returns: Detailed result with convergence information
    ///
    /// - Throws: ``OptimizationError/invalidInput(message:)`` when a **seeded** run's GPU
    ///   attempt is abandoned after it has drawn from the generator. The CPU path is a
    ///   different implementation — `Double` where the kernels are `Float` — so completing
    ///   the run on it would return a different answer under a seed that promised one
    ///   answer. Refusing is the only response that keeps the promise. An **unseeded** run
    ///   never throws: it falls back to the CPU, which is what a caller who set no seed
    ///   wanted. Sizes below the GPU threshold cannot reach either case.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
    /// let optimizer = DifferentialEvolution<VectorN<Double>>(config: .default, searchSpace: [(-10.0, 10.0), (-10.0, 10.0)])
    /// let result = try optimizer.optimizeDetailed(objective: sphere)
    /// print("Converged: \(result.converged)")
    /// print("Reason: \(result.convergenceReason)")
    /// print("Generations: \(result.generations)")
    /// ```
    public func optimizeDetailed(
        objective: @escaping (V) -> V.Scalar
    ) throws -> DifferentialEvolutionResult<V> {

        let dimension = searchSpace.count

        // Initialize population randomly within search space
        var population = initializePopulation(size: config.populationSize, dimension: dimension)

        // Evaluate initial population
        var fitness = population.map { objective($0) }
        var evaluations = config.populationSize

        // Track best solution
        guard let initialBestIndex = fitness.indices.min(by: { fitness[$0] < fitness[$1] }) else {
            return DifferentialEvolutionResult(
                solution: population[0],
                fitness: fitness[0],
                generations: 0,
                evaluations: evaluations,
                converged: false,
                convergenceReason: "Empty population",
                convergenceHistory: []
            )
        }
        var bestIndex = initialBestIndex
        var bestSolution = population[bestIndex]
        var bestFitness = fitness[bestIndex]

        // Convergence tracking
        var convergenceHistory: [V.Scalar] = []
        var generationsWithoutImprovement = 0
        let improvementThreshold = V.Scalar(1) / V.Scalar(1_000_000)  // 1e-6
        let maxGenerationsWithoutImprovement = 10

        // Evolution loop
        var generation = 0
        var converged = false
        var convergenceReason = ""

        while generation < config.generations {
            let previousBest = bestFitness

            // Try GPU path if available, fall back to CPU
            var usedGPU = false
            #if canImport(Metal)
            if shouldUseGPU() {
                // `shouldUseGPU()` has already decided the GPU applies, so everything inside
                // the attempt is either a result or a mid-flight abort — never "the GPU did
                // not apply here". That distinction is the whole defect this runner exists
                // for: the attempt draws one kernel seed per individual before the first
                // operation that can fail, so abandoning it without rewinding would leave
                // the generator advanced and the CPU fallback resuming where no seed
                // predicts. See GPU/GPUAttempt.swift.
                let outcome = rng.attemptGPU(seeded: config.seed != nil) {
                    try runGenerationGPU(
                        population: population,
                        fitness: fitness,
                        bestIndex: bestIndex,
                        objective: objective
                    )
                }

                if let gpuResult = try outcome.resultOrCPUFallback(
                    operation: "GPU differential evolution generation \(generation)"
                ) {
                    population = gpuResult.population
                    fitness = gpuResult.fitness
                    bestIndex = gpuResult.bestIndex
                    bestFitness = fitness[bestIndex]
                    bestSolution = population[bestIndex]
                    evaluations += config.populationSize
                    usedGPU = true
                }
            }
            #endif

            if !usedGPU {
                // CPU path (or GPU fallback)
                // Create trial population
                var trialPopulation = [V]()
                trialPopulation.reserveCapacity(config.populationSize)

                for i in 0..<config.populationSize {
                    // Mutation: create mutant vector
                    let mutant = createMutant(
                        population: population,
                        targetIndex: i,
                        bestIndex: bestIndex,
                        dimension: dimension
                    )

                    // Crossover: mix target and mutant
                    let trial = crossover(
                        target: population[i],
                        mutant: mutant,
                        dimension: dimension
                    )

                    trialPopulation.append(trial)
                }

                // Evaluate trial population
                let trialFitness = trialPopulation.map { objective($0) }
                evaluations += config.populationSize

                // Selection: keep better of trial vs target
                for i in 0..<config.populationSize {
                    if trialFitness[i] < fitness[i] {
                        population[i] = trialPopulation[i]
                        fitness[i] = trialFitness[i]

                        // Update best if needed
                        if trialFitness[i] < bestFitness {
                            bestFitness = trialFitness[i]
                            bestSolution = trialPopulation[i]
                            bestIndex = i
                        }
                    }
                }
            }

            // Record convergence
            convergenceHistory.append(bestFitness)
            generation += 1

            // Check for convergence
            let improvement = previousBest - bestFitness
            if improvement < improvementThreshold {
                generationsWithoutImprovement += 1
                if generationsWithoutImprovement >= maxGenerationsWithoutImprovement {
                    converged = true
                    convergenceReason = "Fitness improvement < \(improvementThreshold) for \(maxGenerationsWithoutImprovement) generations"
                    break
                }
            } else {
                generationsWithoutImprovement = 0
            }
        }

        if !converged {
            convergenceReason = "Maximum generations reached"
        }

        return DifferentialEvolutionResult(
            solution: bestSolution,
            fitness: bestFitness,
            generations: generation,
            evaluations: evaluations,
            converged: converged,
            convergenceReason: convergenceReason,
            convergenceHistory: convergenceHistory
        )
    }

    // MARK: - Private Helpers

    /// Initialize population randomly within search space bounds.
    private func initializePopulation(size: Int, dimension: Int) -> [V] {
        var population = [V]()
        population.reserveCapacity(size)

        for _ in 0..<size {
            var components = [V.Scalar]()
            components.reserveCapacity(dimension)

            for d in 0..<dimension {
                let (lower, upper) = searchSpace[d]
                // Generate random value in [0, 1)
                let randRaw = rng.next()
                let randValue = V.Scalar(Int(randRaw >> 32)) / V.Scalar(Int(UInt32.max)) // fp-safety:disable
                let value = lower + randValue * (upper - lower)
                components.append(value)
            }

            guard let vector = V.fromArray(components) else { continue }
            population.append(vector)
        }

        return population
    }

    /// Create a mutant vector using the configured strategy.
    private func createMutant(
        population: [V],
        targetIndex: Int,
        bestIndex: Int,
        dimension: Int
    ) -> V {
        let popSize = population.count
        // Convert mutation factor to V.Scalar
        let FInt = Int(config.mutationFactor * 1_000_000)
        let F = V.Scalar(FInt) / V.Scalar(1_000_000)

        switch config.strategy {
        case .rand1:
            // rand/1: mutant = r1 + F × (r2 - r3)
            let indices = selectDistinctRandomIndices(count: 3, excluding: targetIndex, max: popSize)
            let r1 = population[indices[0]]
            let r2 = population[indices[1]]
            let r3 = population[indices[2]]

            let mutant = r1 + F * (r2 - r3)
            return clampToSearchSpace(mutant)

        case .best1:
            // best/1: mutant = best + F × (r1 - r2)
            let indices = selectDistinctRandomIndices(count: 2, excluding: targetIndex, max: popSize)
            let best = population[bestIndex]
            let r1 = population[indices[0]]
            let r2 = population[indices[1]]

            let mutant = best + F * (r1 - r2)
            return clampToSearchSpace(mutant)

        case .currentToBest1:
            // current-to-best/1: mutant = current + F × (best - current) + F × (r1 - r2)
            let indices = selectDistinctRandomIndices(count: 2, excluding: targetIndex, max: popSize)
            let current = population[targetIndex]
            let best = population[bestIndex]
            let r1 = population[indices[0]]
            let r2 = population[indices[1]]

            let term1 = F * (best - current)
            let term2 = F * (r1 - r2)
            let mutant = current + term1 + term2
            return clampToSearchSpace(mutant)
        }
    }

    /// Perform binomial crossover between target and mutant vectors.
    private func crossover(
        target: V,
        mutant: V,
        dimension: Int
    ) -> V {
        let targetArray = target.toArray()
        let mutantArray = mutant.toArray()

        var trial = [V.Scalar]()
        trial.reserveCapacity(dimension)

        // Ensure at least one component from mutant
        let jRand = Int(rng.next() % UInt64(dimension))

        for j in 0..<dimension {
            // Generate random [0,1) value
            let randValue = Double(rng.next()) / Double(UInt64.max) // fp-safety:disable
            if randValue < config.crossoverRate || j == jRand {
                trial.append(mutantArray[j])
            } else {
                trial.append(targetArray[j])
            }
        }

        guard let result = V.fromArray(trial) else { return target }
        return result
    }

    /// Clamp a vector to search space bounds.
    private func clampToSearchSpace(_ vector: V) -> V {
        let vectorArray = vector.toArray()
        var clamped = [V.Scalar]()
        clamped.reserveCapacity(searchSpace.count)

        for (i, (lower, upper)) in searchSpace.enumerated() {
            let value = vectorArray[i]
            clamped.append(min(max(value, lower), upper))
        }

        guard let result = V.fromArray(clamped) else { return vector }
        return result
    }

    /// Select distinct random indices, excluding a specific index.
    private func selectDistinctRandomIndices(
        count: Int,
        excluding: Int,
        max: Int
    ) -> [Int] {
        var indices = Set<Int>()
        indices.insert(excluding)  // Exclude this one

        while indices.count < count + 1 {
            let idx = Int(rng.next() % UInt64(max))
            indices.insert(idx)
        }

        // Remove excluded index and return sorted (for determinism)
        indices.remove(excluding)
        return Array(indices).sorted()
    }

    // MARK: - GPU Acceleration

    /// Determine if GPU acceleration should be used.
    ///
    /// GPU is enabled when:
    /// 1. Metal is available
    /// 2. Using VectorN<Double> (GPU uses Float32)
    /// 3. Population size >= 1000 (GPU overhead not worth it for small populations)
    ///
    /// - Returns: true if GPU should be used
    ///
    /// A seed is deliberately *not* one of the conditions. 2.6.0 declined the GPU whenever
    /// one was set, because a mid-flight GPU failure would otherwise finish the run on the
    /// CPU — a `Double` implementation where the kernels are `Float` — and return a
    /// different answer under a seed that promised one. That was determinism bought by
    /// giving up the acceleration for exactly the callers most likely to need it.
    /// ``optimizeDetailed(objective:)`` now throws, so it can refuse a broken promise
    /// instead of arranging never to be in a position to make one, and a seeded run reaches
    /// the GPU again. See project/plans/proposals/GPUAttemptSeedContract.md §4.
    ///
    /// Internal rather than private so the tests can assert that a seeded configuration at
    /// the threshold really does engage the GPU: a determinism test that quietly ran on the
    /// CPU would pass while proving nothing about the path it is named for.
    internal func shouldUseGPU() -> Bool {
        #if canImport(Metal)
        // Only use GPU for VectorN<Double> (GPU uses Float32)
        guard V.self == VectorN<Double>.self else {
            return false
        }

        // Check if Metal device available and population large enough
        return MetalDevice.shouldUseGPU(populationSize: config.populationSize)
        #else
        return false
        #endif
    }

    #if canImport(Metal)
    /// Run one generation on GPU (VectorN<Double> only).
    ///
    /// Executes mutation, crossover, and selection on GPU. Fitness evaluation still on CPU.
    ///
    /// - Parameters:
    ///   - population: Current population (as flat array)
    ///   - fitness: Current fitness values
    ///   - bestIndex: Index of best individual
    ///   - objective: Fitness function
    ///
    /// - Returns: Updated (population, fitness, bestIndex), or `nil` when a Metal resource
    ///   could not be obtained. Both that and a thrown error abandon the attempt; they
    ///   differ only in whether there is an error to report to the caller.
    ///
    /// - Throws: ``OptimizationError/invalidInput(message:)`` when the dispatch itself
    ///   fails — no command buffer, or a command buffer that ends in `.error`.
    ///
    /// - Important: Call this only through ``RNGWrapper/attemptGPU(seeded:_:)``. It draws
    ///   from the generator (mutation indices, then one crossover seed per individual)
    ///   before the first operation that can fail, so abandoning it without the runner's
    ///   rewind leaves the stream advanced past anything the seed predicts.
    private func runGenerationGPU(
        population: [V],
        fitness: [V.Scalar],
        bestIndex: Int,
        objective: @escaping (V) -> V.Scalar
    ) throws -> (population: [V], fitness: [V.Scalar], bestIndex: Int)? {
        // Cast to VectorN<Double> (already checked in shouldUseGPU)
        guard let device = MetalDevice.shared else {
            return nil
        }

        let dimension = searchSpace.count
        let popSize = config.populationSize

        // Convert population to flat Float array for GPU
        var populationFlat = [Float]()
        populationFlat.reserveCapacity(popSize * dimension)
        for individual in population {
            for value in individual.toArray() {
                populationFlat.append(Float(value))
            }
        }

        // Prepare GPU buffers
        guard let populationBuffer = device.device.makeBuffer(
            bytes: &populationFlat,
            length: populationFlat.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            return nil
        }

        // Create mutants buffer
        guard let mutantsBuffer = device.device.makeBuffer(
            length: populationFlat.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            return nil
        }

        // Create trials buffer
        guard let trialsBuffer = device.device.makeBuffer(
            length: populationFlat.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            return nil
        }

        // Generate random indices for mutation (3 per individual)
        var randomIndices = [UInt32]()
        randomIndices.reserveCapacity(popSize * 3)
        for i in 0..<popSize {
            let indices = selectDistinctRandomIndices(count: 3, excluding: i, max: popSize)
            for idx in indices {
                randomIndices.append(UInt32(idx))
            }
        }

        guard let indicesBuffer = device.device.makeBuffer(
            bytes: &randomIndices,
            length: randomIndices.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        ) else {
            return nil
        }

        // Generate random seeds for crossover
        var randomSeeds = [UInt32]()
        randomSeeds.reserveCapacity(popSize)
        for _ in 0..<popSize {
            randomSeeds.append(UInt32(rng.next() & 0xFFFFFFFF))
        }

        guard let seedsBuffer = device.device.makeBuffer(
            bytes: &randomSeeds,
            length: randomSeeds.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        ) else {
            return nil
        }

        // Prepare search space bounds
        var searchSpaceFlat = [SIMD2<Float>]()
        for (lower, upper) in searchSpace {
            searchSpaceFlat.append(SIMD2(x: Float(lower), y: Float(upper)))
        }

        guard let searchSpaceBuffer = device.device.makeBuffer(
            bytes: &searchSpaceFlat,
            length: searchSpaceFlat.count * MemoryLayout<SIMD2<Float>>.stride,
            options: .storageModeShared
        ) else {
            return nil
        }

        // Get pipelines.
        //
        // `try` rather than `try?`: the caller can act on a pipeline that failed to build,
        // and discarding the reason left an unseeded run silently slower with no way to
        // find out why. A seeded run now needs the reason, because it is about to refuse.
        let mutationPipeline = try device.getDEMutationPipeline()
        let crossoverPipeline = try device.getDECrossoverPipeline()

        // Create command buffer.
        //
        // This throws rather than returning nil because by here the seeds are drawn and the
        // buffers are filled, so failing is a mid-flight abort rather than "the GPU was
        // never applicable". A queue that cannot vend a command buffer is transient
        // resource exhaustion, which is why the original defect surfaced only under a full
        // parallel run and never in isolation.
        guard let commandBuffer = device.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw OptimizationError.invalidInput(
                message: "Metal command queue could not vend a command buffer for a differential evolution generation"
            )
        }

        // 1. Mutation
        encoder.setComputePipelineState(mutationPipeline)
        encoder.setBuffer(populationBuffer, offset: 0, index: 0)
        encoder.setBuffer(mutantsBuffer, offset: 0, index: 1)
        encoder.setBuffer(indicesBuffer, offset: 0, index: 2)
        var bestIdxInt = Int32(bestIndex)
        encoder.setBytes(&bestIdxInt, length: MemoryLayout<Int32>.stride, index: 3)
        var dimInt = Int32(dimension)
        encoder.setBytes(&dimInt, length: MemoryLayout<Int32>.stride, index: 4)
        var mutFactorFloat = Float(config.mutationFactor)
        encoder.setBytes(&mutFactorFloat, length: MemoryLayout<Float>.stride, index: 5)
        var strategyInt: Int32 = {
            switch config.strategy {
            case .rand1: return 0
            case .best1: return 1
            case .currentToBest1: return 2
            }
        }()
        encoder.setBytes(&strategyInt, length: MemoryLayout<Int32>.stride, index: 6)
        encoder.setBuffer(searchSpaceBuffer, offset: 0, index: 7)
        var popSizeInt = Int32(popSize)
        encoder.setBytes(&popSizeInt, length: MemoryLayout<Int32>.stride, index: 8)

        encoder.dispatchExactly(popSize)

        // 2. Crossover
        encoder.setComputePipelineState(crossoverPipeline)
        encoder.setBuffer(populationBuffer, offset: 0, index: 0)
        encoder.setBuffer(mutantsBuffer, offset: 0, index: 1)
        encoder.setBuffer(trialsBuffer, offset: 0, index: 2)
        encoder.setBuffer(seedsBuffer, offset: 0, index: 3)
        encoder.setBytes(&dimInt, length: MemoryLayout<Int32>.stride, index: 4)
        var crossRateFloat = Float(config.crossoverRate)
        encoder.setBytes(&crossRateFloat, length: MemoryLayout<Float>.stride, index: 5)
        encoder.setBytes(&popSizeInt, length: MemoryLayout<Int32>.stride, index: 6)
        encoder.dispatchExactly(popSize)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // `.error` is a terminal state, so `waitUntilCompleted()` returns either way and the
        // read below would hand back the buffer's previous contents — indistinguishable from
        // a successful run that computed different numbers. GeneticAlgorithm gained this
        // check earlier in the session; these paths did not, and the gpu-safety checker
        // found them.
        guard commandBuffer.status != .error else {
            throw OptimizationError.invalidInput(
                message: """
                    A differential evolution generation did not complete on the GPU: \
                    \(commandBuffer.error?.localizedDescription ?? "unknown Metal failure")
                    """
            )
        }

        // Read back trials from GPU
        let trialsPtr = trialsBuffer.contents().bindMemory(to: Float.self, capacity: popSize * dimension)
        var trialPopulation = [V]()
        trialPopulation.reserveCapacity(popSize)

        for i in 0..<popSize {
            var components = [V.Scalar]()
            components.reserveCapacity(dimension)
            for d in 0..<dimension {
                components.append(V.Scalar(trialsPtr[i * dimension + d]))
            }
            if let vec = V.fromArray(components) {
                trialPopulation.append(vec)
            }
        }

        // Evaluate trial fitness on CPU (can't run Swift closures on GPU)
        let trialFitness = trialPopulation.map { objective($0) }

        // Selection on CPU (simple comparison)
        var newPopulation = population
        var newFitness = fitness
        var newBestIndex = bestIndex
        var newBestFitness = fitness[bestIndex]

        for i in 0..<popSize {
            if trialFitness[i] < newFitness[i] {
                newPopulation[i] = trialPopulation[i]
                newFitness[i] = trialFitness[i]

                if trialFitness[i] < newBestFitness {
                    newBestFitness = trialFitness[i]
                    newBestIndex = i
                }
            }
        }

        return (population: newPopulation, fitness: newFitness, bestIndex: newBestIndex)
    }
    #endif

    // MARK: - Penalty Method for Constraints

    /// Minimize with constraints using penalty method.
    private func minimizeWithPenalty(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        constraints: [MultivariateConstraint<V>]
    ) throws -> MultivariateOptimizationResult<V> {

        // Penalty weight (adaptive)
        // The weight the caller chose, or the historical 100 by default. The
        // config guarantees it is positive and finite, so no guard is needed here.
        let penaltyWeight = V.Scalar(config.constraintPenaltyWeight)

        // Create penalized objective
        let penalizedObjective: (V) -> V.Scalar = { solution in
            let baseValue = objective(solution)

            // Calculate constraint violations
            var penalty = V.Scalar.zero
            for constraint in constraints {
                let violation: V.Scalar
                switch constraint {
                case .equality(function: let g, gradient: _):
                    // Equality: g(x) = 0
                    let gVal = g(solution)
                    violation = gVal * gVal  // Quadratic penalty
                case .inequality(function: let g, gradient: _):
                    // Inequality: g(x) ≤ 0
                    let gVal = g(solution)
                    violation = max(V.Scalar.zero, gVal) * max(V.Scalar.zero, gVal)
                case .linearInequality, .linearEquality:
                    // Linear constraints: use function property
                    let g = constraint.function
                    let gVal = g(solution)
                    if constraint.isEquality {
                        violation = gVal * gVal
                    } else {
                        violation = max(V.Scalar.zero, gVal) * max(V.Scalar.zero, gVal)
                    }
                }
                penalty += violation
            }

            return baseValue + penaltyWeight * penalty
        }

        // Run optimization with penalized objective
        let detailedResult = try optimizeDetailed(objective: penalizedObjective)

        return MultivariateOptimizationResult(
            solution: detailedResult.solution,
            value: objective(detailedResult.solution),  // Return unpenalized value
            iterations: detailedResult.generations,
            converged: detailedResult.converged,
            gradientNorm: V.Scalar.zero,
            history: nil
        )
    }
}
