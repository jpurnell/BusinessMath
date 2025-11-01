//
//  StressTesting.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - StressScenario

/// A stress testing scenario with defined shocks to drivers.
///
/// `StressScenario` defines a specific stress scenario (e.g., recession, crisis)
/// with shocks applied to various business drivers. Shocks are expressed as
/// proportional changes (e.g., -0.15 = -15% change).
///
/// ## Usage
///
/// ```swift
/// // Use pre-defined scenario
/// let recession = StressScenario<Double>.recession
///
/// // Create custom scenario
/// let pandemic = StressScenario(
///     name: "Pandemic",
///     description: "Global pandemic impact",
///     shocks: [
///         "Revenue": -0.40,
///         "RemoteWorkCosts": 0.15
///     ]
/// )
/// ```
public struct StressScenario<T: Real & Sendable>: Sendable {
	/// Name of the scenario.
	public let name: String

	/// Description of the scenario.
	public let description: String

	/// Shocks to apply: driver name -> proportional change.
	public let shocks: [String: T]

	public init(name: String, description: String, shocks: [String: T]) {
		self.name = name
		self.description = description
		self.shocks = shocks
	}

	// MARK: - Pre-defined Scenarios

	/// Economic recession scenario.
	public static var recession: StressScenario<T> {
		StressScenario(
			name: "Recession",
			description: "Economic recession scenario",
			shocks: [
				"Revenue": T(-15) / T(100),      // -15%
				"COGS": T(5) / T(100),            // +5%
				"InterestRate": T(2) / T(100)     // +2% points
			]
		)
	}

	/// Severe financial crisis scenario (2008-style).
	public static var crisis: StressScenario<T> {
		StressScenario(
			name: "Financial Crisis",
			description: "Severe financial crisis (2008-style)",
			shocks: [
				"Revenue": T(-30) / T(100),
				"COGS": T(10) / T(100),
				"InterestRate": T(5) / T(100),
				"CustomerChurn": T(20) / T(100)
			]
		)
	}

	/// Major supply chain disruption scenario.
	public static var supplyShock: StressScenario<T> {
		StressScenario(
			name: "Supply Chain Shock",
			description: "Major supply chain disruption",
			shocks: [
				"COGS": T(25) / T(100),
				"DeliveryTime": T(50) / T(100),
				"InventoryLevel": T(-30) / T(100)
			]
		)
	}
}

// MARK: - StressTest

/// Stress testing framework for running multiple scenarios.
///
/// `StressTest` applies defined scenarios to a baseline and evaluates
/// the impact on key metrics.
///
/// ## Usage
///
/// ```swift
/// let scenarios = [
///     StressScenario<Double>.recession,
///     StressScenario<Double>.crisis
/// ]
///
/// let stressTest = StressTest(scenarios: scenarios)
/// ```
public struct StressTest<T: Real & Sendable>: Sendable {
	/// Scenarios to test.
	public let scenarios: [StressScenario<T>]

	public init(scenarios: [StressScenario<T>]) {
		self.scenarios = scenarios
	}
}

// MARK: - ScenarioResult

/// Result of applying a stress scenario.
public struct ScenarioResult<T: Real & Sendable>: Sendable {
	/// The scenario that was applied.
	public let scenario: StressScenario<T>

	/// Baseline NPV before shock.
	public let baselineNPV: T

	/// Scenario NPV after shock.
	public let scenarioNPV: T

	/// Impact (scenario - baseline).
	public let impact: T

	public init(
		scenario: StressScenario<T>,
		baselineNPV: T,
		scenarioNPV: T,
		impact: T
	) {
		self.scenario = scenario
		self.baselineNPV = baselineNPV
		self.scenarioNPV = scenarioNPV
		self.impact = impact
	}

	public var description: String {
		let impactPercent = (impact / baselineNPV) * T(100)
		return """
		Scenario: \(scenario.name)
		Baseline NPV: \(baselineNPV)
		Scenario NPV: \(scenarioNPV)
		Impact: \(impact) (\(impactPercent)%)
		"""
	}
}

// MARK: - StressTestReport

/// Report summarizing stress test results.
public struct StressTestReport<T: Real & Sendable>: Sendable {
	/// Results for each scenario.
	public let results: [ScenarioResult<T>]

	public init(results: [ScenarioResult<T>]) {
		self.results = results
	}

	/// Summary report sorted by impact (worst first).
	public var summary: String {
		var report = "Stress Test Summary\n"
		report += "===================\n\n"

		for result in results.sorted(by: { $0.impact < $1.impact }) {
			report += result.description + "\n\n"
		}

		return report
	}

	/// Worst-case scenario (lowest NPV).
	public var worstCase: ScenarioResult<T>? {
		results.min(by: { $0.scenarioNPV < $1.scenarioNPV })
	}

	/// Best-case scenario (highest NPV).
	public var bestCase: ScenarioResult<T>? {
		results.max(by: { $0.scenarioNPV < $1.scenarioNPV })
	}
}
