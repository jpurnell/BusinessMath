//
//  MetalDevice.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

#if canImport(Metal)
import Metal
import Foundation

/// Manages Metal device lifecycle and compute pipeline state.
///
/// This singleton provides centralized access to Metal resources for GPU-accelerated
/// genetic algorithm operations. It handles device initialization, pipeline caching,
/// and capability detection.
///
/// ## Thread Safety
///
/// All methods are thread-safe. Pipeline states are cached on first access.
///
/// ## Usage
///
/// ```swift
/// guard let device = MetalDevice.shared else {
///     // Metal not available - fall back to CPU
///     return
/// }
///
/// let pipeline = try device.getCrossoverPipeline()
/// ```
internal final class MetalDevice: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared Metal device instance (nil if Metal unavailable).
    static let shared: MetalDevice? = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        return MetalDevice(device: device)
    }()

    // MARK: - Properties

    /// Underlying Metal device
    let device: MTLDevice

    /// Command queue for GPU work submission
    let commandQueue: MTLCommandQueue

    /// Metal shader library
    let library: MTLLibrary

    // Compute pipeline states (lazy-loaded and cached)
    private let pipelineLock = NSLock()
    private var _crossoverPipeline: MTLComputePipelineState?
    private var _mutationPipeline: MTLComputePipelineState?
    private var _selectionPipeline: MTLComputePipelineState?

    // Differential Evolution pipelines
    private var _deMutationPipeline: MTLComputePipelineState?
    private var _deCrossoverPipeline: MTLComputePipelineState?
    private var _deSelectionPipeline: MTLComputePipelineState?

    // Particle Swarm Optimization pipeline
    private var _psoUpdatePipeline: MTLComputePipelineState?

    // MARK: - Initialization

    private init(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue

        // For SPM, we need to compile the Metal shader at runtime from source
        // Try to load the default library first (works in Xcode), fallback to runtime compilation
        if let defaultLibrary = device.makeDefaultLibrary() {
            self.library = defaultLibrary
        } else {
            // Fallback: compile from embedded source string
            do {
                self.library = try Self.compileShaderLibrary(device: device)
            } catch {
                fatalError("Failed to load or compile Metal library: \(error)")
            }
        }
    }

    /// Compile Metal shader library from embedded source.
    ///
    /// This is used when running from SPM where no default library is available.
    private static func compileShaderLibrary(device: MTLDevice) throws -> MTLLibrary {
        let shaderSource = Self.getShaderSource()
        return try device.makeLibrary(source: shaderSource, options: nil)
    }

    /// Get embedded Metal shader source.
    ///
    /// In production, this should be loaded from the Shaders.metal file.
    /// For now, we embed it as a string for SPM compatibility.
    private static func getShaderSource() -> String {
        // TODO: Load from Shaders.metal file as a resource
        // For now, return embedded source
        return """
        #include <metal_stdlib>
        using namespace metal;

        // Random Number Generation
        inline uint pcg_hash(uint input) {
            uint state = input * 747796405u + 2891336453u;
            uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
            return (word >> 22u) ^ word;
        }

        inline float random_float(uint seed, uint index) {
            uint hash = pcg_hash(seed + index);
            return float(hash) / 4294967296.0;
        }

        // Crossover Kernel
        kernel void crossoverPopulation(
            device const float* parent1 [[buffer(0)]],
            device const float* parent2 [[buffer(1)]],
            device float* offspring [[buffer(2)]],
            device const uint* randomSeeds [[buffer(3)]],
            constant int& dimension [[buffer(4)]],
            constant float& crossoverRate [[buffer(5)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint seed = randomSeeds[id];
            uint offset = id * dimension;

            float r = random_float(seed, 0);
            bool doCrossover = r < crossoverRate;

            if (doCrossover) {
                for (int i = 0; i < dimension; i++) {
                    float geneRand = random_float(seed, uint(i) + 1);
                    if (geneRand < 0.5) {
                        offspring[offset + i] = parent1[offset + i];
                    } else {
                        offspring[offset + i] = parent2[offset + i];
                    }
                }
            } else {
                for (int i = 0; i < dimension; i++) {
                    offspring[offset + i] = parent1[offset + i];
                }
            }
        }

        // Mutation Kernel
        kernel void mutatePopulation(
            device float* population [[buffer(0)]],
            device const uint* randomSeeds [[buffer(1)]],
            constant int& dimension [[buffer(2)]],
            constant float& mutationRate [[buffer(3)]],
            constant float& mutationStrength [[buffer(4)]],
            constant float2* searchSpace [[buffer(5)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint seed = randomSeeds[id];
            uint offset = id * dimension;

            for (int i = 0; i < dimension; i++) {
                float r = random_float(seed, uint(i) * 2);

                if (r < mutationRate) {
                    float u1 = random_float(seed, uint(i) * 2 + 1);
                    float u2 = random_float(seed, uint(i) * 2 + 2);
                    u1 = max(u1, 1e-8);

                    float gaussian = sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI_F * u2);

                    float lower = searchSpace[i].x;
                    float upper = searchSpace[i].y;
                    float range = upper - lower;
                    float mutation = gaussian * mutationStrength * range;

                    float newValue = population[offset + i] + mutation;
                    population[offset + i] = clamp(newValue, lower, upper);
                }
            }
        }

        // Tournament Selection Kernel
        kernel void tournamentSelection(
            device const float* population [[buffer(0)]],
            device const float* fitness [[buffer(1)]],
            device float* selected [[buffer(2)]],
            device const uint* randomSeeds [[buffer(3)]],
            constant int& dimension [[buffer(4)]],
            constant int& tournamentSize [[buffer(5)]],
            constant int& populationSize [[buffer(6)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint seed = randomSeeds[id];

            int bestIndex = -1;
            float bestFitness = INFINITY;

            for (int t = 0; t < tournamentSize; t++) {
                float r = random_float(seed, uint(t));
                int candidateIndex = int(r * float(populationSize)) % populationSize;
                float candidateFitness = fitness[candidateIndex];

                if (candidateFitness < bestFitness) {
                    bestFitness = candidateFitness;
                    bestIndex = candidateIndex;
                }
            }

            uint outputOffset = id * dimension;
            uint inputOffset = bestIndex * dimension;

            for (int i = 0; i < dimension; i++) {
                selected[outputOffset + i] = population[inputOffset + i];
            }
        }

        // Copy Individuals Kernel
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

        // Differential Evolution Kernels
        kernel void deMutation(
            device const float* population [[buffer(0)]],
            device float* mutants [[buffer(1)]],
            device const uint* randomIndices [[buffer(2)]],
            constant int& bestIndex [[buffer(3)]],
            constant int& dimension [[buffer(4)]],
            constant float& mutationFactor [[buffer(5)]],
            constant int& strategy [[buffer(6)]],
            constant float2* searchSpace [[buffer(7)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint offset = id * dimension;
            uint indicesOffset = id * 3;
            uint r1_idx = randomIndices[indicesOffset];
            uint r2_idx = randomIndices[indicesOffset + 1];
            uint r3_idx = randomIndices[indicesOffset + 2];

            for (int i = 0; i < dimension; i++) {
                float mutant;
                if (strategy == 0) {
                    float r1 = population[r1_idx * dimension + i];
                    float r2 = population[r2_idx * dimension + i];
                    float r3 = population[r3_idx * dimension + i];
                    mutant = r1 + mutationFactor * (r2 - r3);
                } else if (strategy == 1) {
                    float best = population[bestIndex * dimension + i];
                    float r1 = population[r1_idx * dimension + i];
                    float r2 = population[r2_idx * dimension + i];
                    mutant = best + mutationFactor * (r1 - r2);
                } else {
                    float current = population[offset + i];
                    float best = population[bestIndex * dimension + i];
                    float r1 = population[r1_idx * dimension + i];
                    float r2 = population[r2_idx * dimension + i];
                    mutant = current + mutationFactor * (best - current) + mutationFactor * (r1 - r2);
                }
                float lower = searchSpace[i].x;
                float upper = searchSpace[i].y;
                mutants[offset + i] = clamp(mutant, lower, upper);
            }
        }

        kernel void deCrossover(
            device const float* targets [[buffer(0)]],
            device const float* mutants [[buffer(1)]],
            device float* trials [[buffer(2)]],
            device const uint* randomSeeds [[buffer(3)]],
            constant int& dimension [[buffer(4)]],
            constant float& crossoverRate [[buffer(5)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint offset = id * dimension;
            uint seed = randomSeeds[id];
            float jRandFloat = random_float(seed, 0);
            int jRand = int(jRandFloat * float(dimension)) % dimension;

            for (int i = 0; i < dimension; i++) {
                float r = random_float(seed, uint(i) + 1);
                if (r < crossoverRate || i == jRand) {
                    trials[offset + i] = mutants[offset + i];
                } else {
                    trials[offset + i] = targets[offset + i];
                }
            }
        }

        kernel void deSelection(
            device float* population [[buffer(0)]],
            device const float* trials [[buffer(1)]],
            device float* fitness [[buffer(2)]],
            device const float* trialFitness [[buffer(3)]],
            constant int& dimension [[buffer(4)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint offset = id * dimension;
            if (trialFitness[id] < fitness[id]) {
                for (int i = 0; i < dimension; i++) {
                    population[offset + i] = trials[offset + i];
                }
                fitness[id] = trialFitness[id];
            }
        }

        // Particle Swarm Optimization Kernel
        kernel void psoUpdateParticles(
            device const float* currentVelocities [[buffer(0)]],
            device const float* currentPositions [[buffer(1)]],
            device const float* personalBest [[buffer(2)]],
            device const float* globalBest [[buffer(3)]],
            device float* newVelocities [[buffer(4)]],
            device float* newPositions [[buffer(5)]],
            device const uint* randomSeeds [[buffer(6)]],
            constant int& dimension [[buffer(7)]],
            constant float& inertiaWeight [[buffer(8)]],
            constant float& cognitiveCoeff [[buffer(9)]],
            constant float& socialCoeff [[buffer(10)]],
            constant float2* searchSpace [[buffer(11)]],
            constant float2* velocityLimits [[buffer(12)]],
            constant bool& hasVelocityClamp [[buffer(13)]],
            uint id [[thread_position_in_grid]]
        ) {
            uint seed = randomSeeds[id];
            uint offset = id * dimension;

            for (int d = 0; d < dimension; d++) {
                // Generate random values r1, r2
                float r1 = random_float(seed, uint(d) * 2);
                float r2 = random_float(seed, uint(d) * 2 + 1);

                // PSO velocity update: v = w×v + c1×r1×(pbest - x) + c2×r2×(gbest - x)
                float v = currentVelocities[offset + d];
                float x = currentPositions[offset + d];
                float pbest = personalBest[offset + d];
                float gbest = globalBest[d];

                float newV = inertiaWeight * v
                           + cognitiveCoeff * r1 * (pbest - x)
                           + socialCoeff * r2 * (gbest - x);

                // Clamp velocity if needed
                if (hasVelocityClamp) {
                    float vLower = velocityLimits[d].x;
                    float vUpper = velocityLimits[d].y;
                    newV = clamp(newV, vLower, vUpper);
                }

                // Update position: x = x + v
                float newX = x + newV;

                // Clamp position to search space
                float xLower = searchSpace[d].x;
                float xUpper = searchSpace[d].y;
                newX = clamp(newX, xLower, xUpper);

                // Write outputs
                newVelocities[offset + d] = newV;
                newPositions[offset + d] = newX;
            }
        }
        """
    }

    // MARK: - Pipeline State Access

    /// Get or create crossover compute pipeline.
    ///
    /// - Returns: Compute pipeline for crossover kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getCrossoverPipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _crossoverPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "crossoverPopulation") else {
            throw OptimizationError.invalidInput(message: "Metal function 'crossoverPopulation' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _crossoverPipeline = pipeline
        return pipeline
    }

    /// Get or create mutation compute pipeline.
    ///
    /// - Returns: Compute pipeline for mutation kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getMutationPipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _mutationPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "mutatePopulation") else {
            throw OptimizationError.invalidInput(message: "Metal function 'mutatePopulation' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _mutationPipeline = pipeline
        return pipeline
    }

    /// Get or create selection compute pipeline.
    ///
    /// - Returns: Compute pipeline for tournament selection kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getSelectionPipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _selectionPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "tournamentSelection") else {
            throw OptimizationError.invalidInput(message: "Metal function 'tournamentSelection' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _selectionPipeline = pipeline
        return pipeline
    }

    // MARK: - Differential Evolution Pipelines

    /// Get or create DE mutation compute pipeline.
    ///
    /// - Returns: Compute pipeline for DE mutation kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getDEMutationPipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _deMutationPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "deMutation") else {
            throw OptimizationError.invalidInput(message: "Metal function 'deMutation' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _deMutationPipeline = pipeline
        return pipeline
    }

    /// Get or create DE crossover compute pipeline.
    ///
    /// - Returns: Compute pipeline for DE crossover kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getDECrossoverPipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _deCrossoverPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "deCrossover") else {
            throw OptimizationError.invalidInput(message: "Metal function 'deCrossover' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _deCrossoverPipeline = pipeline
        return pipeline
    }

    /// Get or create DE selection compute pipeline.
    ///
    /// - Returns: Compute pipeline for DE selection kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getDESelectionPipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _deSelectionPipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "deSelection") else {
            throw OptimizationError.invalidInput(message: "Metal function 'deSelection' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _deSelectionPipeline = pipeline
        return pipeline
    }

    // MARK: - Particle Swarm Optimization Pipelines

    /// Get or create PSO particle update compute pipeline.
    ///
    /// - Returns: Compute pipeline for PSO particle update kernel
    /// - Throws: `OptimizationError` if kernel not found or compilation fails
    func getPSOUpdatePipeline() throws -> MTLComputePipelineState {
        pipelineLock.lock()
        defer { pipelineLock.unlock() }

        if let pipeline = _psoUpdatePipeline {
            return pipeline
        }

        guard let function = library.makeFunction(name: "psoUpdateParticles") else {
            throw OptimizationError.invalidInput(message: "Metal function 'psoUpdateParticles' not found")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        _psoUpdatePipeline = pipeline
        return pipeline
    }

    // MARK: - Capability Detection

    /// Determine if GPU acceleration should be used based on problem size.
    ///
    /// GPU acceleration has overhead from CPU↔GPU data transfer. It's only
    /// beneficial when the population is large enough to amortize this cost.
    ///
    /// - Parameter populationSize: Number of individuals in population
    /// - Returns: `true` if GPU is available and beneficial for this size
    ///
    /// ## Threshold
    ///
    /// Based on benchmarking:
    /// - **< 1000**: CPU faster (transfer overhead dominates)
    /// - **≥ 1000**: GPU faster (10-100× speedup)
    static func shouldUseGPU(populationSize: Int) -> Bool {
        guard shared != nil else {
            return false  // Metal not available
        }

        // GPU overhead only justified for large populations
        return populationSize >= 1000
    }

    // MARK: - Device Information

    /// Maximum threads per threadgroup supported by device.
    var maxThreadsPerThreadgroup: Int {
        device.maxThreadsPerThreadgroup.width
    }

    /// Device name for debugging/logging.
    var name: String {
        device.name
    }

    /// Whether device supports unified memory (macOS typically does).
    var supportsUnifiedMemory: Bool {
        #if os(macOS)
        return true  // All Apple Silicon and Intel Macs support unified memory
        #else
        return false
        #endif
    }
}
#endif
