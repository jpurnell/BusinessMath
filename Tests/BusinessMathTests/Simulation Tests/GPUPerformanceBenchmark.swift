//
//  GPUPerformanceBenchmark.swift
//  BusinessMathTests
//
//  Quick performance test to verify GPU optimizations
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("GPU Performance Benchmark")
struct GPUPerformanceBenchmark {

    @Test("Measure GPU performance improvement")
    func benchmarkGPUPerformance() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        let model = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        let iterationCounts = [10_000, 50_000, 100_000]

        print("\n=== GPU Performance Benchmark ===")
        print("Iterations | GPU Time | CPU Time | Speedup")
        print("-----------|----------|----------|--------")

        for iterations in iterationCounts {
            // GPU version
            var gpuSim = MonteCarloSimulation(
                iterations: iterations,
                enableGPU: true,
                expressionModel: model
            )
            gpuSim.addInput(SimulationInput(
                name: "A",
                distribution: DistributionNormal(100.0, 10.0)
            ))
            gpuSim.addInput(SimulationInput(
                name: "B",
                distribution: DistributionNormal(50.0, 5.0)
            ))

            let gpuStart = Date()
            let gpuResults = try gpuSim.run()
            let gpuTime = Date().timeIntervalSince(gpuStart) * 1000

            // CPU version
            var cpuSim = MonteCarloSimulation(
                iterations: iterations,
                enableGPU: false,
                expressionModel: model
            )
            cpuSim.addInput(SimulationInput(
                name: "A",
                distribution: DistributionNormal(100.0, 10.0)
            ))
            cpuSim.addInput(SimulationInput(
                name: "B",
                distribution: DistributionNormal(50.0, 5.0)
            ))

            let cpuStart = Date()
            let cpuResults = try cpuSim.run()
            let cpuTime = Date().timeIntervalSince(cpuStart) * 1000

            let speedup = cpuTime / gpuTime

            print(String(format: "%10d | %8.1f | %8.1f | %5.1f×",
                        iterations, gpuTime, cpuTime, speedup))

            // Verify GPU was used
            #expect(gpuResults.usedGPU == true, "GPU should be used for \(iterations) iterations")

            // Verify results are statistically similar
            let meanDiff = abs(gpuResults.statistics.mean - cpuResults.statistics.mean)
            let meanAvg = (gpuResults.statistics.mean + cpuResults.statistics.mean) / 2
            let percentDiff = (meanDiff / meanAvg) * 100
            #expect(percentDiff < 1.0, "GPU and CPU means should be within 1%")
        }

        print("\nNote: First run includes GPU initialization overhead")
        print("Expected speedup: 5-15x after warmup on M1/M2/M3")
        #endif
    }
}
