//
//  MetalBuffers.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

#if canImport(Metal)
import Metal
import Foundation

/// Manages GPU buffers for genetic algorithm population data.
///
/// Handles allocation and data transfer between CPU and GPU for:
/// - Population genes (double-buffered for ping-pong updates)
/// - Fitness values
/// - Random seeds for GPU RNG
///
/// ## Memory Strategy
///
/// Uses `.storageModeShared` for zero-copy access on unified memory architectures
/// (Apple Silicon). On discrete GPUs, this becomes explicit copy.
///
/// ## Usage
///
/// This type is internal. Buffers are allocated, uploaded and read back by the
/// heuristics themselves; a caller only chooses the population size and dimension,
/// which is what determines the buffer geometry described above.
///
/// ```swift
/// let optimizer = GeneticAlgorithm<VectorN<Double>>(
/// 	config: .default,
/// 	searchSpace: Array(repeating: (lower: -10.0, upper: 10.0), count: 10)
/// )
/// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
/// let result = try optimizer.optimizeDetailed(objective: sphere)
/// ```
internal final class MetalBuffers {

    // MARK: - Properties

    let device: MTLDevice

    /// Population buffer A (ping-pong buffer 1).
    ///
    /// Stores genes for all individuals: `[ind0_gene0, ind0_gene1, ..., ind1_gene0, ...]`
    private(set) var populationA: MTLBuffer

    /// Population buffer B (ping-pong buffer 2).
    ///
    /// Used for writing new generation while reading current generation.
    private(set) var populationB: MTLBuffer

    /// Fitness buffer (one value per individual).
    private(set) var fitness: MTLBuffer

    /// Random seeds for GPU RNG (one seed per individual).
    private(set) var randomSeeds: MTLBuffer

    let populationSize: Int
    let dimension: Int

    // MARK: - Initialization

    /// Create Metal buffers for genetic algorithm.
    ///
    /// - Parameters:
    ///   - device: Metal device
    ///   - populationSize: Number of individuals
    ///   - dimension: Number of genes per individual
    ///   - randomSeeds: RNG state for the GPU kernels, one seed per individual, drawn by
    ///     the caller from whatever generator the caller was configured with. This is a
    ///     parameter rather than something this type produces because the seeds *are* the
    ///     GPU's randomness: every tournament, crossover point, and mutation the kernels
    ///     perform is a hash of `randomSeeds[id]`. Filling them here from the system
    ///     generator would mean `GeneticAlgorithmConfig.seed` reproduced a run below the
    ///     GPU threshold and not above it — the same API, the same seed, silently
    ///     non-reproducible. There is deliberately no default: a caller must say where
    ///     its randomness comes from.
    /// - Throws: `OptimizationError` if allocation fails
    /// - Precondition: `randomSeeds.count == populationSize`
    init(device: MTLDevice, populationSize: Int, dimension: Int, randomSeeds seedValues: [UInt32]) throws {
        guard seedValues.count == populationSize else {
            throw OptimizationError.invalidInput(
                message: "Seed count mismatch: expected \(populationSize), got \(seedValues.count)"
            )
        }

        self.device = device
        self.populationSize = populationSize
        self.dimension = dimension

        // Calculate buffer sizes
        let populationBytes = populationSize * dimension * MemoryLayout<Float>.stride
        let fitnessBytes = populationSize * MemoryLayout<Float>.stride
        let seedBytes = populationSize * MemoryLayout<UInt32>.stride

        // Allocate buffers
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

        // Initialize random seeds for GPU RNG from the caller's generator
        uploadRandomSeeds(seedValues)
    }

    // MARK: - Random Seed Initialization

    /// Copy the caller's RNG state into the seed buffer.
    ///
    /// - Parameter seedValues: One seed per individual, already drawn by the caller.
    private func uploadRandomSeeds(_ seedValues: [UInt32]) {
        let seedPointer = randomSeeds.contents().bindMemory(to: UInt32.self, capacity: populationSize)
        for (i, seed) in seedValues.enumerated() {
            seedPointer[i] = seed
        }
    }

    // MARK: - Data Transfer (CPU ↔ GPU)

    /// Upload population data from CPU to GPU.
    ///
    /// - Parameters:
    ///   - data: Flat array of genes `[ind0_gene0, ind0_gene1, ..., ind1_gene0, ...]`
    ///   - buffer: Target buffer (typically `populationA` or `populationB`)
    ///
    /// - Precondition: `data.count == populationSize * dimension`
    func uploadPopulation(_ data: [Float], to buffer: MTLBuffer) {
        guard data.count == populationSize * dimension else {
            preconditionFailure("Data size mismatch: expected \(populationSize * dimension), got \(data.count)")
        }

        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: data.count)
        for (i, value) in data.enumerated() {
            pointer[i] = value
        }
    }

    /// Download population data from GPU to CPU.
    ///
    /// - Parameter buffer: Source buffer
    /// - Returns: Flat array of genes
    func downloadPopulation(from buffer: MTLBuffer) -> [Float] {
        let count = populationSize * dimension
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    /// Upload fitness values to GPU.
    ///
    /// - Parameter data: Fitness values (one per individual)
    ///
    /// - Precondition: `data.count == populationSize`
    func uploadFitness(_ data: [Float]) {
        guard data.count == populationSize else {
            preconditionFailure("Fitness data size mismatch: expected \(populationSize), got \(data.count)")
        }

        let pointer = fitness.contents().bindMemory(to: Float.self, capacity: populationSize)
        for (i, value) in data.enumerated() {
            pointer[i] = value
        }
    }

    /// Download fitness values from GPU to CPU.
    ///
    /// - Returns: Fitness values (one per individual)
    func downloadFitness() -> [Float] { // LIVE: GPU result retrieval for fitness evaluation pipeline
        let pointer = fitness.contents().bindMemory(to: Float.self, capacity: populationSize)
        return Array(UnsafeBufferPointer(start: pointer, count: populationSize))
    }

    // MARK: - Buffer Swapping

    /// Swap population buffers for ping-pong update pattern.
    ///
    /// After evolving population from A → B, swap so B becomes the new A.
    func swapPopulationBuffers() { // LIVE: ping-pong buffer management for GPU evolution pipeline
        swap(&populationA, &populationB)
    }

    // MARK: - Memory Information

    /// Total GPU memory allocated (in bytes).
    var totalMemoryAllocated: Int {
        let populationBytes = populationSize * dimension * MemoryLayout<Float>.stride * 2  // A + B
        let fitnessBytes = populationSize * MemoryLayout<Float>.stride
        let seedBytes = populationSize * MemoryLayout<UInt32>.stride
        return populationBytes + fitnessBytes + seedBytes
    }

    /// Total GPU memory allocated (formatted string).
    var memoryDescription: String { // LIVE: diagnostic output for GPU memory monitoring
        let bytes = totalMemoryAllocated
        let mb = Double(bytes) / (1024 * 1024) // fp-safety:disable
        return "\(mb.number(2)) MB"
    }
}
#endif
