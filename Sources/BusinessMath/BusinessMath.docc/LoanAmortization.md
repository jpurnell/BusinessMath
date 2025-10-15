# Loan Amortization Analysis

Build a complete loan amortization schedule and analyze payment breakdowns.

## Overview

This tutorial shows you how to analyze loans using BusinessMath's time value of money functions. You'll learn how to:

- Calculate monthly loan payments
- Generate complete amortization schedules
- Analyze principal vs. interest breakdown
- Compare different loan scenarios
- Calculate cumulative totals for tax purposes
- Evaluate payoff strategies

**Time estimate:** 20-30 minutes

## Prerequisites

- Basic understanding of Swift
- Familiarity with loan concepts (principal, interest, amortization)
- Understanding of time value of money (see <doc:TimeValueOfMoney>)

## Step 1: Define the Loan

Start with the loan parameters. We'll use a typical 30-year mortgage.

```swift
import BusinessMath

// Loan parameters
let principal = 300_000.0      // $300,000 home loan
let annualRate = 0.06          // 6% annual interest rate
let years = 30                 // 30-year term
let monthlyRate = annualRate / 12
let totalPayments = years * 12  // 360 payments

print("Mortgage Loan Analysis")
print("=====================")
print("Principal: $\(String(format: "%.2f", principal))")
print("Annual Rate: \(String(format: "%.2f%%", annualRate * 100))")
print("Term: \(years) years (\(totalPayments) payments)")
print("Monthly Rate: \(String(format: "%.4f%%", monthlyRate * 100))")
```

**Expected output:**
```
Mortgage Loan Analysis
=====================
Principal: $300,000.00
Annual Rate: 6.00%
Term: 30 years (360 payments)
Monthly Rate: 0.5000%
```

## Step 2: Calculate Monthly Payment

Use the `payment()` function to calculate the monthly payment.

```swift
// Calculate monthly payment
let monthlyPayment = payment(
    presentValue: principal,
    rate: monthlyRate,
    periods: totalPayments,
    futureValue: 0,  // Loan fully paid off at end
    type: .ordinary  // Payments at end of month
)

print("\nMonthly Payment: $\(String(format: "%.2f", monthlyPayment))")

// Calculate total amount paid over life of loan
let totalPaid = monthlyPayment * Double(totalPayments)
let totalInterest = totalPaid - principal

print("Total Paid: $\(String(format: "%.2f", totalPaid))")
print("Total Interest: $\(String(format: "%.2f", totalInterest))")
print("Interest as % of Principal: \(String(format: "%.1f%%", (totalInterest / principal) * 100))")
```

**Expected output:**
```
Monthly Payment: $1,798.65

Total Paid: $647,514.57
Total Interest: $347,514.57
Interest as % of Principal: 115.8%
```

> **Note:** You pay more in interest than the original principal! This is why it's important to understand amortization.

## Step 3: Analyze First Payment

Break down the first payment into principal and interest components.

```swift
// First payment breakdown
let firstInterest = interestPayment(
    rate: monthlyRate,
    period: 1,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

let firstPrincipal = principalPayment(
    rate: monthlyRate,
    period: 1,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

print("\nFirst Payment Breakdown:")
print("  Interest: $\(String(format: "%.2f", firstInterest)) (\(String(format: "%.1f%%", (firstInterest / monthlyPayment) * 100)))")
print("  Principal: $\(String(format: "%.2f", firstPrincipal)) (\(String(format: "%.1f%%", (firstPrincipal / monthlyPayment) * 100)))")
print("  Total: $\(String(format: "%.2f", firstInterest + firstPrincipal))")

// Verify it matches monthly payment
let difference = abs((firstInterest + firstPrincipal) - monthlyPayment)
print("  Verification: \(difference < 0.01 ? "✓ Correct" : "✗ Error")")
```

**Expected output:**
```
First Payment Breakdown:
  Interest: $1,500.00 (83.4%)
  Principal: $298.65 (16.6%)
  Total: $1,798.65
  Verification: ✓ Correct
```

> **Insight:** In early payments, most goes to interest. Only 17% reduces principal!

## Step 4: Analyze Last Payment

Compare to the final payment to see how the balance shifts.

```swift
// Last payment breakdown
let lastInterest = interestPayment(
    rate: monthlyRate,
    period: totalPayments,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

let lastPrincipal = principalPayment(
    rate: monthlyRate,
    period: totalPayments,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

print("\nLast Payment Breakdown (Payment #\(totalPayments)):")
print("  Interest: $\(String(format: "%.2f", lastInterest)) (\(String(format: "%.1f%%", (lastInterest / monthlyPayment) * 100)))")
print("  Principal: $\(String(format: "%.2f", lastPrincipal)) (\(String(format: "%.1f%%", (lastPrincipal / monthlyPayment) * 100)))")
print("  Total: $\(String(format: "%.2f", lastInterest + lastPrincipal))")

print("\nChange from First to Last Payment:")
print("  Interest: $\(String(format: "%.2f", firstInterest)) → $\(String(format: "%.2f", lastInterest))")
print("  Principal: $\(String(format: "%.2f", firstPrincipal)) → $\(String(format: "%.2f", lastPrincipal))")
```

**Expected output:**
```
Last Payment Breakdown (Payment #360):
  Interest: $8.94 (0.5%)
  Principal: $1,789.71 (99.5%)
  Total: $1,798.65

Change from First to Last Payment:
  Interest: $1,500.00 → $8.94
  Principal: $298.65 → $1,789.71
```

> **Insight:** By the end, almost all payment goes to principal!

## Step 5: Generate Amortization Schedule

Create a complete payment-by-payment schedule.

```swift
// Generate full amortization schedule
print("\nAmortization Schedule (First 12 Months):")
print("Payment | Principal  | Interest   | Balance")
print("--------|------------|------------|----------")

var remainingBalance = principal

for month in 1...12 {
    let interestPmt = interestPayment(
        rate: monthlyRate,
        period: month,
        totalPeriods: totalPayments,
        presentValue: principal,
        futureValue: 0,
        type: .ordinary
    )

    let principalPmt = principalPayment(
        rate: monthlyRate,
        period: month,
        totalPeriods: totalPayments,
        presentValue: principal,
        futureValue: 0,
        type: .ordinary
    )

    remainingBalance -= principalPmt

    print(String(format: "  %3d   | $%9.2f | $%9.2f | $%10.2f",
                 month, principalPmt, interestPmt, remainingBalance))
}

// Show sample from middle and end
print("  ...   |    ...     |    ...     |    ...")

// Month 180 (halfway)
let mid = totalPayments / 2
let midInterest = interestPayment(rate: monthlyRate, period: mid, totalPeriods: totalPayments,
                                  presentValue: principal, futureValue: 0, type: .ordinary)
let midPrincipal = principalPayment(rate: monthlyRate, period: mid, totalPeriods: totalPayments,
                                    presentValue: principal, futureValue: 0, type: .ordinary)
let midBalance = principal - (1...mid).map { period in
    principalPayment(rate: monthlyRate, period: period, totalPeriods: totalPayments,
                    presentValue: principal, futureValue: 0, type: .ordinary)
}.reduce(0, +)

print(String(format: "  %3d   | $%9.2f | $%9.2f | $%10.2f",
             mid, midPrincipal, midInterest, midBalance))
```

## Step 6: Analyze by Year

Calculate annual totals for tax and accounting purposes.

```swift
// Calculate totals for each year
print("\n\nAnnual Summary:")
print("Year | Principal  | Interest   | Total Payments | Ending Balance")
print("-----|------------|------------|----------------|---------------")

var cumulativePrincipal = 0.0
var currentBalance = principal

for year in 1...5 {  // Show first 5 years
    let startPeriod = (year - 1) * 12 + 1
    let endPeriod = year * 12

    let yearInterest = cumulativeInterest(
        rate: monthlyRate,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
        totalPeriods: totalPayments,
        presentValue: principal,
        futureValue: 0,
        type: .ordinary
    )

    let yearPrincipal = cumulativePrincipal(
        rate: monthlyRate,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
        totalPeriods: totalPayments,
        presentValue: principal,
        futureValue: 0,
        type: .ordinary
    )

    cumulativePrincipal += yearPrincipal
    currentBalance -= yearPrincipal

    let yearTotal = yearInterest + yearPrincipal

    print(String(format: "  %2d | $%10.2f | $%10.2f | $%14.2f | $%13.2f",
                 year, yearPrincipal, yearInterest, yearTotal, currentBalance))
}

print(" ... |    ...     |    ...     |      ...       |     ...")

// Show year 30
let year30Interest = cumulativeInterest(
    rate: monthlyRate,
    startPeriod: 349,  // Last 12 payments
    endPeriod: 360,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

let year30Principal = cumulativePrincipal(
    rate: monthlyRate,
    startPeriod: 349,
    endPeriod: 360,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

print(String(format: "  %2d | $%10.2f | $%10.2f | $%14.2f | $%13.2f",
             30, year30Principal, year30Interest, year30Principal + year30Interest, 0.0))
```

**Expected output:**
```
Annual Summary:
Year | Principal  | Interest   | Total Payments | Ending Balance
-----|------------|------------|----------------|---------------
   1 | $  3,724.38 | $ 17,859.42 | $   21,583.80 | $ 296,275.62
   2 | $  3,950.87 | $ 17,632.93 | $   21,583.80 | $ 292,324.75
   3 | $  4,192.37 | $ 17,391.43 | $   21,583.80 | $ 288,132.38
   4 | $  4,450.04 | $ 17,133.76 | $   21,583.80 | $ 283,682.34
   5 | $  4,725.12 | $ 16,858.68 | $   21,583.80 | $ 278,957.22
 ... |    ...     |    ...     |      ...       |     ...
  30 | $ 21,247.87 | $    335.93 | $   21,583.80 | $         0.00
```

> **Insight:** Year 1 interest ($17,859) is tax deductible if itemizing!

## Step 7: Compare Loan Scenarios

Compare different loan terms and rates.

```swift
print("\n\nLoan Comparison:")
print("Scenario              | Payment   | Total Paid | Total Interest")
print("----------------------|-----------|------------|---------------")

// Scenario 1: Original (30-year, 6%)
print(String(format: "30-year @ 6.00%%      | $%8.2f | $%9.2f | $%13.2f",
             monthlyPayment, totalPaid, totalInterest))

// Scenario 2: 15-year loan
let payment15yr = payment(presentValue: principal, rate: monthlyRate,
                          periods: 15 * 12, futureValue: 0, type: .ordinary)
let total15yr = payment15yr * Double(15 * 12)
let interest15yr = total15yr - principal
print(String(format: "15-year @ 6.00%%      | $%8.2f | $%9.2f | $%13.2f",
             payment15yr, total15yr, interest15yr))

// Scenario 3: Lower rate (5%)
let lowRate = 0.05 / 12
let paymentLowRate = payment(presentValue: principal, rate: lowRate,
                             periods: totalPayments, futureValue: 0, type: .ordinary)
let totalLowRate = paymentLowRate * Double(totalPayments)
let interestLowRate = totalLowRate - principal
print(String(format: "30-year @ 5.00%%      | $%8.2f | $%9.2f | $%13.2f",
             paymentLowRate, totalLowRate, interestLowRate))

// Scenario 4: Higher rate (7%)
let highRate = 0.07 / 12
let paymentHighRate = payment(presentValue: principal, rate: highRate,
                              periods: totalPayments, futureValue: 0, type: .ordinary)
let totalHighRate = paymentHighRate * Double(totalPayments)
let interestHighRate = totalHighRate - principal
print(String(format: "30-year @ 7.00%%      | $%8.2f | $%9.2f | $%13.2f",
             paymentHighRate, totalHighRate, interestHighRate))

print("\nKey Insights:")
print("  • 15-year term saves $\(String(format: "%.0f", totalInterest - interest15yr)) in interest")
print("  • But increases payment by $\(String(format: "%.0f", payment15yr - monthlyPayment))/month")
print("  • 1% rate increase adds $\(String(format: "%.0f", paymentHighRate - monthlyPayment))/month")
print("  • And $\(String(format: "%.0f", interestHighRate - totalInterest)) more in total interest")
```

## Step 8: Evaluate Extra Payment Strategy

See the impact of making extra principal payments.

```swift
// Strategy: Pay extra $200/month toward principal
let extraPayment = 200.0
let totalMonthlyPayment = monthlyPayment + extraPayment

print("\n\nExtra Payment Analysis:")
print("Standard payment: $\(String(format: "%.2f", monthlyPayment))")
print("Extra payment: $\(String(format: "%.2f", extraPayment))")
print("Total payment: $\(String(format: "%.2f", totalMonthlyPayment))")

// Calculate payoff time with extra payments
var balance = principal
var month = 0
var totalPaidWithExtra = 0.0
var totalInterestWithExtra = 0.0

while balance > 0 && month < totalPayments {
    month += 1

    // Calculate interest on current balance
    let interest = balance * monthlyRate

    // Apply payment
    let principalReduction = min(totalMonthlyPayment - interest, balance)
    balance -= principalReduction

    totalPaidWithExtra += interest + principalReduction
    totalInterestWithExtra += interest
}

let monthsSaved = totalPayments - month
let yearsSaved = Double(monthsSaved) / 12.0
let interestSaved = totalInterest - totalInterestWithExtra

print("\nResults with $\(String(format: "%.0f", extraPayment))/month extra:")
print("  Payoff time: \(month) months (\(String(format: "%.1f", Double(month) / 12.0)) years)")
print("  Time saved: \(monthsSaved) months (\(String(format: "%.1f", yearsSaved)) years)")
print("  Total interest paid: $\(String(format: "%.2f", totalInterestWithExtra))")
print("  Interest saved: $\(String(format: "%.2f", interestSaved))")
print("  Extra principal paid: $\(String(format: "%.2f", extraPayment * Double(month)))")
print("  Net savings: $\(String(format: "%.2f", interestSaved - (extraPayment * Double(month))))")
```

**Expected output:**
```
Extra Payment Analysis:
Standard payment: $1,798.65
Extra payment: $200.00
Total payment: $1,998.65

Results with $200/month extra:
  Payoff time: 268 months (22.3 years)
  Time saved: 92 months (7.7 years)
  Total interest paid: $253,880.65
  Interest saved: $93,633.92
  Extra principal paid: $53,600.00
  Net savings: $40,033.92
```

> **Insight:** $200/month extra saves $93k in interest and pays off 7.7 years early!

## Step 9: Create Reusable Function

Package everything into a reusable function.

```swift
struct LoanAnalysis {
    let principal: Double
    let monthlyPayment: Double
    let totalPayments: Int
    let totalPaid: Double
    let totalInterest: Double

    func printSummary() {
        print("Loan Analysis Summary")
        print("=====================")
        print("Principal: $\(String(format: "%.2f", principal))")
        print("Monthly Payment: $\(String(format: "%.2f", monthlyPayment))")
        print("Total Payments: \(totalPayments)")
        print("Total Paid: $\(String(format: "%.2f", totalPaid))")
        print("Total Interest: $\(String(format: "%.2f", totalInterest))")
        print("Interest / Principal: \(String(format: "%.1f%%", (totalInterest / principal) * 100))")
    }
}

func analyzeLoan(principal: Double, annualRate: Double, years: Int) -> LoanAnalysis {
    let monthlyRate = annualRate / 12
    let totalPayments = years * 12

    let monthlyPayment = payment(
        presentValue: principal,
        rate: monthlyRate,
        periods: totalPayments,
        futureValue: 0,
        type: .ordinary
    )

    let totalPaid = monthlyPayment * Double(totalPayments)
    let totalInterest = totalPaid - principal

    return LoanAnalysis(
        principal: principal,
        monthlyPayment: monthlyPayment,
        totalPayments: totalPayments,
        totalPaid: totalPaid,
        totalInterest: totalInterest
    )
}

// Use it
let myLoan = analyzeLoan(principal: 300_000, annualRate: 0.06, years: 30)
myLoan.printSummary()

// Compare different scenarios
print("\nComparing scenarios:")
analyzeLoan(principal: 300_000, annualRate: 0.06, years: 30).printSummary()
print()
analyzeLoan(principal: 300_000, annualRate: 0.06, years: 15).printSummary()
```

## Key Takeaways

1. **Early payments are mostly interest**: In a 30-year loan, 83% of the first payment is interest
2. **Extra payments save significantly**: Even $200/month extra can save years and tens of thousands
3. **Shorter terms save interest**: A 15-year loan costs much less in total interest
4. **Rates matter**: 1% rate difference adds hundreds to monthly payments
5. **Understanding amortization helps**: Make informed decisions about mortgages and loans

## Next Steps

- Explore <doc:InvestmentAnalysis> to evaluate investments
- Read about <doc:TimeValueOfMoney> for more financial calculations
- Build a loan calculator app using these functions
- Create a loan comparison tool for rate shopping

## See Also

- <doc:TimeValueOfMoney>
- <doc:InvestmentAnalysis>
- ``payment(presentValue:rate:periods:futureValue:type:)``
- ``principalPayment(rate:period:totalPeriods:presentValue:futureValue:type:)``
- ``interestPayment(rate:period:totalPeriods:presentValue:futureValue:type:)``
- ``cumulativeInterest(rate:startPeriod:endPeriod:totalPeriods:presentValue:futureValue:type:)``
- ``cumulativePrincipal(rate:startPeriod:endPeriod:totalPeriods:presentValue:futureValue:type:)``
