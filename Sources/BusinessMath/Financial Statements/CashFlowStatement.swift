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

	/// Breakdown of working capital changes by cash flow role.
	///
	/// Returns a dictionary showing the period-over-period change for each working capital
	/// component. This enables detailed analysis of which components are driving changes
	/// in operating cash flow.
	///
	/// ## Business Context
	///
	/// Understanding working capital changes by component is critical for:
	/// - **Cash flow forecasting**: Model individual components (AR, inventory, AP) separately
	/// - **Working capital optimization**: Identify which components need management attention
	/// - **LBO cash flow modeling**: Build detailed working capital builds/releases
	/// - **Covenant compliance**: Track specific components mentioned in credit agreements
	///
	/// ## Formula
	///
	/// For each component with `usesChangeInBalance == true`:
	/// ```
	/// Component Change = Ending Balance - Beginning Balance
	/// ```
	///
	/// **Convention:**
	/// - **Positive change** (increase in asset or decrease in liability) = **use of cash**
	/// - **Negative change** (decrease in asset or increase in liability) = **source of cash**
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let cashFlowStmt = try CashFlowStatement(entity: company, periods: periods, accounts: accounts)
	///
	/// // Get detailed working capital breakdown
	/// let wcComponents = cashFlowStmt.workingCapitalChangesByComponent
	///
	/// // Analyze AR changes
	/// if let arChanges = wcComponents[.changeInAccountsReceivable] {
	///     let q2Change = arChanges[q2]!
	///     if q2Change > 0 {
	///         print("AR increased by $\(q2Change) - use of cash")
	///         print("Collections are slowing - review AR aging")
	///     } else {
	///         print("AR decreased by $\(-q2Change) - source of cash")
	///         print("Improved collections")
	///     }
	/// }
	///
	/// // Analyze inventory changes
	/// if let invChanges = wcComponents[.changeInInventory] {
	///     let q2Change = invChanges[q2]!
	///     if q2Change > 0 {
	///         print("Inventory increased by $\(q2Change) - use of cash")
	///         print("Building inventory (growth or inefficiency?)")
	///     }
	/// }
	///
	/// // Analyze AP changes
	/// if let apChanges = wcComponents[.changeInAccountsPayable] {
	///     let q2Change = apChanges[q2]!
	///     if q2Change > 0 {
	///         print("AP increased by $\(q2Change) - source of cash")
	///         print("Taking longer to pay suppliers")
	///     }
	/// }
	/// ```
	///
	/// ## LBO Cash Flow Modeling
	///
	/// ```swift
	/// let wcComponents = cashFlowStmt.workingCapitalChangesByComponent
	///
	/// // Model working capital as % of revenue
	/// let revenue = incomeStmt.totalRevenue
	///
	/// // Calculate AR as days sales outstanding (DSO)
	/// if let arChanges = wcComponents[.changeInAccountsReceivable],
	///    let arBalance = balanceSheet.accountsReceivableBalance {
	///     let dso = (arBalance[q2]! / revenue[q2]!) * 365
	///     print("DSO: \(dso) days")
	///
	///     // Forecast future AR based on target DSO
	///     let targetDSO = 45.0  // days
	///     let targetAR = (revenue[q3]! / 365) * targetDSO
	///     let projectedARChange = targetAR - arBalance[q2]!
	///     print("Projected AR change Q3: $\(projectedARChange)")
	/// }
	///
	/// // Calculate inventory turnover
	/// // Calculate AP days payable outstanding (DPO)
	/// // Build comprehensive working capital forecast
	/// ```
	///
	/// ## Identifying Working Capital Efficiency Opportunities
	///
	/// ```swift
	/// let wcComponents = cashFlowStmt.workingCapitalChangesByComponent
	///
	/// // Compare changes to identify trends
	/// for (role, changes) in wcComponents {
	///     let q1toQ2 = changes[q2]! - changes[q1]!
	///
	///     switch role {
	///     case .changeInAccountsReceivable:
	///         if q1toQ2 > 0 {
	///             print("⚠️ AR build accelerating - review credit policies")
	///         }
	///
	///     case .changeInInventory:
	///         if q1toQ2 > 0 {
	///             print("⚠️ Inventory build accelerating - check for obsolescence")
	///         }
	///
	///     case .changeInAccountsPayable:
	///         if q1toQ2 < 0 {
	///             print("⚠️ AP declining - negotiate better payment terms")
	///         }
	///
	///     default:
	///         break
	///     }
	/// }
	/// ```
	///
	/// ## Return Value
	///
	/// Dictionary where:
	/// - **Keys**: ``CashFlowRole`` for each working capital component
	/// - **Values**: ``TimeSeries`` of period-over-period changes
	/// - Only includes roles where `usesChangeInBalance == true`
	///
	/// **Note:** The first period will have a change value (diff from period 0 to period 1).
	/// This is automatically calculated by `TimeSeries.diff()`.
	///
	/// - Returns: Dictionary mapping cash flow roles to their period changes
	/// - SeeAlso: ``workingCapitalChanges``
	/// - SeeAlso: ``CashFlowRole/usesChangeInBalance``
	public var workingCapitalChangesByComponent: [CashFlowRole: TimeSeries<T>] {
		var components: [CashFlowRole: TimeSeries<T>] = [:]

		// Filter to working capital accounts only
		let wcAccounts = accounts.filter { $0.cashFlowRole?.usesChangeInBalance == true }

		// Get unique roles
		let wcRoles = Set(wcAccounts.compactMap { $0.cashFlowRole })

		for role in wcRoles {
			// Get all accounts for this role
			let accountsForRole = wcAccounts.filter { $0.cashFlowRole == role }

			if !accountsForRole.isEmpty {
				// Aggregate balances for this role
				let aggregatedBalance = FinancialStatementHelpers.aggregateAccounts(
					accountsForRole,
					periods: periods
				)

				// Apply diff() to get period-over-period changes
				let changes = aggregatedBalance.diff()
				components[role] = changes
			}
		}

		return components
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

