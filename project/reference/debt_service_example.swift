#!/usr/bin/env swift

import Foundation

/*
 Debt Service Coverage Ratio (DSCR) Example

 This demonstrates the improved API that automatically derives principal payments
 from balance sheet debt account changes.

 ## Before (Manual Calculation):

 ```swift
 // User had to manually calculate principal payments
 let debtBalances = [100_000, 95_000, 90_000, 85_000]
 var principalPayments: [Double] = []
 for i in 1..<debtBalances.count {
     let payment = debtBalances[i-1] - debtBalances[i]
     principalPayments.append(payment)
 }

 // Then pass them to debtServiceCoverage
 let dscr = debtServiceCoverage(
     incomeStatement: incomeStatement,
     principalPayments: TimeSeries(...),  // Had to create manually
     interestPayments: interestSeries
 )
 ```

 ## After (Automatic Derivation):

 ```swift
 // Find the accounts
 let debtAccount = balanceSheet.liabilityAccounts.first {
     $0.name.contains("Long-term Debt")
 }!

 let interestAccount = incomeStatement.expenseAccounts.first {
     $0.name.contains("Interest")
 }!

 // DSCR automatically derives principal from debt changes!
 let dscr = debtServiceCoverage(
     incomeStatement: incomeStatement,
     balanceSheet: balanceSheet,
     debtAccount: debtAccount,
     interestAccount: interestAccount
 )
 ```

 ## How Principal Derivation Works:

 The function uses `diff(lag: 1)` to compute period-over-period changes:

 ```
 Period    Debt Balance    Change (diff)    Principal Payment
 ------    ------------    -------------    -----------------
 Q1 2025    $100,000           -             (no prior period)
 Q2 2025     $95,000        -$5,000            $5,000
 Q3 2025     $90,000        -$5,000            $5,000
 Q4 2025     $85,000        -$5,000            $5,000
 ```

 Note: `diff()` returns negative values for declining balances, so we negate them
 to get positive principal payments.

 ## Edge Cases Handled:

 1. **New borrowing** (debt increases): Principal payments become negative
    - This correctly represents cash inflow from new debt

 2. **Flat debt** (refinancing): Principal payments are zero
    - Use the manual overload if you need to account for refinancing

 3. **First period**: No prior period for diff, so first payment is missing
    - This is expected behavior - DSCR starts from Q2 onwards

 ## When NOT to Use Auto-Derivation:

 - Refinancing occurred (debt stayed flat but payments were made)
 - Debt was acquired through M&A
 - Off-balance-sheet obligations need inclusion
 - Principal schedule doesn't match balance sheet

 In these cases, use the manual overload with explicit payment series.
 */

print("✓ Debt Service Coverage Ratio now has automatic principal payment derivation")
print("")
print("Key Benefits:")
print("1. No manual calculation of principal payments needed")
print("2. Direct link to balance sheet debt account changes")
print("3. Correctly handles new borrowing (negative principal payments)")
print("4. Maintains backward compatibility (manual overload still available)")
print("")
print("Usage:")
print("  let dscr = debtServiceCoverage(")
print("      incomeStatement: incomeStatement,")
print("      balanceSheet: balanceSheet,")
print("      debtAccount: debtAccount,        // ← Balance sheet account")
print("      interestAccount: interestAccount  // ← Income statement account")
print("  )")
