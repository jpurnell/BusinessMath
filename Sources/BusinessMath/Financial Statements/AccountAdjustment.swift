//
//  AccountAdjustment.swift
//  BusinessMath
//
//  Created for v2.0.0 Pro Forma Adjustment System
//

import Foundation
import Numerics

/// A pro forma adjustment to an account's time series values.
///
/// `AccountAdjustment` represents normalized adjustments applied to financial accounts
/// to calculate adjusted EBITDA or other pro forma metrics. Common in private equity
/// quality of earnings analyses and LBO valuations.
///
/// ## Business Context
///
/// PE operators and investors use pro forma adjustments to normalize financial statements
/// by removing one-time items and adjusting for run-rate performance. This provides a
/// clearer picture of sustainable, recurring earnings.
///
/// ## Common Adjustment Types
///
/// - **Addbacks**: Non-recurring expenses added back to EBITDA (legal fees, restructuring)
/// - **Owner Compensation**: Normalizing excess owner compensation to market rates
/// - **One-Time Charges**: Non-recurring items (acquisition costs, facility closures)
/// - **Normalized Expenses**: Adjusting expenses to sustainable run rates
///
/// ## Example Usage
///
/// ```swift
/// // Quality of Earnings: Add back one-time legal settlement
/// let legalSettlement = AccountAdjustment(
///     adjustmentType: .addback,
///     amount: TimeSeries(periods: [q1], values: [250_000]),
///     description: "One-time legal settlement - non-recurring",
///     metadata: ["category": "legal", "verified": "true"]
/// )
///
/// // Apply adjustment to legal expense account
/// let adjustedLegal = legalExpense.applying(adjustment: legalSettlement)
///
/// // Calculate adjusted EBITDA
/// let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: [legalSettlement])
/// ```
///
/// ## LBO Use Case
///
/// ```swift
/// // Normalize owner compensation for market rates
/// let ownerSalary = AccountAdjustment(
///     adjustmentType: .ownerCompensation,
///     amount: TimeSeries(periods: periods, values: [150_000, 150_000, 150_000, 150_000]),
///     description: "Normalize owner compensation from $400K to market rate $250K",
///     metadata: ["market_rate": "$250K", "excess": "$150K"]
/// )
///
/// // Add back non-recurring acquisition costs
/// let acquisitionCosts = AccountAdjustment(
///     adjustmentType: .oneTimeCharge,
///     amount: TimeSeries(periods: [q1], values: [500_000]),
///     description: "Acquisition-related legal and advisory fees",
///     metadata: ["deal": "Acme Corp acquisition"]
/// )
///
/// // Calculate normalized EBITDA for valuation
/// let normalizedEBITDA = incomeStmt.adjustedEBITDA(
///     adjustments: [ownerSalary, acquisitionCosts]
/// )
/// ```
///
/// - SeeAlso: ``IncomeStatement/adjustedEBITDA(adjustments:)``
/// - SeeAlso: ``Account/applying(adjustment:)``
public struct AccountAdjustment<T: Real & Sendable>: Codable, Sendable where T: Codable {

	/// The type of adjustment being applied.
	public let adjustmentType: AdjustmentType

	/// The adjustment amounts over time.
	///
	/// Positive values increase the account balance (addbacks).
	/// Negative values decrease the account balance.
	public let amount: TimeSeries<T>

	/// Human-readable description of the adjustment.
	///
	/// Should explain the business rationale and why the adjustment is appropriate.
	/// Used in quality of earnings memos and investor presentations.
	public let description: String

	/// Additional metadata about the adjustment.
	///
	/// Useful for tracking supporting documentation, approval status, or categorization.
	///
	/// ## Example Metadata
	///
	/// ```swift
	/// [
	///     "approvedBy": "Investment Committee",
	///     "supportingDoc": "QoE_Analysis_v3.pdf",
	///     "confidence": "high",
	///     "recurring": "false"
	/// ]
	/// ```
	public let metadata: [String: String]

	/// Categories of pro forma adjustments.
	///
	/// Each type represents a different rationale for normalizing financial statements.
	public enum AdjustmentType: String, Codable, Sendable, CaseIterable {

		/// Expense addback to increase EBITDA.
		///
		/// Used for non-recurring or non-operating expenses that should be excluded
		/// from normalized earnings. These are added back to EBITDA.
		///
		/// ## Examples
		/// - Legal settlements (one-time)
		/// - Restructuring charges
		/// - Asset impairments
		/// - Acquisition-related costs
		/// - COVID-related expenses
		case addback

		/// Normalized expense adjustment.
		///
		/// Adjusts expenses to sustainable run rates when historical amounts are
		/// not representative of ongoing operations.
		///
		/// ## Examples
		/// - Normalizing temporarily inflated costs
		/// - Adjusting for partial-period costs
		/// - Pro-rating seasonal variations
		case normalizedExpense

		/// One-time charge or revenue.
		///
		/// Non-recurring items that distort historical performance and should be
		/// excluded from normalized metrics.
		///
		/// ## Examples
		/// - Large one-time gains/losses
		/// - Facility closure costs
		/// - Product discontinuation charges
		/// - Insurance recoveries
		case oneTimeCharge

		/// Owner/related-party compensation normalization.
		///
		/// Adjusts owner compensation or related-party transactions to market rates.
		/// Common in SMB acquisitions where owner salary may be above/below market.
		///
		/// ## Examples
		/// - Excess owner salary above market rate
		/// - Below-market rent paid to owner-controlled entity
		/// - Family member payroll normalization
		case ownerCompensation

		/// Other adjustment types.
		///
		/// Catch-all for adjustments that don't fit standard categories.
		/// Use sparingly and document thoroughly in description.
		case other
	}

	/// Creates a new pro forma adjustment.
	///
	/// - Parameters:
	///   - adjustmentType: The category of adjustment
	///   - amount: Time series of adjustment amounts (positive = addback)
	///   - description: Business rationale for the adjustment
	///   - metadata: Optional supporting information (default: empty)
	public init(
		adjustmentType: AdjustmentType,
		amount: TimeSeries<T>,
		description: String,
		metadata: [String: String] = [:]
	) {
		self.adjustmentType = adjustmentType
		self.amount = amount
		self.description = description
		self.metadata = metadata
	}
}

// MARK: - Account Extensions

extension Account {

	/// Applies a single pro forma adjustment to create an adjusted account.
	///
	/// Returns a new account with the adjustment applied to its time series values.
	/// The original account remains unchanged.
	///
	/// ## Business Use Case
	///
	/// Use when normalizing a specific expense account before calculating adjusted EBITDA.
	///
	/// ## Example
	///
	/// ```swift
	/// // Original legal expense: $500K (includes $250K one-time settlement)
	/// let legalExpense = try Account(
	///     entity: company,
	///     name: "Legal Fees",
	///     incomeStatementRole: .operatingExpenseOther,
	///     timeSeries: TimeSeries(periods: [q1], values: [500_000])
	/// )
	///
	/// // Add back one-time settlement
	/// let settlement = AccountAdjustment(
	///     adjustmentType: .addback,
	///     amount: TimeSeries(periods: [q1], values: [250_000]),
	///     description: "One-time litigation settlement"
	/// )
	///
	/// // Adjusted legal expense: $250K (normalized run rate)
	/// let adjustedLegal = legalExpense.applying(adjustment: settlement)
	/// ```
	///
	/// - Parameter adjustment: The adjustment to apply
	/// - Returns: New account with adjusted time series values
	/// - Note: Original account is unchanged (immutable operation)
	public func applying(adjustment: AccountAdjustment<T>) -> Account<T> {
		// Build adjusted values period by period
		let adjustedValues = self.timeSeries.periods.map { period -> T in
			let baseValue = self.timeSeries[period]!
			let adjustmentValue = adjustment.amount[period] ?? T(0)
			return baseValue + adjustmentValue
		}

		let adjustedTimeSeries = TimeSeries(
			periods: self.timeSeries.periods,
			values: adjustedValues
		)

		// Create new account with adjusted values
		// All other properties (name, role, metadata) remain the same
		return try! Account(
			entity: self.entity,
			name: self.name,
			incomeStatementRole: self.incomeStatementRole,
			balanceSheetRole: self.balanceSheetRole,
			cashFlowRole: self.cashFlowRole,
			timeSeries: adjustedTimeSeries,
			metadata: self.metadata
		)
	}

	/// Applies multiple pro forma adjustments to create an adjusted account.
	///
	/// Applies all adjustments sequentially and returns the net adjusted account.
	/// Useful when multiple normalization items apply to a single account.
	///
	/// ## Business Use Case
	///
	/// Use when an account has multiple non-recurring items or normalization needs.
	///
	/// ## Example
	///
	/// ```swift
	/// // G&A expense with multiple one-time items
	/// let gnaExpense = try Account(
	///     entity: company,
	///     name: "General & Administrative",
	///     incomeStatementRole: .generalAndAdministrative,
	///     timeSeries: gnaData
	/// )
	///
	/// // Multiple adjustments
	/// let adjustments = [
	///     AccountAdjustment(
	///         adjustmentType: .oneTimeCharge,
	///         amount: TimeSeries(periods: [q1], values: [100_000]),
	///         description: "Relocation costs"
	///     ),
	///     AccountAdjustment(
	///         adjustmentType: .ownerCompensation,
	///         amount: TimeSeries(periods: periods, values: [25_000, 25_000, 25_000, 25_000]),
	///         description: "Normalize CFO comp to market"
	///     )
	/// ]
	///
	/// let adjustedGNA = gnaExpense.applying(adjustments: adjustments)
	/// ```
	///
	/// - Parameter adjustments: Array of adjustments to apply
	/// - Returns: New account with all adjustments applied
	public func applying(adjustments: [AccountAdjustment<T>]) -> Account<T> {
		guard !adjustments.isEmpty else { return self }

		// Build adjusted values period by period
		let adjustedValues = self.timeSeries.periods.map { period -> T in
			let baseValue = self.timeSeries[period]!

			// Sum all adjustment values for this period
			let totalAdjustmentForPeriod = adjustments.reduce(T(0)) { sum, adj in
				let adjustmentValue = adj.amount[period] ?? T(0)
				return sum + adjustmentValue
			}

			return baseValue + totalAdjustmentForPeriod
		}

		let adjustedTimeSeries = TimeSeries(
			periods: self.timeSeries.periods,
			values: adjustedValues
		)

		return try! Account(
			entity: self.entity,
			name: self.name,
			incomeStatementRole: self.incomeStatementRole,
			balanceSheetRole: self.balanceSheetRole,
			cashFlowRole: self.cashFlowRole,
			timeSeries: adjustedTimeSeries,
			metadata: self.metadata
		)
	}
}

// MARK: - IncomeStatement Extensions

extension IncomeStatement {

	/// Calculates adjusted EBITDA after applying pro forma adjustments.
	///
	/// Returns EBITDA with the specified adjustments applied. Commonly used in PE/LBO
	/// valuations and quality of earnings analyses to calculate normalized earnings.
	///
	/// ## Business Context
	///
	/// Adjusted EBITDA (also called "Normalized EBITDA" or "Pro Forma EBITDA") removes
	/// non-recurring items and normalizes expenses to show sustainable earnings power.
	/// This is critical for:
	/// - LBO valuations (purchase price = multiple × adjusted EBITDA)
	/// - Debt covenant calculations
	/// - Management incentive comp metrics
	/// - Investor presentations
	///
	/// ## Formula
	///
	/// ```
	/// Adjusted EBITDA = EBITDA + Sum of Adjustments
	/// ```
	///
	/// Where adjustments are typically positive (addbacks) but can be negative.
	///
	/// ## Example: Quality of Earnings Analysis
	///
	/// ```swift
	/// let incomeStmt = try IncomeStatement(entity: target, periods: periods, accounts: accounts)
	///
	/// // Define pro forma adjustments
	/// let adjustments = [
	///     // Add back one-time legal settlement
	///     AccountAdjustment(
	///         adjustmentType: .addback,
	///         amount: TimeSeries(periods: [q1], values: [250_000]),
	///         description: "Non-recurring litigation settlement"
	///     ),
	///     // Normalize owner compensation
	///     AccountAdjustment(
	///         adjustmentType: .ownerCompensation,
	///         amount: TimeSeries(periods: periods, values: [150_000, 150_000, 150_000, 150_000]),
	///         description: "Excess owner comp above $250K market rate"
	///     ),
	///     // Add back acquisition costs
	///     AccountAdjustment(
	///         adjustmentType: .oneTimeCharge,
	///         amount: TimeSeries(periods: [q4], values: [500_000]),
	///         description: "Deal-related advisory fees"
	///     )
	/// ]
	///
	/// // Calculate metrics
	/// let reportedEBITDA = incomeStmt.ebitda
	/// let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)
	///
	/// // LBO valuation at 6.0× adjusted EBITDA
	/// let valuationMultiple = 6.0
	/// let enterpriseValue = adjustedEBITDA.map { $0 * valuationMultiple }
	/// ```
	///
	/// ## Investor Presentation
	///
	/// ```swift
	/// // Bridge from reported to adjusted EBITDA
	/// print("Reported EBITDA: $\(reportedEBITDA[q4]!)")
	/// for adjustment in adjustments {
	///     print("  + \(adjustment.description): $\(adjustment.amount[q4] ?? 0)")
	/// }
	/// print("Adjusted EBITDA: $\(adjustedEBITDA[q4]!)")
	/// ```
	///
	/// ## Important Notes
	///
	/// - Original `ebitda` property remains unchanged
	/// - Adjustments must have matching periods with the income statement
	/// - This is opt-in: use only when needed for normalized metrics
	/// - Over-adjusting reduces credibility; document thoroughly
	///
	/// - Parameter adjustments: Array of pro forma adjustments to apply
	/// - Returns: Time series of adjusted EBITDA values
	/// - SeeAlso: ``ebitda`` for unadjusted EBITDA
	/// - SeeAlso: ``AccountAdjustment``
	public func adjustedEBITDA(adjustments: [AccountAdjustment<T>]) -> TimeSeries<T> {
		guard !adjustments.isEmpty else {
			return self.ebitda
		}

		// Build adjusted EBITDA period by period
		let adjustedValues = self.periods.map { period -> T in
			let baseEBITDA = self.ebitda[period]!

			// Sum all adjustment values for this period
			let totalAdjustmentForPeriod = adjustments.reduce(T(0)) { sum, adj in
				let adjustmentValue = adj.amount[period] ?? T(0)
				return sum + adjustmentValue
			}

			return baseEBITDA + totalAdjustmentForPeriod
		}

		return TimeSeries(periods: self.periods, values: adjustedValues)
	}
}
