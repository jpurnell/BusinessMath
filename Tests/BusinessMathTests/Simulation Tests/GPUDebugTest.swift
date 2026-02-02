//
//  GPUDebugTest.swift
//  BusinessMathTests
//
//  Diagnostic test to debug NaN values from GPU execution
//

import Foundation
import Testing
@testable import BusinessMath

#if canImport(Metal)
import Metal
#endif

@Suite("GPU Debug Tests")
struct GPUDebugTests {

    @Test("Debug bytecode generation for simple profit model")
    func debugBytecodeGeneration() throws {
        // Create the same model as the playground
        let profitModel = MonteCarloExpressionModel { builder in
            let revenue = builder[0]  // First input
            let costs = builder[1]    // Second input
            return revenue - costs
        }

        // Get the compiled bytecode
        let bytecode = profitModel.compile()
        print("\n=== Compiled Bytecode ===")
        for (i, instruction) in bytecode.enumerated() {
            print("  [\(i)] \(instruction)")
        }

        // Get GPU bytecode
        let gpuBytecode = profitModel.gpuBytecode()
        print("\n=== GPU Bytecode ===")
        for (i, op) in gpuBytecode.enumerated() {
            print("  [\(i)] opcode=\(op.opcode), arg1=\(op.arg1), arg2=\(op.arg2)")
        }

        // Test CPU evaluation first
        let testInputs = [1_000_000.0, 700_000.0]
        let cpuResult = try profitModel.evaluate(inputs: testInputs)
        print("\n=== CPU Evaluation ===")
        print("  Inputs: \(testInputs)")
        print("  Result: \(cpuResult)")
        print("  Expected: 300,000")

        #expect(cpuResult == 300_000.0)
    }

    @Test("Debug GPU device simulation with hardcoded inputs")
    func debugGPUDevice() throws {
        #if canImport(Metal)
        guard let gpuDevice = MonteCarloGPUDevice() else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        print("\n=== GPU Device Test ===")

        // Create simple distributions
        // Distribution type 0 = Normal
        let distributions: [(type: Int32, params: (Float, Float, Float))] = [
            (type: 0, params: (1_000_000.0, 100_000.0, 0.0)),  // Revenue: Normal(1M, 100K)
            (type: 0, params: (700_000.0, 50_000.0, 0.0))       // Costs: Normal(700K, 50K)
        ]

        // Create bytecode for: revenue - costs
        // INPUT 0, INPUT 1, SUB
        let bytecode: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (opcode: 4, arg1: 0, arg2: 0.0),  // INPUT 0 (revenue)
            (opcode: 4, arg1: 1, arg2: 0.0),  // INPUT 1 (costs)
            (opcode: 1, arg1: 0, arg2: 0.0)   // SUB
        ]

        print("Distributions:")
        for (i, dist) in distributions.enumerated() {
            print("  [\(i)] type=\(dist.type), params=(\(dist.params.0), \(dist.params.1), \(dist.params.2))")
        }

        print("Bytecode:")
        for (i, op) in bytecode.enumerated() {
            print("  [\(i)] opcode=\(op.opcode), arg1=\(op.arg1), arg2=\(op.arg2)")
        }

        // Run simulation
        let results = try gpuDevice.runSimulation(
            distributions: distributions,
            modelBytecode: bytecode,
            iterations: 1000
        )

        // Check first few results
        print("\nFirst 10 results:")
        for i in 0..<min(10, results.count) {
            print("  [\(i)] \(results[i])")
        }

        // Calculate statistics
        let mean = results.reduce(0.0, +) / Float(results.count)
        let nanCount = results.filter { $0.isNaN }.count
        let infCount = results.filter { $0.isInfinite }.count

        print("\nStatistics:")
        print("  Mean: \(mean)")
        print("  NaN count: \(nanCount)")
        print("  Inf count: \(infCount)")
        print("  Min: \(results.min() ?? Float.nan)")
        print("  Max: \(results.max() ?? Float.nan)")

        // Verify results are reasonable
        #expect(nanCount == 0, "No NaN values should be present")
        #expect(infCount == 0, "No infinite values should be present")
        #expect(mean > 200_000 && mean < 400_000, "Mean should be around 300,000")
        #endif
    }
}
