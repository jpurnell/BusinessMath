//
//  ScenarioAnalysisBuilderTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMathDSL

/// Tests for Scenario Analysis Result Builder (DSL)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Scenario Analysis Builder Tests (DSL)")
struct ScenarioAnalysisBuilderTests {

    // MARK: - Basic Scenario Tests

    @Test("Single scenario with base case")
    func singleScenario() async throws {
        let analysis = ScenarioAnalysis {
            Scenario("Base Case") {
                Parameter("revenue", value: 1_000_000)
                Parameter("growth", value: 0.15)
                Parameter("expenses", value: 0.60)
            }
        }

        #expect(analysis.scenarios.count == 1)
        #expect(analysis.scenarios[0].name == "Base Case")
        #expect(analysis.scenarios[0].parameters["revenue"] == 1_000_000)
        #expect(analysis.scenarios[0].parameters["growth"] == 0.15)
        #expect(analysis.scenarios[0].parameters["expenses"] == 0.60)
    }

    @Test("Multiple named scenarios")
    func multipleScenarios() async throws {
        let analysis = ScenarioAnalysis {
            Scenario("Conservative") {
                Parameter("revenue", value: 800_000)
                Parameter("growth", value: 0.05)
            }
            Scenario("Base Case") {
                Parameter("revenue", value: 1_000_000)
                Parameter("growth", value: 0.15)
            }
            Scenario("Aggressive") {
                Parameter("revenue", value: 1_500_000)
                Parameter("growth", value: 0.30)
            }
        }

        #expect(analysis.scenarios.count == 3)
        #expect(analysis.scenarios[0].name == "Conservative")
        #expect(analysis.scenarios[1].name == "Base Case")
        #expect(analysis.scenarios[2].name == "Aggressive")
    }

    // MARK: - Parameter Variation Tests

    @Test("Single parameter variation")
    func singleParameterVariation() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
                Parameter("expenses", value: 0.60)
            }
            Vary("growth", from: 0.05, to: 0.25, steps: 5)
        }

        // Should generate 5 scenarios with growth from 5% to 25%
        #expect(analysis.scenarios.count == 5)

        // Verify growth values (with tolerance for floating point)
        let growthValues = analysis.scenarios.map { $0.parameters["growth"] ?? 0 }
        #expect(abs(growthValues[0] - 0.05) < 0.0001)
        #expect(abs(growthValues[1] - 0.10) < 0.0001)
        #expect(abs(growthValues[2] - 0.15) < 0.0001)
        #expect(abs(growthValues[3] - 0.20) < 0.0001)
        #expect(abs(growthValues[4] - 0.25) < 0.0001)

        // All should have same revenue and expenses
        for scenario in analysis.scenarios {
            #expect(scenario.parameters["revenue"] == 1_000_000)
            #expect(scenario.parameters["expenses"] == 0.60)
        }
    }

    @Test("Multiple parameter variations")
    func multipleParameterVariations() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
            }
            Vary("growth", from: 0.10, to: 0.20, steps: 3)
            Vary("expenses", from: 0.50, to: 0.70, steps: 3)
        }

        // 3 growth × 3 expenses = 9 scenarios
        #expect(analysis.scenarios.count == 9)

        // Verify we have all combinations
        let growthValues = Set(analysis.scenarios.map { $0.parameters["growth"] ?? 0 })
        let expenseValues = Set(analysis.scenarios.map { $0.parameters["expenses"] ?? 0 })

        #expect(growthValues.count == 3)
        #expect(expenseValues.count == 3)
    }

    @Test("Parameter variation with specific values")
    func parameterVariationWithValues() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
            }
            Vary("taxRate", values: [0.15, 0.21, 0.25, 0.30])
        }

        #expect(analysis.scenarios.count == 4)

        let taxRates = analysis.scenarios.map { $0.parameters["taxRate"] ?? 0 }
        #expect(taxRates == [0.15, 0.21, 0.25, 0.30])
    }

    // MARK: - Sensitivity Analysis Tests

    @Test("Sensitivity analysis on single parameter")
    func sensitivityAnalysis() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
                Parameter("expenses", value: 0.60)
                Parameter("taxRate", value: 0.21)
            }
            Sensitivity(on: "revenue", range: 0.80...1.20, steps: 5)
        }

        // Should vary revenue from 80% to 120% of base (800k to 1.2M)
        #expect(analysis.scenarios.count == 5)

        let revenueValues = analysis.scenarios.map { $0.parameters["revenue"] ?? 0 }
        #expect(abs(revenueValues[0] - 800_000) < 1)
        #expect(abs(revenueValues[2] - 1_000_000) < 1)  // Middle is base
        #expect(abs(revenueValues[4] - 1_200_000) < 1)
    }

    @Test("Tornado chart data generation")
    func tornadoChartData() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
                Parameter("expenses", value: 0.60)
                Parameter("growth", value: 0.15)
            }
            TornadoChart {
                Vary("revenue", by: 0.20)     // ±20%
                Vary("expenses", by: 0.10)    // ±10%
                Vary("growth", by: 0.05)      // ±5 percentage points
            }
        }

        // Each parameter gets low/base/high = 3 scenarios per parameter × 3 parameters = 9
        #expect(analysis.scenarios.count == 9)

        // Verify revenue variations
        let revenueScenarios = analysis.scenarios.filter {
            $0.name.contains("revenue")
        }
        #expect(revenueScenarios.count == 3)
    }

    // MARK: - Scenario Comparison Tests

    @Test("Compare scenario outcomes")
    func compareScenarios() async throws {
        let analysis = ScenarioAnalysis {
            Scenario("Conservative") {
                Parameter("revenue", value: 800_000)
                Parameter("growth", value: 0.05)
            }
            Scenario("Aggressive") {
                Parameter("revenue", value: 1_500_000)
                Parameter("growth", value: 0.30)
            }
        }

        // Define evaluation function
        let evaluate: (Scenario) -> Double = { scenario in
            let revenue = scenario.parameters["revenue"] ?? 0
            let growth = scenario.parameters["growth"] ?? 0
            return revenue * (1 + growth)  // Year 1 revenue
        }

        let results = analysis.evaluate(with: evaluate)

        #expect(results.count == 2)
        #expect(results["Conservative"] == 840_000)      // 800k * 1.05
        #expect(results["Aggressive"] == 1_950_000)      // 1.5M * 1.30
    }

    @Test("Find best and worst scenarios")
    func findBestWorstScenarios() async throws {
        let analysis = ScenarioAnalysis {
            Scenario("Low") {
                Parameter("revenue", value: 500_000)
            }
            Scenario("Medium") {
                Parameter("revenue", value: 1_000_000)
            }
            Scenario("High") {
                Parameter("revenue", value: 2_000_000)
            }
        }

        let evaluate: (Scenario) -> Double = { scenario in
            scenario.parameters["revenue"] ?? 0
        }

        let best = analysis.best(by: evaluate)
        let worst = analysis.worst(by: evaluate)

        #expect(best?.name == "High")
        #expect(worst?.name == "Low")
    }

    // MARK: - Integration with Cash Flow Model Tests

    @Test("Scenario analysis with cash flow model")
    func scenarioWithCashFlowModel() async throws {
        let analysis = ScenarioAnalysis {
            Scenario("Conservative") {
                Parameter("baseRevenue", value: 800_000)
                Parameter("growthRate", value: 0.05)
                Parameter("expenseRate", value: 0.65)
            }
            Scenario("Aggressive") {
                Parameter("baseRevenue", value: 1_500_000)
                Parameter("growthRate", value: 0.25)
                Parameter("expenseRate", value: 0.55)
            }
        }

        // Evaluate each scenario using CashFlowModel
        let evaluateYear1NetIncome: (Scenario) -> Double = { scenario in
            let projection = CashFlowModel(
                revenue: Revenue {
                    Base(scenario.parameters["baseRevenue"] ?? 0)
                    GrowthRate(scenario.parameters["growthRate"] ?? 0)
                },
                expenses: Expenses {
                    Variable(percentage: scenario.parameters["expenseRate"] ?? 0)
                },
                taxes: Taxes {
                    CorporateRate(0.21)
                }
            )
            return projection.calculate(year: 1).netIncome
        }

        let results = analysis.evaluate(with: evaluateYear1NetIncome)

        // Conservative: 800k * 0.35 * 0.79 = 221,200
        #expect(abs(results["Conservative"]! - 221_200) < 1)

        // Aggressive: 1.5M * 0.45 * 0.79 = 533,250
        #expect(abs(results["Aggressive"]! - 533_250) < 1)
    }

    @Test("Monte Carlo scenario generation")
    func monteCarloScenarios() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
            }
            MonteCarlo(trials: 100) {
                RandomParameter("growth", distribution: .normal(mean: 0.15, stdDev: 0.05))
                RandomParameter("expenses", distribution: .uniform(min: 0.50, max: 0.70))
            }
        }

        // Should generate 100 random scenarios
        #expect(analysis.scenarios.count == 100)

        // All should have base revenue
        for scenario in analysis.scenarios {
            #expect(scenario.parameters["revenue"] == 1_000_000)
        }

        // Growth and expenses should vary
        let growthValues = analysis.scenarios.map { $0.parameters["growth"] ?? 0 }
        let expenseValues = analysis.scenarios.map { $0.parameters["expenses"] ?? 0 }

        #expect(Set(growthValues).count > 1)
        #expect(Set(expenseValues).count > 1)

        // Check growth is roughly normal around 0.15
        let meanGrowth = growthValues.reduce(0, +) / Double(growthValues.count)
        #expect(abs(meanGrowth - 0.15) < 0.02)  // Within 2%

        // Check expenses are within uniform range
        for expense in expenseValues {
            #expect(expense >= 0.50)
            #expect(expense <= 0.70)
        }
    }

    // MARK: - Statistical Analysis Tests

    @Test("Calculate scenario statistics")
    func scenarioStatistics() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("expenses", value: 0.60)
            }
            Vary("revenue", from: 800_000, to: 1_200_000, steps: 5)
        }

        let evaluate: (Scenario) -> Double = { scenario in
            let revenue = scenario.parameters["revenue"] ?? 0
            return revenue * 0.20  // 20% net margin
        }

        let stats = analysis.statistics(for: evaluate)

        #expect(stats.mean == 200_000)      // Mean of (160k + 180k + 200k + 220k + 240k)
        #expect(stats.min == 160_000)
        #expect(stats.max == 240_000)
        #expect(stats.median == 200_000)
        #expect(stats.stdDev > 0)
    }

    @Test("Percentile analysis")
    func percentileAnalysis() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("expenses", value: 0.60)
            }
            Vary("revenue", from: 100_000, to: 1_000_000, steps: 100)
        }

        let evaluate: (Scenario) -> Double = { scenario in
            scenario.parameters["revenue"] ?? 0
        }

        let p10 = analysis.percentile(10, for: evaluate)
        let p50 = analysis.percentile(50, for: evaluate)
        let p90 = analysis.percentile(90, for: evaluate)

        #expect(p10 < p50)
        #expect(p50 < p90)
        #expect(abs(p50 - 550_000) < 10_000)  // Median around middle
    }

    // MARK: - Edge Cases

    @Test("Empty scenario analysis")
    func emptyScenarioAnalysis() async throws {
        let analysis = ScenarioAnalysis {}

        #expect(analysis.scenarios.isEmpty)
    }

    @Test("Scenario with no parameters")
    func scenarioWithNoParameters() async throws {
        let analysis = ScenarioAnalysis {
            Scenario("Empty") {}
        }

        #expect(analysis.scenarios.count == 1)
        #expect(analysis.scenarios[0].parameters.isEmpty)
    }

    @Test("Zero steps in variation")
    func zeroStepsVariation() async throws {
        let analysis = ScenarioAnalysis {
            BaseScenario {
                Parameter("revenue", value: 1_000_000)
            }
            Vary("growth", from: 0.10, to: 0.20, steps: 1)
        }

        // Single step should use the 'from' value
        #expect(analysis.scenarios.count == 1)
        #expect(analysis.scenarios[0].parameters["growth"] == 0.10)
    }
}
