#!/usr/bin/env swift

import Foundation

/*
 Current Portion of Long-Term Debt (CPLTD) and Principal Payment Calculation

 ## The Accounting Problem

 When a company has debt, the balance sheet typically shows:
 - Long-term Debt (due > 1 year)
 - Current Portion of Long-term Debt (CPLTD) (due ≤ 1 year)

 Each quarter:
 1. Principal payments REDUCE the CPLTD balance
 2. Reclassification FROM long-term TO current INCREASES the CPLTD balance

 Example:
 ```
 Quarter  Long-term   CPLTD    Total    Principal   Reclassification
 -------  ---------   -----    -----    ---------   ----------------
 Q1       $95,000     $5,000   $100k    -           -
 Q2       $95,000     $0       $95k     $5,000      -
          (pay $5k from CPLTD)
 Q3       $90,000     $5,000   $95k     -           $5,000
          (reclassify $5k from LT → CPLTD)
 Q4       $90,000     $0       $90k     $5,000      -
          (pay $5k from CPLTD)
 ```

 ## Why CPLTD Alone Doesn't Work

 CPLTD Change (Q1 → Q2):
 - Change = $0 - $5,000 = -$5,000 ✓ (correctly shows $5k payment)

 CPLTD Change (Q2 → Q3):
 - Change = $5,000 - $0 = +$5,000 ❌ (shows increase, but no new borrowing!)
 - This is reclassification, NOT new debt

 CPLTD Change (Q3 → Q4):
 - Change = $0 - $5,000 = -$5,000 ✓ (correctly shows $5k payment)

 Result: CPLTD changes are inconsistent because they capture BOTH payments and
 reclassification. You can't reliably derive principal payments from CPLTD alone.

 ## Why Total Debt DOES Work

 Total Debt Change (Q1 → Q2):
 - Change = $95k - $100k = -$5,000 ✓ (principal payment)

 Total Debt Change (Q2 → Q3):
 - Change = $95k - $95k = $0 ✓ (reclassification is internal, no net change!)

 Total Debt Change (Q3 → Q4):
 - Change = $90k - $95k = -$5,000 ✓ (principal payment)

 Result: Total debt changes ONLY reflect actual principal payments because
 reclassification between LT and CPLTD is internal (no net change to total).

 ## Implementation in BusinessMath

 The library handles this correctly:

 ```swift
 // Balance sheet already aggregates all debt
 let totalDebtTS = balanceSheet.interestBearingDebt  // LT + CPLTD + short-term

 // Create an account with total debt
 let debtAccount = Account(
     name: "Total Interest-Bearing Debt",
     timeSeries: totalDebtTS,
     role: .longTermDebt
 )

 // This correctly derives principal payments
 let dscr = debtServiceCoverage(
     incomeStatement: incomeStatement,
     balanceSheet: balanceSheet,
     debtAccount: debtAccount,
     interestAccount: interestAccount
 )
 ```

 ## What balanceSheet.interestBearingDebt Includes

 From BalanceSheetRole.swift line 248, `.isDebt` includes:
 - .shortTermDebt
 - .currentPortionLongTermDebt  ← Your CPLTD account!
 - .longTermDebt

 So `interestBearingDebt` automatically aggregates ALL debt, giving you the
 correct total for principal payment derivation.

 ## Key Takeaway

 ✅ DO use: Total Debt (LT + CPLTD + short-term)
    - Changes = Principal Payments (reliable)
    - Reclassification is internal (no impact)

 ❌ DON'T use: CPLTD alone
    - Changes = Payments + Reclassification (unreliable)
    - Can't distinguish between the two

 The `debtServiceCoverage()` function with automatic derivation handles this
 correctly by expecting you to pass total debt, not individual accounts.
 */

print("✓ Current Portion of Long-Term Debt (CPLTD) Handling")
print("")
print("Key Insight:")
print("  CPLTD alone: Changes reflect payments + reclassification (unreliable)")
print("  Total Debt:  Changes reflect ONLY payments (reliable!)")
print("")
print("Why?")
print("  Reclassification (LT → CPLTD) is internal - no net change to total debt")
print("  Only actual principal payments change total debt")
print("")
print("Usage:")
print("  let totalDebtTS = balanceSheet.interestBearingDebt  // Aggregates all debt")
print("  let debtAccount = Account(")
print("      name: \"Total Interest-Bearing Debt\",")
print("      timeSeries: totalDebtTS,  // ← Includes LT + CPLTD + short-term")
print("      role: .longTermDebt")
print("  )")
print("")
print("This ensures quarterly changes correctly reflect principal payments,")
print("even when debt is reclassified from long-term to current portion.")
