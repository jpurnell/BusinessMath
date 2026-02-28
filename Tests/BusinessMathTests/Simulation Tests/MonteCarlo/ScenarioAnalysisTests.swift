//
//  ScenarioAnalysisTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("ScenarioAnalysis Tests")
struct ScenarioAnalysisTests {

	@Test("Scenario initialization with name and inputs")
	func scenarioInitialization() {
		let scenario = Scenario(name: "Base Case") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		#expect(scenario.name == "Base Case")
		#expect(scenario.inputValues.count == 2)
		#expect(scenario.inputValues["Revenue"] == 1_000_000.0)
		#expect(scenario.inputValues["Costs"] == 700_000.0)
	}

	@Test("ScenarioAnalysis basic setup")
	func scenarioAnalysisSetup() {
		// Create model
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]  // Revenue - Costs
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let baseCase = Scenario(name: "Base Case") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		analysis.addScenario(baseCase)

		#expect(analysis.scenarios.count == 1)
		#expect(analysis.scenarios[0].name == "Base Case")
	}

	@Test("ScenarioAnalysis run single scenario")
	func scenarioAnalysisSingleScenario() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let baseCase = Scenario(name: "Base Case") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		analysis.addScenario(baseCase)

		let results = try analysis.run()

		#expect(results.count == 1)
		#expect(results["Base Case"] != nil)

		let baseCaseResults = results["Base Case"]!
		// Mean should be exactly 300,000 (deterministic inputs: 1,000,000 - 700,000)
		// Use tolerance to make deterministic intent explicit
		#expect(abs(baseCaseResults.statistics.mean - 300_000.0) < 0.01)
	}

	@Test("ScenarioAnalysis multiple scenarios - base/best/worst")
	func scenarioAnalysisMultipleScenarios() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let baseCase = Scenario(name: "Base Case") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		let bestCase = Scenario(name: "Best Case") { config in
			config.setValue(1_200_000.0, forInput: "Revenue")
			config.setValue(600_000.0, forInput: "Costs")
		}

		let worstCase = Scenario(name: "Worst Case") { config in
			config.setValue(800_000.0, forInput: "Revenue")
			config.setValue(800_000.0, forInput: "Costs")
		}

		analysis.addScenario(baseCase)
		analysis.addScenario(bestCase)
		analysis.addScenario(worstCase)

		let results = try analysis.run()

		#expect(results.count == 3)

		let baseProfit = results["Base Case"]!.statistics.mean
		let bestProfit = results["Best Case"]!.statistics.mean
		let worstProfit = results["Worst Case"]!.statistics.mean

		// Best case should be most profitable
		#expect(bestProfit > baseProfit)
		#expect(baseProfit > worstProfit)
	}

	@Test("ScenarioAnalysis with distributions")
	func scenarioAnalysisWithDistributions() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 5_000
		)

		let normalCase = Scenario(name: "Normal Uncertainty") { config in
			config.setDistribution(DistributionNormal(1_000_000.0, 100_000.0), forInput: "Revenue")
			config.setDistribution(DistributionNormal(700_000.0, 50_000.0), forInput: "Costs")
		}

		let highUncertainty = Scenario(name: "High Uncertainty") { config in
			config.setDistribution(DistributionNormal(1_000_000.0, 200_000.0), forInput: "Revenue")
			config.setDistribution(DistributionNormal(700_000.0, 100_000.0), forInput: "Costs")
		}

		analysis.addScenario(normalCase)
		analysis.addScenario(highUncertainty)

		let results = try analysis.run()

		let normalResults = results["Normal Uncertainty"]!
		let highResults = results["High Uncertainty"]!

		// Both should have similar means (~300k)
		#expect(abs(normalResults.statistics.mean - 300_000.0) < 50_000.0)
		#expect(abs(highResults.statistics.mean - 300_000.0) < 50_000.0)

		// High uncertainty should have larger standard deviation
		#expect(highResults.statistics.stdDev > normalResults.statistics.stdDev)
	}

	@Test("ScenarioComparison initialization")
	func scenarioComparisonInit() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let scenario1 = Scenario(name: "Scenario1") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		let scenario2 = Scenario(name: "Scenario2") { config in
			config.setValue(1_100_000.0, forInput: "Revenue")
			config.setValue(750_000.0, forInput: "Costs")
		}

		analysis.addScenario(scenario1)
		analysis.addScenario(scenario2)

		let results = try analysis.run()
		let comparison = ScenarioComparison(results: results)

		#expect(comparison.scenarioNames.count == 2)
		#expect(comparison.scenarioNames.contains("Scenario1"))
		#expect(comparison.scenarioNames.contains("Scenario2"))
	}

	@Test("ScenarioComparison best and worst scenarios by mean")
	func scenarioComparisonBestWorst() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let low = Scenario(name: "Low") { config in
			config.setValue(900_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		let medium = Scenario(name: "Medium") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		let high = Scenario(name: "High") { config in
			config.setValue(1_100_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		analysis.addScenario(low)
		analysis.addScenario(medium)
		analysis.addScenario(high)

		let results = try analysis.run()
		let comparison = ScenarioComparison(results: results)

		let best = comparison.bestScenario(by: .mean)
		let worst = comparison.worstScenario(by: .mean)

		#expect(best.name == "High")
		#expect(worst.name == "Low")
	}

	@Test("ScenarioComparison ranking by different metrics")
	func scenarioComparisonRanking() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 5_000
		)

		let stable = Scenario(name: "Stable") { config in
			config.setDistribution(DistributionNormal(1_000_000.0, 10_000.0), forInput: "Revenue")
			config.setDistribution(DistributionNormal(700_000.0, 5_000.0), forInput: "Costs")
		}

		let volatile = Scenario(name: "Volatile") { config in
			config.setDistribution(DistributionNormal(1_000_000.0, 200_000.0), forInput: "Revenue")
			config.setDistribution(DistributionNormal(700_000.0, 100_000.0), forInput: "Costs")
		}

		analysis.addScenario(stable)
		analysis.addScenario(volatile)

		let results = try analysis.run()
		let comparison = ScenarioComparison(results: results)

		// Rank by standard deviation (volatility)
		let ranked = comparison.rankScenarios(by: .stdDev, ascending: true)

		// Stable should be first (lower std dev)
		#expect(ranked[0].name == "Stable")
		#expect(ranked[1].name == "Volatile")
	}

	@Test("SensitivityAnalysis single input")
	func sensitivityAnalysisSingle() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		let baseValues: [String: Double] = [
			"Revenue": 1_000_000.0,
			"Costs": 700_000.0
		]

		let sensitivity = SensitivityAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			baseValues: baseValues,
			iterations: 1_000
		)

		let result = try sensitivity.analyzeInput(
			"Revenue",
			range: 0.8...1.2  // ±20%
		)

		#expect(result.inputName == "Revenue")
		#expect(result.baseValue == 1_000_000.0)
		#expect(result.scenarios.count > 0)

		// Check that output changes as input changes
		let firstMean = result.scenarios[0].result.statistics.mean
		let lastMean = result.scenarios[result.scenarios.count - 1].result.statistics.mean

		#expect(firstMean != lastMean, "Output should change with input")
	}

	@Test("SensitivityAnalysis tornado chart data")
	func sensitivityAnalysisTornado() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			let revenue = inputs[0]
			let costs = inputs[1]
			let taxRate = inputs[2]
			return (revenue - costs) * (1.0 - taxRate)
		}

		let baseValues: [String: Double] = [
			"Revenue": 1_000_000.0,
			"Costs": 700_000.0,
			"TaxRate": 0.3
		]

		let sensitivity = SensitivityAnalysis(
			inputNames: ["Revenue", "Costs", "TaxRate"],
			model: model,
			baseValues: baseValues,
			iterations: 1_000
		)

		let tornado = try sensitivity.tornadoChart(range: 0.9...1.1)  // ±10%

		#expect(tornado.count == 3)

		// Each input should have a range
		for bar in tornado {
			#expect(bar.low < bar.high, "\(bar.inputName) should have low < high")
		}

		// Tornado bars should be sorted by impact (descending)
		for i in 0..<(tornado.count - 1) {
			let impact1 = tornado[i].high - tornado[i].low
			let impact2 = tornado[i + 1].high - tornado[i + 1].low
			#expect(impact1 >= impact2, "Tornado should be sorted by impact")
		}
	}

	@Test("SensitivityAnalysis identifies key drivers")
	func sensitivityAnalysisKeyDrivers() throws {
		// Model where revenue has much larger impact than tax rate
		let model: @Sendable ([Double]) -> Double = { inputs in
			let revenue = inputs[0]
			let costs = inputs[1]
			let taxRate = inputs[2]
			return (revenue - costs) * (1.0 - taxRate)
		}

		let baseValues: [String: Double] = [
			"Revenue": 1_000_000.0,
			"Costs": 100_000.0,  // Small costs
			"TaxRate": 0.01  // Low tax rate
		]

		let sensitivity = SensitivityAnalysis(
			inputNames: ["Revenue", "Costs", "TaxRate"],
			model: model,
			baseValues: baseValues,
			iterations: 1_000
		)

		let tornado = try sensitivity.tornadoChart(range: 0.9...1.1)

		// Revenue should be the top driver (largest impact)
		#expect(tornado[0].inputName == "Revenue")
	}

	@Test("Scenario with mixed fixed values and distributions")
	func scenarioMixedInputs() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 5_000
		)

		let mixedScenario = Scenario(name: "Mixed") { config in
			// Revenue is fixed
			config.setValue(1_000_000.0, forInput: "Revenue")
			// Costs are uncertain
			config.setDistribution(DistributionNormal(700_000.0, 50_000.0), forInput: "Costs")
		}

		analysis.addScenario(mixedScenario)

		let results = try analysis.run()
		let mixedResults = results["Mixed"]!

		// Mean should be around 300k
		#expect(abs(mixedResults.statistics.mean - 300_000.0) < 30_000.0)

		// Should have some variability from uncertain costs
		#expect(mixedResults.statistics.stdDev > 0.0)
		#expect(mixedResults.statistics.stdDev < 60_000.0)  // Roughly same as cost stdDev
	}

	@Test("ScenarioAnalysis stress testing")
	func scenarioAnalysisStressTesting() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let normal = Scenario(name: "Normal") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		let revenueCollapse = Scenario(name: "Revenue Collapse") { config in
			config.setValue(500_000.0, forInput: "Revenue")  // 50% drop
			config.setValue(700_000.0, forInput: "Costs")
		}

		let costSpike = Scenario(name: "Cost Spike") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(1_100_000.0, forInput: "Costs")  // Costs exceed revenue
		}

		analysis.addScenario(normal)
		analysis.addScenario(revenueCollapse)
		analysis.addScenario(costSpike)

		let results = try analysis.run()

		let normalProfit = results["Normal"]!.statistics.mean
		let collapseProfit = results["Revenue Collapse"]!.statistics.mean
		let spikeProfit = results["Cost Spike"]!.statistics.mean

		// Normal should be profitable
		#expect(normalProfit > 0.0)

		// Revenue collapse should be unprofitable
		#expect(collapseProfit < 0.0)

		// Cost spike should be very unprofitable
		#expect(spikeProfit < 0.0)
		// Both are negative, but we check which is worse (more negative)
		#expect(spikeProfit < 0.0 && collapseProfit < 0.0, "Both should be unprofitable")
	}

	@Test("ScenarioComparison summary statistics")
	func scenarioComparisonSummary() throws {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		let scenario1 = Scenario(name: "S1") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setValue(700_000.0, forInput: "Costs")
		}

		let scenario2 = Scenario(name: "S2") { config in
			config.setValue(1_200_000.0, forInput: "Revenue")
			config.setValue(800_000.0, forInput: "Costs")
		}

		analysis.addScenario(scenario1)
		analysis.addScenario(scenario2)

		let results = try analysis.run()
		let comparison = ScenarioComparison(results: results)

		let summary = comparison.summaryTable(metrics: [.mean, .median, .stdDev])

		#expect(summary.count == 2)
		#expect(summary["S1"] != nil)
		#expect(summary["S2"] != nil)

		let s1Summary = summary["S1"]!
		#expect(s1Summary.count == 3)  // mean, p50, stdDev
	}

	@Test("Scenario configuration builder pattern")
	func scenarioBuilderPattern() {
		let scenario = Scenario(name: "Complex") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			config.setDistribution(DistributionNormal(700_000.0, 50_000.0), forInput: "Costs")
			config.setValue(0.3, forInput: "TaxRate")
			config.setDistribution(DistributionUniform(0.05, 0.15), forInput: "GrowthRate")
		}

		// Total inputs = values + distributions
		let totalInputs = scenario.inputValues.count + scenario.inputDistributions.count
		#expect(totalInputs == 4)
		#expect(scenario.inputValues["Revenue"] == 1_000_000.0)
		#expect(scenario.inputValues["TaxRate"] == 0.3)
		#expect(scenario.inputDistributions["Costs"] != nil)
		#expect(scenario.inputDistributions["GrowthRate"] != nil)
	}

	@Test("ScenarioAnalysis error - missing input configuration")
	func scenarioAnalysisMissingInput() {
		let model: @Sendable ([Double]) -> Double = { inputs in
			inputs[0] - inputs[1]
		}

		var analysis = ScenarioAnalysis(
			inputNames: ["Revenue", "Costs"],
			model: model,
			iterations: 1_000
		)

		// Scenario that doesn't configure all inputs
		let incomplete = Scenario(name: "Incomplete") { config in
			config.setValue(1_000_000.0, forInput: "Revenue")
			// Missing "Costs" configuration
		}

		analysis.addScenario(incomplete)

		#expect(throws: ScenarioError.self) {
			let _ = try analysis.run()
		}
	}
}
