//
//  MonteCarloGPUDevice.swift
//  BusinessMath
//
//  GPU Device Manager for Monte Carlo Simulation
//
//  Manages:
//  - Metal device and command queue
//  - Kernel compilation and caching
//  - Buffer allocation and data transfer
//  - GPU execution pipeline
//

#if canImport(Metal)
import Metal
import Foundation

/// GPU device manager for Monte Carlo simulation
///
/// This class orchestrates GPU-accelerated Monte Carlo simulations by:
/// 1. Compiling Metal kernels from source
/// 2. Managing GPU buffers for RNG states, distributions, and outputs
/// 3. Executing the simulation pipeline: RNG init → sampling + evaluation → results
/// 4. Transferring results back to CPU
///
/// **Thread Safety**: This class is `@unchecked Sendable` with internal synchronization.
/// All public methods are thread-safe.
///
/// **Usage**:
/// ```swift
/// let device = MonteCarloGPUDevice()
/// let results = try device.runSimulation(
///     distributions: [(.normal, (100.0, 15.0, 0.0))],
///     modelBytecode: [(opcode: 4, arg1: 0, arg2: 0.0)],
///     iterations: 100_000
/// )
/// ```
@available(macOS 10.15, iOS 13.0, *)
public final class MonteCarloGPUDevice: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared GPU device instance for optimal performance
    ///
    /// Reusing the same device across simulations provides:
    /// - Amortized Metal library compilation cost (one-time ~50ms)
    /// - Buffer pooling and reuse (avoids repeated allocations)
    /// - Persistent pipeline cache
    ///
    /// Returns `nil` if Metal is unavailable or initialization fails.
    public static let shared: MonteCarloGPUDevice? = MonteCarloGPUDevice()

    // MARK: - Types

    /// Distribution configuration for GPU
    public typealias DistributionConfig = (type: Int32, params: (Float, Float, Float))

    /// Model bytecode operation
    public typealias ModelOperation = (opcode: Int32, arg1: Int32, arg2: Float)

    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    // Cached pipeline states
    private var initRNGPipeline: MTLComputePipelineState?
    private var monteCarloIterationPipeline: MTLComputePipelineState?

    // PERFORMANCE: Buffer pool to avoid repeated allocations
    private var bufferCache: [Int: Buffers] = [:]
    private let bufferCacheLock = NSLock()

    // MARK: - Initialization

    /// Initialize GPU device manager
    ///
    /// Returns nil if Metal is not available or kernel compilation fails.
    public init?() {
        // Get Metal device
        guard let metalDevice = MetalDevice.shared else {
            return nil
        }

        self.device = metalDevice.device
        self.commandQueue = metalDevice.commandQueue

        // Compile Metal library from inline source
        // Note: In production, we'd use .module bundle, but for now compile from source
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        // Include all kernel code inline
        // (In production, this would reference the .metal files)

        struct RNGState {
            ulong s0;
            ulong s1;
        };

        struct DistributionParams {
            float param1;
            float param2;
            float param3;
        };

        struct ModelOp {
            int opcode;
            int arg1;
            float arg2;
        };

        constant int MAX_INPUTS = 32;
        constant int MAX_STACK = 32;

        // RNG - thread address space
        inline float nextUniform(thread RNGState* state) {
            ulong s1 = state->s0;
            ulong s0 = state->s1;
            state->s0 = s0;
            s1 ^= s1 << 23;
            state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
            return float(state->s0 + state->s1) * 5.421010862427522e-20f;
        }

        // RNG - device address space (for kernel buffers)
        inline float nextUniform(device RNGState* state) {
            ulong s1 = state->s0;
            ulong s0 = state->s1;
            state->s0 = s0;
            s1 ^= s1 << 23;
            state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
            return float(state->s0 + state->s1) * 5.421010862427522e-20f;
        }

        inline float2 nextNormal(thread RNGState* state, float mean, float stdDev) {
            float u1 = max(nextUniform(state), 1e-10f);  // Prevent log(0)
            float u2 = nextUniform(state);
            float r = sqrt(-2.0f * log(u1));
            float theta = 2.0f * M_PI_F * u2;
            return float2(mean + stdDev * r * cos(theta), mean + stdDev * r * sin(theta));
        }

        inline float2 nextNormal(device RNGState* state, float mean, float stdDev) {
            float u1 = max(nextUniform(state), 1e-10f);  // Prevent log(0)
            float u2 = nextUniform(state);
            float r = sqrt(-2.0f * log(u1));
            float theta = 2.0f * M_PI_F * u2;
            return float2(mean + stdDev * r * cos(theta), mean + stdDev * r * sin(theta));
        }

        // Distributions - thread address space
        inline float sampleDistribution(thread RNGState* state, constant DistributionParams* params, int distType) {
            switch (distType) {
                case 0: return nextNormal(state, params->param1, params->param2).x;
                case 1: return params->param1 + nextUniform(state) * (params->param2 - params->param1);
                case 2: {
                    float min = params->param1, max = params->param2, mode = params->param3;
                    float u = nextUniform(state), fc = (mode - min) / (max - min);
                    return u < fc ? min + sqrt(u * (max - min) * (mode - min)) :
                                   max - sqrt((1.0f - u) * (max - min) * (max - mode));
                }
                case 3: return -log(max(1.0f - nextUniform(state), 1e-10f)) / params->param1;
                case 4: return exp(nextNormal(state, params->param1, params->param2).x);
                default: return 0.0f;
            }
        }

        // Distributions - device address space (for kernel buffers)
        inline float sampleDistribution(device RNGState* state, constant DistributionParams* params, int distType) {
            switch (distType) {
                case 0: return nextNormal(state, params->param1, params->param2).x;
                case 1: return params->param1 + nextUniform(state) * (params->param2 - params->param1);
                case 2: {
                    float min = params->param1, max = params->param2, mode = params->param3;
                    float u = nextUniform(state), fc = (mode - min) / (max - min);
                    return u < fc ? min + sqrt(u * (max - min) * (mode - min)) :
                                   max - sqrt((1.0f - u) * (max - min) * (max - mode));
                }
                case 3: return -log(max(1.0f - nextUniform(state), 1e-10f)) / params->param1;
                case 4: return exp(nextNormal(state, params->param1, params->param2).x);
                default: return 0.0f;
            }
        }

        // Model evaluator
        inline float evaluateModel(thread float* inputs, constant ModelOp* ops, int numOps) {
            float stack[MAX_STACK];
            int stackPtr = 0;
            for (int i = 0; i < numOps; i++) {
                constant ModelOp& op = ops[i];
                switch (op.opcode) {
                    // Binary operations
                    case 0: stack[stackPtr - 2] = stack[stackPtr - 2] + stack[stackPtr - 1]; stackPtr--; break;  // ADD
                    case 1: stack[stackPtr - 2] = stack[stackPtr - 2] - stack[stackPtr - 1]; stackPtr--; break;  // SUB
                    case 2: stack[stackPtr - 2] = stack[stackPtr - 2] * stack[stackPtr - 1]; stackPtr--; break;  // MUL
                    case 3: stack[stackPtr - 2] = stack[stackPtr - 2] / stack[stackPtr - 1]; stackPtr--; break;  // DIV
                    case 4: stack[stackPtr++] = inputs[op.arg1]; break;  // INPUT
                    case 5: stack[stackPtr++] = op.arg2; break;  // CONST
                    case 6: stack[stackPtr - 2] = pow(stack[stackPtr - 2], stack[stackPtr - 1]); stackPtr--; break;  // POW
                    case 7: stack[stackPtr - 2] = min(stack[stackPtr - 2], stack[stackPtr - 1]); stackPtr--; break;  // MIN
                    case 8: stack[stackPtr - 2] = max(stack[stackPtr - 2], stack[stackPtr - 1]); stackPtr--; break;  // MAX

                    // Unary operations
                    case 9: stack[stackPtr - 1] = -stack[stackPtr - 1]; break;  // NEG
                    case 10: stack[stackPtr - 1] = abs(stack[stackPtr - 1]); break;  // ABS
                    case 11: stack[stackPtr - 1] = sqrt(stack[stackPtr - 1]); break;  // SQRT
                    case 12: stack[stackPtr - 1] = log(stack[stackPtr - 1]); break;  // LOG
                    case 13: stack[stackPtr - 1] = exp(stack[stackPtr - 1]); break;  // EXP
                    case 14: stack[stackPtr - 1] = sin(stack[stackPtr - 1]); break;  // SIN
                    case 15: stack[stackPtr - 1] = cos(stack[stackPtr - 1]); break;  // COS
                    case 16: stack[stackPtr - 1] = tan(stack[stackPtr - 1]); break;  // TAN

                    // Comparison operations (return 1.0 for true, 0.0 for false)
                    case 17: stack[stackPtr - 2] = (stack[stackPtr - 2] < stack[stackPtr - 1]) ? 1.0f : 0.0f; stackPtr--; break;  // LT
                    case 18: stack[stackPtr - 2] = (stack[stackPtr - 2] > stack[stackPtr - 1]) ? 1.0f : 0.0f; stackPtr--; break;  // GT
                    case 19: stack[stackPtr - 2] = (stack[stackPtr - 2] <= stack[stackPtr - 1]) ? 1.0f : 0.0f; stackPtr--; break;  // LE
                    case 20: stack[stackPtr - 2] = (stack[stackPtr - 2] >= stack[stackPtr - 1]) ? 1.0f : 0.0f; stackPtr--; break;  // GE
                    case 21: stack[stackPtr - 2] = (abs(stack[stackPtr - 2] - stack[stackPtr - 1]) < 1e-6f) ? 1.0f : 0.0f; stackPtr--; break;  // EQ
                    case 22: stack[stackPtr - 2] = (abs(stack[stackPtr - 2] - stack[stackPtr - 1]) >= 1e-6f) ? 1.0f : 0.0f; stackPtr--; break;  // NE

                    // Conditional operation (SELECT: condition ? trueValue : falseValue)
                    case 23: {
                        float falseVal = stack[stackPtr - 1];
                        float trueVal = stack[stackPtr - 2];
                        float condition = stack[stackPtr - 3];
                        stack[stackPtr - 3] = (condition != 0.0f) ? trueVal : falseVal;
                        stackPtr -= 2;
                        break;
                    }
                }
            }
            return stack[0];
        }

        // Kernels
        kernel void initializeRNG(
            device RNGState* states [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            states[tid].s0 = baseSeed ^ tid;
            states[tid].s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);
            for (int i = 0; i < 10; i++) { nextUniform(&states[tid]); }
        }

        kernel void monteCarloIteration(
            device RNGState* rngStates [[buffer(0)]],
            constant DistributionParams* distributions [[buffer(1)]],
            constant int* distTypes [[buffer(2)]],
            constant ModelOp* modelOps [[buffer(3)]],
            device float* outputs [[buffer(4)]],
            constant int& numInputs [[buffer(5)]],
            constant int& numOps [[buffer(6)]],
            uint tid [[thread_position_in_grid]]
        ) {
            thread float inputs[MAX_INPUTS];
            for (int i = 0; i < numInputs; i++) {
                inputs[i] = sampleDistribution(&rngStates[tid], &distributions[i], distTypes[i]);
            }
            outputs[tid] = evaluateModel(inputs, modelOps, numOps);
        }
        """

        // Compile library
        let compiledLibrary: MTLLibrary
        do {
            compiledLibrary = try device.makeLibrary(source: kernelSource, options: nil)
        } catch {
            print("❌ Metal kernel compilation failed: \(error)")
            return nil
        }

        self.library = compiledLibrary

        // Pre-compile pipelines
        do {
            self.initRNGPipeline = try self.compilePipeline(functionName: "initializeRNG")
            self.monteCarloIterationPipeline = try self.compilePipeline(functionName: "monteCarloIteration")
        } catch {
            print("❌ Metal pipeline compilation failed: \(error)")
            return nil
        }

        // Verify critical pipelines compiled
        guard initRNGPipeline != nil, monteCarloIterationPipeline != nil else {
            print("❌ Critical pipelines are nil after compilation")
            return nil
        }
    }

    // MARK: - Pipeline Compilation

    private func compilePipeline(functionName: String) throws -> MTLComputePipelineState {
        guard let function = library.makeFunction(name: functionName) else {
            throw GPUError.kernelNotFound(functionName)
        }
        return try device.makeComputePipelineState(function: function)
    }

    // MARK: - Simulation Execution

    /// Run Monte Carlo simulation on GPU
    ///
    /// - Parameters:
    ///   - distributions: Array of distribution configurations (type, params)
    ///   - modelBytecode: Bytecode operations for model evaluation
    ///   - iterations: Number of Monte Carlo iterations
    ///   - seed: Random seed for reproducibility (optional)
    /// - Returns: Array of simulation results (one per iteration)
    /// - Throws: GPUError if execution fails
    public func runSimulation(
        distributions: [DistributionConfig],
        modelBytecode: [ModelOperation],
        iterations: Int,
        seed: UInt64? = nil
    ) throws -> [Float] {
        let numInputs = distributions.count
        let numOps = modelBytecode.count

        // Validate inputs
        guard numInputs > 0 && numInputs <= 32 else {
            throw GPUError.invalidInput("Number of distributions must be 1-32")
        }
        guard numOps > 0 && numOps <= 128 else {
            throw GPUError.invalidInput("Number of bytecode operations must be 1-128")
        }
        guard iterations > 0 else {
            throw GPUError.invalidInput("Iterations must be > 0")
        }

        // Get or allocate buffers (with caching for performance)
        let buffers = try getOrAllocateBuffers(
            iterations: iterations,
            numInputs: numInputs,
            numOps: numOps
        )

        // Upload distribution data
        try uploadDistributions(distributions, to: buffers)

        // Upload model bytecode
        try uploadBytecode(modelBytecode, to: buffers)

        // Execute simulation pipeline
        try executePipeline(
            buffers: buffers,
            iterations: iterations,
            numInputs: numInputs,
            numOps: numOps,
            seed: seed
        )

        // Download results
        return downloadResults(from: buffers.outputs, count: iterations)
    }

    // MARK: - Buffer Management

    private struct Buffers {
        let rngStates: MTLBuffer
        let distributions: MTLBuffer
        let distTypes: MTLBuffer
        let modelOps: MTLBuffer
        let outputs: MTLBuffer
    }

    private func getOrAllocateBuffers(
        iterations: Int,
        numInputs: Int,
        numOps: Int
    ) throws -> Buffers {
        // TODO: Re-enable buffer caching with proper data clearing
        // Currently disabled due to stale data issues

        // Allocate new buffers every time (ensures clean state)
        let rngStateSize = iterations * MemoryLayout<(UInt64, UInt64)>.stride
        let distSize = numInputs * MemoryLayout<(Float, Float, Float)>.stride
        let distTypeSize = numInputs * MemoryLayout<Int32>.stride
        let opsSize = numOps * MemoryLayout<(Int32, Int32, Float)>.stride
        let outputSize = iterations * MemoryLayout<Float>.stride

        guard let rngStates = device.makeBuffer(length: rngStateSize, options: .storageModeShared),
              let distributions = device.makeBuffer(length: distSize, options: .storageModeShared),
              let distTypes = device.makeBuffer(length: distTypeSize, options: .storageModeShared),
              let modelOps = device.makeBuffer(length: opsSize, options: .storageModeShared),
              let outputs = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
            throw GPUError.bufferAllocationFailed
        }

        return Buffers(
            rngStates: rngStates,
            distributions: distributions,
            distTypes: distTypes,
            modelOps: modelOps,
            outputs: outputs
        )
    }

    private func uploadDistributions(_ distributions: [DistributionConfig], to buffers: Buffers) throws {
        let distPointer = buffers.distributions.contents().bindMemory(
            to: (Float, Float, Float).self,
            capacity: distributions.count
        )
        let typePointer = buffers.distTypes.contents().bindMemory(
            to: Int32.self,
            capacity: distributions.count
        )

        for (i, dist) in distributions.enumerated() {
            distPointer[i] = dist.params
            typePointer[i] = dist.type
        }
    }

    private func uploadBytecode(_ bytecode: [ModelOperation], to buffers: Buffers) throws {
        let opsPointer = buffers.modelOps.contents().bindMemory(
            to: (Int32, Int32, Float).self,
            capacity: bytecode.count
        )

        for (i, op) in bytecode.enumerated() {
            opsPointer[i] = op
        }
    }

    private func downloadResults(from buffer: MTLBuffer, count: Int) -> [Float] {
        // OPTIMIZATION: Use bulk memcpy instead of element-wise copy
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
        var results = [Float](repeating: 0, count: count)
        results.withUnsafeMutableBufferPointer { dest in
            dest.baseAddress!.update(from: pointer, count: count)
        }
        return results
    }

    // MARK: - Pipeline Execution

    private func executePipeline(
        buffers: Buffers,
        iterations: Int,
        numInputs: Int,
        numOps: Int,
        seed: UInt64?
    ) throws {
        // OPTIMIZATION: Use single command buffer for both kernels
        // Reduces overhead from 2 kernel launches to 1
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw GPUError.commandBufferCreationFailed
        }

        // Step 1: Initialize RNG (encode but don't commit yet)
        try encodeRNGInitialization(
            commandBuffer: commandBuffer,
            buffer: buffers.rngStates,
            iterations: iterations,
            seed: seed ?? UInt64(arc4random()) << 32 | UInt64(arc4random())
        )

        // Step 2: Encode Monte Carlo iterations in same command buffer
        try encodeMonteCarloIterations(
            commandBuffer: commandBuffer,
            buffers: buffers,
            iterations: iterations,
            numInputs: numInputs,
            numOps: numOps
        )

        // Submit both kernels together and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if commandBuffer.status == .error {
            throw GPUError.executionFailed("GPU pipeline execution failed")
        }
    }

    private func encodeRNGInitialization(
        commandBuffer: MTLCommandBuffer,
        buffer: MTLBuffer,
        iterations: Int,
        seed: UInt64
    ) throws {
        guard let pipeline = initRNGPipeline else {
            throw GPUError.pipelineNotCompiled("initializeRNG")
        }

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GPUError.commandBufferCreationFailed
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        var seedVar = seed
        encoder.setBytes(&seedVar, length: MemoryLayout<UInt64>.stride, index: 1)

        // OPTIMIZATION: Use larger thread groups for better GPU utilization
        let threadsPerGroup = MTLSize(width: min(iterations, 1024), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (iterations + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }

    private func encodeMonteCarloIterations(
        commandBuffer: MTLCommandBuffer,
        buffers: Buffers,
        iterations: Int,
        numInputs: Int,
        numOps: Int
    ) throws {
        guard let pipeline = monteCarloIterationPipeline else {
            throw GPUError.pipelineNotCompiled("monteCarloIteration")
        }

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GPUError.commandBufferCreationFailed
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffers.rngStates, offset: 0, index: 0)
        encoder.setBuffer(buffers.distributions, offset: 0, index: 1)
        encoder.setBuffer(buffers.distTypes, offset: 0, index: 2)
        encoder.setBuffer(buffers.modelOps, offset: 0, index: 3)
        encoder.setBuffer(buffers.outputs, offset: 0, index: 4)

        var numInputsVar = Int32(numInputs)
        var numOpsVar = Int32(numOps)
        encoder.setBytes(&numInputsVar, length: MemoryLayout<Int32>.stride, index: 5)
        encoder.setBytes(&numOpsVar, length: MemoryLayout<Int32>.stride, index: 6)

        // OPTIMIZATION: Use larger thread groups (1024 vs 256) for better occupancy
        let threadsPerGroup = MTLSize(width: min(iterations, 1024), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (iterations + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
}

// MARK: - Error Types

/// Errors that can occur during GPU-accelerated Monte Carlo simulation.
///
/// Represents failures in Metal pipeline setup, buffer allocation, kernel execution,
/// or invalid input parameters.
public enum GPUError: Error {
    /// Metal shader kernel not found in library
    case kernelNotFound(String)

    /// Failed to allocate GPU buffer memory
    case bufferAllocationFailed

    /// Failed to create Metal command buffer
    case commandBufferCreationFailed

    /// GPU kernel execution failed
    case executionFailed(String)

    /// Compute pipeline state not compiled
    case pipelineNotCompiled(String)

    /// Invalid input parameters for GPU computation
    case invalidInput(String)
}

#endif
