//
//  RNGDebugTest.swift
//  BusinessMathTests
//
//  Debug RNG and distribution sampling on GPU
//

import Foundation
import Testing
@testable import BusinessMath

#if canImport(Metal)
import Metal
#endif

@Suite("RNG Debug Tests")
struct RNGDebugTests {

    @Test("Test GPU RNG directly with constant output")
    func testGPURNGDirect() throws {
        #if canImport(Metal)
        guard let gpuDevice = MonteCarloGPUDevice() else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        print("\n=== Testing GPU with Constant Model ===")

        // Use constant model: always return 42.0
        // Bytecode: CONST 42.0
        let bytecode: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (opcode: 5, arg1: 0, arg2: 42.0)  // CONST 42.0
        ]

        // Still need a distribution even though we won't use it
        let distributions: [(type: Int32, params: (Float, Float, Float))] = [
            (type: 0, params: (1000.0, 100.0, 0.0))  // Normal(1000, 100)
        ]

        let results = try gpuDevice.runSimulation(
            distributions: distributions,
            modelBytecode: bytecode,
            iterations: 100
        )

        print("First 10 constant results:")
        for i in 0..<min(10, results.count) {
            print("  [\(i)] \(results[i])")
        }

        let nanCount = results.filter { $0.isNaN }.count
        let allEqual = results.allSatisfy { $0 == 42.0 }

        print("\nConstant model results:")
        print("  All equal to 42.0: \(allEqual)")
        print("  NaN count: \(nanCount)")

        #expect(nanCount == 0, "Constant model should not produce NaN")
        #expect(allEqual, "Constant model should always return 42.0")
        #endif
    }

    @Test("Test GPU with simple input passthrough")
    func testGPUInputPassthrough() throws {
        #if canImport(Metal)
        guard let gpuDevice = MonteCarloGPUDevice() else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        print("\n=== Testing GPU Input Passthrough ===")

        // Model: just return input[0]
        // Bytecode: INPUT 0
        let bytecode: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (opcode: 4, arg1: 0, arg2: 0.0)  // INPUT 0
        ]

        // Use uniform distribution for predictability: Uniform(1000, 2000)
        // All values should be between 1000 and 2000
        let distributions: [(type: Int32, params: (Float, Float, Float))] = [
            (type: 1, params: (1000.0, 2000.0, 0.0))  // Uniform(1000, 2000)
        ]

        let results = try gpuDevice.runSimulation(
            distributions: distributions,
            modelBytecode: bytecode,
            iterations: 100
        )

        print("First 10 passthrough results:")
        for i in 0..<min(10, results.count) {
            print("  [\(i)] \(results[i])")
        }

        let nanCount = results.filter { $0.isNaN }.count
        let infCount = results.filter { $0.isInfinite }.count
        let inRange = results.filter { $0 >= 1000.0 && $0 <= 2000.0 }.count
        let mean = results.reduce(0.0, +) / Float(results.count)

        print("\nPassthrough results:")
        print("  NaN count: \(nanCount)")
        print("  Inf count: \(infCount)")
        print("  In range [1000, 2000]: \(inRange) / \(results.count)")
        print("  Mean: \(mean) (expected ~1500)")
        print("  Min: \(results.min() ?? Float.nan)")
        print("  Max: \(results.max() ?? Float.nan)")

        #expect(nanCount == 0, "Should not produce NaN")
        #expect(infCount == 0, "Should not produce Inf")
        #expect(inRange == results.count, "All values should be in range [1000, 2000]")
        #expect(mean > 1400 && mean < 1600, "Mean should be around 1500")
        #endif
    }

    @Test("Test GPU with addition")
    func testGPUAddition() throws {
        #if canImport(Metal)
        guard let gpuDevice = MonteCarloGPUDevice() else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        print("\n=== Testing GPU Addition ===")

        // Model: CONST 100 + CONST 200 = 300
        let bytecode: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (opcode: 5, arg1: 0, arg2: 100.0),  // CONST 100
            (opcode: 5, arg1: 0, arg2: 200.0),  // CONST 200
            (opcode: 0, arg1: 0, arg2: 0.0)     // ADD
        ]

        // Dummy distribution
        let distributions: [(type: Int32, params: (Float, Float, Float))] = [
            (type: 0, params: (1000.0, 100.0, 0.0))
        ]

        let results = try gpuDevice.runSimulation(
            distributions: distributions,
            modelBytecode: bytecode,
            iterations: 100
        )

        print("First 10 addition results:")
        for i in 0..<min(10, results.count) {
            print("  [\(i)] \(results[i])")
        }

        let nanCount = results.filter { $0.isNaN }.count
        let allEqual = results.allSatisfy { $0 == 300.0 }

        print("\nAddition results:")
        print("  All equal to 300.0: \(allEqual)")
        print("  NaN count: \(nanCount)")

        #expect(nanCount == 0, "Addition should not produce NaN")
        #expect(allEqual, "100 + 200 should always equal 300")
        #endif
    }
}
