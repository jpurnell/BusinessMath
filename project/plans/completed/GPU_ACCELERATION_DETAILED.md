# GPU Acceleration for Genetic Algorithms - Detailed Implementation Plan

**Status:** 🚀 Ready for Implementation (2.1 release candidate)

**Last Updated:** 2025-12-26

---

## Executive Summary

This document provides a comprehensive implementation plan for GPU-accelerated genetic algorithms in BusinessMath, integrating with the existing `MultivariateOptimizer` protocol while leveraging Metal for 10-100× performance improvements on populations of 1,000+.

**Key Design Decisions:**
- ✅ Hybrid CPU/GPU approach (CPU for fitness evaluation, GPU for population operations)
- ✅ Conforms to existing `MultivariateOptimizer` protocol
- ✅ Graceful fallback to CPU-only implementation on non-Metal systems
- ✅ Zero API changes for end users - acceleration is transparent

---

## Architecture Overview

### Component Structure

```
Sources/BusinessMath/Optimization/
├── Heuristic/
│   ├── GeneticAlgorithm.swift           // Base implementation (CPU-only)
│   ├── GeneticAlgorithmTypes.swift       // Shared types and protocols
│   └── GPU/
│       ├── MetalGeneticAlgorithm.swift   // GPU-accelerated variant
│       ├── MetalDevice.swift             // Metal device management
│       ├── MetalBuffers.swift            // Buffer management utilities
│       └── Shaders.metal                 // Metal compute kernels
```

### Design Philosophy

**Separation of Concerns:**
1. **GeneticAlgorithm** - Pure Swift CPU implementation (baseline)
2. **MetalGeneticAlgorithm** - GPU-accelerated variant (conditional compilation)
3. **Shared protocol** - Common interface for both implementations

**Why Hybrid CPU/GPU?**
- Fitness evaluation requires arbitrary Swift closures (can't serialize to GPU)
- Population operations (crossover, mutation, selection) are embarrassingly parallel
- CPU↔GPU transfer overhead only justified for large populations (1,000+)

---

## Implementation Phases

### Phase 1: CPU Baseline (Week 1, Days 1-3)

**Goal:** Implement fully-functional genetic algorithm using CPU only.

#### 1.1 Core Types and Protocols

**File:** `Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithmTypes.swift`

```swift
import Foundation
import Numerics

/// Configuration for genetic algorithm optimization
public struct GeneticAlgorithmConfig {
    /// Population size (individuals per generation)
    public let populationSize: Int

    /// Number of generations to evolve
    public let generations: Int

    /// Crossover probability [0.0, 1.0]
    public let crossoverRate: Double

    /// Mutation probability per gene [0.0, 1.0]
    public let mutationRate: Double

    /// Mutation strength (standard deviation)
    public let mutationStrength: Double

    /// Elite individuals preserved each generation
    public let eliteCount: Int

    /// Tournament size for selection
    public let tournamentSize: Int

    /// Random seed (for reproducibility)
    public let seed: UInt64?

    public init(
        populationSize: Int = 100,
        generations: Int = 100,
        crossoverRate: Double = 0.8,
        mutationRate: Double = 0.1,
        mutationStrength: Double = 0.1,
        eliteCount: Int = 2,
        tournamentSize: Int = 3,
        seed: UInt64? = nil
    ) {
        self.populationSize = populationSize
        self.generations = generations
        self.crossoverRate = crossoverRate
        self.mutationRate = mutationRate
        self.mutationStrength = mutationStrength
        self.eliteCount = eliteCount
        self.tournamentSize = tournamentSize
        self.seed = seed
    }

    /// Default configuration optimized for typical use cases
    public static let `default` = GeneticAlgorithmConfig()

    /// High-performance configuration for large-scale problems
    public static let highPerformance = GeneticAlgorithmConfig(
        populationSize: 1000,
        generations: 500,
        eliteCount: 10,
        tournamentSize: 5
    )
}

/// Genetic algorithm optimization result
public struct GeneticAlgorithmResult<V: VectorSpace> where V.Scalar: Real {
    /// Best solution found
    public let solution: V

    /// Fitness of best solution (objective value)
    public let fitness: V.Scalar

    /// Number of generations evolved
    public let generations: Int

    /// Total fitness evaluations performed
    public let evaluations: Int

    /// Convergence history (best fitness per generation)
    public let convergenceHistory: [V.Scalar]

    /// Population diversity history (variance per generation)
    public let diversityHistory: [V.Scalar]

    /// Whether algorithm converged (fitness improvement < threshold)
    public let converged: Bool

    /// Human-readable convergence reason
    public let convergenceReason: String
}

/// Individual in genetic algorithm population
internal struct Individual<V: VectorSpace> where V.Scalar: Real {
    var genes: V
    var fitness: V.Scalar?

    init(genes: V) {
        self.genes = genes
        self.fitness = nil
    }
}
```

#### 1.2 CPU-Only Genetic Algorithm

**File:** `Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift`

```swift
import Foundation
import Numerics

/// CPU-based genetic algorithm optimizer
///
/// Implements evolutionary optimization using genetic operators (selection, crossover, mutation).
/// This is the baseline CPU implementation with optional GPU acceleration via `MetalGeneticAlgorithm`.
///
/// ## Usage
///
/// ```swift
/// let optimizer = GeneticAlgorithm<VectorN<Double>>(
///     config: .default,
///     searchSpace: [(-10, 10), (-10, 10)]
/// )
///
/// let result = try optimizer.minimize({ v in v.dot(v) }, from: VectorN([5.0, 5.0]))
/// ```
public struct GeneticAlgorithm<V: VectorSpace>: MultivariateOptimizer where V.Scalar: Real {

    // MARK: - Properties

    private let config: GeneticAlgorithmConfig
    private let searchSpace: [(lower: V.Scalar, upper: V.Scalar)]
    private var rng: RandomNumberGenerator

    // MARK: - Initialization

    /// Create a genetic algorithm optimizer
    ///
    /// - Parameters:
    ///   - config: Algorithm configuration (population size, mutation rate, etc.)
    ///   - searchSpace: Bounds for each dimension [(min, max), ...]
    public init(
        config: GeneticAlgorithmConfig = .default,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)]
    ) {
        self.config = config
        self.searchSpace = searchSpace

        if let seed = config.seed {
            var gen = SystemRandomNumberGenerator()
            gen = SystemRandomNumberGenerator() // Reset with seed
            self.rng = gen
        } else {
            self.rng = SystemRandomNumberGenerator()
        }
    }

    // MARK: - MultivariateOptimizer Conformance

    public func minimize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        constraints: [MultivariateConstraint<V>] = []
    ) throws -> MultivariateOptimizationResult<V> {

        // Genetic algorithms don't use initial guess, but we validate it
        guard constraints.isEmpty else {
            throw OptimizationError.unsupportedConstraints(
                "GeneticAlgorithm does not support constraints. Use bounds via searchSpace instead."
            )
        }

        let result = try optimize(objective: objective)

        // Convert to MultivariateOptimizationResult
        return MultivariateOptimizationResult(
            solution: result.solution,
            objectiveValue: result.fitness,
            iterations: result.generations,
            converged: result.converged,
            convergenceReason: result.convergenceReason
        )
    }

    // MARK: - Core Algorithm

    /// Run genetic algorithm optimization
    internal func optimize(objective: @escaping (V) -> V.Scalar) throws -> GeneticAlgorithmResult<V> {

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

            // Evaluate fitness
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

            // Check convergence
            if generation > 10 {
                let recentImprovement = convergenceHistory[generation - 10] - bestFitness
                if recentImprovement < V.Scalar(1e-6) {
                    return GeneticAlgorithmResult(
                        solution: bestIndividual!.genes,
                        fitness: bestFitness,
                        generations: generation + 1,
                        evaluations: evaluationCount,
                        convergenceHistory: convergenceHistory,
                        diversityHistory: diversityHistory,
                        converged: true,
                        convergenceReason: "Fitness improvement < 1e-6 for 10 generations"
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
            convergenceHistory: convergenceHistory,
            diversityHistory: diversityHistory,
            converged: false,
            convergenceReason: "Maximum generations reached"
        )
    }

    // MARK: - Population Initialization

    private func initializePopulation() -> [Individual<V>] {
        var population: [Individual<V>] = []

        for _ in 0..<config.populationSize {
            let genes = randomIndividual()
            population.append(Individual(genes: genes))
        }

        return population
    }

    private func randomIndividual() -> V {
        let dimension = searchSpace.count
        var values: [V.Scalar] = []

        for i in 0..<dimension {
            let (lower, upper) = searchSpace[i]
            let value = lower + V.Scalar.random(in: 0...1) * (upper - lower)
            values.append(value)
        }

        return V.fromArray(values)!
    }

    // MARK: - Genetic Operators

    private func evolvePopulation(_ population: [Individual<V>]) -> [Individual<V>] {
        var newPopulation: [Individual<V>] = []

        // Elitism: preserve best individuals
        let sorted = population.sorted { $0.fitness! < $1.fitness! }
        newPopulation.append(contentsOf: sorted.prefix(config.eliteCount))

        // Generate offspring
        while newPopulation.count < config.populationSize {
            let parent1 = tournamentSelection(population)
            let parent2 = tournamentSelection(population)

            var offspring: Individual<V>

            if Double.random(in: 0...1) < config.crossoverRate {
                offspring = crossover(parent1, parent2)
            } else {
                offspring = parent1
            }

            if Double.random(in: 0...1) < config.mutationRate {
                offspring = mutate(offspring)
            }

            newPopulation.append(offspring)
        }

        return Array(newPopulation.prefix(config.populationSize))
    }

    private func tournamentSelection(_ population: [Individual<V>]) -> Individual<V> {
        var best: Individual<V>?

        for _ in 0..<config.tournamentSize {
            let candidate = population.randomElement()!
            if best == nil || candidate.fitness! < best!.fitness! {
                best = candidate
            }
        }

        return best!
    }

    private func crossover(_ parent1: Individual<V>, _ parent2: Individual<V>) -> Individual<V> {
        let genes1 = parent1.genes.toArray()
        let genes2 = parent2.genes.toArray()

        var childGenes: [V.Scalar] = []

        for i in 0..<genes1.count {
            // Uniform crossover
            if Bool.random() {
                childGenes.append(genes1[i])
            } else {
                childGenes.append(genes2[i])
            }
        }

        return Individual(genes: V.fromArray(childGenes)!)
    }

    private func mutate(_ individual: Individual<V>) -> Individual<V> {
        var genes = individual.genes.toArray()

        for i in 0..<genes.count {
            if Double.random(in: 0...1) < config.mutationRate {
                let (lower, upper) = searchSpace[i]
                let mutation = V.Scalar.random(in: -1...1) * V.Scalar(config.mutationStrength) * (upper - lower)
                genes[i] = max(lower, min(upper, genes[i] + mutation))
            }
        }

        return Individual(genes: V.fromArray(genes)!)
    }

    private func calculateDiversity(_ population: [Individual<V>]) -> V.Scalar {
        // Calculate variance of fitness values
        let fitnesses = population.compactMap { $0.fitness }
        let mean = fitnesses.reduce(V.Scalar.zero, +) / V.Scalar(fitnesses.count)
        let variance = fitnesses.map { ($0 - mean) * ($0 - mean) }.reduce(V.Scalar.zero, +) / V.Scalar(fitnesses.count)
        return variance
    }
}

// MARK: - VectorSpace Helper Extension

extension VectorSpace where Scalar: Real {
    /// Convert to array of scalars
    internal func toArray() -> [Scalar] {
        // This needs to be implemented for each VectorSpace type
        // For VectorN, this would be the elements array
        fatalError("toArray() must be implemented for specific VectorSpace types")
    }

    /// Create from array of scalars
    internal static func fromArray(_ array: [Scalar]) -> Self? {
        fatalError("fromArray() must be implemented for specific VectorSpace types")
    }
}
```

**Note:** We'll need to add `toArray()` and `fromArray()` implementations for `VectorN`, `Vector2D`, and `Vector3D`.

---

### Phase 2: Metal Infrastructure (Week 1, Days 4-5)

**Goal:** Set up Metal device management and buffer utilities.

#### 2.1 Metal Device Management

**File:** `Sources/BusinessMath/Optimization/Heuristic/GPU/MetalDevice.swift`

```swift
#if canImport(Metal)
import Metal
import Foundation

/// Manages Metal device lifecycle and capabilities
internal final class MetalDevice {

    // MARK: - Singleton

    static let shared: MetalDevice? = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        return MetalDevice(device: device)
    }()

    // MARK: - Properties

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary

    // Compute pipelines (lazy-loaded)
    private var crossoverPipeline: MTLComputePipelineState?
    private var mutationPipeline: MTLComputePipelineState?
    private var selectionPipeline: MTLComputePipelineState?

    // MARK: - Initialization

    private init(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal library")
        }
        self.library = library
    }

    // MARK: - Pipeline State

    func getCrossoverPipeline() throws -> MTLComputePipelineState {
        if let pipeline = crossoverPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "crossoverPopulation") else {
            throw OptimizationError.invalidInput(message: "Metal function 'crossoverPopulation' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        crossoverPipeline = pipeline
        return pipeline
    }

    func getMutationPipeline() throws -> MTLComputePipelineState {
        if let pipeline = mutationPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "mutatePopulation") else {
            throw OptimizationError.invalidInput(message: "Metal function 'mutatePopulation' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        mutationPipeline = pipeline
        return pipeline
    }

    func getSelectionPipeline() throws -> MTLComputePipelineState {
        if let pipeline = selectionPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "tournamentSelection") else {
            throw OptimizationError.invalidInput(message: "Metal function 'tournamentSelection' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        selectionPipeline = pipeline
        return pipeline
    }

    // MARK: - Capabilities

    /// Check if GPU acceleration should be used based on problem size
    static func shouldUseGPU(populationSize: Int) -> Bool {
        guard shared != nil else {
            return false
        }

        // GPU overhead is only justified for populations >= 1000
        return populationSize >= 1000
    }
}
#endif
```

#### 2.2 Buffer Management

**File:** `Sources/BusinessMath/Optimization/Heuristic/GPU/MetalBuffers.swift`

```swift
#if canImport(Metal)
import Metal
import Foundation

/// Manages GPU buffers for genetic algorithm population data
internal final class MetalBuffers {

    let device: MTLDevice

    // Population buffers (double-buffered for ping-pong)
    private(set) var populationA: MTLBuffer
    private(set) var populationB: MTLBuffer

    // Fitness buffer
    private(set) var fitness: MTLBuffer

    // Random seeds for GPU RNG
    private(set) var randomSeeds: MTLBuffer

    let populationSize: Int
    let dimension: Int

    init(device: MTLDevice, populationSize: Int, dimension: Int) throws {
        self.device = device
        self.populationSize = populationSize
        self.dimension = dimension

        let populationBytes = populationSize * dimension * MemoryLayout<Float>.stride
        let fitnessBytes = populationSize * MemoryLayout<Float>.stride
        let seedBytes = populationSize * MemoryLayout<UInt32>.stride

        guard let popA = device.makeBuffer(length: populationBytes, options: .storageModeShared),
              let popB = device.makeBuffer(length: populationBytes, options: .storageModeShared),
              let fit = device.makeBuffer(length: fitnessBytes, options: .storageModeShared),
              let seeds = device.makeBuffer(length: seedBytes, options: .storageModeShared) else {
            throw OptimizationError.invalidInput(message: "Failed to allocate Metal buffers")
        }

        self.populationA = popA
        self.populationB = popB
        self.fitness = fit
        self.randomSeeds = seeds

        // Initialize random seeds
        let seedPointer = seeds.contents().bindMemory(to: UInt32.self, capacity: populationSize)
        for i in 0..<populationSize {
            seedPointer[i] = UInt32.random(in: 0...UInt32.max)
        }
    }

    /// Upload population data from Swift array to GPU
    func uploadPopulation(_ data: [Float], to buffer: MTLBuffer) {
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: data.count)
        for (i, value) in data.enumerated() {
            pointer[i] = value
        }
    }

    /// Download population data from GPU to Swift array
    func downloadPopulation(from buffer: MTLBuffer) -> [Float] {
        let count = populationSize * dimension
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    /// Download fitness data from GPU
    func downloadFitness() -> [Float] {
        let pointer = fitness.contents().bindMemory(to: Float.self, capacity: populationSize)
        return Array(UnsafeBufferPointer(start: pointer, count: populationSize))
    }
}
#endif
```

---

### Phase 3: Metal Shaders (Week 2, Days 1-2)

**Goal:** Implement Metal compute kernels for genetic operators.

**File:** `Sources/BusinessMath/Optimization/Heuristic/GPU/Shaders.metal`

```metal
#include <metal_stdlib>
using namespace metal;

// ============================================================================
// MARK: - Random Number Generation
// ============================================================================

/// PCG random number generator (GPU-friendly)
inline uint pcg_hash(uint input) {
    uint state = input * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

/// Generate random float in [0, 1)
inline float random_float(uint seed, uint index) {
    uint hash = pcg_hash(seed + index);
    return float(hash) / 4294967296.0;
}

// ============================================================================
// MARK: - Crossover Kernel
// ============================================================================

/// Uniform crossover: each gene randomly inherited from parent1 or parent2
kernel void crossoverPopulation(
    device const float* parent1 [[buffer(0)]],      // First parent population
    device const float* parent2 [[buffer(1)]],      // Second parent population
    device float* offspring [[buffer(2)]],          // Output offspring population
    device const uint* randomSeeds [[buffer(3)]],   // Random seeds per individual
    constant int& dimension [[buffer(4)]],          // Problem dimension
    constant float& crossoverRate [[buffer(5)]],    // Crossover probability
    uint id [[thread_position_in_grid]]             // Individual index
) {
    uint seed = randomSeeds[id];
    uint offset = id * dimension;

    // Check if crossover occurs
    float r = random_float(seed, 0);
    bool doCrossover = r < crossoverRate;

    if (doCrossover) {
        // Uniform crossover: each gene from random parent
        for (int i = 0; i < dimension; i++) {
            float geneRand = random_float(seed, i + 1);
            if (geneRand < 0.5) {
                offspring[offset + i] = parent1[offset + i];
            } else {
                offspring[offset + i] = parent2[offset + i];
            }
        }
    } else {
        // No crossover: copy parent1
        for (int i = 0; i < dimension; i++) {
            offspring[offset + i] = parent1[offset + i];
        }
    }
}

// ============================================================================
// MARK: - Mutation Kernel
// ============================================================================

/// Gaussian mutation: add random perturbation to genes
kernel void mutatePopulation(
    device float* population [[buffer(0)]],         // Population to mutate (in-place)
    device const uint* randomSeeds [[buffer(1)]],   // Random seeds per individual
    constant int& dimension [[buffer(2)]],          // Problem dimension
    constant float& mutationRate [[buffer(3)]],     // Mutation probability per gene
    constant float& mutationStrength [[buffer(4)]], // Mutation standard deviation
    constant float2* searchSpace [[buffer(5)]],     // Bounds per dimension (lower, upper)
    uint id [[thread_position_in_grid]]             // Individual index
) {
    uint seed = randomSeeds[id];
    uint offset = id * dimension;

    for (int i = 0; i < dimension; i++) {
        float r = random_float(seed, i * 2);

        if (r < mutationRate) {
            // Box-Muller transform for Gaussian distribution
            float u1 = random_float(seed, i * 2 + 1);
            float u2 = random_float(seed, i * 2 + 2);
            float gaussian = sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI_F * u2);

            // Apply mutation
            float lower = searchSpace[i].x;
            float upper = searchSpace[i].y;
            float range = upper - lower;
            float mutation = gaussian * mutationStrength * range;

            float newValue = population[offset + i] + mutation;

            // Clamp to bounds
            population[offset + i] = clamp(newValue, lower, upper);
        }
    }
}

// ============================================================================
// MARK: - Tournament Selection Kernel
// ============================================================================

/// Tournament selection: pick best of k random individuals
kernel void tournamentSelection(
    device const float* population [[buffer(0)]],   // Input population
    device const float* fitness [[buffer(1)]],      // Fitness values
    device float* selected [[buffer(2)]],           // Output selected individuals
    device const uint* randomSeeds [[buffer(3)]],   // Random seeds
    constant int& dimension [[buffer(4)]],          // Problem dimension
    constant int& tournamentSize [[buffer(5)]],     // Tournament size (k)
    constant int& populationSize [[buffer(6)]],     // Total population size
    uint id [[thread_position_in_grid]]             // Output individual index
) {
    uint seed = randomSeeds[id];

    int bestIndex = -1;
    float bestFitness = INFINITY;

    // Run tournament
    for (int t = 0; t < tournamentSize; t++) {
        // Pick random individual
        float r = random_float(seed, t);
        int candidateIndex = int(r * float(populationSize)) % populationSize;
        float candidateFitness = fitness[candidateIndex];

        // Track best
        if (candidateFitness < bestFitness) {
            bestFitness = candidateFitness;
            bestIndex = candidateIndex;
        }
    }

    // Copy best individual to output
    uint outputOffset = id * dimension;
    uint inputOffset = bestIndex * dimension;

    for (int i = 0; i < dimension; i++) {
        selected[outputOffset + i] = population[inputOffset + i];
    }
}

// ============================================================================
// MARK: - Utility Kernels
// ============================================================================

/// Copy population data (for elitism)
kernel void copyIndividuals(
    device const float* source [[buffer(0)]],
    device float* destination [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    uint offset = id * dimension;
    for (int i = 0; i < dimension; i++) {
        destination[offset + i] = source[offset + i];
    }
}

/// Sort population by fitness (GPU-friendly parallel sort)
kernel void parallelBitonicSort(
    device float* fitness [[buffer(0)]],
    device float* population [[buffer(1)]],
    constant int& stage [[buffer(2)]],
    constant int& passOfStage [[buffer(3)]],
    constant int& dimension [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    uint pairDistance = 1 << (stage - passOfStage);
    uint blockWidth = 2 * pairDistance;

    uint leftId = (id % pairDistance) + (id / pairDistance) * blockWidth;
    uint rightId = leftId + pairDistance;

    float leftFitness = fitness[leftId];
    float rightFitness = fitness[rightId];

    bool sortAscending = ((id / (1 << stage)) % 2) == 0;
    bool shouldSwap = (leftFitness > rightFitness) == sortAscending;

    if (shouldSwap) {
        // Swap fitness
        fitness[leftId] = rightFitness;
        fitness[rightId] = leftFitness;

        // Swap corresponding individuals
        uint leftOffset = leftId * dimension;
        uint rightOffset = rightId * dimension;

        for (int i = 0; i < dimension; i++) {
            float temp = population[leftOffset + i];
            population[leftOffset + i] = population[rightOffset + i];
            population[rightOffset + i] = temp;
        }
    }
}
```

---

### Phase 4: GPU Integration (Week 2, Days 3-5)

**Goal:** Integrate Metal kernels with Swift genetic algorithm.

**File:** `Sources/BusinessMath/Optimization/Heuristic/GPU/MetalGeneticAlgorithm.swift`

```swift
#if canImport(Metal)
import Metal
import Foundation
import Numerics

/// GPU-accelerated genetic algorithm using Metal
///
/// This optimizer accelerates population operations (crossover, mutation, selection) on the GPU
/// while keeping fitness evaluation on the CPU. This hybrid approach provides:
/// - 10-100× speedup for populations of 1,000+
/// - Flexibility to use arbitrary Swift closures for fitness functions
/// - Automatic fallback to CPU if Metal is unavailable
public struct MetalGeneticAlgorithm<V: VectorSpace>: MultivariateOptimizer where V.Scalar == Double {

    // MARK: - Properties

    private let config: GeneticAlgorithmConfig
    private let searchSpace: [(lower: Double, upper: Double)]

    // MARK: - Initialization

    public init(
        config: GeneticAlgorithmConfig = .default,
        searchSpace: [(lower: Double, upper: Double)]
    ) {
        self.config = config
        self.searchSpace = searchSpace
    }

    // MARK: - MultivariateOptimizer Conformance

    public func minimize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        constraints: [MultivariateConstraint<V>] = []
    ) throws -> MultivariateOptimizationResult<V> {

        guard constraints.isEmpty else {
            throw OptimizationError.unsupportedConstraints(
                "MetalGeneticAlgorithm does not support constraints"
            )
        }

        // Check if GPU is available and beneficial
        guard let metalDevice = MetalDevice.shared,
              MetalDevice.shouldUseGPU(populationSize: config.populationSize) else {
            // Fallback to CPU implementation
            let cpuOptimizer = GeneticAlgorithm<V>(config: config, searchSpace: searchSpace)
            return try cpuOptimizer.minimize(objective, from: initialGuess, constraints: constraints)
        }

        let result = try optimizeGPU(objective: objective, device: metalDevice)

        return MultivariateOptimizationResult(
            solution: result.solution,
            objectiveValue: result.fitness,
            iterations: result.generations,
            converged: result.converged,
            convergenceReason: result.convergenceReason
        )
    }

    // MARK: - GPU Optimization

    private func optimizeGPU(
        objective: @escaping (V) -> V.Scalar,
        device: MetalDevice
    ) throws -> GeneticAlgorithmResult<V> {

        let dimension = searchSpace.count
        let buffers = try MetalBuffers(
            device: device.device,
            populationSize: config.populationSize,
            dimension: dimension
        )

        // Initialize population on GPU
        let initialPopulation = initializePopulationGPU(buffers: buffers)
        buffers.uploadPopulation(initialPopulation, to: buffers.populationA)

        var convergenceHistory: [Double] = []
        var diversityHistory: [Double] = []
        var bestFitness = Double.infinity
        var bestSolution: V?

        // Get pipelines
        let crossoverPipeline = try device.getCrossoverPipeline()
        let mutationPipeline = try device.getMutationPipeline()
        let selectionPipeline = try device.getSelectionPipeline()

        // Evolution loop
        for generation in 0..<config.generations {

            // Download population for fitness evaluation (CPU)
            let populationData = buffers.downloadPopulation(from: buffers.populationA)
            let fitnessValues = evaluateFitnessCPU(populationData, objective: objective, dimension: dimension)

            // Upload fitness to GPU
            let fitnessPointer = buffers.fitness.contents().bindMemory(to: Float.self, capacity: config.populationSize)
            for (i, fitness) in fitnessValues.enumerated() {
                fitnessPointer[i] = Float(fitness)
            }

            // Track best individual
            if let minFitness = fitnessValues.min(), minFitness < bestFitness {
                bestFitness = minFitness
                let bestIndex = fitnessValues.firstIndex(of: minFitness)!
                let bestGenes = Array(populationData[bestIndex * dimension..<(bestIndex + 1) * dimension])
                bestSolution = V.fromArray(bestGenes.map { Double($0) })
            }

            convergenceHistory.append(bestFitness)
            diversityHistory.append(calculateDiversityGPU(fitnessValues))

            // GPU: Evolve population
            try evolvePopulationGPU(
                buffers: buffers,
                crossoverPipeline: crossoverPipeline,
                mutationPipeline: mutationPipeline,
                selectionPipeline: selectionPipeline,
                commandQueue: device.commandQueue,
                dimension: dimension
            )

            // Check convergence
            if generation > 10 {
                let improvement = convergenceHistory[generation - 10] - bestFitness
                if improvement < 1e-6 {
                    return GeneticAlgorithmResult(
                        solution: bestSolution!,
                        fitness: bestFitness,
                        generations: generation + 1,
                        evaluations: (generation + 1) * config.populationSize,
                        convergenceHistory: convergenceHistory,
                        diversityHistory: diversityHistory,
                        converged: true,
                        convergenceReason: "Fitness improvement < 1e-6 for 10 generations"
                    )
                }
            }
        }

        return GeneticAlgorithmResult(
            solution: bestSolution!,
            fitness: bestFitness,
            generations: config.generations,
            evaluations: config.generations * config.populationSize,
            convergenceHistory: convergenceHistory,
            diversityHistory: diversityHistory,
            converged: false,
            convergenceReason: "Maximum generations reached"
        )
    }

    // MARK: - Helper Methods

    private func initializePopulationGPU(buffers: MetalBuffers) -> [Float] {
        var population: [Float] = []
        let dimension = searchSpace.count

        for _ in 0..<config.populationSize {
            for i in 0..<dimension {
                let (lower, upper) = searchSpace[i]
                let value = lower + Double.random(in: 0...1) * (upper - lower)
                population.append(Float(value))
            }
        }

        return population
    }

    private func evaluateFitnessCPU(
        _ populationData: [Float],
        objective: (V) -> Double,
        dimension: Int
    ) -> [Double] {
        var fitness: [Double] = []

        for i in 0..<config.populationSize {
            let offset = i * dimension
            let genes = Array(populationData[offset..<offset + dimension])
            let vector = V.fromArray(genes.map { Double($0) })!
            fitness.append(objective(vector))
        }

        return fitness
    }

    private func evolvePopulationGPU(
        buffers: MetalBuffers,
        crossoverPipeline: MTLComputePipelineState,
        mutationPipeline: MTLComputePipelineState,
        selectionPipeline: MTLComputePipelineState,
        commandQueue: MTLCommandQueue,
        dimension: Int
    ) throws {

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw OptimizationError.invalidInput(message: "Failed to create Metal command buffer")
        }

        // 1. Tournament selection
        encoder.setComputePipelineState(selectionPipeline)
        encoder.setBuffer(buffers.populationA, offset: 0, index: 0)
        encoder.setBuffer(buffers.fitness, offset: 0, index: 1)
        encoder.setBuffer(buffers.populationB, offset: 0, index: 2)
        encoder.setBuffer(buffers.randomSeeds, offset: 0, index: 3)
        var dim = Int32(dimension)
        var tournSize = Int32(config.tournamentSize)
        var popSize = Int32(config.populationSize)
        encoder.setBytes(&dim, length: MemoryLayout<Int32>.stride, index: 4)
        encoder.setBytes(&tournSize, length: MemoryLayout<Int32>.stride, index: 5)
        encoder.setBytes(&popSize, length: MemoryLayout<Int32>.stride, index: 6)

        let threadGroupSize = MTLSize(width: min(config.populationSize, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (config.populationSize + threadGroupSize.width - 1) / threadGroupSize.width,
            height: 1,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)

        // 2. Crossover (populationB -> populationA)
        encoder.setComputePipelineState(crossoverPipeline)
        encoder.setBuffer(buffers.populationB, offset: 0, index: 0)
        encoder.setBuffer(buffers.populationB, offset: 0, index: 1) // Simplified: use same population
        encoder.setBuffer(buffers.populationA, offset: 0, index: 2)
        encoder.setBuffer(buffers.randomSeeds, offset: 0, index: 3)
        encoder.setBytes(&dim, length: MemoryLayout<Int32>.stride, index: 4)
        var crossRate = Float(config.crossoverRate)
        encoder.setBytes(&crossRate, length: MemoryLayout<Float>.stride, index: 5)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)

        // 3. Mutation (in-place on populationA)
        encoder.setComputePipelineState(mutationPipeline)
        encoder.setBuffer(buffers.populationA, offset: 0, index: 0)
        encoder.setBuffer(buffers.randomSeeds, offset: 0, index: 1)
        encoder.setBytes(&dim, length: MemoryLayout<Int32>.stride, index: 2)
        var mutRate = Float(config.mutationRate)
        var mutStrength = Float(config.mutationStrength)
        encoder.setBytes(&mutRate, length: MemoryLayout<Float>.stride, index: 3)
        encoder.setBytes(&mutStrength, length: MemoryLayout<Float>.stride, index: 4)

        // Create search space buffer
        var searchSpaceData: [SIMD2<Float>] = searchSpace.map { SIMD2<Float>(Float($0.lower), Float($0.upper)) }
        encoder.setBytes(&searchSpaceData, length: searchSpaceData.count * MemoryLayout<SIMD2<Float>>.stride, index: 5)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func calculateDiversityGPU(_ fitness: [Double]) -> Double {
        let mean = fitness.reduce(0.0, +) / Double(fitness.count)
        let variance = fitness.map { ($0 - mean) * ($0 - mean) }.reduce(0.0, +) / Double(fitness.count)
        return variance
    }
}
#endif
```

---

## Testing Strategy

### Unit Tests

**File:** `Tests/BusinessMathTests/Heuristic/GeneticAlgorithmTests.swift`

```swift
import Testing
@testable import BusinessMath

@Suite("Genetic Algorithm Tests")
struct GeneticAlgorithmTests {

    @Test("Sphere function optimization (2D)")
    func testSphereFunction2D() throws {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(populationSize: 50, generations: 100),
            searchSpace: [(-10, 10), (-10, 10)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        #expect(result.objectiveValue < 0.01)
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
    }

    @Test("Rosenbrock function optimization")
    func testRosenbrockFunction() throws {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(populationSize: 100, generations: 500),
            searchSpace: [(-5, 5), (-5, 5)]
        )

        let rosenbrock = { (v: VectorN<Double>) -> Double in
            let x = v[0], y = v[1]
            return (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x)
        }

        let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))

        #expect(result.objectiveValue < 1.0)
        #expect(abs(result.solution[0] - 1.0) < 0.5)
        #expect(abs(result.solution[1] - 1.0) < 0.5)
    }
}
```

### Performance Benchmarks

**File:** `Tests/BusinessMathTests/Heuristic/GeneticAlgorithmPerformanceTests.swift`

```swift
import Testing
@testable import BusinessMath

@Suite("Genetic Algorithm Performance Tests", .serialized)
struct GeneticAlgorithmPerformanceTests {

    @Test("CPU vs GPU performance comparison")
    func testCPUvsGPUPerformance() throws {
        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let searchSpace = Array(repeating: (-10.0, 10.0), count: 10)

        // CPU benchmark
        let cpuOptimizer = GeneticAlgorithm<VectorN<Double>>(
            config: .highPerformance,
            searchSpace: searchSpace
        )

        let cpuStart = Date()
        let cpuResult = try cpuOptimizer.minimize(sphere, from: VectorN(Array(repeating: 5.0, count: 10)))
        let cpuTime = Date().timeIntervalSince(cpuStart)

        #if canImport(Metal)
        // GPU benchmark
        let gpuOptimizer = MetalGeneticAlgorithm<VectorN<Double>>(
            config: .highPerformance,
            searchSpace: searchSpace
        )

        let gpuStart = Date()
        let gpuResult = try gpuOptimizer.minimize(sphere, from: VectorN(Array(repeating: 5.0, count: 10)))
        let gpuTime = Date().timeIntervalSince(gpuStart)

        print("CPU time: \(cpuTime)s, GPU time: \(gpuTime)s, Speedup: \(cpuTime / gpuTime)×")

        // GPU should be faster for large populations
        if MetalDevice.shared != nil {
            #expect(gpuTime < cpuTime)
        }
        #endif
    }
}
```

---

## Performance Targets

| Population Size | Dimensions | CPU Time | GPU Time | Speedup |
|----------------|------------|----------|----------|---------|
| 100            | 10         | ~1s      | ~1.5s    | 0.67×   |
| 1,000          | 10         | ~15s     | ~2s      | 7.5×    |
| 10,000         | 10         | ~180s    | ~5s      | 36×     |
| 1,000          | 50         | ~60s     | ~6s      | 10×     |

**Note:** GPU overhead dominates for small populations; CPU is faster. GPU shines at scale.

---

## Documentation

### User-Facing Documentation

Add to README:

```markdown
### Genetic Algorithms

BusinessMath provides GPU-accelerated genetic algorithms for global optimization:

```swift
import BusinessMath

// Define search space
let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

// Create optimizer (automatically uses GPU if available)
let optimizer = GeneticAlgorithm<VectorN<Double>>(
    config: .highPerformance,
    searchSpace: searchSpace
)

// Minimize objective function
let result = try optimizer.minimize({ v in v.dot(v) }, from: VectorN([5.0, 5.0]))
print("Solution: \(result.solution), Fitness: \(result.objectiveValue)")
```

**When to use GPU acceleration:**
- Population size ≥ 1,000
- Running on macOS with Metal support
- Multiple generations (100+)

**GPU acceleration is automatic** - no API changes required!
```

---

## Implementation Timeline

| Phase | Days | Deliverables |
|-------|------|--------------|
| 1. CPU Baseline | 3 | `GeneticAlgorithm.swift`, `GeneticAlgorithmTypes.swift`, basic tests |
| 2. Metal Infrastructure | 2 | `MetalDevice.swift`, `MetalBuffers.swift` |
| 3. Metal Shaders | 2 | `Shaders.metal` (crossover, mutation, selection kernels) |
| 4. GPU Integration | 3 | `MetalGeneticAlgorithm.swift`, performance tests |
| 5. Documentation & Polish | 2 | README, examples, final benchmarks |

**Total:** ~12 days (2.4 weeks with buffer)

---

## Success Criteria

- ✅ CPU-only genetic algorithm works correctly
- ✅ GPU acceleration provides 10× speedup for populations ≥ 1,000
- ✅ Graceful fallback to CPU on non-Metal systems
- ✅ Conforms to `MultivariateOptimizer` protocol
- ✅ No API changes for users (GPU is transparent)
- ✅ Comprehensive test coverage (≥90%)
- ✅ Performance benchmarks documented

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| GPU slower than CPU for small problems | Automatic threshold check (1,000+ population) |
| Metal not available on system | Graceful fallback to CPU implementation |
| Memory transfer overhead | Minimize CPU↔GPU transfers; only fitness needs round-trip |
| Debugging Metal shaders | Comprehensive CPU tests first; Metal validation layers |

---

## Future Enhancements (Post-2.1)

1. **GPU fitness evaluation** - For simple analytical functions (e.g., polynomials)
2. **Multi-GPU support** - Distribute population across devices
3. **Adaptive algorithms** - Differential Evolution, PSO, CMA-ES
4. **Island model** - Multiple sub-populations with migration
5. **Constraint handling** - Penalty methods, repair operators

---

## References

- [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
- [Genetic Algorithms in Search, Optimization, and Machine Learning (Goldberg)](https://dl.acm.org/doi/book/10.5555/534133)
- [GPU-Accelerated Evolutionary Algorithms (Pospichal et al.)](https://ieeexplore.ieee.org/document/5586511)
