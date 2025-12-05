//
//  FinancialValidation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - FinancialValidation

/// Financial-specific validation rules.
///
/// `FinancialValidation` provides validation rules specific to financial
/// statements and metrics, ensuring data integrity and flagging unusual patterns.
public enum FinancialValidation {

	// MARK: - Balance Sheet Balances

	/// Validates that a balance sheet balances (Assets = Liabilities + Equity).
	public struct BalanceSheetBalances<T>: ValidationRule where T: Real & Sendable & Codable & Comparable & FloatingPoint {
			public typealias Value = BalanceSheet<T>
			
			@inline(__always)
			private func total(_ accounts: [Account<T>], _ period: Period) -> T {
				accounts.reduce(T.zero) { sum, account in
					let v: T = account.timeSeries[period] ?? T.zero
					return sum + v
				}
			}
			
			@inline(__always)
			private func withinTolerance(_ diff: T, tolerance tol: T, scale: T) -> Bool {
				// Epsilon is at least one ulp at the current scale, or a tiny fraction of tol
				// Avoid Double literal conversion: compute 1e-12 as 1 / 1_000_000_000 in T
				let rel = tol * (T(Int(1e-12)))
				// Scale-aware epsilon: at least one ulp at this scale, or a tiny fraction of tolerance
				let eps = max(T.ulpOfOne * scale, rel)
				return diff <= tol + eps
			}

			public let tolerance: T

			/// Creates a balance sheet balance validation rule.
			///
			/// - Parameter tolerance: The tolerance for rounding errors. Defaults to 0.01.
			public init(tolerance: T = .zero) {
				self.tolerance = tolerance
			}

			public func validate(_ value: BalanceSheet<T>?, context: ValidationContext) -> ValidationResult {
				guard let balanceSheet = value else {
					return .invalid([ValidationError(
						field: context.fieldName,
						value: "nil",
						rule: "BalanceSheetBalances",
						message: "Balance sheet cannot be nil"
					)])
				}

				var errors: [ValidationError] = []

				// Check each period
				for period in balanceSheet.periods {
					guard let assets = balanceSheet.totalAssets[period],
						  let liabilities = balanceSheet.totalLiabilities[period],
						  let equity = balanceSheet.totalEquity[period] else {
						continue
					}
					let lhs = assets.isNaN ? 0 : assets
					let rhs = (liabilities + equity)

					let diff = abs(lhs - rhs)
					
					// Scale-aware epsilon to absorb binary FP noise near the threshold.
					// Build a reasonable "scale" for ulp-based epsilon.
					let s1 = max(abs(lhs), abs(rhs))
					let s2 = max(abs(diff), max(tolerance, T(1)))
					let scale = max(s1, s2)
					
					if !withinTolerance(diff, tolerance: tolerance, scale: scale) {
						let msg = "Assets do not equal Liabilities + Equity (difference: \(diff))."
						errors.append(ValidationError(
							field: "\(context.fieldName) - \(period.label)",
							value: [
								"Assets": assets,
								"Liabilities": liabilities,
								"Equity": equity,
								"Difference": diff
							],
							rule: "BalanceSheetBalances",
							message: msg,
							suggestion: "Check if all accounts are properly classified and valued"
						))
					}
				}

				return errors.isEmpty ? .valid : .invalid(errors)
			}
		}
	
	

	// MARK: - Positive Revenue

	/// Validates that all revenue values are positive.
	public struct PositiveRevenue<T>: ValidationRule where T: Real & Sendable & Codable & Comparable {
		public typealias Value = IncomeStatement<T>

		public init() {}

		public func validate(_ value: IncomeStatement<T>?, context: ValidationContext) -> ValidationResult {
			guard let incomeStatement = value else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "PositiveRevenue",
					message: "Income statement cannot be nil"
				)])
			}

			var errors: [ValidationError] = []

			// Check each period
			for period in incomeStatement.periods {
				guard let revenue = incomeStatement.totalRevenue[period] else {
					continue
				}

				if revenue < .zero {
					errors.append(ValidationError(
						field: "\(context.fieldName) - \(period.label)",
						value: revenue,
						rule: "PositiveRevenue",
						message: "Revenue is negative: \(revenue)",
						suggestion: "Check if revenue was entered as a negative or if this is a refund/return"
					))
				}
			}

			return errors.isEmpty ? .valid : .invalid(errors)
		}
	}

	// MARK: - Reasonable Gross Margin

	/// Validates that gross margin is reasonable (warns if unusual).
	public struct ReasonableGrossMargin<T>: ValidationRule where T: Real & Sendable & Codable & Comparable & FloatingPoint {
		public typealias Value = IncomeStatement<T>

		private let minMargin: T
		private let maxMargin: T

		/// Creates a reasonable gross margin validation rule.
		///
		/// - Parameters:
		///   - minMargin: Minimum expected gross margin. Defaults to -0.20 (20% loss).
		///   - maxMargin: Maximum expected gross margin. Defaults to 0.90 (90%).
		public init(minMargin: T = -0.20, maxMargin: T = 0.90) {
			self.minMargin = minMargin
			self.maxMargin = maxMargin
		}

		public func validate(_ value: IncomeStatement<T>?, context: ValidationContext) -> ValidationResult {
			guard let incomeStatement = value else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "ReasonableGrossMargin",
					message: "Income statement cannot be nil"
				)])
			}

			var warnings: [ValidationError] = []

			// Check each period
			for period in incomeStatement.periods {
				guard let revenue = incomeStatement.totalRevenue[period],
					  revenue > .zero else {
					continue
				}

				guard let grossProfit = incomeStatement.grossProfit[period] else {
					continue
				}

				let margin = grossProfit / revenue

				if margin <= minMargin || margin >= maxMargin {
					warnings.append(ValidationError(
						field: "\(context.fieldName) - \(period.label)",
						value: margin,
						rule: "ReasonableGrossMargin",
						message: "Unusual gross margin: \(margin) (expected between \(minMargin) and \(maxMargin))",
						suggestion: "Review COGS calculations and revenue recognition"
					))
				}
			}

			return warnings.isEmpty ? .valid : .validWithWarnings(warnings)
		}
	}

	// MARK: - Cash Flow Reconciliation

	/// Validates that cash flow statement reconciles with balance sheet cash changes.
	///
	/// This rule checks that the net cash flow from the cash flow statement matches
	/// the change in cash and cash equivalents on the balance sheet between periods.
	public struct CashFlowReconciliation<T>: ValidationRule where T: Real & Sendable & Codable & Comparable {
		public typealias Value = (cashFlowStatement: CashFlowStatement<T>, balanceSheet: BalanceSheet<T>)

		private let tolerance: T

		/// Creates a cash flow reconciliation validation rule.
		///
		/// - Parameter tolerance: The tolerance for rounding errors. Defaults to 0.01.
		public init(tolerance: T = 0.01) {
			self.tolerance = tolerance
		}

		public func validate(_ value: (cashFlowStatement: CashFlowStatement<T>, balanceSheet: BalanceSheet<T>)?, context: ValidationContext) -> ValidationResult {
			guard let value = value else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "nil",
					rule: "CashFlowReconciliation",
					message: "Cash flow statement and balance sheet cannot be nil"
				)])
			}

			let cashFlowStmt = value.cashFlowStatement
			let balanceSheet = value.balanceSheet

			// Ensure entities match
			guard cashFlowStmt.entity == balanceSheet.entity else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "entity mismatch",
					rule: "CashFlowReconciliation",
					message: "Cash flow statement and balance sheet must be for the same entity"
				)])
			}

			var errors: [ValidationError] = []

			// Get cash balances from balance sheet
			let cashAccounts = balanceSheet.assetAccounts.filter { $0.assetType == .cashAndEquivalents }
			guard !cashAccounts.isEmpty else {
				return .invalid([ValidationError(
					field: context.fieldName,
					value: "no cash accounts",
					rule: "CashFlowReconciliation",
					message: "Balance sheet must have at least one cash account"
				)])
			}

			// Sum all cash accounts to get total cash per period
			var totalCash = cashAccounts[0].timeSeries
			for account in cashAccounts.dropFirst() {
				totalCash = totalCash + account.timeSeries
			}

			// Check reconciliation for each consecutive period pair
			let netCashFlow = cashFlowStmt.netCashFlow

			for i in 1..<balanceSheet.periods.count {
				let currentPeriod = balanceSheet.periods[i]
				let previousPeriod = balanceSheet.periods[i - 1]

				guard let currentCash = totalCash[currentPeriod],
					  let previousCash = totalCash[previousPeriod],
					  let periodNetCashFlow = netCashFlow[currentPeriod] else {
					continue
				}

				let cashChange = currentCash - previousCash
				let diff = abs(cashChange - periodNetCashFlow)

				if diff > tolerance {
					errors.append(ValidationError(
						field: "\(context.fieldName) - \(currentPeriod.label)",
						value: [
							"Beginning Cash": previousCash,
							"Ending Cash": currentCash,
							"Cash Change": cashChange,
							"Net Cash Flow": periodNetCashFlow,
							"Difference": diff
						],
						rule: "CashFlowReconciliation",
						message: "Cash flow does not reconcile with balance sheet (difference: \(diff))",
						suggestion: "Check that all cash flows are properly categorized and that cash accounts are complete"
					))
				}
			}

			return errors.isEmpty ? .valid : .invalid(errors)
		}
	}
}
