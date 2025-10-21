//
//  FinancialScenario.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Numerics

/// A financial scenario represents a specific set of assumptions for financial projections.
///
/// `FinancialScenario` encapsulates a coherent set of business assumptions by defining
/// driver overrides and narrative assumptions. Financial scenarios enable "what-if" analysis
/// by varying key inputs to understand different potential outcomes.
///
/// ## Creating Scenarios
///
/// ```swift
/// // Base case with expected values
/// let basePrice = DeterministicDriver(name: "Price", value: 100.0)
/// let baseVolume = DeterministicDriver(name: "Volume", value: 1000.0)
///
/// var baseOverrides: [String: AnyDriver<Double>] = [:]
/// baseOverrides["Price"] = AnyDriver(basePrice)
/// baseOverrides["Volume"] = AnyDriver(baseVolume)
///
/// var baseAssumptions: [String: String] = [:]
/// baseAssumptions["Market"] = "Stable conditions"
/// baseAssumptions["Competition"] = "Current market share maintained"
///
/// let baseCase = FinancialScenario(
///     name: "Base Case",
///     description: "Expected scenario with stable market conditions",
///     driverOverrides: baseOverrides,
///     assumptions: baseAssumptions
/// )
/// ```
///
/// ## Common Scenario Types
///
/// ### Best Case / Optimistic
/// ```swift
/// var optimisticOverrides: [String: AnyDriver<Double>] = [:]
/// optimisticOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 120.0))
/// optimisticOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 1200.0))
///
/// let bestCase = FinancialScenario(
///     name: "Best Case",
///     description: "Optimistic scenario with favorable market response",
///     driverOverrides: optimisticOverrides
/// )
/// ```
///
/// ### Worst Case / Pessimistic
/// ```swift
/// var pessimisticOverrides: [String: AnyDriver<Double>] = [:]
/// pessimisticOverrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 90.0))
/// pessimisticOverrides["Volume"] = AnyDriver(DeterministicDriver(name: "Volume", value: 800.0))
/// pessimisticOverrides["Costs"] = AnyDriver(DeterministicDriver(name: "Costs", value: 55.0))
///
/// let worstCase = FinancialScenario(
///     name: "Worst Case",
///     description: "Pessimistic scenario with market headwinds",
///     driverOverrides: pessimisticOverrides
/// )
/// ```
///
/// ### Uncertainty / Probabilistic
/// ```swift
/// var uncertainOverrides: [String: AnyDriver<Double>] = [:]
/// uncertainOverrides["Volume"] = AnyDriver(
///     ProbabilisticDriver(
///         name: "Volume",
///         distribution: DistributionNormal(mean: 1000.0, standardDeviation: 150.0)
///     )
/// )
///
/// let uncertainScenario = FinancialScenario(
///     name: "Market Uncertainty",
///     description: "Volume uncertainty due to economic conditions",
///     driverOverrides: uncertainOverrides
/// )
/// ```
///
/// ## Using Scenarios with ScenarioRunner
///
/// Scenarios are typically executed using ``ScenarioRunner`` to generate
/// financial projections:
///
/// ```swift
/// let runner = ScenarioRunner()
/// let projection = runner.run(
///     scenario: baseCase,
///     baseDrivers: defaultDrivers,
///     periods: periods
/// )
///
/// // Access results
/// let netIncome = projection.incomeStatement.netIncome
/// let totalAssets = projection.balanceSheet.totalAssets
/// ```
///
/// ## Driver Override Strategy
///
/// Driver overrides replace base case drivers with scenario-specific values:
/// - **Full replacement**: Override completely replaces the base driver
/// - **Partial overrides**: Only specified drivers are replaced, others use base values
/// - **Type-agnostic**: Can override deterministic drivers with probabilistic ones and vice versa
///
/// ## Design Principles
///
/// - **Immutability**: Scenarios are value types and cannot be modified after creation
/// - **Composability**: Scenarios can be created by combining partial scenarios
/// - **Clarity**: Names and descriptions provide human-readable context
/// - **Flexibility**: Driver overrides use type erasure (``AnyDriver``) for heterogeneous collections
///
/// ## Topics
///
/// ### Creating Scenarios
/// - ``init(name:description:driverOverrides:assumptions:)``
///
/// ### Properties
/// - ``name``
/// - ``description``
/// - ``driverOverrides``
/// - ``assumptions``
///
/// ### Running Scenarios
/// - ``ScenarioRunner``
/// - ``FinancialProjection``
public struct FinancialScenario: Sendable {

	// MARK: - Properties

	/// The name of this scenario (e.g., "Base Case", "Optimistic", "Worst Case").
	public let name: String

	/// A detailed description of this scenario's key characteristics and assumptions.
	public let description: String

	/// Driver overrides that replace base case values for this scenario.
	///
	/// Keys are driver names, values are type-erased drivers (``AnyDriver``) that
	/// produce values for the scenario. When a scenario is run, these overrides
	/// replace the corresponding base case drivers.
	///
	/// ## Example
	/// ```swift
	/// var overrides: [String: AnyDriver<Double>] = [:]
	/// overrides["Price"] = AnyDriver(DeterministicDriver(name: "Price", value: 120.0))
	/// overrides["Volume"] = AnyDriver(
	///     ProbabilisticDriver(
	///         name: "Volume",
	///         distribution: DistributionNormal(1200.0, 100.0)
	///     )
	/// )
	/// ```
	public let driverOverrides: [String: AnyDriver<Double>]

	/// Human-readable assumptions that characterize this scenario.
	///
	/// These provide narrative context and documentation for the scenario's
	/// business logic. Keys are assumption categories, values are descriptions.
	///
	/// ## Example
	/// ```swift
	/// var assumptions: [String: String] = [:]
	/// assumptions["Market Growth"] = "5% annual growth in addressable market"
	/// assumptions["Competition"] = "Two new competitors enter in Q3"
	/// assumptions["Pricing"] = "20% premium pricing due to brand strength"
	/// ```
	public let assumptions: [String: String]

	// MARK: - Initialization

	/// Creates a scenario with the specified characteristics.
	///
	/// - Parameters:
	///   - name: A short, descriptive name for the scenario.
	///   - description: A detailed description of the scenario's characteristics.
	///   - driverOverrides: Driver overrides to apply (default: empty).
	///   - assumptions: Human-readable assumptions (default: empty).
	///
	/// ## Example
	/// ```swift
	/// var overrides: [String: AnyDriver<Double>] = [:]
	/// overrides["Revenue Growth"] = AnyDriver(
	///     DeterministicDriver(name: "Revenue Growth", value: 0.15)
	/// )
	///
	/// var assumptions: [String: String] = [:]
	/// assumptions["Market"] = "Strong demand growth"
	///
	/// let scenario = FinancialScenario(
	///     name: "High Growth",
	///     description: "15% revenue growth scenario",
	///     driverOverrides: overrides,
	///     assumptions: assumptions
	/// )
	/// ```
	public init(
		name: String,
		description: String,
		driverOverrides: [String: AnyDriver<Double>] = [:],
		assumptions: [String: String] = [:]
	) {
		self.name = name
		self.description = description
		self.driverOverrides = driverOverrides
		self.assumptions = assumptions
	}
}

// MARK: - Convenience Methods

extension FinancialScenario {

	/// Returns whether this scenario has any driver overrides.
	public var hasDriverOverrides: Bool {
		return !driverOverrides.isEmpty
	}

	/// Returns whether this scenario has any documented assumptions.
	public var hasAssumptions: Bool {
		return !assumptions.isEmpty
	}

	/// Returns the number of drivers being overridden in this scenario.
	public var overrideCount: Int {
		return driverOverrides.count
	}
}
