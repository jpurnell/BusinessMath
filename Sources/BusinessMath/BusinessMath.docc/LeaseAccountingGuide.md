# Lease Accounting (IFRS 16 / ASC 842)

Model lease liabilities, right-of-use assets, and lease accounting under modern standards.

## Overview

Under IFRS 16 and ASC 842, most leases must be capitalized on the balance sheet as a right-of-use (ROU) asset and lease liability. The ``Lease`` type provides comprehensive tools for:
- Calculating present value of lease payments with proper discount rates
- Generating amortization schedules for lease liabilities
- Computing ROU asset depreciation
- Handling short-term and low-value lease exemptions
- Modeling lease modifications and extensions
- Calculating sale-and-leaseback transactions

This guide walks through lease accounting from initial recognition through disposal.

## Understanding Lease Accounting Basics

### Key Concepts

Under modern lease accounting:
- **Lease Liability**: Present value of future lease payments, discounted at the appropriate rate
- **Right-of-Use Asset**: Initial lease liability plus initial direct costs and prepayments
- **Interest Expense**: Calculated on the outstanding lease liability balance
- **Depreciation**: ROU asset is depreciated over the shorter of lease term or asset life

### When to Capitalize Leases

All leases must be capitalized except:
- **Short-term leases**: 12 months or less
- **Low-value leases**: Underlying asset value < $5,000

## Basic Lease Recognition

Calculate the initial lease liability and ROU asset:

```swift
import BusinessMath

// Quarterly lease payments for office space
let q1 = Period.quarter(year: 2025, quarter: 1)
let periods = [q1, q1 + 1, q1 + 2, q1 + 3]  // 4 quarters = 1 year

let payments = TimeSeries(
    periods: periods,
    values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]
)

// Create lease with 6% annual discount rate
let lease = Lease(
    payments: payments,
    discountRate: 0.06  // Incremental borrowing rate
)

// Calculate present value (lease liability)
let liability = lease.presentValue()
print("Initial lease liability: $\(liability)")  // ~$96,454

// Calculate right-of-use asset
let rouAsset = lease.rightOfUseAsset()
print("ROU asset: $\(rouAsset)")  // Same as liability initially
```

## Lease Liability Amortization Schedule

Generate a complete amortization schedule:

```swift
let schedule = lease.liabilitySchedule()

// Display schedule
for (period, balance) in schedule.sorted(by: { $0.key < $1.key }) {
    print("\(period.label): Balance $\(String(format: "%.2f", balance))")
}

// First period shows initial liability
// Subsequent periods show ending balance after payment
```

Detailed breakdown with interest and principal:

```swift
let q1 = Period.quarter(year: 2025, quarter: 1)

// Interest expense for first quarter
let interest1 = lease.interestExpense(period: q1)
print("Q1 Interest: $\(interest1)")  // Liability × (6% / 4)

// Principal reduction
let principal1 = lease.principalReduction(period: q1)
print("Q1 Principal: $\(principal1)")  // Payment - Interest

// Payment breakdown
let payment = 25_000.0
let totalExpense = interest1 + principal1
print("Total payment: $\(payment)")
```

## Initial Direct Costs and Prepayments

Include initial direct costs and prepayments in ROU asset:

```swift
let lease = Lease(
    payments: payments,
    discountRate: 0.08,
    initialDirectCosts: 5_000.0,  // Legal fees, commissions
    prepaidAmount: 10_000.0       // First month + security deposit
)

let liability = lease.presentValue()  // PV of payments only
let rouAsset = lease.rightOfUseAsset()  // PV + costs + prepayments

print("Lease liability: $\(liability)")
print("ROU asset: $\(rouAsset)")  // Higher than liability
```

## Depreciation of ROU Asset

Calculate straight-line depreciation:

```swift
let q1 = Period.quarter(year: 2025, quarter: 1)

// Depreciation per period (straight-line)
let depreciation = lease.depreciation(period: q1)
print("Q1 Depreciation: $\(depreciation)")  // ROU asset ÷ lease term

// Carrying value after each period
let carryingValue1 = lease.carryingValue(period: q1)
let carryingValue2 = lease.carryingValue(period: q1 + 1)
print("Q1 carrying value: $\(carryingValue1)")
print("Q2 carrying value: $\(carryingValue2)")  // Lower
```

## Income Statement Impact

Complete P&L impact each period:

```swift
let q1 = Period.quarter(year: 2025, quarter: 1)

// Interest expense (financing cost)
let interest = lease.interestExpense(period: q1)

// Depreciation expense (operating expense)
let depreciation = lease.depreciation(period: q1)

// Total P&L impact
let totalExpense = interest + depreciation
print("Q1 Total Expense: $\(totalExpense)")

// Note: Expense is front-loaded (higher interest early)
// Compare to straight-line rent expense under old standard
```

## Discount Rate Selection

### Implicit Rate in the Lease

If known, use the rate implicit in the lease:

```swift
// Usually only known for lessor
let lease = Lease(
    payments: payments,
    discountRate: 0.055,  // Rate implicit in lease
    discountRateType: .implicitRate
)
```

### Incremental Borrowing Rate

Most lessees use their incremental borrowing rate (IBR):

```swift
// Calculate IBR
let ibr = calculateIncrementalBorrowingRate(
    riskFreeRate: 0.03,        // Treasury rate
    creditSpread: 0.02,        // Company's credit spread
    assetRiskPremium: 0.005    // Asset-specific risk
)
print("IBR: \(ibr * 100)%")  // 5.5%

let lease = Lease(
    payments: payments,
    discountRate: ibr,
    discountRateType: .incrementalBorrowingRate
)
```

### Impact of Discount Rate

Higher discount rates reduce present value:

```swift
let lowRate = Lease(payments: payments, discountRate: 0.04)
let highRate = Lease(payments: payments, discountRate: 0.10)

print("PV at 4%: $\(lowRate.presentValue())")   // Higher PV
print("PV at 10%: $\(highRate.presentValue())")  // Lower PV
```

## Short-Term Lease Exemption

Leases of 12 months or less can be expensed:

```swift
let shortTermLease = Lease(
    payments: payments,
    discountRate: 0.06,
    leaseTerm: .months(12)  // Explicitly specify term
)

if shortTermLease.isShortTerm {
    print("Qualifies for short-term exemption")
    // Can expense payments as incurred
    // No ROU asset or liability
}

// When exemption applied:
let rouAsset = shortTermLease.rightOfUseAsset()  // Returns 0
let schedule = shortTermLease.liabilitySchedule()  // Returns zeros
```

## Low-Value Lease Exemption

Leases of assets < $5,000 can be expensed:

```swift
let lowValueLease = Lease(
    payments: payments,
    discountRate: 0.06,
    underlyingAssetValue: 4_500.0  // Below $5K threshold
)

if lowValueLease.isLowValue {
    print("Qualifies for low-value exemption")
    // Can expense payments as incurred
}
```

## Variable Lease Payments

Handle variable payments separately:

```swift
// Fixed minimum payments
let fixedPayments = TimeSeries(
    periods: periods,
    values: [20_000.0, 20_000.0, 20_000.0, 20_000.0]
)

// Variable payments (e.g., based on sales)
let variablePayments = TimeSeries(
    periods: periods,
    values: [3_000.0, 5_000.0, 4_500.0, 6_000.0]
)

let lease = Lease(
    payments: fixedPayments,
    discountRate: 0.07,
    variablePayments: variablePayments
)

// Only fixed payments in liability
let liability = lease.presentValue()  // PV of fixed portion only

// Total cash payment includes variable component
let totalCash = lease.totalCashPayment(period: periods[0])
print("Total Q1 payment: $\(totalCash)")  // Fixed + variable
```

## Lease Modifications

### Extension

Extend the lease term:

```swift
let originalLease = Lease(
    payments: payments,
    discountRate: 0.06
)

// Extend by 2 more quarters
let extensionPayments = TimeSeries(
    periods: [q1 + 4, q1 + 5],
    values: [26_000.0, 26_000.0]
)

let extendedLease = originalLease.extend(
    additionalPayments: extensionPayments
)

let originalROU = originalLease.rightOfUseAsset()
let newROU = extendedLease.rightOfUseAsset()
print("ROU increase: $\(newROU - originalROU)")
```

### Rent Reduction

Modify payment amounts (e.g., COVID rent relief):

```swift
// Reduced payments for next 2 quarters
let reducedPayments = TimeSeries(
    periods: [q1, q1 + 1],
    values: [15_000.0, 15_000.0]  // Down from $25,000
)

let modifiedLease = originalLease.modify(
    newPayments: reducedPayments,
    atPeriod: q1
)

// Remeasure lease liability and ROU asset
```

## Lease vs Buy Analysis

Evaluate whether to lease or purchase:

```swift
// Lease option
let leasePV = leasePaymentsPV(
    periodicPayment: 5_000.0,
    periods: 60,  // 5 years monthly
    discountRate: 0.006  // Monthly rate
)

// Buy option
let buyPV = buyAssetPV(
    purchasePrice: 250_000.0,
    salvageValue: 50_000.0,
    holdingPeriod: 5,
    discountRate: 0.075,
    maintenanceCost: 2_000.0  // Annual
)

let analysis = LeaseVsBuyAnalysis(leasePV: leasePV, buyPV: buyPV)

if analysis.shouldLease {
    print("Recommendation: \(analysis.recommendation)")
    print("Savings: \(analysis.savingsPercentage * 100)%")
} else {
    print("Buying is more economical")
}
```

## Sale and Leaseback Transactions

Model selling an asset and leasing it back:

```swift
let assetCarryingValue = 500_000.0
let salePrice = 600_000.0

let leasebackPayments = TimeSeries(
    periods: periods,
    values: [40_000.0, 40_000.0, 40_000.0, 40_000.0]
)

let transaction = SaleAndLeaseback(
    carryingValue: assetCarryingValue,
    salePrice: salePrice,
    leasebackPayments: leasebackPayments,
    discountRate: 0.06,
    startDate: q1.startDate
)

// Gain recognition
let gainRecognized = transaction.recognizedGain()
let deferredGain = transaction.deferredGain()

print("Recognized gain: $\(gainRecognized)")
print("Deferred gain: $\(deferredGain)")

// Cash benefit
let cashBenefit = transaction.netCashBenefit
print("Net cash from transaction: $\(cashBenefit)")

// Economic analysis
if transaction.isEconomicallyBeneficial {
    print("Transaction creates value")
}
```

## Finance vs Operating Lease Classification

Determine lease type under ASC 842:

```swift
let classification = classifyLease(
    leaseTerm: 48,           // months
    assetUsefulLife: 60,     // months
    presentValue: 90_000.0,
    assetFairValue: 100_000.0,
    ownershipTransfer: false,
    purchaseOption: false
)

switch classification {
case .finance:
    print("Finance lease")
    // Depreciation + interest expense
case .operating:
    print("Operating lease")
    // Single lease expense (straight-line)
}
```

Classification tests:
- Ownership transfers at end
- Purchase option reasonably certain
- Lease term ≥ 75% of useful life
- PV of payments ≥ 90% of fair value
- Asset has no alternative use

## Complete Lease Example

Here's a comprehensive lease accounting scenario:

```swift
import BusinessMath

// Office lease: 5 years, quarterly payments
let startDate = Period.quarter(year: 2025, quarter: 1)
let periods = (0..<20).map { startDate + $0 }  // 20 quarters

// Fixed rent with 3% annual escalation
var payments: [Double] = []
let baseRent = 30_000.0
for i in 0..<20 {
    let yearIndex = i / 4
    let escalatedRent = baseRent * pow(1.03, Double(yearIndex))
    payments.append(escalatedRent)
}

let paymentSeries = TimeSeries(periods: periods, values: payments)

// Create lease with costs
let lease = Lease(
    payments: paymentSeries,
    discountRate: 0.068,  // 6.8% IBR
    initialDirectCosts: 15_000.0,  // Broker commission
    prepaidAmount: 30_000.0,       // First quarter rent
    depreciationMethod: .straightLine,
    leaseTerm: .years(5),
    underlyingAssetValue: 2_000_000.0  // Office space value
)

// Initial recognition
let liability = lease.presentValue()
let rouAsset = lease.rightOfUseAsset()

print("=== Initial Recognition ===")
print("Lease liability: $\(String(format: "%.2f", liability))")
print("ROU asset: $\(String(format: "%.2f", rouAsset))")

// First year expense breakdown
print("\n=== Year 1 Expenses ===")
for i in 0..<4 {
    let period = periods[i]
    let interest = lease.interestExpense(period: period)
    let depreciation = lease.depreciation(period: period)
    let total = interest + depreciation

    print("\(period.label): Interest $\(String(format: "%.0f", interest)), " +
          "Depreciation $\(String(format: "%.0f", depreciation)), " +
          "Total $\(String(format: "%.0f", total))")
}

// Maturity analysis for disclosure
print("\n=== Payment Maturity Analysis ===")
let maturity = lease.maturityAnalysis()
for (year, amount) in maturity.sorted(by: { $0.key < $1.key }) {
    print("\(year): $\(String(format: "%.0f", amount))")
}

// Total commitment disclosure
let totalPayments = lease.totalFuturePayments()
print("\nTotal future lease payments: $\(String(format: "%.0f", totalPayments))")
print("Present value: $\(String(format: "%.0f", liability))")
print("Implicit interest: $\(String(format: "%.0f", totalPayments - liability))")
```

## Disclosure Requirements

Key disclosures for lease accounting:

```swift
// Total commitments
let totalCommitments = lease.totalFuturePayments()

// Weighted average discount rate
let effectiveRate = lease.effectiveRate

// Weighted average remaining term
// (calculate from payment schedule)

// Maturity analysis
let maturity = lease.maturityAnalysis()

// Expense breakdown
let currentPeriod = Period.quarter(year: 2025, quarter: 1)
let interest = lease.interestExpense(period: currentPeriod)
let depreciation = lease.depreciation(period: currentPeriod)
```

## Common Patterns

### Monthly Lease with Annual Payments

```swift
// Annual payments but monthly periods for reporting
let year2025 = Period.year(2025)
let annualPayment = 120_000.0

// Convert to monthly equivalent
let months = year2025.months()
let monthlyPayment = annualPayment / 12.0

let monthlyPayments = TimeSeries(
    periods: months,
    values: Array(repeating: monthlyPayment, count: 12)
)

let lease = Lease(
    payments: monthlyPayments,
    discountRate: 0.06  // Will be converted to monthly rate automatically
)
```

### Residual Value Guarantees

```swift
let lease = Lease(
    payments: payments,
    discountRate: 0.07,
    residualValue: 20_000.0  // Guaranteed residual at end
)

// Residual value increases lease liability
let liabilityWithResidual = lease.presentValue()
```

### Leasehold Improvements

```swift
// ROU asset + leasehold improvements
let rouAsset = lease.rightOfUseAsset()
let improvements = 50_000.0
let totalAsset = rouAsset + improvements

// Depreciate over shorter of lease term or improvement life
```

## Next Steps

- Explore <doc:DebtAndFinancingGuide> for modeling debt obligations and capital structure
- Learn about <doc:FinancialStatementsGuide> for integrating leases into complete financial statements
- Review <doc:TimeValueOfMoney> for understanding present value calculations

## See Also

- ``Lease``
- ``SaleAndLeaseback``
- ``LeaseVsBuyAnalysis``
- ``LeaseClassification``
- ``LeaseTerm``
- ``DepreciationMethod``
