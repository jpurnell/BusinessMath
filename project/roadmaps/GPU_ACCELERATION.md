## GPU Acceleration (Phase 9)

**Status:** 🔮 Deferred to Phase 9 (future release)

**Rationale:**
- GPU acceleration is a **performance enhancement**, not a functional requirement
- Current CPU implementations are sufficient for typical use cases
- Metal integration adds platform-specific complexity (macOS only)
- Phase 8 priorities (sparse, multi-period, robust) deliver more immediate value

**Expected Performance:** 10-100× speedup for genetic algorithms with populations of 1,000+

**Implementation Scope:** ~2 weeks
- Metal device management and shader compilation
- GPU-accelerated genetic algorithm
- Parallel fitness evaluation, crossover, mutation kernels
- CPU fallback for non-Metal systems

**Not needed if:**
- Current CPU performance meets user needs
- Use cases involve small populations (< 1,000)
- Cross-platform compatibility is critical
- Development resources are limited

### Success Criteria

**Technical Metrics:**
- ✅ Metal device initialization and fallback logic
- ✅ GPU genetic algorithm produces same results as CPU (within tolerance)
- ✅ Measured 10× speedup for populations of 1,000+
- ✅ Zero crashes on systems without Metal support
- ✅ All tests pass (CPU and GPU variants)

**Deliverables:**
- ✅ `GPUHeuristicOptimizer.swift` with Metal integration
- ✅ Metal shader files (.metal)
- ✅ Comprehensive test suite with CPU/GPU comparison
- ✅ Performance benchmark results
- ✅ Documentation on when to use GPU vs CPU

---

### Phase 9 Conclusion

GPU acceleration remains a **well-scoped future enhancement** that can be implemented when performance requirements justify the added complexity. The current CPU-based heuristic optimizers in BusinessMath are production-ready and suitable for the vast majority of use cases.

**Current Status:** Phase 8 is functionally complete without GPU acceleration. Phase 9 is deferred to a future release when user demand or performance requirements make it a priority.

## Pseudocode:

**Estimated Time:** 2 weeks (optional, advanced)

**File:** `Sources/BusinessMath/Optimization/GPU/GPUHeuristicOptimizer.swift`

```swift
#if canImport(Metal)
import Metal

/// GPU-accelerated heuristic optimizer using Metal
@available(macOS 10.13, *)
public struct GPUHeuristicOptimizer<V: VectorSpace> where V.Scalar == Float {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw OptimizationError.invalidInput(message: "Metal not available")
        }

        guard let queue = device.makeCommandQueue() else {
            throw OptimizationError.invalidInput(message: "Cannot create command queue")
        }

        self.device = device
        self.commandQueue = queue
        self.library = try device.makeDefaultLibrary()!
    }

    /// Run genetic algorithm on GPU
    public func geneticAlgorithm(
        objective: @escaping (V) -> Float,
        populationSize: Int,
        generations: Int,
        searchSpace: [(lower: Float, upper: Float)]
    ) throws -> HeuristicOptimizationResult<V> {

        // Metal kernel for fitness evaluation (parallel)
        let fitnessKernel = library.makeFunction(name: "evaluateFitness")!
        let fitnessPipeline = try device.makeComputePipelineState(function: fitnessKernel)

        // Metal kernel for crossover (parallel)
        let crossoverKernel = library.makeFunction(name: "crossoverPopulation")!
        let crossoverPipeline = try device.makeComputePipelineState(function: crossoverKernel)

        // Initialize population on GPU
        var population = initializePopulationGPU(
            size: populationSize,
            dimension: V.dimension,
            searchSpace: searchSpace
        )

        // Evolution loop
        for generation in 0..<generations {
            // Evaluate fitness (GPU)
            let fitness = evaluateFitnessGPU(
                population: population,
                pipeline: fitnessPipeline
            )

            // Selection, crossover, mutation (GPU)
            population = evolvePopulationGPU(
                population: population,
                fitness: fitness,
                crossoverPipeline: crossoverPipeline
            )
        }

        // Return best individual
        let finalFitness = evaluateFitnessGPU(
            population: population,
            pipeline: fitnessPipeline
        )

        let bestIndex = finalFitness.enumerated().min(by: { $0.element < $1.element })!.offset
        let bestSolution = V.fromArray(Array(population[bestIndex]))!

        return HeuristicOptimizationResult(
            solution: bestSolution,
            objectiveValue: finalFitness[bestIndex],
            generations: generations,
            evaluations: populationSize * generations,
            converged: true,
            convergenceHistory: [],
            diversityHistory: []
        )
    }

    // GPU helper functions omitted for brevity
}
#endif
```

**Metal Shader (Shaders.metal):**
```metal
#include <metal_stdlib>
using namespace metal;

kernel void evaluateFitness(
    device const float* population [[buffer(0)]],
    device float* fitness [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread evaluates one individual
    device const float* individual = population + id * dimension;

    // Example: Sphere function
    float sum = 0.0;
    for (int i = 0; i < dimension; i++) {
        sum += individual[i] * individual[i];
    }

    fitness[id] = sum;
}

kernel void crossoverPopulation(
    device const float* parents [[buffer(0)]],
    device float* offspring [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    constant float& crossoverRate [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread creates one offspring via crossover
    uint parent1 = id;
    uint parent2 = (id + 1) % (id + 1);  // Simplified

    for (int i = 0; i < dimension; i++) {
        float r = float(id * dimension + i) / 1000.0;  // Pseudo-random
        if (r < crossoverRate) {
            offspring[id * dimension + i] = parents[parent1 * dimension + i];
        } else {
            offspring[id * dimension + i] = parents[parent2 * dimension + i];
        }
    }
}
```

**Tests Required:**
- ✅ GPU optimizer produces same results as CPU (within tolerance)
- ✅ GPU speedup measured (10x for large populations)
- ✅ Graceful fallback if Metal unavailable