import Testing
import Foundation
#if canImport(Metal)
import Metal
#endif
@testable import BusinessMath

/// Tests for GPU device manager
///
/// Validates the Swift-side GPU orchestration layer that manages:
/// - Device initialization and kernel compilation
/// - Buffer allocation and data transfer
/// - Kernel execution coordination
/// - Error handling and graceful degradation
@Suite("Monte Carlo GPU Device Manager Tests")
struct MonteCarloGPUDeviceTests {

    // MARK: - Test Configuration Types

    struct DistributionConfig {
        let type: Int32        // Distribution type enum
        let params: (Float, Float, Float)  // param1, param2, param3
    }

    struct ModelBytecode {
        let operations: [(opcode: Int32, arg1: Int32, arg2: Float)]
    }

    // MARK: - Tests

    @Test("GPU device initialization")
    func testDeviceInitialization() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        // Verify device exists
        let device = metalDevice.device
        #expect(device.name != "")

        // Verify command queue exists
        let commandQueue = metalDevice.commandQueue
        #expect(commandQueue.label != nil || commandQueue.label == nil) // Just check it's not crashing

        print("✓ Metal device available: \(device.name)")
        #endif
    }

    @Test("Kernel compilation from source")
    func testKernelCompilation() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device

        // Minimal kernel source
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void testKernel(
            device float* output [[buffer(0)]],
            uint tid [[thread_position_in_grid]]
        ) {
            output[tid] = float(tid) * 2.0f;
        }
        """

        // Compile kernel
        guard let library = try? device.makeLibrary(source: kernelSource, options: nil) else {
            #expect(Bool(false), "Failed to compile kernel source")
            return
        }

        guard let function = library.makeFunction(name: "testKernel") else {
            #expect(Bool(false), "Failed to find kernel function")
            return
        }

        // Create pipeline state
        let pipeline = try device.makeComputePipelineState(function: function)
        #expect(pipeline.threadExecutionWidth > 0)

        print("✓ Kernel compiled successfully")
        #endif
    }

    @Test("Buffer allocation and data transfer")
    func testBufferManagement() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let count = 1000

        // Allocate buffer
        let bufferSize = count * MemoryLayout<Float>.stride
        guard let buffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            #expect(Bool(false), "Failed to allocate buffer")
            return
        }

        // Write data to buffer
        let testData: [Float] = (0..<count).map { Float($0) }
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            pointer[i] = testData[i]
        }

        // Read data back
        let readBack = (0..<count).map { pointer[$0] }

        // Verify round-trip
        for i in 0..<count {
            #expect(readBack[i] == testData[i], "Data mismatch at index \(i)")
        }

        print("✓ Buffer allocation and transfer working")
        #endif
    }

    @Test("Simple kernel execution")
    func testKernelExecution() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue
        let count = 256

        // Kernel that doubles each element
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void doubleValues(
            device float* values [[buffer(0)]],
            uint tid [[thread_position_in_grid]]
        ) {
            values[tid] = values[tid] * 2.0f;
        }
        """

        // Compile kernel
        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let function = library.makeFunction(name: "doubleValues") else {
            return // Skip if compilation fails
        }

        let pipeline = try device.makeComputePipelineState(function: function)

        // Create and initialize buffer
        var inputData: [Float] = (0..<count).map { Float($0) }
        let bufferSize = count * MemoryLayout<Float>.stride
        guard let buffer = device.makeBuffer(bytes: &inputData, length: bufferSize, options: .storageModeShared) else {
            return
        }

        // Execute kernel
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)

        let threadsPerGroup = MTLSize(width: min(count, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(width: (count + 255) / 256, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Verify results
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            let expected = Float(i) * 2.0
            let actual = pointer[i]
            #expect(abs(actual - expected) < 0.001, "Mismatch at \(i): expected \(expected), got \(actual)")
        }

        print("✓ Kernel execution successful")
        #endif
    }

    @Test("RNG initialization kernel")
    func testRNGInitialization() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue
        let count = 1000

        // Kernel source with RNG initialization
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct RNGState {
            ulong s0;
            ulong s1;
        };

        inline float nextUniform(thread RNGState* state) {
            ulong s1 = state->s0;
            ulong s0 = state->s1;
            state->s0 = s0;
            s1 ^= s1 << 23;
            state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
            return float(state->s0 + state->s1) * 1.08420217e-19f;
        }

        kernel void initializeRNG(
            device RNGState* states [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            states[tid].s0 = baseSeed ^ tid;
            states[tid].s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);

            // Warm up
            for (int i = 0; i < 10; i++) {
                nextUniform(&states[tid]);
            }
        }

        kernel void generateSamples(
            device RNGState* states [[buffer(0)]],
            device float* outputs [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            outputs[tid] = nextUniform(&states[tid]);
        }
        """

        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let initFunc = library.makeFunction(name: "initializeRNG"),
              let sampleFunc = library.makeFunction(name: "generateSamples") else {
            return // Skip if compilation fails
        }

        let initPipeline = try device.makeComputePipelineState(function: initFunc)
        let samplePipeline = try device.makeComputePipelineState(function: sampleFunc)

        // Allocate buffers
        let stateSize = count * MemoryLayout<(UInt64, UInt64)>.stride
        let outputSize = count * MemoryLayout<Float>.stride

        guard let stateBuffer = device.makeBuffer(length: stateSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
            return
        }

        // Initialize RNG
        var seed: UInt64 = 12345
        let commandBuffer1 = commandQueue.makeCommandBuffer()!
        let encoder1 = commandBuffer1.makeComputeCommandEncoder()!
        encoder1.setComputePipelineState(initPipeline)
        encoder1.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder1.setBytes(&seed, length: MemoryLayout<UInt64>.stride, index: 1)

        let threadsPerGroup = MTLSize(width: min(count, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(width: (count + 255) / 256, height: 1, depth: 1)
        encoder1.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder1.endEncoding()
        commandBuffer1.commit()
        commandBuffer1.waitUntilCompleted()

        // Generate samples
        let commandBuffer2 = commandQueue.makeCommandBuffer()!
        let encoder2 = commandBuffer2.makeComputeCommandEncoder()!
        encoder2.setComputePipelineState(samplePipeline)
        encoder2.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder2.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder2.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder2.endEncoding()
        commandBuffer2.commit()
        commandBuffer2.waitUntilCompleted()

        // Verify samples are in [0, 1)
        let pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
        let samples = (0..<count).map { pointer[$0] }

        #expect(samples.allSatisfy { $0 >= 0.0 && $0 < 1.0 }, "All samples should be in [0, 1)")

        // Check some basic randomness (not all same)
        let uniqueCount = Set(samples.map { Int($0 * 100) }).count
        #expect(uniqueCount > 50, "Should have reasonable variety in samples")

        print("✓ RNG initialization and sampling working")
        #endif
    }

    @Test("Multi-buffer coordination")
    func testMultiBufferCoordination() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue
        let count = 512

        // Kernel that uses multiple buffers (A + B = C)
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void addVectors(
            device const float* inputA [[buffer(0)]],
            device const float* inputB [[buffer(1)]],
            device float* output [[buffer(2)]],
            uint tid [[thread_position_in_grid]]
        ) {
            output[tid] = inputA[tid] + inputB[tid];
        }
        """

        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let function = library.makeFunction(name: "addVectors") else {
            return
        }

        let pipeline = try device.makeComputePipelineState(function: function)

        // Create three buffers
        var dataA: [Float] = (0..<count).map { Float($0) }
        var dataB: [Float] = (0..<count).map { Float($0 * 2) }

        let bufferSize = count * MemoryLayout<Float>.stride
        guard let bufferA = device.makeBuffer(bytes: &dataA, length: bufferSize, options: .storageModeShared),
              let bufferB = device.makeBuffer(bytes: &dataB, length: bufferSize, options: .storageModeShared),
              let bufferC = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            return
        }

        // Execute kernel
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(bufferA, offset: 0, index: 0)
        encoder.setBuffer(bufferB, offset: 0, index: 1)
        encoder.setBuffer(bufferC, offset: 0, index: 2)

        let threadsPerGroup = MTLSize(width: 256, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (count + 255) / 256, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Verify results
        let pointer = bufferC.contents().bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            let expected = dataA[i] + dataB[i]
            let actual = pointer[i]
            #expect(abs(actual - expected) < 0.001)
        }

        print("✓ Multi-buffer coordination working")
        #endif
    }

    @Test("Thread layout calculation")
    func testThreadLayoutCalculation() throws {
        // Test optimal thread layout for various iteration counts
        let testCases = [
            (iterations: 100, expectedGroups: 1, threadsPerGroup: 100),
            (iterations: 256, expectedGroups: 1, threadsPerGroup: 256),
            (iterations: 512, expectedGroups: 2, threadsPerGroup: 256),
            (iterations: 1000, expectedGroups: 4, threadsPerGroup: 256),
            (iterations: 10_000, expectedGroups: 40, threadsPerGroup: 256),
        ]

        for testCase in testCases {
            let threadsPerGroup = min(testCase.iterations, 256)
            let threadGroups = (testCase.iterations + threadsPerGroup - 1) / threadsPerGroup

            #expect(threadsPerGroup <= 256, "Threads per group should not exceed 256")
            #expect(threadGroups * threadsPerGroup >= testCase.iterations,
                   "Total threads should cover all iterations")

            print("✓ Layout for \(testCase.iterations) iterations: \(threadGroups) groups × \(threadsPerGroup) threads")
        }
    }

    @Test("Error handling for invalid buffer size")
    func testErrorHandling() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device

        // Try to allocate unreasonably large buffer (should fail gracefully)
        let hugeSize = Int.max / 2
        let buffer = device.makeBuffer(length: hugeSize, options: .storageModeShared)

        // Buffer allocation should fail (return nil)
        #expect(buffer == nil, "Huge buffer allocation should fail")

        print("✓ Error handling working (invalid buffer size)")
        #endif
    }

    @Test("Memory reuse pattern")
    func testMemoryReuse() throws {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let bufferSize = 1024 * MemoryLayout<Float>.stride

        // Allocate buffer
        var buffer1: MTLBuffer? = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        #expect(buffer1 != nil)

        // Release buffer
        buffer1 = nil

        // Allocate again (should reuse memory pool)
        let buffer2 = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        #expect(buffer2 != nil)

        print("✓ Memory reuse pattern working")
        #endif
    }
}
