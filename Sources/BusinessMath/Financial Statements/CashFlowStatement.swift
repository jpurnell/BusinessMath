//
//  CashFlowStatement.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - CashFlowStatementError

/// Errors that can occur when creating or manipulating cash flow statements.
public enum CashFlowStatementError: Error, Sendable {
	/// The entity is missing from one or more accounts
	case entityMismatch

	/// Periods are inconsistent across accounts
	case periodMismatch

	/// No accounts provided
	case noAccounts

	/// Wrong account type (expected operating, investing, or financing)
	case invalidAccountType(expected: AccountType, actual: AccountType)
}

// MARK: - CashFlowStatement

/// Cash flow statement for a single entity over multiple periods.
///
/// `CashFlowStatement` aggregates cash flow accounts from operating, investing,
/// and financing activities to show how cash moves through the business.
///
/// ## Creating Cash Flow Statements
///
/// ```swift
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// let periods = [
///     Period.quarter(year: 2024, quarter: 1),
///     Period.quarter(year: 2024, quarter: 2)
/// ]
///
/// let operatingAccount = try Account(
///     entity: entity,
///     name: "Cash from Operations",
///     type: .operating,
///     timeSeries: operatingSeries
/// )
///
/// let cashFlowStmt = try CashFlowStatement(
///     entity: entity,
///     periods: periods,
///     operatingAccounts: [operatingAccount],
///     investingAccounts: [investingAccount],
///     financingAccounts: [financingAccount]
/// )
/// ```
///
/// ## Accessing Metrics
///
/// ```swift
/// // Cash flows by category
/// let operatingCF = cashFlowStmt.operatingCashFlow
/// let investingCF = cashFlowStmt.investingCashFlow
/// let financingCF = cashFlowStmt.financingCashFlow
///
/// // Key metrics
/// let netCashFlow = cashFlowStmt.netCashFlow
/// let freeCashFlow = cashFlowStmt.freeCashFlow
/// ```
///
/// ## Free Cash Flow
///
/// Free cash flow (FCF) is a key metric that shows cash available for distribution
/// to investors after capital expenditures:
///
/// **FCF = Operating Cash Flow + Investing Cash Flow**
///
/// Investing cash flow is typically negative (capital expenditures), so FCF
/// represents cash available after reinvesting in the business.
///
/// ## Topics
///
/// ### Creating Cash Flow Statements
/// - ``init(entity:periods:accounts:)``
///
/// ### Properties
/// - ``entity``
/// - ``periods``
/// - ``operatingAccounts``
/// - ``investingAccounts``
/// - ``financingAccounts``
///
/// ### Cash Flow Metrics
/// - ``operatingCashFlow``
/// - ``investingCashFlow``
/// - ``financingCashFlow``
/// - ``netCashFlow``
/// - ``freeCashFlow``
///
/// ### Materialization
/// - ``materialize()``
/// - ``Materialized``
public struct CashFlowStatement<T: Real & Sendable>: Sendable where T: Codable {

	/// The entity this cash flow statement belongs to.
	public let entity: Entity

	/// The periods covered by this cash flow statement.
	public let periods: [Period]

	/// All accounts in this cash flow statement.
	///
	/// Each account must have a `cashFlowRole` to be included.
	/// Accounts with the same role will be automatically aggregated when computing metrics.
	public let accounts: [Account<T>]

	/// All operating cash flow accounts.
	///
	/// This computed property filters accounts by their `cashFlowRole.isOperating` flag.
	public var operatingAccounts: [Account<T>] {
		accounts.filter { $0.cashFlowRole?.isOperating == true }
	}

	/// All investing cash flow accounts.
	///
	/// This computed property filters accounts by their `cashFlowRole.isInvesting` flag.
	public var investingAccounts: [Account<T>] {
		accounts.filter { $0.cashFlowRole?.isInvesting == true }
	}

	/// All financing cash flow accounts.
	///
	/// This computed property filters accounts by their `cashFlowRole.isFinancing` flag.
	public var financingAccounts: [Account<T>] {
		accounts.filter { $0.cashFlowRole?.isFinancing == true }
	}

	/// Creates a cash flow statement with validation using the new role-based API.
	///
	/// - Parameters:
	///   - entity: The entity this statement belongs to
	///   - periods: The periods covered
	///   - accounts: All accounts (must have `cashFlowRole`)
	///
	/// - Throws: ``FinancialModelError`` if validation fails
	public init(
		entity: Entity,
		periods: [Period],
		accounts: [Account<T>]
	) throws {
		// Validate all accounts have cash flow roles
		for account in accounts {
			guard account.cashFlowRole != nil else {
				throw FinancialModelError.accountMissingRole(
					statement: .cashFlowStatement,
					accountName: account.name
				)
			}
		}

		// Validate entity and period consistency using shared helpers
		try FinancialStatementHelpers.validateEntityConsistency(accounts: accounts, entity: entity)
		try FinancialStatementHelpers.validatePeriodConsistency(accounts: accounts, periods: periods)

		self.entity = entity
		self.periods = periods
		self.accounts = accounts
	}

	// MARK: - Cash Flow Metrics

	/// Operating cash flow from core business activities.
	///
	/// Sum of all operating cash flow accounts. Typically includes:
	/// - Cash received from customers
	/// - Cash paid to suppliers and employees
	/// - Working capital changes
	public var operatingCashFlow: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(operatingAccounts, periods: periods)
	}

	/// Investing cash flow from buying/selling long-term assets.
	///
	/// Sum of all investing cash flow accounts. Typically includes:
	/// - Capital expenditures (CapEx) - typically negative
	/// - Asset sales - typically positive
	/// - Investment purchases/sales
	public var investingCashFlow: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(investingAccounts, periods: periods)
	}

	/// Financing cash flow from debt and equity transactions.
	///
	/// Sum of all financing cash flow accounts. Typically includes:
	/// - Debt issuance/repayment
	/// - Equity issuance
	/// - Dividend payments
	/// - Stock buybacks
	public var financingCashFlow: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(financingAccounts, periods: periods)
	}

	/// Net cash flow (operating + investing + financing).
	///
	/// Represents the total change in cash for the period. This should
	/// reconcile with the change in cash on the balance sheet.
	public var netCashFlow: TimeSeries<T> {
		return operatingCashFlow + investingCashFlow + financingCashFlow
	}

	/// Free cash flow (operating + investing).
	///
	/// Represents cash available for distribution after capital expenditures.
	/// This is a key metric for valuation and financial health.
	///
	/// **FCF = Operating Cash Flow + Investing Cash Flow**
	///
	/// Since investing cash flow is typically negative (CapEx), this shows
	/// cash available after reinvesting in the business.
	public var freeCashFlow: TimeSeries<T> {
		return operatingCashFlow + investingCashFlow
	}

	/// Working capital changes (changes in receivables, inventory, payables, etc.).
	///
	/// Aggregates all accounts where `cashFlowRole.usesChangeInBalance == true`.
	/// These accounts represent balance sheet items where the period-over-period
	/// change affects operating cash flow.
	///
	/// For accounts with `usesChangeInBalance == true`, automatically applies
	/// `TimeSeries.diff()` to convert balance data to period changes.
	public var workingCapitalChanges: TimeSeries<T> {
		let wcAccounts = accounts.filter { $0.cashFlowRole?.usesChangeInBalance == true }

		guard !wcAccounts.isEmpty else {
			let zeros = Array(repeating: T(0), count: periods.count)
			return TimeSeries(periods: periods, values: zeros)
		}

		// Apply diff() to each account to get period-over-period changes
		var changesSeries = [TimeSeries<T>]()
		for account in wcAccounts {
			let changes = account.timeSeries.diff()
			changesSeries.append(changes)
		}

		// Aggregate all changes
		var result = changesSeries[0]
		for series in changesSeries.dropFirst() {
			result = result + series
		}

		return result
	}

}

// MARK: - Materialized Cash Flow Statement

extension CashFlowStatement {

	/// Materialized version of a cash flow statement with pre-computed metrics.
	///
	/// Use `Materialized` when computing metrics repeatedly across many companies.
	/// All metrics are computed once and stored, trading memory for speed.
	///
	/// ## Example
	/// ```swift
	/// let materialized = cashFlowStmt.materialize()
	///
	/// // Metrics are pre-computed, not recalculated on each access
	/// for period in materialized.periods {
	///     print("Period: \(period)")
	///     print("  Operating CF: \(materialized.operatingCashFlow[period] ?? 0)")
	///     print("  Free CF: \(materialized.freeCashFlow[period] ?? 0)")
	/// }
	/// ```
	public struct Materialized: Sendable {
		/// The entity this cash flow statement belongs to.
		public let entity: Entity

		/// The time periods covered by this statement.
		public let periods: [Period]

		/// All accounts in the cash flow statement.
		public let accounts: [Account<T>]

		// Pre-computed cash flows

		/// Cash flow from operating activities (net income + non-cash items ± working capital changes).
		public let operatingCashFlow: TimeSeries<T>

		/// Cash flow from investing activities (capex, acquisitions, asset sales).
		public let investingCashFlow: TimeSeries<T>

		/// Cash flow from financing activities (debt issuance/repayment, dividends, equity).
		public let financingCashFlow: TimeSeries<T>

		/// Net cash flow: Operating + Investing + Financing.
		public let netCashFlow: TimeSeries<T>

		/// Free cash flow: Operating Cash Flow - Capital Expenditures.
		public let freeCashFlow: TimeSeries<T>

		/// Changes in working capital (current assets - current liabilities).
		public let workingCapitalChanges: TimeSeries<T>
	}

	/// Creates a materialized version with all metrics pre-computed.
	///
	/// - Returns: A ``Materialized`` cash flow statement with pre-computed metrics
	public func materialize() -> Materialized {
		return Materialized(
			entity: entity,
			periods: periods,
			accounts: accounts,
			operatingCashFlow: operatingCashFlow,
			investingCashFlow: investingCashFlow,
			financingCashFlow: financingCashFlow,
			netCashFlow: netCashFlow,
			freeCashFlow: freeCashFlow,
			workingCapitalChanges: workingCapitalChanges
		)
	}
}

// MARK: - Codable Conformance

/// Codable conformance for CashFlowStatement enables JSON serialization.
///
/// Only encodes essential data (entity, periods, accounts). Computed cash flows
/// are recalculated upon decoding.
extension CashFlowStatement: Codable {

	private enum CodingKeys: String, CodingKey {
		case entity
		case periods
		case accounts
	}

	/// Encode the cash flow statement to an encoder.
	/// - Parameter encoder: The encoder to write to
	/// - Throws: EncodingError if encoding fails
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(entity, forKey: .entity)
		try container.encode(periods, forKey: .periods)
		try container.encode(accounts, forKey: .accounts)
	}

	/// Decode a cash flow statement from a decoder.
	/// - Parameter decoder: The decoder to read from
	/// - Throws: DecodingError if decoding fails
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entity = try container.decode(Entity.self, forKey: .entity)
		let periods = try container.decode([Period].self, forKey: .periods)
		let accounts = try container.decode([Account<T>].self, forKey: .accounts)

		try self.init(
			entity: entity,
			periods: periods,
			accounts: accounts
		)
	}
}

