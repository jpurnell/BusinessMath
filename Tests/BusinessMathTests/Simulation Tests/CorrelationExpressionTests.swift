import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

/// Tests for correlation support with expression models
///
/// Validates that expression models work correctly with correlated inputs
/// using the Iman-Conover rank correlation method.
@Suite("Correlation with Expression Models")
struct CorrelationExpressionTests {

    // MARK: - Basic Correlation Tests

    @Test("Set correlation matrix for expression model")
    func testSetCorrelationMatrix() throws {
        let model = MonteCarloExpressionModel { builder in
            builder[0] - builder[1]
        }

        var simulation = MonteCarloSimulation(
            iterations: 1_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))

        // Set positive correlation
        try simulation.setCorrelationMatrix([
            [1.0, 0.7],
            [0.7, 1.0]
        ])

        // Should not throw
        let results = try simulation.run()
        #expect(results.usedGPU == false, "Correlation forces CPU execution")
        #expect(results.statistics.mean.isFinite)
    }

    @Test("Correlation matrix validation - dimension mismatch")
    func testCorrelationDimensionMismatch() throws {
        let model = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        var simulation = MonteCarloSimulation(
            iterations: 1_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))

        // Try to set 3x3 matrix for 2 inputs
        #expect(throws: SimulationError.self) {
            try simulation.setCorrelationMatrix([
                [1.0, 0.5, 0.3],
                [0.5, 1.0, 0.2],
                [0.3, 0.2, 1.0]
            ])
        }
    }

    @Test("Correlation matrix validation - invalid diagonal")
    func testInvalidDiagonal() throws {
        let model = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        var simulation = MonteCarloSimulation(
            iterations: 1_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))

        // Diagonal must be 1.0
        #expect(throws: SimulationError.self) {
            try simulation.setCorrelationMatrix([
                [0.9, 0.5],  // Invalid diagonal
                [0.5, 1.0]
            ])
        }
    }

    // MARK: - Statistical Validation Tests

    @Test("Positive correlation increases variance")
    func testPositiveCorrelationVariance() throws {
        // Model: A + B
        // With positive correlation, variance of sum should be higher than independent case
        let model = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        // Independent case
        var independentSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        independentSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        independentSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))
        let independentResults = try independentSim.run()

        // Correlated case (positive correlation)
        var correlatedSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        correlatedSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        correlatedSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))
        try correlatedSim.setCorrelationMatrix([
            [1.0, 0.8],  // Strong positive correlation
            [0.8, 1.0]
        ])
        let correlatedResults = try correlatedSim.run()

        // Means should be similar
        let meanDiff = abs(correlatedResults.statistics.mean - independentResults.statistics.mean)
        #expect(meanDiff < 2.0, "Means should be similar")

        // Variance should be higher with positive correlation
        // Var(A+B) = Var(A) + Var(B) + 2*Cov(A,B)
        // With correlation, Cov(A,B) > 0, so variance increases
        #expect(correlatedResults.statistics.stdDev > independentResults.statistics.stdDev,
                "Positive correlation should increase variance")

        print("✓ Positive correlation variance:")
        print("  Independent stdDev: \(independentResults.statistics.stdDev)")
        print("  Correlated stdDev: \(correlatedResults.statistics.stdDev)")
        print("  Ratio: \(correlatedResults.statistics.stdDev / independentResults.statistics.stdDev)")
    }

    @Test("Negative correlation decreases variance")
    func testNegativeCorrelationVariance() throws {
        // Model: A + B
        // With negative correlation, variance of sum should be lower
        let model = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        // Independent case
        var independentSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        independentSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        independentSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))
        let independentResults = try independentSim.run()

        // Correlated case (negative correlation)
        var correlatedSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        correlatedSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        correlatedSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))
        try correlatedSim.setCorrelationMatrix([
            [1.0, -0.8],  // Strong negative correlation
            [-0.8, 1.0]
        ])
        let correlatedResults = try correlatedSim.run()

        // Variance should be lower with negative correlation
        // Var(A+B) = Var(A) + Var(B) + 2*Cov(A,B)
        // With negative correlation, Cov(A,B) < 0, so variance decreases
        #expect(correlatedResults.statistics.stdDev < independentResults.statistics.stdDev,
                "Negative correlation should decrease variance")

        print("✓ Negative correlation variance:")
        print("  Independent stdDev: \(independentResults.statistics.stdDev)")
        print("  Correlated stdDev: \(correlatedResults.statistics.stdDev)")
        print("  Ratio: \(correlatedResults.statistics.stdDev / independentResults.statistics.stdDev)")
    }

    // MARK: - Financial Model Tests

    @Test("Correlated revenue and costs financial model")
    func testCorrelatedFinancialModel() throws {
        // Model: Profit = Revenue - Costs
        // Revenue and costs tend to move together (both high in good times, low in bad times)
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let costs = builder[1]
            return revenue - costs
        }

        var simulation = MonteCarloSimulation(
            iterations: 20_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(1_000_000, 100_000)))
        simulation.addInput(SimulationInput(name: "Costs", distribution: DistributionNormal(700_000, 50_000)))

        // Revenue and costs are positively correlated (0.6)
        // When revenue is high, costs also tend to be high
        try simulation.setCorrelationMatrix([
            [1.0, 0.6],
            [0.6, 1.0]
        ])

        let results = try simulation.run()

        // Verify execution on CPU
        #expect(results.usedGPU == false)

        // Expected profit around 300K
        #expect(results.statistics.mean > 250_000 && results.statistics.mean < 350_000)

        // Calculate risk of loss
        let riskOfLoss = results.probabilityBelow(0)
        #expect(riskOfLoss < 0.02, "Risk of loss should be low")

        print("✓ Correlated financial model:")
        print("  Mean profit: $\(Int(results.statistics.mean))")
        print("  StdDev: $\(Int(results.statistics.stdDev))")
        print("  Risk of loss: \(riskOfLoss * 100)%")
    }

    @Test("Three-variable correlation")
    func testThreeVariableCorrelation() throws {
        // Model: Production = min(Demand, min(Capacity, Materials))
        // All three variables are correlated with market conditions
        let model = MonteCarloExpressionModel { builder in
            let demand = builder[0]
            let capacity = builder[1]
            let materials = builder[2]

            // min(demand, capacity, materials)
            let minCapMat = capacity.min(materials)
            return demand.min(minCapMat)
        }

        var simulation = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "Demand", distribution: DistributionNormal(1000, 100)))
        simulation.addInput(SimulationInput(name: "Capacity", distribution: DistributionNormal(1200, 150)))
        simulation.addInput(SimulationInput(name: "Materials", distribution: DistributionNormal(1100, 120)))

        // All three are moderately correlated with market conditions
        try simulation.setCorrelationMatrix([
            [1.0, 0.5, 0.4],  // Demand correlates with capacity and materials
            [0.5, 1.0, 0.6],  // Capacity correlates with materials
            [0.4, 0.6, 1.0]
        ])

        let results = try simulation.run()

        #expect(results.usedGPU == false)
        #expect(results.statistics.mean > 800 && results.statistics.mean < 1200)
        #expect(results.statistics.min > 0)

        print("✓ Three-variable correlation:")
        print("  Mean production: \(Int(results.statistics.mean))")
        print("  P5-P95: [\(Int(results.percentiles.p5)), \(Int(results.percentiles.p95))]")
    }

    // MARK: - Correlation with Conditional Expressions

    @Test("Correlation with conditional expressions")
    func testCorrelationWithConditionals() throws {
        // Model: Apply bonus if revenue exceeds threshold
        // Revenue and threshold are negatively correlated (high threshold in bad times)
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let threshold = builder[1]

            let exceedsThreshold = revenue.greaterThan(threshold)
            let withBonus = revenue * 1.2
            return exceedsThreshold.ifElse(then: withBonus, else: revenue)
        }

        var simulation = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(1000, 150)))
        simulation.addInput(SimulationInput(name: "Threshold", distribution: DistributionNormal(900, 100)))

        // Revenue and threshold are negatively correlated
        // When revenue is high, threshold tends to be lower (easier to get bonus)
        try simulation.setCorrelationMatrix([
            [1.0, -0.4],
            [-0.4, 1.0]
        ])

        let results = try simulation.run()

        #expect(results.usedGPU == false)
        #expect(results.statistics.mean > 1000 && results.statistics.mean < 1300)

        print("✓ Correlation with conditionals:")
        print("  Mean outcome: \(Int(results.statistics.mean))")
        print("  StdDev: \(Int(results.statistics.stdDev))")
    }

    // MARK: - Edge Cases

    @Test("Perfect positive correlation")
    func testPerfectPositiveCorrelation() throws {
        // Model: A - B with perfect positive correlation
        // When A and B move together perfectly, variance should be minimized
        let model = MonteCarloExpressionModel { builder in
            builder[0] - builder[1]
        }

        var simulation = MonteCarloSimulation(
            iterations: 5_000,
            enableGPU: false,
            expressionModel: model
        )

        simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))

        // Perfect positive correlation
        try simulation.setCorrelationMatrix([
            [1.0, 0.99],  // Nearly perfect (1.0 would make matrix singular)
            [0.99, 1.0]
        ])

        let results = try simulation.run()

        // With perfect correlation: Var(A-B) ≈ Var(A) + Var(B) - 2*sqrt(Var(A)*Var(B))
        // Should be very small
        #expect(results.statistics.stdDev < 3.0, "StdDev should be very small with perfect correlation")

        print("✓ Perfect positive correlation:")
        print("  StdDev: \(results.statistics.stdDev) (expected < 3)")
    }

    @Test("Zero correlation behaves like independent")
    func testZeroCorrelation() throws {
        let model = MonteCarloExpressionModel { builder in
            builder[0] + builder[1]
        }

        // Independent case
        var independentSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        independentSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        independentSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))
        let independentResults = try independentSim.run()

        // Zero correlation case
        var zeroCorSim = MonteCarloSimulation(
            iterations: 10_000,
            enableGPU: false,
            expressionModel: model
        )
        zeroCorSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 10)))
        zeroCorSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 10)))
        try zeroCorSim.setCorrelationMatrix([
            [1.0, 0.0],  // Zero correlation = independent
            [0.0, 1.0]
        ])
        let zeroCorResults = try zeroCorSim.run()

        // Results should be very similar
        let meanDiff = abs(zeroCorResults.statistics.mean - independentResults.statistics.mean)
        let stdDevDiff = abs(zeroCorResults.statistics.stdDev - independentResults.statistics.stdDev)

        #expect(meanDiff < 1.0, "Means should be nearly identical")
        #expect(stdDevDiff < 0.5, "StdDevs should be nearly identical")

        print("✓ Zero correlation vs independent:")
        print("  Mean diff: \(meanDiff)")
        print("  StdDev diff: \(stdDevDiff)")
    }
}
