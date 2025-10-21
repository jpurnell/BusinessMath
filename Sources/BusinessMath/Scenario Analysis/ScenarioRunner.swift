//
//  ScenarioRunner.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Numerics

/// Executes financial scenarios to produce financial projections.
///
/// `ScenarioRunner` is the engine that transforms scenario definitions into
/// concrete financial projections. It applies driver overrides, executes the
/// projection logic, and assembles the results into a ``FinancialProjection``.
///
/// ## Basic Usage
///
/// ```swift
/// let scenario = FinancialScenario(
///     name: "Base Case",
///     description: "Expected scenario",
///     driverOverrides: driverOverrides
/// )
///
/// let runner = ScenarioRunner()
/// let projection = try runner.run(
///     scenario: scenario,
///     entity: company,
///     periods: periods
/// ) { drivers, periods in
///     // Build financial statements from drivers
///     let revenueValues = periods.map { drivers["Revenue"]!.sample(for: $0) }
///     let costValues = periods.map { drivers["Costs"]!.sample(for: $0) }
///
///     // Create accounts and statements
///     // ... (see detailed example below)
///
///     return (incomeStatement, balanceSheet, cashFlowStatement)
/// }
/// ```
///
/// ## Complete Example
///
/// Here's a complete example showing how to build financial statements from drivers:
///
/// ```swift
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// let periods = Period.year(2025).quarters()
///
/// // Define drivers
/// let revenueDriver = DeterministicDriver(name: "Revenue", value: 100_000.0)
/// let costDriver = DeterministicDriver(name: "COGS", value: 60_000.0)
/// let opexDriver = DeterministicDriver(name: "OpEx", value: 20_000.0)
///
/// var overrides: [String: AnyDriver<Double>] = [:]
/// overrides["Revenue"] = AnyDriver(revenueDriver)
/// overrides["COGS"] = AnyDriver(costDriver)
/// overrides["OpEx"] = AnyDriver(opexDriver)
///
/// let scenario = FinancialScenario(
///     name: "Base Case",
///     description: "Steady state operations",
///     driverOverrides: overrides
/// )
///
/// let runner = ScenarioRunner()
/// let projection = try runner.run(
///     scenario: scenario,
///     entity: entity,
///     periods: periods
/// ) { drivers, periods in
///     // Sample driver values for each period
///     let revenueValues = periods.map { drivers["Revenue"]!.sample(for: $0) }
///     let cogsValues = periods.map { drivers["COGS"]!.sample(for: $0) }
///     let opexValues = periods.map { drivers["OpEx"]!.sample(for: $0) }
///
///     // Create time series
///     let revenueSeries = TimeSeries(periods: periods, values: revenueValues)
///     let cogsSeries = TimeSeries(periods: periods, values: cogsValues)
///     let opexSeries = TimeSeries(periods: periods, values: opexValues)
///
///     // Create accounts
///     let revenueAccount = try Account(
///         entity: entity,
///         name: "Revenue",
///         type: .revenue,
///         timeSeries: revenueSeries
///     )
///
///     var cogsMetadata = AccountMetadata()
///     cogsMetadata.category = "COGS"
///     let cogsAccount = try Account(
///         entity: entity,
///         name: "Cost of Goods Sold",
///         type: .expense,
///         timeSeries: cogsSeries,
///         metadata: cogsMetadata
///     )
///
///     let opexAccount = try Account(
///         entity: entity,
///         name: "Operating Expenses",
///         type: .expense,
///         timeSeries: opexSeries
///     )
///
///     // Build income statement
///     let incomeStatement = try IncomeStatement(
///         entity: entity,
///         periods: periods,
///         revenueAccounts: [revenueAccount],
///         expenseAccounts: [cogsAccount, opexAccount]
///     )
///
///     // Build balance sheet (simplified: equity = cumulative net income)
///     let netIncome = incomeStatement.netIncome
///     let equityAccount = try Account(
///         entity: entity,
///         name: "Retained Earnings",
///         type: .equity,
///         timeSeries: netIncome
///     )
///
///     let balanceSheet = try BalanceSheet(
///         entity: entity,
///         periods: periods,
///         assetAccounts: [equityAccount],  // Simplified
///         liabilityAccounts: [],
///         equityAccounts: [equityAccount]
///     )
///
///     // Build cash flow statement
///     let cashAccount = try Account(
///         entity: entity,
///         name: "Operating Cash Flow",
///         type: .operating,
///         timeSeries: netIncome  // Simplified: cash = net income
///     )
///
///     let cashFlowStatement = try CashFlowStatement(
///         entity: entity,
///         periods: periods,
///         operatingAccounts: [cashAccount],
///         investingAccounts: [],
///         financingAccounts: []
///     )
///
///     return (incomeStatement, balanceSheet, cashFlowStatement)
/// }
///
/// // Access results
/// print("Scenario: \(projection.scenario.name)")
/// print("Q1 Net Income: \(projection.incomeStatement.netIncome[periods[0]]!)")
/// ```
///
/// ## Builder Function Pattern
///
/// The builder function receives:
/// - **drivers**: Dictionary of driver names to type-erased drivers from the scenario
/// - **periods**: Array of periods to project over
///
/// The builder should:
/// 1. Sample each driver for each period
/// 2. Create TimeSeries from the sampled values
/// 3. Create Account objects for each time series
/// 4. Assemble accounts into financial statements
/// 5. Return a tuple of (IncomeStatement, BalanceSheet, CashFlowStatement)
///
/// ## Probabilistic Scenarios
///
/// For probabilistic drivers, each call to `run()` produces a different sample:
///
/// ```swift
/// let uncertainRevenue = ProbabilisticDriver(
///     name: "Revenue",
///     distribution: DistributionNormal(mean: 100_000.0, standardDeviation: 10_000.0)
/// )
///
/// // Run the same scenario 1000 times for Monte Carlo simulation
/// var projections: [FinancialProjection] = []
/// for _ in 0..<1000 {
///     let projection = try runner.run(scenario: scenario, entity: entity, periods: periods, builder: builder)
///     projections.append(projection)
/// }
///
/// // Analyze distribution of outcomes
/// let netIncomes = projections.map { $0.incomeStatement.netIncome[periods[0]]! }
/// let meanNetIncome = netIncomes.reduce(0.0, +) / Double(netIncomes.count)
/// let p95NetIncome = netIncomes.sorted()[Int(0.95 * Double(netIncomes.count))]
/// ```
///
/// ## Design Principles
///
/// - **Flexibility**: Builder pattern allows arbitrary mappings from drivers to statements
/// - **Composability**: Scenarios can be run independently and compared
/// - **Traceability**: Each projection maintains its generating scenario
/// - **Reusability**: Same builder can be used across multiple scenarios
///
/// ## Topics
///
/// ### Running Scenarios
/// - ``run(scenario:entity:periods:builder:)``
///
/// ### Type Aliases
/// - ``StatementBuilder``
///
/// ### Related Types
/// - ``FinancialScenario``
/// - ``FinancialProjection``
public struct ScenarioRunner: Sendable {

	// MARK: - Type Aliases

	/// A function that builds financial statements from drivers and periods.
	///
	/// The builder receives a dictionary of drivers and a list of periods, and
	/// must return a tuple containing the three core financial statements.
	///
	/// ## Parameters
	/// - **drivers**: Dictionary mapping driver names to type-erased drivers
	/// - **periods**: Array of periods to project over
	///
	/// ## Returns
	/// A tuple of (IncomeStatement, BalanceSheet, CashFlowStatement)
	///
	/// ## Example
	/// ```swift
	/// let builder: ScenarioRunner.StatementBuilder = { drivers, periods in
	///     // Sample drivers
	///     let revenueValues = periods.map { drivers["Revenue"]!.sample(for: $0) }
	///
	///     // Create time series
	///     let revenueSeries = TimeSeries(periods: periods, values: revenueValues)
	///
	///     // Build accounts
	///     let revenueAccount = try Account(...)
	///
	///     // Build statements
	///     let incomeStatement = try IncomeStatement(...)
	///     let balanceSheet = try BalanceSheet(...)
	///     let cashFlowStatement = try CashFlowStatement(...)
	///
	///     return (incomeStatement, balanceSheet, cashFlowStatement)
	/// }
	/// ```
	public typealias StatementBuilder = @Sendable (
		_ drivers: [String: AnyDriver<Double>],
		_ periods: [Period]
	) throws -> (
		IncomeStatement<Double>,
		BalanceSheet<Double>,
		CashFlowStatement<Double>
	)

	// MARK: - Initialization

	/// Creates a new scenario runner.
	///
	/// ScenarioRunner is a stateless executor, so a single instance can be
	/// reused to run multiple scenarios.
	///
	/// ## Example
	/// ```swift
	/// let runner = ScenarioRunner()
	///
	/// // Run multiple scenarios with the same runner
	/// let baseProjection = try runner.run(scenario: baseCase, ...)
	/// let optimisticProjection = try runner.run(scenario: optimistic, ...)
	/// let pessimisticProjection = try runner.run(scenario: pessimistic, ...)
	/// ```
	public init() {
		// Stateless runner - no initialization needed
	}

	// MARK: - Execution

	/// Executes a scenario and produces a financial projection.
	///
	/// This method applies the scenario's driver overrides and invokes the
	/// builder function to generate financial statements.
	///
	/// - Parameters:
	///   - scenario: The scenario to execute, containing driver overrides and metadata.
	///   - entity: The entity (company) this projection represents.
	///   - periods: The time periods to project over.
	///   - builder: A function that transforms drivers into financial statements.
	///
	/// - Returns: A ``FinancialProjection`` containing the scenario and resulting statements.
	///
	/// - Throws: Any errors from the builder function (typically ``AccountError`` or
	///   statement validation errors).
	///
	/// ## Example
	/// ```swift
	/// let runner = ScenarioRunner()
	/// let projection = try runner.run(
	///     scenario: scenario,
	///     entity: company,
	///     periods: quarters
	/// ) { drivers, periods in
	///     // Build statements from drivers
	///     return (incomeStatement, balanceSheet, cashFlowStatement)
	/// }
	/// ```
	///
	/// ## Execution Flow
	/// 1. Extracts driver overrides from the scenario
	/// 2. Invokes the builder with drivers and periods
	/// 3. Receives the three financial statements from the builder
	/// 4. Wraps everything in a FinancialProjection
	/// 5. Returns the projection with full traceability to the scenario
	///
	/// ## Error Handling
	/// The runner itself does not throw errors, but the builder function may throw:
	/// - ``AccountError``: If account creation fails (e.g., entity mismatch)
	/// - ``IncomeStatementError``: If income statement validation fails
	/// - ``BalanceSheetError``: If balance sheet doesn't balance
	/// - ``CashFlowStatementError``: If cash flow statement validation fails
	public func run(
		scenario: FinancialScenario,
		entity: Entity,
		periods: [Period],
		builder: StatementBuilder
	) throws -> FinancialProjection {
		// Extract drivers from scenario
		let drivers = scenario.driverOverrides

		// Invoke builder to create financial statements
		let (incomeStatement, balanceSheet, cashFlowStatement) = try builder(drivers, periods)

		// Wrap in FinancialProjection
		return FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)
	}
}
