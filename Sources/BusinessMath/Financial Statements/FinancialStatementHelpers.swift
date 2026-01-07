//
//  FinancialStatementHelpers.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/6/26.
//

import Foundation
import Numerics

/// Shared helper functions for financial statement operations.
///
/// This file contains common functionality used across IncomeStatement, BalanceSheet,
/// and CashFlowStatement to reduce code duplication and ensure consistency.
enum FinancialStatementHelpers {

	// MARK: - Account Aggregation

	/// Aggregates multiple accounts into a single time series by summing their values.
	///
	/// This function is used by all financial statements to combine multiple accounts
	/// (e.g., multiple revenue accounts, multiple asset accounts) into a single total.
	///
	/// - Parameters:
	///   - accounts: Array of accounts to aggregate
	///   - periods: The periods for the financial statement
	///
	/// - Returns: A `TimeSeries` containing the sum of all account values, or zeros if empty
	///
	/// ## Example
	/// ```swift
	/// let accounts = [revenueAccount1, revenueAccount2, revenueAccount3]
	/// let totalRevenue = FinancialStatementHelpers.aggregateAccounts(accounts, periods: periods)
	/// ```
	static func aggregateAccounts<T: Real & Sendable & Codable>(
		_ accounts: [Account<T>],
		periods: [Period]
	) -> TimeSeries<T> {
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

	// MARK: - Validation Helpers

	/// Validates that all accounts belong to the specified entity.
	///
	/// - Parameters:
	///   - accounts: Accounts to validate
	///   - entity: The expected entity
	///
	/// - Throws: ``FinancialModelError/entityMismatch(expected:found:accountName:)`` if any account
	///   has a different entity
	static func validateEntityConsistency<T>(
		accounts: [Account<T>],
		entity: Entity
	) throws {
		for account in accounts {
			guard account.entity == entity else {
				throw FinancialModelError.entityMismatch(
					expected: entity.id,
					found: account.entity.id,
					accountName: account.name
				)
			}
		}
	}

	/// Validates that all accounts contain data for all required periods.
	///
	/// - Parameters:
	///   - accounts: Accounts to validate
	///   - periods: The required periods
	///
	/// - Throws: ``FinancialModelError/periodMismatch(accountName:missing:)`` if any account
	///   is missing data for one or more periods
	static func validatePeriodConsistency<T>(
		accounts: [Account<T>],
		periods: [Period]
	) throws {
		for account in accounts {
			let accountPeriods = Set(account.timeSeries.periods)
			let statementPeriods = Set(periods)
			let missing = statementPeriods.subtracting(accountPeriods)

			if !missing.isEmpty {
				throw FinancialModelError.periodMismatch(
					accountName: account.name,
					missing: Array(missing).sorted()
				)
			}
		}
	}
}
