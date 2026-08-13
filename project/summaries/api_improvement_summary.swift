#!/usr/bin/env swift

import Foundation

/*
 API Improvement: High-Level Ratio Functions Using Aggregated Accounts

 ## The Problem

 The original API required users to manually:
 1. Extract aggregated debt from balance sheet
 2. Wrap it in an Account struct
 3. Find interest expense account
 4. Pass everything to the function

 This was inconsistent with other ratio functions like returnOnAssets(),
 returnOnEquity(), etc., which just take financial statements directly.

 ## The Solution

 Added high-level overloads that follow the established pattern:
 - Take financial statements as parameters
 - Use aggregated properties internally
 - Automatically find required accounts
 - Return calculated ratios

 ## Before (Low-Level API - Still Available)

 ```swift
 // Manual extraction required
 let totalDebtTS = balanceSheet.interestBearingDebt

 // Manual account wrapping required
 let debtAccount = Account(
     name: "Total Interest-Bearing Debt",
     timeSeries: totalDebtTS,
     role: .longTermDebt
 )

 // Manual search for interest expense
 let interestAccount = incomeStatement.expenseAccounts.first {
     $0.name.contains("Interest")
 }!

 // Finally, calculate DSCR
 let dscr = debtServiceCoverage(
     incomeStatement: incomeStatement,
     balanceSheet: balanceSheet,
     debtAccount: debtAccount,
     interestAccount: interestAccount
 )
 ```

 ## After (High-Level API - Recommended)

 ```swift
 // Simple! Just pass the financial statements
 let dscr = try debtServiceCoverage(
     incomeStatement: incomeStatement,
     balanceSheet: balanceSheet
 )

 // Or get all solvency ratios at once (DSCR now auto-calculated!)
 let solvency = solvencyRatios(
     incomeStatement: incomeStatement,
     balanceSheet: balanceSheet
 )

 print("DSCR: \(solvency.debtServiceCoverage![q1]!)x")
 ```

 ## What Changed

 ### 1. New High-Level debtServiceCoverage() Overload

 ```swift
 public func debtServiceCoverage<T: Real & Sendable>(
     incomeStatement: IncomeStatement<T>,
     balanceSheet: BalanceSheet<T>
 ) throws -> TimeSeries<T>
 ```

 Automatically:
 - Uses `balanceSheet.interestBearingDebt` (aggregates all debt)
 - Finds interest expense in income statement
 - Derives principal payments from debt changes
 - Returns DSCR

 ### 2. Updated solvencyRatios() to Auto-Calculate DSCR

 Previously: DSCR was nil unless you manually passed payment data
 Now: DSCR automatically calculated from balance sheet if not provided

 ```swift
 // Old behavior:
 let solvency = solvencyRatios(incomeStatement, balanceSheet)
 solvency.debtServiceCoverage  // ❌ Was nil!

 // New behavior:
 let solvency = solvencyRatios(incomeStatement, balanceSheet)
 solvency.debtServiceCoverage  // ✅ Automatically calculated!
 ```

 ## API Design Consistency

 Now all ratio functions follow the same pattern:

 ```swift
 // Profitability ratios
 let roa = returnOnAssets(incomeStatement: is, balanceSheet: bs)
 let roe = returnOnEquity(incomeStatement: is, balanceSheet: bs)
 let roic = returnOnInvestedCapital(incomeStatement: is, balanceSheet: bs, taxRate: 0.21)

 // Efficiency ratios
 let assetTurnover = assetTurnover(incomeStatement: is, balanceSheet: bs)
 let invTurnover = try inventoryTurnover(incomeStatement: is, balanceSheet: bs)

 // Coverage ratios (NEW - now consistent!)
 let interestCov = try interestCoverage(incomeStatement: is)
 let dscr = try debtServiceCoverage(incomeStatement: is, balanceSheet: bs)

 // Comprehensive ratio structs
 let profitability = profitabilityRatios(incomeStatement: is, balanceSheet: bs)
 let efficiency = efficiencyRatios(incomeStatement: is, balanceSheet: bs)
 let liquidity = liquidityRatios(balanceSheet: bs)
 let solvency = solvencyRatios(incomeStatement: is, balanceSheet: bs)  // ← DSCR included!
 ```

 ## Benefits

 1. ✅ **Consistency** - Matches pattern of other ratio functions
 2. ✅ **Simplicity** - No manual account extraction/wrapping
 3. ✅ **Correctness** - Uses aggregated debt (LT + CPLTD + short-term)
 4. ✅ **Backward Compatibility** - Low-level API still available for advanced use
 5. ✅ **Automatic CPLTD Handling** - Correctly tracks principal from all debt accounts

 ## Advanced Use Cases

 The low-level API is still available when you need:
 - Custom debt accounts (exclude certain debt types)
 - Manual payment schedules (refinancing, off-balance-sheet)
 - Specific interest expense accounts

 Just use the overloads with explicit account parameters.
 */

print("✓ API Improvement: High-Level Ratio Functions")
print("")
print("Before:")
print("  let totalDebtTS = balanceSheet.interestBearingDebt")
print("  let debtAccount = Account(...)")
print("  let interestAccount = incomeStatement.expenseAccounts.first { ... }!")
print("  let dscr = debtServiceCoverage(..., debtAccount: ..., interestAccount: ...)")
print("")
print("After:")
print("  let dscr = try debtServiceCoverage(")
print("      incomeStatement: incomeStatement,")
print("      balanceSheet: balanceSheet")
print("  )")
print("")
print("solvencyRatios() now auto-calculates DSCR!")
print("All ratio functions now follow consistent pattern ✓")
