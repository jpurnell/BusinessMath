//
//  FinancialProjection.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Numerics

/// A complete financial projection representing the results of running a scenario.
///
/// `FinancialProjection` encapsulates the output of scenario analysis, containing
/// the scenario that was run along with the resulting financial statements. This
/// structure provides a unified view of projected financial performance across
/// income statement, balance sheet, and cash flow statement.
///
/// ## Creating Financial Projections
///
/// Financial projections are typically created by ``ScenarioRunner`` when executing
/// a scenario, but can also be constructed manually for testing or custom workflows:
///
/// ```swift
/// let scenario = FinancialScenario(
///     name: "Base Case",
///     description: "Expected scenario"
/// )
///
/// let projection = FinancialProjection(
///     scenario: scenario,
///     incomeStatement: incomeStmt,
///     balanceSheet: balanceSheet,
///     cashFlowStatement: cashFlowStmt
/// )
/// ```
///
/// ## Accessing Financial Metrics
///
/// Once created, you can access any metric from the underlying statements:
///
/// ```swift
/// // Income statement metrics
/// let revenue = projection.incomeStatement.totalRevenue
/// let netIncome = projection.incomeStatement.netIncome
/// let netMargin = projection.incomeStatement.netMargin
///
/// // Balance sheet metrics
/// let totalAssets = projection.balanceSheet.totalAssets
/// let totalLiabilities = projection.balanceSheet.totalLiabilities
/// let equity = projection.balanceSheet.totalEquity
///
/// // Cash flow metrics
/// let operatingCashFlow = projection.cashFlowStatement.totalOperatingCashFlow
/// let freeCashFlow = projection.cashFlowStatement.freeCashFlow
/// ```
///
/// ## Comparing Multiple Projections
///
/// A common use case is comparing projections from different scenarios:
///
/// ```swift
/// let baseProjection = runner.run(scenario: baseCase, ...)
/// let optimisticProjection = runner.run(scenario: optimistic, ...)
/// let pessimisticProjection = runner.run(scenario: pessimistic, ...)
///
/// // Compare net income across scenarios
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// let baseIncome = baseProjection.incomeStatement.netIncome[q1]!
/// let optimisticIncome = optimisticProjection.incomeStatement.netIncome[q1]!
/// let pessimisticIncome = pessimisticProjection.incomeStatement.netIncome[q1]!
///
/// // Analyze range of outcomes
/// let incomeRange = optimisticIncome - pessimisticIncome
/// let percentageUncertainty = (incomeRange / baseIncome) * 100.0
/// ```
///
/// ## Scenario Context
///
/// Each projection maintains a reference to the scenario that generated it,
/// providing full traceability:
///
/// ```swift
/// print("Scenario: \(projection.scenario.name)")
/// print("Description: \(projection.scenario.description)")
///
/// // Review assumptions
/// for (category, assumption) in projection.scenario.assumptions {
///     print("\(category): \(assumption)")
/// }
///
/// // Review driver overrides
/// print("Number of driver overrides: \(projection.scenario.overrideCount)")
/// ```
///
/// ## Use Cases
///
/// - **Scenario Planning**: Compare multiple future states
/// - **Sensitivity Analysis**: Understand impact of input changes
/// - **Monte Carlo Simulation**: Aggregate probabilistic outcomes
/// - **Reporting**: Generate scenario-based financial reports
/// - **Decision Making**: Evaluate strategic alternatives
///
/// ## Design Principles
///
/// - **Immutability**: Projections are value types and cannot be modified
/// - **Completeness**: Contains all three core financial statements
/// - **Traceability**: Maintains reference to generating scenario
/// - **Type Safety**: Generic over `Real` for numerical flexibility
///
/// ## Topics
///
/// ### Creating Projections
/// - ``init(scenario:incomeStatement:balanceSheet:cashFlowStatement:)``
///
/// ### Properties
/// - ``scenario``
/// - ``incomeStatement``
/// - ``balanceSheet``
/// - ``cashFlowStatement``
///
/// ### Running Scenarios
/// - ``ScenarioRunner``
/// - ``FinancialScenario``
public struct FinancialProjection: Sendable {

	// MARK: - Properties

	/// The scenario that generated this projection.
	///
	/// Contains the scenario name, description, driver overrides, and assumptions
	/// that were used to create this financial projection.
	///
	/// ## Example
	/// ```swift
	/// print("Scenario: \(projection.scenario.name)")
	/// print("Description: \(projection.scenario.description)")
	/// print("Overrides: \(projection.scenario.overrideCount)")
	/// ```
	public let scenario: FinancialScenario

	/// The projected income statement showing revenues, expenses, and profitability.
	///
	/// Provides access to all income statement metrics including total revenue,
	/// total expenses, gross profit, operating income, net income, and various
	/// margin ratios.
	///
	/// ## Example
	/// ```swift
	/// let revenue = projection.incomeStatement.totalRevenue
	/// let netIncome = projection.incomeStatement.netIncome
	/// let netMargin = projection.incomeStatement.netMargin
	///
	/// // Access specific period
	/// let q1NetIncome = netIncome[Period.quarter(year: 2025, quarter: 1)]
	/// ```
	public let incomeStatement: IncomeStatement<Double>

	/// The projected balance sheet showing assets, liabilities, and equity.
	///
	/// Provides access to all balance sheet metrics including total assets,
	/// total liabilities, total equity, and various financial ratios.
	///
	/// ## Example
	/// ```swift
	/// let assets = projection.balanceSheet.totalAssets
	/// let liabilities = projection.balanceSheet.totalLiabilities
	/// let equity = projection.balanceSheet.totalEquity
	///
	/// // Verify accounting equation
	/// let period = Period.quarter(year: 2025, quarter: 1)
	/// let balanced = abs(assets[period]! - (liabilities[period]! + equity[period]!)) < 0.01
	/// ```
	public let balanceSheet: BalanceSheet<Double>

	/// The projected cash flow statement showing operating, investing, and financing cash flows.
	///
	/// Provides access to all cash flow metrics including operating cash flow,
	/// investing cash flow, financing cash flow, and free cash flow.
	///
	/// ## Example
	/// ```swift
	/// let operatingCF = projection.cashFlowStatement.totalOperatingCashFlow
	/// let freeCF = projection.cashFlowStatement.freeCashFlow
	///
	/// // Calculate cash flow metrics
	/// let period = Period.quarter(year: 2025, quarter: 1)
	/// let cashConversion = operatingCF[period]! / projection.incomeStatement.netIncome[period]!
	/// ```
	public let cashFlowStatement: CashFlowStatement<Double>

	// MARK: - Initialization

	/// Creates a financial projection with the specified scenario and statements.
	///
	/// - Parameters:
	///   - scenario: The scenario that generated this projection.
	///   - incomeStatement: The projected income statement.
	///   - balanceSheet: The projected balance sheet.
	///   - cashFlowStatement: The projected cash flow statement.
	///
	/// ## Example
	/// ```swift
	/// let scenario = FinancialScenario(
	///     name: "Base Case",
	///     description: "Expected scenario"
	/// )
	///
	/// let projection = FinancialProjection(
	///     scenario: scenario,
	///     incomeStatement: incomeStmt,
	///     balanceSheet: balanceSheet,
	///     cashFlowStatement: cashFlowStmt
	/// )
	/// ```
	///
	/// - Note: In typical usage, projections are created by ``ScenarioRunner``
	///   rather than constructed manually.
	public init(
		scenario: FinancialScenario,
		incomeStatement: IncomeStatement<Double>,
		balanceSheet: BalanceSheet<Double>,
		cashFlowStatement: CashFlowStatement<Double>
	) {
		self.scenario = scenario
		self.incomeStatement = incomeStatement
		self.balanceSheet = balanceSheet
		self.cashFlowStatement = cashFlowStatement
	}
}

// MARK: - Convenience Methods

extension FinancialProjection {

	/// The entity this projection belongs to.
	///
	/// Derived from the income statement entity. All statements in a projection
	/// should belong to the same entity.
	public var entity: Entity {
		return incomeStatement.entity
	}

	/// The periods covered by this projection.
	///
	/// Derived from the income statement periods. All statements in a projection
	/// should cover the same periods.
	public var periods: [Period] {
		return incomeStatement.periods
	}

	/// Returns the scenario name for easy identification.
	public var scenarioName: String {
		return scenario.name
	}

	/// Returns the scenario description.
	public var scenarioDescription: String {
		return scenario.description
	}
}
