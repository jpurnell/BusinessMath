# Debt & Financing Models

Learn how to model debt instruments, capital structure, equity financing, covenants, and lease accounting.

## Overview

BusinessMath provides comprehensive tools for modeling corporate finance decisions across debt and equity. This tutorial shows you how to:
- Create amortization schedules for loans and bonds
- Calculate optimal capital structure and WACC
- Model equity financing rounds and dilution
- Monitor debt covenant compliance
- Analyze lease vs buy decisions

## Content

## Debt Instruments & Amortization

### Basic Loan Amortization

Create a simple mortgage with level payments:

```swift
import BusinessMath

// 30-year mortgage: $300,000 at 4.5%
let mortgage = DebtInstrument(
    principal: 300_000.0,
    interestRate: 0.045,
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 30, to: Date())!,
    paymentFrequency: .monthly,
    amortizationType: .levelPayment
)

let schedule = mortgage.schedule()

// First payment breakdown
let firstPeriod = schedule.periods.first!
print("Monthly Payment: $\(schedule.payment[firstPeriod]!)")        // $1,520.06
print("Interest: $\(schedule.interest[firstPeriod]!)")              // $1,125.00
print("Principal: $\(schedule.principal[firstPeriod]!)")            // $395.06

// Total interest over life of loan
print("Total Interest: $\(schedule.totalInterest)")                  // $247,220
```

### Amortization Types

BusinessMath supports four amortization patterns:

#### Level Payment (Constant Total Payment)

Most common for mortgages and consumer loans. Total payment stays constant while principal portion increases over time:

```swift
let levelPayment = DebtInstrument(
    principal: 100_000.0,
    interestRate: 0.06,
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 5, to: Date())!,
    paymentFrequency: .monthly,
    amortizationType: .levelPayment
)

let schedule = levelPayment.schedule()

// Payment is constant every period
for period in schedule.periods.prefix(3) {
    print("Payment: $\(schedule.payment[period]!)")  // Always ~$1,933.28
}
```

#### Straight Line (Equal Principal Payments)

Principal payment is constant, interest declines, so total payment declines:

```swift
let straightLine = DebtInstrument(
    principal: 60_000.0,
    interestRate: 0.08,
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 3, to: Date())!,
    paymentFrequency: .quarterly,
    amortizationType: .straightLine
)

let schedule = straightLine.schedule()

// Principal payment is constant, total payment declines
for period in schedule.periods.prefix(3) {
    print("Principal: $\(schedule.principal[period]!)")  // Always $5,000
    print("Total Payment: $\(schedule.payment[period]!)") // Declines each quarter
}
```

#### Bullet Payment (Interest-Only with Principal at Maturity)

Common for bonds and some commercial loans:

```swift
let bulletLoan = DebtInstrument(
    principal: 500_000.0,
    interestRate: 0.055,
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 5, to: Date())!,
    paymentFrequency: .semiAnnual,
    amortizationType: .bulletPayment
)

let schedule = bulletLoan.schedule()

// All periods except last have zero principal payment
for period in schedule.periods.dropLast() {
    print("Principal Payment: $\(schedule.principal[period]!)")  // $0
    print("Interest Payment: $\(schedule.interest[period]!)")    // $13,750
}

// Last period includes full principal
let lastPeriod = schedule.periods.last!
print("Final Payment: $\(schedule.payment[lastPeriod]!)")  // $513,750
```

#### Custom Payment Schedule

For structured payments or irregular schedules:

```swift
let customPayments = [15_000.0, 20_000.0, 25_000.0, 30_000.0, 40_000.0]

let customLoan = DebtInstrument(
    principal: 120_000.0,
    interestRate: 0.07,
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 5, to: Date())!,
    paymentFrequency: .annual,
    amortizationType: .custom(schedule: customPayments)
)
```

### Effective Annual Rate

Compare nominal rates with different compounding frequencies:

```swift
let monthlyCompounding = DebtInstrument(
    principal: 10_000.0,
    interestRate: 0.12,  // 12% APR
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
    paymentFrequency: .monthly,
    amortizationType: .levelPayment
)

let ear = monthlyCompounding.effectiveAnnualRate()
print("Effective Annual Rate: \(ear * 100)%")  // 12.68%
```

## Capital Structure & WACC

### Weighted Average Cost of Capital

Calculate a company's overall cost of capital:

```swift
// Company with $600M equity and $400M debt
let waccRate = wacc(
    equityValue: 600_000_000,
    debtValue: 400_000_000,
    costOfEquity: 0.12,
    costOfDebt: 0.06,
    taxRate: 0.25
)

print("WACC: \(waccRate * 100)%")  // 9.0%
```

**Formula**: WACC = (E/(E+D)) × Re + (D/(E+D)) × Rd × (1-T)

Where:
- E = Market value of equity
- D = Market value of debt
- Re = Cost of equity
- Rd = Cost of debt (before tax)
- T = Corporate tax rate

### Using CapitalStructure Type

Track and analyze capital structure:

```swift
let structure = CapitalStructure(
    debtValue: 400_000_000,
    equityValue: 600_000_000,
    costOfDebt: 0.06,
    costOfEquity: 0.12,
    taxRate: 0.25
)

print("WACC: \(structure.wacc * 100)%")                           // 9.0%
print("Debt Ratio: \(structure.debtRatio * 100)%")                // 40%
print("Debt-to-Equity: \(structure.debtToEquityRatio)")           // 0.67
print("After-tax Cost of Debt: \(structure.afterTaxCostOfDebt * 100)%")  // 4.5%

// Tax benefits from debt
print("Annual Tax Shield: $\(structure.annualTaxShield)")         // $6M
```

### Cost of Equity (CAPM)

Calculate cost of equity using the Capital Asset Pricing Model:

```swift
let costOfEquity = capm(
    riskFreeRate: 0.03,      // 3-year Treasury
    beta: 1.2,               // Company beta
    marketReturn: 0.10       // Expected market return
)

print("Cost of Equity: \(costOfEquity * 100)%")  // 11.4%
```

**Formula**: Re = Rf + β × (Rm - Rf)

### Beta Levering & Unlevering

Adjust beta for financial leverage:

```swift
// Remove leverage to get asset beta
let assetBeta = unleverBeta(
    leveredBeta: 1.5,
    debtToEquityRatio: 0.5,
    taxRate: 0.30
)
print("Unlevered Beta: \(assetBeta)")  // 1.11

// Add leverage back for different capital structure
let newEquityBeta = leverBeta(
    unleveredBeta: assetBeta,
    debtToEquityRatio: 0.75,  // Higher leverage
    taxRate: 0.30
)
print("New Levered Beta: \(newEquityBeta)")  // 1.69
```

## Equity Financing & Cap Tables

### Basic Cap Table

Track ownership across founders and investors:

```swift
let alice = CapTable.Shareholder(
    name: "Alice (Founder)",
    shares: 6_000_000,
    investmentDate: Date(),
    pricePerShare: 0.001
)

let bob = CapTable.Shareholder(
    name: "Bob (Founder)",
    shares: 4_000_000,
    investmentDate: Date(),
    pricePerShare: 0.001
)

var capTable = CapTable(
    shareholders: [alice, bob],
    optionPool: 0
)

let ownership = capTable.ownership()
print("Alice owns: \(ownership["Alice (Founder)"]! * 100)%")  // 60%
print("Bob owns: \(ownership["Bob (Founder)"]! * 100)%")      // 40%
```

### Modeling Financing Rounds

Track dilution through funding rounds:

```swift
// Series A: $5M at $15M pre-money
capTable = capTable.modelRound(
    preMoneyValuation: 15_000_000,
    investment: 5_000_000,
    investorName: "VC Fund A"
)

let postSeriesA = capTable.ownership()
print("Alice after Series A: \(postSeriesA["Alice (Founder)"]! * 100)%")  // 45%
print("VC Fund A: \(postSeriesA["VC Fund A"]! * 100)%")                   // 25%

// Series B: $15M at $50M pre-money
capTable = capTable.modelRound(
    preMoneyValuation: 50_000_000,
    investment: 15_000_000,
    investorName: "VC Fund B"
)

let postSeriesB = capTable.ownership()
print("Alice after Series B: \(postSeriesB["Alice (Founder)"]! * 100)%")  // ~34.6%
```

### Option Pool Dilution

Calculate dilution from creating an option pool:

```swift
let prePoolShares = 10_000_000.0
let poolSize = 2_000_000.0  // 2M share option pool

let dilution = optionPoolDilution(
    poolSize: poolSize,
    prePoolShares: prePoolShares
)

print("Founder dilution from option pool: \(dilution * 100)%")  // 16.67%
```

### Anti-Dilution Protection

Model full ratchet and weighted average anti-dilution:

```swift
// Investor has 1M shares at $2/share, now raising at $1/share (down round)
let adjustedShares = applyAntiDilution(
    originalShares: 1_000_000,
    originalPrice: 2.00,
    newPrice: 1.00,
    type: .fullRatchet
)

print("Shares after full ratchet: \(adjustedShares)")  // 2,000,000

// Weighted average is less dilutive
let weightedShares = applyWeightedAverageAntiDilution(
    originalShares: 1_000_000,
    originalPrice: 2.00,
    newPrice: 1.00,
    newShares: 500_000,
    fullyDilutedBeforeRound: 10_000_000
)

print("Shares after weighted average: \(weightedShares)")  // ~1,476,190
```

### SAFE & Convertible Notes

Model Simple Agreements for Future Equity:

```swift
let safe = SAFE(
    investment: 100_000,
    postMoneyCap: 10_000_000,
    type: .postMoney
)

// Convert at Series A
let conversion = safe.convert(seriesAValuation: 20_000_000)
print("SAFE converts to \(conversion.shares) shares")
print("Conversion price: $\(conversion.pricePerShare)")

// Convertible note with discount and cap
let noteConversion = convertNote(
    principal: 500_000,
    valuationCap: 8_000_000,
    discount: 0.20,
    seriesAPrice: 2.00
)

print("Note converts to \(noteConversion.shares) shares")
```

## Debt Covenants

### Monitoring Financial Covenants

Track compliance with lender restrictions:

```swift
let covenants = [
    FinancialCovenant(
        name: "Minimum Current Ratio",
        requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
    ),
    FinancialCovenant(
        name: "Maximum Debt-to-Equity",
        requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
    ),
    FinancialCovenant(
        name: "Minimum Interest Coverage",
        requirement: .minimumRatio(metric: .interestCoverage, threshold: 3.0)
    )
]

let monitor = CovenantMonitor(covenants: covenants)
let results = monitor.checkCompliance(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet,
    period: q1
)

for result in results {
    let status = result.isCompliant ? "✓ PASS" : "✗ FAIL"
    print("\(status) \(result.covenant.name)")
    print("  Actual: \(result.actualValue)")
    print("  Required: \(result.requiredValue)")
}
```

### Interest Coverage Ratio

Calculate a key debt service metric:

```swift
let coverage = calculateInterestCoverage(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet,
    period: q1
)

print("Interest Coverage: \(coverage)x")

if coverage < 2.0 {
    print("Warning: Low interest coverage - difficulty servicing debt")
} else if coverage > 5.0 {
    print("Strong: Company can easily cover interest payments")
}
```

## Lease Accounting

### Lease vs Buy Analysis

Compare the economics of leasing vs purchasing:

```swift
// Leasing: $2,000/month for 5 years
let leasePV = leasePaymentsPV(
    periodicPayment: 2_000,
    periods: 60,
    discountRate: 0.06 / 12
)

// Buying: $100,000 purchase, $500 annual maintenance, $20,000 salvage
let buyPV = buyAssetPV(
    purchasePrice: 100_000,
    salvageValue: 20_000,
    holdingPeriod: 5,
    discountRate: 0.06,
    maintenanceCost: 500
)

let analysis = LeaseVsBuyAnalysis(leasePV: leasePV, buyPV: buyPV)

print("Net Advantage to Leasing: $\(analysis.netAdvantageToLeasing)")
print("Should lease? \(analysis.shouldLease)")
print("Savings: \(analysis.savingsPercentage * 100)%")
```

### Lease Liability & ROU Asset

Calculate present value for balance sheet recognition (IFRS 16 / ASC 842):

```swift
let payments = Array(repeating: 5_000.0, count: 60)  // $5,000/month for 5 years

let lease = Lease(
    payments: payments,
    discountRate: 0.05 / 12,  // Monthly discount rate
    residualValue: 0
)

print("Lease Liability: $\(lease.presentValue())")
print("Right-of-Use Asset: $\(lease.rightOfUseAsset())")

// Generate amortization schedule
let schedule = lease.liabilitySchedule()
for (index, entry) in schedule.prefix(12).enumerated() {
    print("Month \(index + 1):")
    print("  Payment: $\(entry.payment)")
    print("  Interest: $\(entry.interest)")
    print("  Principal: $\(entry.principal)")
    print("  Balance: $\(entry.balance)")
}
```

### Sale-and-Leaseback

Analyze sale-and-leaseback transactions:

```swift
let transaction = SaleAndLeaseback(
    salePrice: 5_000_000,
    bookValue: 4_000_000,
    leaseTerm: 20,
    annualLeasePayment: 400_000,
    discountRate: 0.06
)

print("Gain on Sale: $\(transaction.gainOnSale)")
print("PV of Lease Obligations: $\(transaction.leaseObligationPV)")
print("Net Cash Benefit: $\(transaction.netCashBenefit)")
print("Economically Beneficial? \(transaction.isEconomicallyBeneficial)")
```

### Lease Classification

Determine if a lease is finance or operating (ASC 842):

```swift
let classification = classifyLease(
    leaseTerm: 8,
    assetUsefulLife: 10,
    presentValue: 90_000,
    assetFairValue: 100_000,
    ownershipTransfer: false,
    purchaseOption: false
)

switch classification {
case .finance:
    print("Finance Lease - capitalize on balance sheet")
case .operating:
    print("Operating Lease - expense as incurred")
}
```

## Practical Examples

### Complete Debt Analysis

Analyze a company's debt structure:

```swift
// Existing debt: $500M term loan
let termLoan = DebtInstrument(
    principal: 500_000_000,
    interestRate: 0.055,
    startDate: Date(),
    maturityDate: Calendar.current.date(byAdding: .year, value: 7, to: Date())!,
    paymentFrequency: .quarterly,
    amortizationType: .levelPayment
)

let schedule = termLoan.schedule()

// Current capital structure
let structure = CapitalStructure(
    debtValue: 500_000_000,
    equityValue: 1_000_000_000,
    costOfDebt: 0.055,
    costOfEquity: 0.11,
    taxRate: 0.25
)

print("=== Debt Analysis ===")
print("Quarterly Payment: $\(schedule.payment[schedule.periods.first!]!)")
print("Annual Debt Service: $\(schedule.payment[schedule.periods.first!]! * 4)")
print("Total Interest (Life of Loan): $\(schedule.totalInterest)")
print()
print("=== Capital Structure ===")
print("WACC: \(structure.wacc * 100)%")
print("Debt Ratio: \(structure.debtRatio * 100)%")
print("Annual Tax Shield: $\(structure.annualTaxShield)")
print("After-tax Cost of Debt: \(structure.afterTaxCostOfDebt * 100)%")
```

### Modeling a Financing Round

Track a startup through multiple rounds:

```swift
// Founders start with 10M shares
let founder1 = CapTable.Shareholder(name: "Founder 1", shares: 6_000_000, investmentDate: Date(), pricePerShare: 0.001)
let founder2 = CapTable.Shareholder(name: "Founder 2", shares: 4_000_000, investmentDate: Date(), pricePerShare: 0.001)

var capTable = CapTable(shareholders: [founder1, founder2], optionPool: 0)

print("=== At Founding ===")
var ownership = capTable.ownership()
print("Founder 1: \(ownership["Founder 1"]! * 100)%")
print("Founder 2: \(ownership["Founder 2"]! * 100)%")

// Seed: $2M at $8M pre
capTable = capTable.modelRound(preMoneyValuation: 8_000_000, investment: 2_000_000, investorName: "Seed Investors")
print("\n=== After Seed ($2M at $8M pre) ===")
ownership = capTable.ownership()
for (name, pct) in ownership.sorted(by: { $0.value > $1.value }) {
    print("\(name): \(pct * 100)%")
}

// Series A: $10M at $40M pre
capTable = capTable.modelRound(preMoneyValuation: 40_000_000, investment: 10_000_000, investorName: "Series A Lead")
print("\n=== After Series A ($10M at $40M pre) ===")
ownership = capTable.ownership()
for (name, pct) in ownership.sorted(by: { $0.value > $1.value }) {
    print("\(name): \(pct * 100)%")
}
```

## Best Practices

### Debt Instruments
1. **Match payment frequency to cash flows**: Monthly for consumer, quarterly/annual for commercial
2. **Consider prepayment options**: Factor in early repayment flexibility
3. **Account for fees**: Include origination fees in effective rate calculations
4. **Model different scenarios**: Test sensitivity to interest rate changes

### Capital Structure
1. **Industry benchmarks**: Compare D/E ratios to industry peers
2. **Tax benefits**: Remember debt provides tax shield (interest is deductible)
3. **Financial flexibility**: Maintain access to capital markets
4. **Optimal structure**: Balance tax benefits vs bankruptcy costs

### Equity Financing
1. **Model dilution**: Always project ownership through future rounds
2. **Option pool timing**: Create pool before priced rounds to minimize founder dilution
3. **Protective provisions**: Understand investor rights beyond ownership percentage
4. **409A valuations**: Keep common stock valuations current for option grants

### Lease Accounting
1. **Discount rate**: Use incremental borrowing rate if implicit rate unknown
2. **Lease term**: Include renewal options reasonably certain to be exercised
3. **Variable payments**: Exclude from liability calculation
4. **Reassessment**: Review lease classifications annually

## Next Steps

- Explore <doc:InvestmentAnalysis> for NPV and IRR calculations
- Learn about <doc:FinancialRatiosGuide> for analyzing leverage ratios
- See <doc:ScenarioAnalysisGuide> for modeling multiple financing scenarios
- Review <doc:TimeValueOfMoney> for present value fundamentals

## Related Topics

- ``DebtInstrument``
- ``AmortizationSchedule``
- ``wacc(equityValue:debtValue:costOfEquity:costOfDebt:taxRate:)``
- ``CapitalStructure``
- ``capm(riskFreeRate:beta:marketReturn:)``
- ``CapTable``
- ``SAFE``
- ``FinancialCovenant``
- ``CovenantMonitor``
- ``Lease``
- ``LeaseVsBuyAnalysis``
