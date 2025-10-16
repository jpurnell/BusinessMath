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
/// - ``init(entity:periods:operatingAccounts:investingAccounts:financingAccounts:)``
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

	/// All operating cash flow accounts.
	public let operatingAccounts: [Account<T>]

	/// All investing cash flow accounts.
	public let investingAccounts: [Account<T>]

	/// All financing cash flow accounts.
	public let financingAccounts: [Account<T>]

	/// Creates a cash flow statement with validation.
	///
	/// - Parameters:
	///   - entity: The entity this statement belongs to
	///   - periods: The periods covered
	///   - operatingAccounts: Operating cash flow accounts (must have type .operating)
	///   - investingAccounts: Investing cash flow accounts (must have type .investing)
	///   - financingAccounts: Financing cash flow accounts (must have type .financing)
	///
	/// - Throws: ``CashFlowStatementError`` if validation fails
	public init(
		entity: Entity,
		periods: [Period],
		operatingAccounts: [Account<T>],
		investingAccounts: [Account<T>],
		financingAccounts: [Account<T>]
	) throws {
		// Validate entity consistency
		for account in operatingAccounts + investingAccounts + financingAccounts {
			guard account.entity == entity else {
				throw CashFlowStatementError.entityMismatch
			}
		}

		// Validate account types
		for account in operatingAccounts {
			guard account.type == .operating else {
				throw CashFlowStatementError.invalidAccountType(expected: .operating, actual: account.type)
			}
		}

		for account in investingAccounts {
			guard account.type == .investing else {
				throw CashFlowStatementError.invalidAccountType(expected: .investing, actual: account.type)
			}
		}

		for account in financingAccounts {
			guard account.type == .financing else {
				throw CashFlowStatementError.invalidAccountType(expected: .financing, actual: account.type)
			}
		}

		self.entity = entity
		self.periods = periods
		self.operatingAccounts = operatingAccounts
		self.investingAccounts = investingAccounts
		self.financingAccounts = financingAccounts
	}

	// MARK: - Cash Flow Metrics

	/// Operating cash flow from core business activities.
	///
	/// Sum of all operating cash flow accounts. Typically includes:
	/// - Cash received from customers
	/// - Cash paid to suppliers and employees
	/// - Working capital changes
	public var operatingCashFlow: TimeSeries<T> {
		return aggregateAccounts(operatingAccounts)
	}

	/// Investing cash flow from buying/selling long-term assets.
	///
	/// Sum of all investing cash flow accounts. Typically includes:
	/// - Capital expenditures (CapEx) - typically negative
	/// - Asset sales - typically positive
	/// - Investment purchases/sales
	public var investingCashFlow: TimeSeries<T> {
		return aggregateAccounts(investingAccounts)
	}

	/// Financing cash flow from debt and equity transactions.
	///
	/// Sum of all financing cash flow accounts. Typically includes:
	/// - Debt issuance/repayment
	/// - Equity issuance
	/// - Dividend payments
	/// - Stock buybacks
	public var financingCashFlow: TimeSeries<T> {
		return aggregateAccounts(financingAccounts)
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

	// MARK: - Helper Methods

	/// Aggregates multiple accounts into a single time series.
	private func aggregateAccounts(_ accounts: [Account<T>]) -> TimeSeries<T> {
		guard !accounts.isEmpty else {
			// Return zero-filled series for empty account list
			let zeros = Array(repeating: T(0), count: periods.count)
			return TimeSeries(periods: periods, values: zeros)
		}

		// Start with first account's time series
		var result = accounts[0].timeSeries

		// Add remaining accounts
		for account in accounts.dropFirst() {
			result = result + account.timeSeries
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
		public let entity: Entity
		public let periods: [Period]

		public let operatingAccounts: [Account<T>]
		public let investingAccounts: [Account<T>]
		public let financingAccounts: [Account<T>]

		// Pre-computed cash flows
		public let operatingCashFlow: TimeSeries<T>
		public let investingCashFlow: TimeSeries<T>
		public let financingCashFlow: TimeSeries<T>
		public let netCashFlow: TimeSeries<T>
		public let freeCashFlow: TimeSeries<T>
	}

	/// Creates a materialized version with all metrics pre-computed.
	///
	/// - Returns: A ``Materialized`` cash flow statement with pre-computed metrics
	public func materialize() -> Materialized {
		return Materialized(
			entity: entity,
			periods: periods,
			operatingAccounts: operatingAccounts,
			investingAccounts: investingAccounts,
			financingAccounts: financingAccounts,
			operatingCashFlow: operatingCashFlow,
			investingCashFlow: investingCashFlow,
			financingCashFlow: financingCashFlow,
			netCashFlow: netCashFlow,
			freeCashFlow: freeCashFlow
		)
	}
}

// MARK: - Codable Conformance

extension CashFlowStatement: Codable {

	private enum CodingKeys: String, CodingKey {
		case entity
		case periods
		case operatingAccounts
		case investingAccounts
		case financingAccounts
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(entity, forKey: .entity)
		try container.encode(periods, forKey: .periods)
		try container.encode(operatingAccounts, forKey: .operatingAccounts)
		try container.encode(investingAccounts, forKey: .investingAccounts)
		try container.encode(financingAccounts, forKey: .financingAccounts)
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entity = try container.decode(Entity.self, forKey: .entity)
		let periods = try container.decode([Period].self, forKey: .periods)
		let operatingAccounts = try container.decode([Account<T>].self, forKey: .operatingAccounts)
		let investingAccounts = try container.decode([Account<T>].self, forKey: .investingAccounts)
		let financingAccounts = try container.decode([Account<T>].self, forKey: .financingAccounts)

		try self.init(
			entity: entity,
			periods: periods,
			operatingAccounts: operatingAccounts,
			investingAccounts: investingAccounts,
			financingAccounts: financingAccounts
		)
	}
}
