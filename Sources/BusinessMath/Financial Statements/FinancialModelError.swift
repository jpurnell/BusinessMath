import Foundation

/// Errors that can occur when working with financial models and statements
///
/// These errors indicate validation failures or mismatches when creating
/// financial statements, accounts, and related structures.
public enum FinancialModelError: Error, Sendable, Equatable {
	/// Account must have at least one role (incomeStatementRole, balanceSheetRole, or cashFlowRole)
	case accountMustHaveAtLeastOneRole

	/// Account is missing required role for the statement it's being added to
	///
	/// - Parameters:
	///   - statement: The statement type (incomeStatement, balanceSheet, cashFlow)
	///   - accountName: Name of the account missing the role
	case accountMissingRole(statement: StatementType, accountName: String)

	/// Entity mismatch between statement and account
	///
	/// All accounts in a statement must belong to the same entity.
	///
	/// - Parameters:
	///   - expected: The entity ID expected by the statement
	///   - found: The entity ID of the mismatched account
	///   - accountName: Name of the account with wrong entity
	case entityMismatch(expected: String, found: String, accountName: String)

	/// Period mismatch between statement and account
	///
	/// All accounts must have data for the statement's periods.
	///
	/// - Parameters:
	///   - accountName: Name of the account with mismatched periods
	///   - missing: Periods present in statement but missing in account
	case periodMismatch(accountName: String, missing: [Period])
}

/// Type of financial statement
public enum StatementType: String, Sendable {
	case incomeStatement
	case balanceSheet
	case cashFlowStatement
}

// MARK: - LocalizedError Conformance

extension FinancialModelError: LocalizedError {
    /// Human-Reaadable description of the error for debugging
        public var errorDescription: String? {
		switch self {
		case .accountMustHaveAtLeastOneRole:
			return "Account must have at least one role: incomeStatementRole, balanceSheetRole, or cashFlowRole"

		case .accountMissingRole(let statement, let accountName):
			return "Account '\(accountName)' is missing required \(statement.rawValue) role"

		case .entityMismatch(let expected, let found, let accountName):
			return "Entity mismatch: expected '\(expected)' but account '\(accountName)' has entity '\(found)'"

		case .periodMismatch(let accountName, let missing):
			let periodList = missing.map { $0.description }.joined(separator: ", ")
			return "Account '\(accountName)' is missing data for periods: \(periodList)"
		}
	}
}
