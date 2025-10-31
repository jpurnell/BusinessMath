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
	public struct BalanceSheetBalances<T>: ValidationRule where T: Real & Sendable & Codable & Comparable {
		public typealias Value = BalanceSheet<T>

		private let tolerance: T

		/// Creates a balance sheet balance validation rule.
		///
		/// - Parameter tolerance: The tolerance for rounding errors. Defaults to 0.01.
		public init(tolerance: T = 0.01) {
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

				let diff = abs(assets - (liabilities + equity))

				if diff > tolerance {
					errors.append(ValidationError(
						field: "\(context.fieldName) - \(period.label)",
						value: [
							"Assets": assets,
							"Liabilities": liabilities,
							"Equity": equity,
							"Difference": diff
						],
						rule: "BalanceSheetBalances",
						message: "Assets do not equal Liabilities + Equity (difference: \(diff))",
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
		///   - maxMargin: Maximum expected gross margin. Defaults to 1.00 (100%).
		public init(minMargin: T = -0.20, maxMargin: T = 1.00) {
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
}
