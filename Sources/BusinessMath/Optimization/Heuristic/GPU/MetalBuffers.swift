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
/// ```swift
/// let buffers = try MetalBuffers(
///     device: device.device,
///     populationSize: 1000,
///     dimension: 10
/// )
///
/// // Upload initial population
/// buffers.uploadPopulation(data, to: buffers.populationA)
///
/// // Download results
/// let results = buffers.downloadPopulation(from: buffers.populationA)
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
    /// - Throws: `OptimizationError` if allocation fails
    init(device: MTLDevice, populationSize: Int, dimension: Int) throws {
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

        // Initialize random seeds for GPU RNG
        initializeRandomSeeds()
    }

    // MARK: - Random Seed Initialization

    private func initializeRandomSeeds() {
        let seedPointer = randomSeeds.contents().bindMemory(to: UInt32.self, capacity: populationSize)
        for i in 0..<populationSize {
            seedPointer[i] = UInt32.random(in: 0...UInt32.max)
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
        precondition(data.count == populationSize * dimension,
                     "Data size mismatch: expected \(populationSize * dimension), got \(data.count)")

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
        precondition(data.count == populationSize,
                     "Fitness data size mismatch: expected \(populationSize), got \(data.count)")

        let pointer = fitness.contents().bindMemory(to: Float.self, capacity: populationSize)
        for (i, value) in data.enumerated() {
            pointer[i] = value
        }
    }

    /// Download fitness values from GPU to CPU.
    ///
    /// - Returns: Fitness values (one per individual)
    func downloadFitness() -> [Float] {
        let pointer = fitness.contents().bindMemory(to: Float.self, capacity: populationSize)
        return Array(UnsafeBufferPointer(start: pointer, count: populationSize))
    }

    // MARK: - Buffer Swapping

    /// Swap population buffers for ping-pong update pattern.
    ///
    /// After evolving population from A → B, swap so B becomes the new A.
    func swapPopulationBuffers() {
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
    var memoryDescription: String {
        let bytes = totalMemoryAllocated
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.2f MB", mb)
    }
}
#endif
