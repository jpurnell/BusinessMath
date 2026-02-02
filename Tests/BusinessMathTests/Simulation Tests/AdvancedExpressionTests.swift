import Testing
import Foundation
@testable import BusinessMath

/// Tests for advanced expression features: comparisons and conditionals
///
/// Validates that comparison operators and if/else conditionals work correctly
/// in both CPU and GPU execution paths.
@Suite("Advanced Expression Features")
struct AdvancedExpressionTests {

    // MARK: - Comparison Tests

    @Test("Less than comparison")
    func testLessThan() throws {
        let model = MonteCarloExpressionModel { builder in
            let a = builder[0]
            let b = builder[1]
            return a.lessThan(b)
        }

        // Test where a < b (should return 1.0)
        var result = model.toClosure()([5.0, 10.0])
        #expect(result == 1.0)

        // Test where a >= b (should return 0.0)
        result = model.toClosure()([10.0, 5.0])
        #expect(result == 0.0)
    }

    @Test("Greater than comparison")
    func testGreaterThan() throws {
        let model = MonteCarloExpressionModel { builder in
            builder[0].greaterThan(100.0)
        }

        var result = model.toClosure()( [150.0]
        )
        #expect(result == 1.0)

        result = model.toClosure()( [50.0]
        )
        #expect(result == 0.0)
    }

    @Test("Equal comparison with epsilon")
    func testEqual() throws {
        let model = MonteCarloExpressionModel { builder in
            builder[0].equal(builder[1])
        }

        // Exactly equal
        var result = model.toClosure()( [10.0, 10.0]
        )
        #expect(result == 1.0)

        // Very close (within epsilon)
        result = model.toClosure()( [10.0, 10.0 + 1e-11]
        )
        #expect(result == 1.0)

        // Different
        result = model.toClosure()( [10.0, 10.1]
        )
        #expect(result == 0.0)
    }

    // MARK: - Conditional Tests

    @Test("Simple if-else conditional")
    func testSimpleConditional() throws {
        // Model: if revenue > 1000 then revenue * 1.2 else revenue
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let condition = revenue.greaterThan(1000.0)
            let bonus = revenue * 1.2
            return condition.ifElse(then: bonus, else: revenue)
        }

        // Above threshold - should apply bonus
        var result = model.toClosure()( [1500.0]
        )
        #expect(result == 1800.0)  // 1500 * 1.2

        // Below threshold - no bonus
        result = model.toClosure()( [800.0]
        )
        #expect(result == 800.0)
    }

    @Test("Nested conditionals")
    func testNestedConditionals() throws {
        // Model: Tiered bonus system
        // if revenue > 2000: 30% bonus
        // else if revenue > 1000: 20% bonus
        // else: no bonus
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]

            let tier1 = revenue.greaterThan(2000.0)
            let tier1Value = revenue * 1.3

            let tier2 = revenue.greaterThan(1000.0)
            let tier2Value = revenue * 1.2

            // Nested: if (> 2000) then 1.3x else (if (> 1000) then 1.2x else 1x)
            let innerConditional = tier2.ifElse(then: tier2Value, else: revenue)
            return tier1.ifElse(then: tier1Value, else: innerConditional)
        }

        // Tier 1: > 2000
        var result = model.toClosure()( [2500.0]
        )
        #expect(result == 3250.0)  // 2500 * 1.3

        // Tier 2: > 1000 but <= 2000
        result = model.toClosure()( [1500.0]
        )
        #expect(result == 1800.0)  // 1500 * 1.2

        // No bonus: <= 1000
        result = model.toClosure()( [800.0]
        )
        #expect(result == 800.0)
    }

    @Test("Conditional with constants")
    func testConditionalWithConstants() throws {
        // Model: max(profit, 0) using conditional
        let model = MonteCarloExpressionModel { builder in
            let profit = builder[0]
            let isProfitable = profit.greaterThan(0.0)
            return isProfitable.ifElse(then: profit, else: 0.0)
        }

        // Positive profit
        var result = model.toClosure()( [150.0]
        )
        #expect(result == 150.0)

        // Negative profit - clamped to 0
        result = model.toClosure()( [-50.0]
        )
        #expect(result == 0.0)
    }

    // MARK: - Monte Carlo Integration Tests

    @Test("Conditional in Monte Carlo simulation - CPU")
    func testConditionalInMonteCarloCPU() throws {
        // Model: Apply 20% bonus if revenue exceeds threshold
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let threshold = builder[1]

            let exceedsThreshold = revenue.greaterThan(threshold)
            let withBonus = revenue * 1.2

            return exceedsThreshold.ifElse(then: withBonus, else: revenue)
        }

        var simulation = MonteCarloSimulation(
            iterations: 1_000,
            enableGPU: false,  // Force CPU
            expressionModel: model
        )

        simulation.addInput(SimulationInput(
            name: "Revenue",
            distribution: DistributionUniform(900, 1100)  // Centered around threshold
        ))
        simulation.addInput(SimulationInput(
            name: "Threshold",
            distribution: DistributionNormal(1000, 0.1)  // Nearly constant
        ))

        let results = try simulation.run()

        // Verify results make sense
        #expect(results.usedGPU == false)
        #expect(results.statistics.mean > 900 && results.statistics.mean < 1300)
        #expect(results.statistics.min > 0)

        print("✓ Conditional CPU simulation: mean=\(results.statistics.mean)")
    }

    @Test("Conditional in Monte Carlo simulation - GPU")
    func testConditionalInMonteCarloGPU() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        // Model: Capacity-constrained production
        let model = MonteCarloExpressionModel { builder in
            let demand = builder[0]
            let capacity = builder[1]

            let exceedsCapacity = demand.greaterThan(capacity)
            return exceedsCapacity.ifElse(then: capacity, else: demand)
        }

        var simulation = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: true,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(
            name: "Demand",
            distribution: DistributionNormal(1000, 200)
        ))
        simulation.addInput(SimulationInput(
            name: "Capacity",
            distribution: DistributionNormal(1200, 100)
        ))

        let results = try simulation.run()

        // Verify GPU was used
        #expect(results.usedGPU == true, "Should use GPU for 10K iterations")

        // Production should be clamped by capacity
        #expect(results.statistics.mean < 1300)
        #expect(results.statistics.min > 0)

        print("✓ Conditional GPU simulation: usedGPU=\(results.usedGPU), mean=\(results.statistics.mean)")
        #endif
    }

    @Test("GPU vs CPU statistical equivalence with conditionals")
    func testGPUvsCPUEquivalenceConditional() throws {
        #if canImport(Metal)
        guard MonteCarloGPUDevice() != nil else {
            print("⊘ Skipping: Metal unavailable")
            return
        }

        // Model: Progressive tax brackets
        let model = MonteCarloExpressionModel { builder in
            let income = builder[0]

            // 0% tax if income <= 50K
            // 20% tax if 50K < income <= 100K
            // 30% tax if income > 100K

            let bracket1 = income.lessOrEqual(50_000.0)
            let bracket2 = income.lessOrEqual(100_000.0)

            let tax0 = 0.0
            let tax20 = income * 0.2
            let tax30 = income * 0.3

            // Nested conditionals for tax brackets
            let innerCond = bracket2.ifElse(then: tax20, else: tax30)
            return bracket1.ifElse(then: tax0, else: innerCond)
        }

        // GPU simulation
        var gpuSim = MonteCarloSimulation(iterations: 20_000, enableGPU: true, expressionModel: model)
        gpuSim.addInput(SimulationInput(name: "Income", distribution: DistributionUniform(0, 150_000)))
        let gpuResults = try gpuSim.run()

        // CPU simulation
        var cpuSim = MonteCarloSimulation(iterations: 20_000, enableGPU: false, expressionModel: model)
        cpuSim.addInput(SimulationInput(name: "Income", distribution: DistributionUniform(0, 150_000)))
        let cpuResults = try cpuSim.run()

        // Verify execution paths
        #expect(gpuResults.usedGPU == true)
        #expect(cpuResults.usedGPU == false)

        // Compare statistics (within 2% tolerance due to RNG)
        let meanDiff = abs(gpuResults.statistics.mean - cpuResults.statistics.mean) / cpuResults.statistics.mean
        #expect(meanDiff < 0.02, "GPU and CPU means should match within 2%")

        print("✓ GPU vs CPU conditional equivalence:")
        print("  GPU: mean=\(gpuResults.statistics.mean)")
        print("  CPU: mean=\(cpuResults.statistics.mean)")
        print("  Difference: \(meanDiff * 100)%")
        #endif
    }

    // MARK: - Complex Model Tests

    @Test("Multiple comparisons in single model")
    func testMultipleComparisons() throws {
        // Model that counts how many inputs exceed thresholds
        let model = MonteCarloExpressionModel { builder in
            let a = builder[0]
            let b = builder[1]
            let c = builder[2]

            let aHigh = a.greaterThan(100.0)
            let bHigh = b.greaterThan(50.0)
            let cHigh = c.greaterThan(25.0)

            // Sum up the boolean results (1.0 or 0.0)
            return aHigh + bHigh + cHigh
        }

        // All exceed thresholds
        var result = model.toClosure()([150.0, 75.0, 30.0])
        #expect(result == 3.0)

        // Only 2 exceed
        result = model.toClosure()([150.0, 40.0, 30.0])
        #expect(result == 2.0)

        // None exceed
        result = model.toClosure()([50.0, 25.0, 10.0])
        #expect(result == 0.0)
    }

    @Test("Comparison with arithmetic")
    func testComparisonWithArithmetic() throws {
        // Model: Calculate bonus only if profit margin > 20%
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let costs = builder[1]

            let profit = revenue - costs
            let margin = profit / revenue
            let goodMargin = margin.greaterThan(0.2)

            let bonus = profit * 0.1
            return goodMargin.ifElse(then: bonus, else: 0.0)
        }

        // Good margin (30%): should get bonus
        var result = model.toClosure()([1000.0, 700.0])  // 300 profit, 30% margin
        #expect(result == 30.0)  // 10% of 300

        // Poor margin (10%): no bonus
        result = model.toClosure()([1000.0, 900.0])  // 100 profit, 10% margin
        #expect(result == 0.0)
    }
}
