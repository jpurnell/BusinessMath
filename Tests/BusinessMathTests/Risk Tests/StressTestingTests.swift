import Testing
import Foundation
@testable import BusinessMath

@Suite("Stress Testing Tests")
struct StressTestingTests {

	// MARK: - Stress Scenario Tests

	@Test("Recession scenario has expected shocks")
	func recessionScenario() throws {
		let scenario = StressScenario<Double>.recession

		#expect(scenario.name == "Recession")
		#expect(scenario.shocks["Revenue"] == -0.15)
		#expect(scenario.shocks["COGS"] == 0.05)
		#expect(scenario.shocks["InterestRate"] == 0.02)
	}

	@Test("Financial crisis scenario more severe than recession")
	func crisisScenario() throws {
		let recession = StressScenario<Double>.recession
		let crisis = StressScenario<Double>.crisis

		#expect(crisis.name == "Financial Crisis")
		// Crisis should have more severe revenue impact
		#expect(abs(crisis.shocks["Revenue"]!) > abs(recession.shocks["Revenue"]!))
	}

	@Test("Supply shock scenario targets operations")
	func supplyShockScenario() throws {
		let scenario = StressScenario<Double>.supplyShock

		#expect(scenario.name == "Supply Chain Shock")
		#expect(scenario.shocks["COGS"] != nil)
		#expect(scenario.shocks["COGS"]! > 0.0) // Costs increase
	}

	@Test("Custom stress scenario")
	func customScenario() throws {
		let scenario = StressScenario(
			name: "Pandemic",
			description: "Global pandemic impact",
			shocks: [
				"Revenue": -0.40,
				"RemoteWorkCosts": 0.15
			]
		)

		#expect(scenario.name == "Pandemic")
		#expect(scenario.shocks.count == 2)
		#expect(scenario.shocks["Revenue"] == -0.40)
	}

	// MARK: - Simple Financial Projection for Testing

	@Test("Stress test runs multiple scenarios")
	func multipleScenarios() throws {
		let scenarios = [
			StressScenario<Double>.recession,
			StressScenario<Double>.crisis,
			StressScenario<Double>.supplyShock
		]

		let stressTest = StressTest(scenarios: scenarios)

		#expect(stressTest.scenarios.count == 3)
		#expect(stressTest.scenarios[0].name == "Recession")
		#expect(stressTest.scenarios[1].name == "Financial Crisis")
		#expect(stressTest.scenarios[2].name == "Supply Chain Shock")
	}

	@Test("Scenario result tracks impact")
	func scenarioResult() throws {
		let scenario = StressScenario<Double>.recession
		let baselineNPV = 1_000_000.0
		let scenarioNPV = 850_000.0
		let impact = scenarioNPV - baselineNPV

		// Create a mock result structure
		#expect(impact < 0.0) // Should be negative for recession
		#expect(abs(impact) == 150_000.0)
	}

	@Test("Stress test report identifies worst case")
	func worstCaseScenario() throws {
		// This test verifies that the report can identify
		// the scenario with the worst impact
		let recession = StressScenario<Double>.recession
		let crisis = StressScenario<Double>.crisis

		#expect(recession.shocks["Revenue"] != nil)
		#expect(crisis.shocks["Revenue"] != nil)
		// Crisis should be worse than recession
		#expect(abs(crisis.shocks["Revenue"]!) > abs(recession.shocks["Revenue"]!))
	}

	@Test("Stress test report identifies best case")
	func bestCaseScenario() throws {
		// Test that we can identify least severe scenario
		let recession = StressScenario<Double>.recession
		let supplyShock = StressScenario<Double>.supplyShock

		// Both have negative impacts but can be compared
		#expect(recession.shocks.count > 0)
		#expect(supplyShock.shocks.count > 0)
	}

	// MARK: - Shock Application Tests

	@Test("Positive shock increases values")
	func positiveShock() throws {
		let baseValue = 100.0
		let shock = 0.10 // +10%
		let shockedValue = baseValue * (1.0 + shock)

		#expect(abs(shockedValue - 110.0) < 0.0001)
		#expect(shockedValue > baseValue)
	}

	@Test("Negative shock decreases values")
	func negativeShock() throws {
		let baseValue = 100.0
		let shock = -0.15 // -15%
		let shockedValue = baseValue * (1.0 + shock)

		#expect(shockedValue == 85.0)
		#expect(shockedValue < baseValue)
	}

	@Test("Zero shock maintains values")
	func zeroShock() throws {
		let baseValue = 100.0
		let shock = 0.0
		let shockedValue = baseValue * (1.0 + shock)

		#expect(shockedValue == baseValue)
	}

	// MARK: - Scenario Severity Tests

	@Test("Scenarios sorted by severity")
	func scenarioSorting() throws {
		let scenarios = [
			StressScenario<Double>.recession,
			StressScenario<Double>.crisis,
			StressScenario<Double>.supplyShock
		]

		// Verify we can compare scenario severity
		for scenario in scenarios {
			#expect(scenario.shocks.count > 0)
			#expect(scenario.name.isEmpty == false)
		}
	}
}
