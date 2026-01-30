import Testing
import Foundation
@testable import BusinessMath

/// Performance benchmarks for GPU-accelerated Monte Carlo simulation
///
/// These tests measure and compare GPU vs CPU performance for various
/// simulation sizes and model complexities.
///
/// **Note**: These tests are manual benchmarks, not part of regular test suite.
/// Run individually to measure performance on your hardware.
/// All tests are disabled by default - enable individually for benchmarking.
@Suite("Monte Carlo GPU Performance Benchmarks")
struct MonteCarloGPUPerformanceTests {

    // MARK: - Small Simulation Benchmark (1K iterations)

    @Test("1K iterations: CPU should be faster (GPU overhead)", .disabled())
    func benchmark1KIterations() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        let model = MonteCarloExpressionModel { builder in
            let a = builder[0]
            let b = builder[1]
            return a + b
        }

        // CPU benchmark
        let cpuStart = Date()
        var cpuSim = MonteCarloSimulation(
            iterations: 1_000,
            enableGPU: false,
            expressionModel: model
        )
        cpuSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        cpuSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
        let cpuResults = try cpuSim.run()
        let cpuTime = Date().timeIntervalSince(cpuStart)

        // GPU benchmark (should fall back to CPU due to threshold)
        let gpuStart = Date()
        var gpuSim = MonteCarloSimulation(
            iterations: 1_000,
            enableGPU: true,
            expressionModel: model
        )
        gpuSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        gpuSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
        let gpuResults = try gpuSim.run()
        let gpuTime = Date().timeIntervalSince(gpuStart)

        print("📊 1K Iterations Benchmark:")
        print("   CPU: \(Int(cpuTime * 1000))ms (usedGPU: \(cpuResults.usedGPU))")
        print("   GPU path: \(Int(gpuTime * 1000))ms (usedGPU: \(gpuResults.usedGPU))")
        print("   Expected: Both should use CPU due to threshold")
        #endif
    }

    // MARK: - Medium Simulation Benchmark (10K iterations)

    @Test("10K iterations: GPU should show 5-10x speedup", .disabled())
    func benchmark10KIterations() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let costs = builder[1]
            let tax = builder[2]
            return revenue - costs * (1.0 + tax)
        }

        // CPU benchmark
        let cpuStart = Date()
        var cpuSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        cpuSim.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(1_000_000, 100_000)))
        cpuSim.addInput(SimulationInput(name: "Costs", distribution: DistributionNormal(700_000, 50_000)))
        cpuSim.addInput(SimulationInput(name: "Tax", distribution: DistributionUniform(0.2, 0.3)))
        let cpuResults = try cpuSim.run()
        let cpuTime = Date().timeIntervalSince(cpuStart)

        // GPU benchmark
        let gpuStart = Date()
        var gpuSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: true,
            expressionModel: model
        )
        gpuSim.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(1_000_000, 100_000)))
        gpuSim.addInput(SimulationInput(name: "Costs", distribution: DistributionNormal(700_000, 50_000)))
        gpuSim.addInput(SimulationInput(name: "Tax", distribution: DistributionUniform(0.2, 0.3)))
        let gpuResults = try gpuSim.run()
        let gpuTime = Date().timeIntervalSince(gpuStart)

        let speedup = cpuTime / gpuTime

        print("📊 10K Iterations Benchmark:")
        print("   CPU: \(Int(cpuTime * 1000))ms (usedGPU: \(cpuResults.usedGPU))")
        print("   GPU: \(Int(gpuTime * 1000))ms (usedGPU: \(gpuResults.usedGPU))")
        print("   Speedup: \(String(format: "%.1f", speedup))x")
        print("   Expected: 5-10x speedup on M1/M2/M3")
        #endif
    }

    // MARK: - Large Simulation Benchmark (100K iterations)

    @Test("100K iterations: GPU should show 10-20x speedup", .disabled())
    func benchmark100KIterations() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        let model = MonteCarloExpressionModel { builder in
            let units = builder[0]
            let price = builder[1]
            let fixedCosts = builder[2]
            let variableCost = builder[3]

            let revenue = units * price
            let totalCosts = fixedCosts + (units * variableCost)
            return revenue - totalCosts
        }

        // CPU benchmark
        let cpuStart = Date()
        var cpuSim = MonteCarloSimulation(
            iterations: 100_000,
            enableGPU: false,
            expressionModel: model
        )
        cpuSim.addInput(SimulationInput(name: "Units", distribution: DistributionNormal(10_000, 1_000)))
        cpuSim.addInput(SimulationInput(name: "Price", distribution: DistributionUniform(90, 110)))
        cpuSim.addInput(SimulationInput(name: "FixedCosts", distribution: DistributionNormal(200_000, 20_000)))
        cpuSim.addInput(SimulationInput(name: "VariableCost", distribution: DistributionTriangular(low: 40, high: 60, base: 50)))
        let cpuResults = try cpuSim.run()
        let cpuTime = Date().timeIntervalSince(cpuStart)

        // GPU benchmark
        let gpuStart = Date()
        var gpuSim = MonteCarloSimulation(
            iterations: 100_000,
            enableGPU: true,
            expressionModel: model
        )
        gpuSim.addInput(SimulationInput(name: "Units", distribution: DistributionNormal(10_000, 1_000)))
        gpuSim.addInput(SimulationInput(name: "Price", distribution: DistributionUniform(90, 110)))
        gpuSim.addInput(SimulationInput(name: "FixedCosts", distribution: DistributionNormal(200_000, 20_000)))
        gpuSim.addInput(SimulationInput(name: "VariableCost", distribution: DistributionTriangular(low: 40, high: 60, base: 50)))
        let gpuResults = try gpuSim.run()
        let gpuTime = Date().timeIntervalSince(gpuStart)

        let speedup = cpuTime / gpuTime

        print("📊 100K Iterations Benchmark:")
        print("   CPU: \(String(format: "%.2f", cpuTime))s (usedGPU: \(cpuResults.usedGPU))")
        print("   GPU: \(String(format: "%.2f", gpuTime))s (usedGPU: \(gpuResults.usedGPU))")
        print("   Speedup: \(String(format: "%.1f", speedup))x")
        print("   Expected: 10-20x speedup on M1/M2/M3")
        print("   Results match: \(abs(cpuResults.statistics.mean - gpuResults.statistics.mean) / cpuResults.statistics.mean < 0.01 ? "✓" : "✗")")
        #endif
    }

    // MARK: - Very Large Simulation Benchmark (1M iterations)

    @Test("1M iterations: GPU should show 50-100x speedup", .disabled())
    func benchmark1MIterations() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        let model = MonteCarloExpressionModel { builder in
            builder[0] * builder[1] - builder[2]
        }

        // CPU benchmark (will be slow!)
        print("⏳ Running 1M iterations on CPU (this will take ~30-60 seconds)...")
        let cpuStart = Date()
        var cpuSim = MonteCarloSimulation(
            iterations: 1_000_000,
            enableGPU: false,
            expressionModel: model
        )
        cpuSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        cpuSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
        cpuSim.addInput(SimulationInput(name: "C", distribution: DistributionNormal(1000, 100)))
        let cpuResults = try cpuSim.run()
        let cpuTime = Date().timeIntervalSince(cpuStart)

        // GPU benchmark (should be fast!)
        print("⚡ Running 1M iterations on GPU...")
        let gpuStart = Date()
        var gpuSim = MonteCarloSimulation(
            iterations: 1_000_000,
            enableGPU: true,
            expressionModel: model
        )
        gpuSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        gpuSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
        gpuSim.addInput(SimulationInput(name: "C", distribution: DistributionNormal(1000, 100)))
        let gpuResults = try gpuSim.run()
        let gpuTime = Date().timeIntervalSince(gpuStart)

        let speedup = cpuTime / gpuTime

        print("📊 1M Iterations Benchmark:")
        print("   CPU: \(String(format: "%.1f", cpuTime))s (usedGPU: \(cpuResults.usedGPU))")
        print("   GPU: \(String(format: "%.2f", gpuTime))s (usedGPU: \(gpuResults.usedGPU))")
        print("   Speedup: \(String(format: "%.1f", speedup))x")
        print("   Expected: 50-100x speedup on M1/M2/M3")
        print("   Results match: \(abs(cpuResults.statistics.mean - gpuResults.statistics.mean) / cpuResults.statistics.mean < 0.01 ? "✓" : "✗")")
        #endif
    }

    // MARK: - Model Complexity Benchmark

    @Test("Complex model vs simple model performance", .disabled())
    func benchmarkModelComplexity() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        let iterations = 50_000

        // Simple model: a + b
        let simpleModel = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        let simpleStart = Date()
        var simpleSim = MonteCarloSimulation(iterations: iterations, enableGPU: true, expressionModel: simpleModel)
        simpleSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        simpleSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
        _ = try simpleSim.run()
        let simpleTime = Date().timeIntervalSince(simpleStart)

        // Complex model: (a * b) + (c * d) - (e / 2)
        let complexModel = MonteCarloExpressionModel { builder in
            let a = builder[0]
            let b = builder[1]
            let c = builder[2]
            let d = builder[3]
            let e = builder[4]
            return (a * b) + (c * d) - (e / 2.0)
        }

        let complexStart = Date()
        var complexSim = MonteCarloSimulation(iterations: iterations, enableGPU: true, expressionModel: complexModel)
        complexSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        complexSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(2, 0.2)))
        complexSim.addInput(SimulationInput(name: "C", distribution: DistributionNormal(50, 5)))
        complexSim.addInput(SimulationInput(name: "D", distribution: DistributionNormal(3, 0.3)))
        complexSim.addInput(SimulationInput(name: "E", distribution: DistributionNormal(1000, 100)))
        _ = try complexSim.run()
        let complexTime = Date().timeIntervalSince(complexStart)

        print("📊 Model Complexity Benchmark (\(iterations) iterations):")
        print("   Simple (a + b): \(Int(simpleTime * 1000))ms")
        print("   Complex ((a*b) + (c*d) - (e/2)): \(Int(complexTime * 1000))ms")
        print("   Overhead: \(String(format: "%.1f", (complexTime / simpleTime - 1) * 100))%")
        print("   Expected: Minimal overhead due to parallel GPU execution")
        #endif
    }
}
