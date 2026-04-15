//
//  StatementIntegration.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - ValidationResult

/// The result of validating three-statement linkage consistency.
///
/// Contains individual pass/fail flags for each validation check,
/// plus an aggregate `allValid` flag and a list of human-readable issues.
///
/// ## Example
/// ```swift
/// let result = integration.validate(tolerance: 0.01)
/// if !result.allValid {
///     for issue in result.issues {
///         print("Issue: \(issue)")
///     }
/// }
/// ```
public struct StatementValidationResult<T: Real & Sendable>: Sendable where T: Codable {

    /// Whether the balance sheet equation (Assets = Liabilities + Equity) holds each period.
    public let balanceSheetValid: Bool

    /// Whether net income flows correctly from the income statement to retained earnings.
    public let netIncomeFlowValid: Bool

    /// True only if all individual checks pass.
    public let allValid: Bool

    /// Human-readable descriptions of any issues found.
    public let issues: [String]

    /// Creates a validation result.
    ///
    /// - Parameters:
    ///   - balanceSheetValid: Whether the balance sheet equation holds
    ///   - netIncomeFlowValid: Whether net income flows to retained earnings correctly
    ///   - issues: Descriptions of any issues found
    public init(
        balanceSheetValid: Bool,
        netIncomeFlowValid: Bool,
        issues: [String]
    ) {
        self.balanceSheetValid = balanceSheetValid
        self.netIncomeFlowValid = netIncomeFlowValid
        self.allValid = balanceSheetValid && netIncomeFlowValid
        self.issues = issues
    }
}

// MARK: - StatementIntegration

/// A three-statement linkage engine that validates consistency between
/// an income statement, balance sheet, and cash flow statement.
///
/// `StatementIntegration` enforces the fundamental accounting relationships:
/// - Net income from the income statement flows to retained earnings on the balance sheet
/// - The balance sheet equation (Assets = Liabilities + Equity) holds each period
///
/// ## Example
///
/// ```swift
/// let integration = StatementIntegration(
///     incomeStatement: incomeStmt,
///     balanceSheet: balanceSheet,
///     cashFlowStatement: cashFlowStmt
/// )
///
/// let result = integration.validate(tolerance: 0.01)
/// if result.allValid {
///     print("All three statements are consistent")
/// } else {
///     for issue in result.issues {
///         print("Issue: \(issue)")
///     }
/// }
/// ```
public struct StatementIntegration<T: Real & Sendable>: Sendable where T: Codable {

    /// The income statement being validated.
    public let incomeStatement: IncomeStatement<T>

    /// The balance sheet being validated.
    public let balanceSheet: BalanceSheet<T>

    /// The cash flow statement being validated.
    public let cashFlowStatement: CashFlowStatement<T>

    /// Creates a new statement integration validator.
    ///
    /// - Parameters:
    ///   - incomeStatement: The income statement
    ///   - balanceSheet: The balance sheet
    ///   - cashFlowStatement: The cash flow statement
    public init(
        incomeStatement: IncomeStatement<T>,
        balanceSheet: BalanceSheet<T>,
        cashFlowStatement: CashFlowStatement<T>
    ) {
        self.incomeStatement = incomeStatement
        self.balanceSheet = balanceSheet
        self.cashFlowStatement = cashFlowStatement
    }

    /// Validates that net income flows correctly from the income statement
    /// to retained earnings changes on the balance sheet.
    ///
    /// For each consecutive pair of periods, checks that:
    /// ```
    /// RetainedEarnings[t] - RetainedEarnings[t-1] == NetIncome[t]
    /// ```
    /// within the specified tolerance.
    ///
    /// If only one period exists, validation passes vacuously (no transitions to check).
    ///
    /// - Parameter tolerance: Maximum acceptable difference between expected and actual values
    /// - Returns: `true` if net income flows correctly to retained earnings
    public func validateNetIncomeFlow(tolerance: T) -> Bool {
        return netIncomeFlowIssues(tolerance: tolerance).isEmpty
    }

    /// Validates that Assets = Liabilities + Equity for each period.
    ///
    /// - Parameter tolerance: Maximum acceptable difference
    /// - Returns: `true` if the balance sheet equation holds for all periods
    public func validateBalanceSheetEquation(tolerance: T) -> Bool {
        return balanceSheetEquationIssues(tolerance: tolerance).isEmpty
    }

    /// Returns a comprehensive validation result covering all checks.
    ///
    /// - Parameter tolerance: Maximum acceptable difference for numeric comparisons
    /// - Returns: A ``ValidationResult`` with pass/fail flags and descriptive issues
    public func validate(tolerance: T) -> StatementValidationResult<T> {
        let bsIssues = balanceSheetEquationIssues(tolerance: tolerance)
        let niIssues = netIncomeFlowIssues(tolerance: tolerance)

        let allIssues = bsIssues + niIssues

        return StatementValidationResult(
            balanceSheetValid: bsIssues.isEmpty,
            netIncomeFlowValid: niIssues.isEmpty,
            issues: allIssues
        )
    }

    // MARK: - Private Helpers

    /// Checks the balance sheet equation for each period and returns any issues found.
    private func balanceSheetEquationIssues(tolerance: T) -> [String] {
        var issues: [String] = []
        let assets = balanceSheet.totalAssets
        let liabilities = balanceSheet.totalLiabilities
        let equity = balanceSheet.totalEquity

        for period in balanceSheet.periods {
            guard let assetValue = assets[period],
                  let liabilityValue = liabilities[period],
                  let equityValue = equity[period] else {
                continue
            }

            let liabilitiesAndEquity = liabilityValue + equityValue
            let difference: T
            if assetValue >= liabilitiesAndEquity {
                difference = assetValue - liabilitiesAndEquity
            } else {
                difference = liabilitiesAndEquity - assetValue
            }

            if difference > tolerance {
                issues.append(
                    "Balance sheet equation violated in \(period): "
                    + "Assets (\(assetValue)) != Liabilities + Equity (\(liabilitiesAndEquity))"
                )
            }
        }

        return issues
    }

    /// Checks that net income flows to retained earnings changes and returns any issues found.
    private func netIncomeFlowIssues(tolerance: T) -> [String] {
        var issues: [String] = []
        let netIncome = incomeStatement.netIncome

        // Find retained earnings accounts on the balance sheet
        let retainedEarningsAccounts = balanceSheet.accounts.filter {
            $0.balanceSheetRole == .retainedEarnings
        }

        guard !retainedEarningsAccounts.isEmpty else {
            // No retained earnings account found - cannot validate flow
            // This is not necessarily an error if the BS has no RE account
            return []
        }

        // Aggregate retained earnings (in case there are multiple RE accounts)
        let retainedEarnings = FinancialStatementHelpers.aggregateAccounts(
            retainedEarningsAccounts,
            periods: balanceSheet.periods
        )

        // Use the intersection of IS and BS periods, sorted
        let bsPeriods = balanceSheet.periods

        // Check consecutive period pairs
        guard bsPeriods.count > 1 else {
            // Single period - no transitions to validate
            return []
        }

        for i in 1..<bsPeriods.count {
            let prevPeriod = bsPeriods[i - 1]
            let currPeriod = bsPeriods[i]

            guard let rePrev = retainedEarnings[prevPeriod],
                  let reCurr = retainedEarnings[currPeriod],
                  let ni = netIncome[currPeriod] else {
                continue
            }

            let reChange = reCurr - rePrev
            let difference: T
            if reChange >= ni {
                difference = reChange - ni
            } else {
                difference = ni - reChange
            }

            if difference > tolerance {
                issues.append(
                    "Net income flow mismatch in \(currPeriod): "
                    + "RE change (\(reChange)) != Net Income (\(ni))"
                )
            }
        }

        return issues
    }
}
