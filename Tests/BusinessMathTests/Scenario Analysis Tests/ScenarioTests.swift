//
//  ScenarioTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Financial Scenario Tests")
struct FinancialScenarioTests {

	// MARK: - Test Helpers

	private func createTestPeriods() -> [Period] {
		return [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]
	}

	// MARK: - Basic Creation Tests

	@Test("Scenario creation with name and description")
	func scenarioBasicCreation() {
		let scenario = FinancialScenario(
			name: "Base Case",
			description: "Conservative growth scenario with stable margins"
		)

		#expect(scenario.name == "Base Case")
		#expect(scenario.description == "Conservative growth scenario with stable margins")
		#expect(scenario.driverOverrides.isEmpty)
		#expect(scenario.assumptions.isEmpty)
	}

	@Test("Scenario with driver overrides")
	func scenarioWithDriverOverrides() {
		let optimisticPrice = DeterministicDriver(name: "Price", value: 120.0)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Price"] = AnyDriver(optimisticPrice)

		let scenario = FinancialScenario(
			name: "Optimistic",
			description: "Higher pricing scenario",
			driverOverrides: overrides
		)

		#expect(scenario.driverOverrides.count == 1)
		#expect(scenario.driverOverrides["Price"] != nil)

		// Verify the override driver returns expected value
		let period = Period.quarter(year: 2025, quarter: 1)
		let overrideValue = scenario.driverOverrides["Price"]?.sample(for: period)
		#expect(overrideValue == 120.0)
	}

	@Test("Scenario with multiple driver overrides")
	func scenarioWithMultipleOverrides() {
		let highPrice = DeterministicDriver(name: "Price", value: 150.0)
		let lowVolume = DeterministicDriver(name: "Volume", value: 800.0)
		let highCost = DeterministicDriver(name: "Unit Cost", value: 60.0)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Price"] = AnyDriver(highPrice)
		overrides["Volume"] = AnyDriver(lowVolume)
		overrides["Unit Cost"] = AnyDriver(highCost)

		let scenario = FinancialScenario(
			name: "Worst Case",
			description: "High costs, low volume, and pricing pressure",
			driverOverrides: overrides
		)

		#expect(scenario.driverOverrides.count == 3)
		#expect(scenario.driverOverrides["Price"] != nil)
		#expect(scenario.driverOverrides["Volume"] != nil)
		#expect(scenario.driverOverrides["Unit Cost"] != nil)
	}

	@Test("Scenario with assumptions")
	func scenarioWithAssumptions() {
		var assumptions: [String: String] = [:]
		assumptions["Market Growth"] = "5% annual growth"
		assumptions["Competition"] = "Two new competitors enter market"
		assumptions["Economy"] = "Stable GDP growth"

		let scenario = FinancialScenario(
			name: "Market Expansion",
			description: "Growing market with increased competition",
			assumptions: assumptions
		)

		#expect(scenario.assumptions.count == 3)
		#expect(scenario.assumptions["Market Growth"] == "5% annual growth")
		#expect(scenario.assumptions["Competition"] == "Two new competitors enter market")
		#expect(scenario.assumptions["Economy"] == "Stable GDP growth")
	}

	@Test("Scenario with both overrides and assumptions")
	func scenarioComplete() {
		let optimisticVolume = DeterministicDriver(name: "Volume", value: 1200.0)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Volume"] = AnyDriver(optimisticVolume)

		var assumptions: [String: String] = [:]
		assumptions["Market Conditions"] = "Strong demand due to new regulations"
		assumptions["Sales Strategy"] = "Aggressive marketing campaign"

		let scenario = FinancialScenario(
			name: "Best Case",
			description: "Favorable market conditions with strong execution",
			driverOverrides: overrides,
			assumptions: assumptions
		)

		#expect(scenario.name == "Best Case")
		#expect(scenario.driverOverrides.count == 1)
		#expect(scenario.assumptions.count == 2)
	}

	// MARK: - Driver Override Tests

	@Test("Override driver returns correct value")
	func overrideDriverValue() {
		let periods = createTestPeriods()
		let driver = DeterministicDriver(name: "Revenue Growth", value: 0.15)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue Growth"] = AnyDriver(driver)

		let scenario = FinancialScenario(
			name: "High Growth",
			description: "15% revenue growth scenario",
			driverOverrides: overrides
		)

		// Test that override returns same value for all periods
		for period in periods {
			let value = scenario.driverOverrides["Revenue Growth"]?.sample(for: period)
			#expect(value == 0.15)
		}
	}

	@Test("Override with probabilistic driver")
	func overrideWithProbabilisticDriver() {
		let period = Period.quarter(year: 2025, quarter: 1)
		let uncertain = ProbabilisticDriver<Double>(
			name: "Sales Volume",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Sales Volume"] = AnyDriver(uncertain)

		let scenario = FinancialScenario(
			name: "Uncertain Volume",
			description: "Volume uncertainty due to market volatility",
			driverOverrides: overrides
		)

		// Sample multiple times to verify randomness
		var samples: [Double] = []
		for _ in 0..<100 {
			if let value = scenario.driverOverrides["Sales Volume"]?.sample(for: period) {
				samples.append(value)
			}
		}

		// Verify we got samples
		#expect(samples.count == 100)

		// Verify statistical properties (approximate)
		let sampleMean = samples.reduce(0.0, +) / Double(samples.count)
		#expect(abs(sampleMean - 1000.0) < 50.0)  // Within 50 of expected mean

		// Verify variance exists (not all same value)
		let allSame = samples.allSatisfy { $0 == samples[0] }
		#expect(!allSame)
	}

	// MARK: - Scenario Comparison Tests

	@Test("Different scenarios have different characteristics")
	func scenarioComparison() {
		// Base case
		let baseOverrides: [String: AnyDriver<Double>] = [
			"Price": AnyDriver(DeterministicDriver(name: "Price", value: 100.0)),
			"Volume": AnyDriver(DeterministicDriver(name: "Volume", value: 1000.0))
		]
		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Expected case",
			driverOverrides: baseOverrides
		)

		// Optimistic case
		let optimisticOverrides: [String: AnyDriver<Double>] = [
			"Price": AnyDriver(DeterministicDriver(name: "Price", value: 120.0)),
			"Volume": AnyDriver(DeterministicDriver(name: "Volume", value: 1200.0))
		]
		let optimisticScenario = FinancialScenario(
			name: "Optimistic",
			description: "Best case",
			driverOverrides: optimisticOverrides
		)

		// Pessimistic case
		let pessimisticOverrides: [String: AnyDriver<Double>] = [
			"Price": AnyDriver(DeterministicDriver(name: "Price", value: 90.0)),
			"Volume": AnyDriver(DeterministicDriver(name: "Volume", value: 800.0))
		]
		let pessimisticScenario = FinancialScenario(
			name: "Pessimistic",
			description: "Worst case",
			driverOverrides: pessimisticOverrides
		)

		let period = Period.quarter(year: 2025, quarter: 1)

		// Verify each scenario has different driver values
		let basePrice = baseScenario.driverOverrides["Price"]?.sample(for: period)
		let optimisticPrice = optimisticScenario.driverOverrides["Price"]?.sample(for: period)
		let pessimisticPrice = pessimisticScenario.driverOverrides["Price"]?.sample(for: period)

		#expect(basePrice == 100.0)
		#expect(optimisticPrice == 120.0)
		#expect(pessimisticPrice == 90.0)

		// Verify ordering
		#expect(pessimisticPrice! < basePrice!)
		#expect(basePrice! < optimisticPrice!)
	}

	// MARK: - Edge Cases

	@Test("Empty scenario is valid")
	func emptyScenario() {
		let scenario = FinancialScenario(
			name: "Empty",
			description: "No overrides or assumptions"
		)

		#expect(scenario.driverOverrides.isEmpty)
		#expect(scenario.assumptions.isEmpty)
		#expect(!scenario.name.isEmpty)
		#expect(!scenario.description.isEmpty)
	}

	@Test("Scenario with empty name")
	func scenarioWithEmptyName() {
		let scenario = FinancialScenario(
			name: "",
			description: "This has an empty name"
		)

		#expect(scenario.name.isEmpty)
		#expect(!scenario.description.isEmpty)
	}
}
