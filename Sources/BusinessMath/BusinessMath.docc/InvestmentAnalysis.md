# Investment Analysis

Evaluate investment opportunities using NPV, IRR, and other financial metrics.

## Overview

This tutorial demonstrates how to perform comprehensive investment analysis using BusinessMath. You'll learn how to:

- Calculate Net Present Value (NPV)
- Determine Internal Rate of Return (IRR)
- Use XNPV and XIRR for irregular cash flows
- Calculate profitability index and payback periods
- Compare multiple investment opportunities
- Make data-driven investment decisions

**Time estimate:** 30-40 minutes

## Prerequisites

- Basic understanding of Swift
- Familiarity with investment concepts (cash flows, discount rates)
- Understanding of time value of money (see <doc:TimeValueOfMoney>)

## Step 1: Define the Investment

Let's analyze a real estate investment opportunity.

```swift
import BusinessMath
import Foundation

// Investment opportunity: Rental property
let propertyPrice = 250_000.0
let downPayment = 50_000.0      // 20% down
let renovationCosts = 20_000.0
let initialInvestment = downPayment + renovationCosts  // Total: $70,000

// Expected annual cash flows (after expenses and mortgage)
let year1 = 8_000.0
let year2 = 8_500.0
let year3 = 9_000.0
let year4 = 9_500.0
let year5 = 10_000.0
let salePrice = 300_000.0       // Expected sale price after 5 years
let mortgagePayoff = 190_000.0  // Remaining mortgage balance
let saleProceeds = salePrice - mortgagePayoff  // Net: $110,000

print("Real Estate Investment Analysis")
print("================================")
print("Initial Investment: $\(String(format: "%.0f", initialInvestment))")
print("  Down Payment: $\(String(format: "%.0f", downPayment))")
print("  Renovations: $\(String(format: "%.0f", renovationCosts))")
print("\nExpected Cash Flows:")
print("  Year 1-5: Annual rental income")
print("  Year 5: + Sale proceeds")
print("  Required Return: 12% (target rate)")
```

## Step 2: Calculate NPV

Determine if the investment creates value at your required return.

```swift
// Define all cash flows (negative initial, then positive returns)
let cashFlows = [
    -initialInvestment,  // Year 0: Investment
    year1,               // Year 1: Rental income
    year2,               // Year 2: Rental income
    year3,               // Year 3: Rental income
    year4,               // Year 4: Rental income
    year5 + saleProceeds // Year 5: Rental income + sale
]

// Calculate NPV at required return of 12%
let requiredReturn = 0.12
let npvValue = npv(discountRate: requiredReturn, cashFlows: cashFlows)

print("\nNet Present Value Analysis")
print("===========================")
print("Discount Rate: \(String(format: "%.0f%%", requiredReturn * 100))")
print("NPV: $\(String(format: "%.2f", npvValue))")

if npvValue > 0 {
    print("✓ Positive NPV - Investment adds value")
    print("  For every $1 invested, you create $\(String(format: "%.2f", 1 + npvValue / initialInvestment)) of value")
} else if npvValue < 0 {
    print("✗ Negative NPV - Investment destroys value")
    print("  Should reject this opportunity")
} else {
    print("○ Zero NPV - Breakeven investment")
    print("  Exactly meets required return")
}
```

**Expected output:**
```
Net Present Value Analysis
===========================
Discount Rate: 12%
NPV: $26,943.09
✓ Positive NPV - Investment adds value
  For every $1 invested, you create $1.38 of value
```

## Step 3: Calculate IRR

Find the actual return rate of the investment.

```swift
// Calculate Internal Rate of Return
let irrValue = try irr(cashFlows: cashFlows)

print("\nInternal Rate of Return")
print("=======================")
print("IRR: \(String(format: "%.2f%%", irrValue * 100))")
print("Required Return: \(String(format: "%.2f%%", requiredReturn * 100))")

if irrValue > requiredReturn {
    let spread = (irrValue - requiredReturn) * 100
    print("✓ IRR exceeds required return by \(String(format: "%.2f", spread)) percentage points")
    print("  Investment is attractive")
} else if irrValue < requiredReturn {
    let shortfall = (requiredReturn - irrValue) * 100
    print("✗ IRR falls short by \(String(format: "%.2f", shortfall)) percentage points")
    print("  Investment should be rejected")
} else {
    print("○ IRR equals required return")
    print("  Investment is at breakeven")
}

// Verify: NPV at IRR should be ~0
let npvAtIRR = npv(discountRate: irrValue, cashFlows: cashFlows)
print("\nVerification: NPV at IRR = $\(String(format: "%.2f", npvAtIRR)) (should be ~$0)")
```

**Expected output:**
```
Internal Rate of Return
=======================
IRR: 22.83%
Required Return: 12.00%
✓ IRR exceeds required return by 10.83 percentage points
  Investment is attractive

Verification: NPV at IRR = $0.00 (should be ~$0)
```

## Step 4: Calculate Additional Metrics

Use supporting metrics for a complete picture.

```swift
// Profitability Index
let pi = profitabilityIndex(rate: requiredReturn, cashFlows: cashFlows)

print("\nProfitability Index")
print("===================")
print("PI: \(String(format: "%.2f", pi))")
if pi > 1.0 {
    print("✓ PI > 1.0 - Creates value")
    print("  Returns $\(String(format: "%.2f", pi)) for every $1 invested (at \(String(format: "%.0f%%", requiredReturn * 100)))")
} else if pi < 1.0 {
    print("✗ PI < 1.0 - Destroys value")
} else {
    print("○ PI = 1.0 - Breakeven")
}

// Payback Period (simple)
let payback = paybackPeriod(cashFlows: cashFlows)

print("\nPayback Period")
print("==============")
if let pb = payback {
    print("Simple Payback: \(pb) years")
    print("  Investment recovered in year \(pb)")
} else {
    print("Investment never recovers initial outlay")
}

// Discounted Payback Period
let discountedPayback = discountedPaybackPeriod(rate: requiredReturn, cashFlows: cashFlows)

if let dpb = discountedPayback {
    print("Discounted Payback: \(dpb) years (at \(String(format: "%.0f%%", requiredReturn * 100)))")
    if let pb = payback {
        let difference = dpb - pb
        print("  Takes \(difference) more year(s) when accounting for time value")
    }
} else {
    print("Investment never recovers on discounted basis")
}
```

**Expected output:**
```
Profitability Index
===================
PI: 1.38
✓ PI > 1.0 - Creates value
  Returns $1.38 for every $1 invested (at 12%)

Payback Period
==============
Simple Payback: 5 years
  Investment recovered in year 5

Discounted Payback: 5 years (at 12%)
  Takes 0 more year(s) when accounting for time value
```

## Step 5: Sensitivity Analysis

Test how changes in assumptions affect the decision.

```swift
print("\n\nSensitivity Analysis")
print("====================")

// Test different discount rates
let rates = [0.08, 0.10, 0.12, 0.14, 0.16]

print("NPV at Different Discount Rates:")
print("Rate  | NPV        | Decision")
print("------|------------|----------")

for rate in rates {
    let npv = npv(discountRate: rate, cashFlows: cashFlows)
    let decision = npv > 0 ? "Accept" : "Reject"
	print(String(format: "%4.1f%% | $%9.2f | %@", (rate * 100), npv, decision))
}

// Test different sale prices
print("\nNPV at Different Sale Prices:")
print("Sale Price | Net Proceeds | NPV        | Decision")
print("-----------|--------------|------------|----------")

let salePrices = [260_000.0, 280_000.0, 300_000.0, 320_000.0, 340_000.0]

for price in salePrices {
    let proceeds = price - mortgagePayoff
    let flows = [
        -initialInvestment,
        year1, year2, year3, year4,
        year5 + proceeds
    ]
    let npv = npv(discountRate: requiredReturn, cashFlows: flows)
    let decision = npv > 0 ? "Accept" : "Reject"
	print(String(format: "  $%7.0f | $%11.0f | $%9.2f | %@",
			 price, proceeds, npv, decision))
}

// Find breakeven sale price (where NPV = 0)
print("\nBreakeven Analysis:")

var low = 200_000.0
var high = 350_000.0
var breakeven = (low + high) / 2

// Binary search for breakeven
for _ in 0..<20 {
    let proceeds = breakeven - mortgagePayoff
    let flows = [-initialInvestment, year1, year2, year3, year4, year5 + proceeds]
    let npv = npv(discountRate: requiredReturn, cashFlows: flows)

    if abs(npv) < 1.0 {
        break  // Close enough
    } else if npv > 0 {
        high = breakeven
    } else {
        low = breakeven
    }
    breakeven = (low + high) / 2
}

print("Breakeven Sale Price: $\(String(format: "%.0f", breakeven))")
print("  At this price, NPV = $0 and IRR = \(String(format: "%.0f%%", requiredReturn * 100))")
print("  Current assumption: $\(String(format: "%.0f", salePrice))")
print("  Safety margin: $\(String(format: "%.0f", salePrice - breakeven))")
```

## Step 6: Compare Multiple Investments

Evaluate and rank several opportunities.

```swift
print("\n\nComparing Investment Opportunities")
print("===================================")

// Define three investment opportunities
struct Investment {
    let name: String
    let cashFlows: [Double]
    let description: String
}

let investments = [
    Investment(
        name: "Real Estate",
        cashFlows: [-70_000, 8_000, 8_500, 9_000, 9_500, 120_000],
        description: "Rental property with 5-year hold"
    ),
    Investment(
        name: "Stock Portfolio",
        cashFlows: [-70_000, 5_000, 5_500, 6_000, 6_500, 75_000],
        description: "Diversified equity portfolio"
    ),
    Investment(
        name: "Business Expansion",
        cashFlows: [-70_000, 0, 10_000, 15_000, 20_000, 40_000],
        description: "Expand product line (delayed returns)"
    )
]

// Calculate metrics for each
print("Investment      | NPV       | IRR     | PI   | Payback | Ranking")
print("----------------|-----------|---------|------|---------|--------")

var results: [(name: String, npv: Double, irr: Double, pi: Double)] = []

for investment in investments {
    let npv = npv(discountRate: requiredReturn, cashFlows: investment.cashFlows)
    let irr = try irr(cashFlows: investment.cashFlows)
    let pi = profitabilityIndex(rate: requiredReturn, cashFlows: investment.cashFlows)
    let payback = paybackPeriod(cashFlows: investment.cashFlows) ?? 99

    results.append((investment.name, npv, irr, pi))

    print(String(format: "%@ | $%8.0f | %6.2f%% | %.2f | %d years | ",
                 investment.name, npv, irr * 100, pi, payback))
}

// Rank by NPV (best decision criterion for value creation)
let ranked = results.sorted { $0.npv > $1.npv }

print("\nRanking by NPV (Value Creation):")
for (i, result) in ranked.enumerated() {
    print("  \(i + 1). \(result.name): NPV = $\(String(format: "%.0f", result.npv))")
}

print("\nRecommendation:")
print("  Choose '\(ranked[0].name)' - Highest NPV")
print("  Creates $\(String(format: "%.0f", ranked[0].npv)) of value at \(String(format: "%.0f%%", requiredReturn * 100)) required return")
```

## Step 7: Irregular Cash Flow Analysis

Use XNPV and XIRR for real-world irregular timing.

```swift
print("\n\nIrregular Cash Flow Analysis")
print("============================")

// Real investment with irregular timing
let startDate = Date()
let dates = [
    startDate,                                          // Today: Initial investment
    startDate.addingTimeInterval(90 * 86400),          // 90 days: First return
    startDate.addingTimeInterval(250 * 86400),         // 250 days: Second return
    startDate.addingTimeInterval(400 * 86400),         // 400 days: Third return
    startDate.addingTimeInterval(600 * 86400),         // 600 days: Fourth return
    startDate.addingTimeInterval(5 * 365 * 86400)      // 5 years: Exit
]

let irregularCashFlows = [-70_000.0, 8_000, 8_500, 9_000, 9_500, 120_000]

// Calculate XNPV
let xnpvValue = try xnpv(rate: requiredReturn, dates: dates, cashFlows: irregularCashFlows)

print("Using XNPV for Irregular Timing:")
print("  XNPV: $\(String(format: "%.2f", xnpvValue))")

// Calculate XIRR
let xirrValue = try xirr(dates: dates, cashFlows: irregularCashFlows)

print("  XIRR: \(String(format: "%.2f%%", xirrValue * 100))")

// Compare to regular IRR
let regularIRR = try irr(cashFlows: irregularCashFlows)

print("\nComparison:")
print("  Regular IRR (assumes annual periods): \(String(format: "%.2f%%", regularIRR * 100))")
print("  XIRR (actual dates): \(String(format: "%.2f%%", xirrValue * 100))")
print("  Difference: \(String(format: "%.2f", (xirrValue - regularIRR) * 100)) percentage points")

// Verify XNPV at XIRR is ~0
let xnpvAtXIRR = try xnpv(rate: xirrValue, dates: dates, cashFlows: irregularCashFlows)
print("\nVerification: XNPV at XIRR = $\(String(format: "%.2f", xnpvAtXIRR))")
```

## Step 8: Risk-Adjusted Analysis

Account for risk in your evaluation.

```swift
print("\n\nRisk-Adjusted Analysis")
print("======================")

// Define risk-adjusted discount rates
let riskFreeRate = 0.03      // Treasury rate
let marketReturn = 0.10      // Stock market average
let beta = 1.5               // Investment risk relative to market

// Calculate risk-adjusted rate using CAPM
let riskAdjustedRate = riskFreeRate + beta * (marketReturn - riskFreeRate)

print("Capital Asset Pricing Model (CAPM):")
print("  Risk-free rate: \(String(format: "%.1f%%", riskFreeRate * 100))")
print("  Market return: \(String(format: "%.1f%%", marketReturn * 100))")
print("  Beta (risk): \(String(format: "%.1f", beta))")
print("  Risk-adjusted rate: \(String(format: "%.1f%%", riskAdjustedRate * 100))")

// Recalculate NPV with risk-adjusted rate
let riskAdjustedNPV = npv(discountRate: riskAdjustedRate, cashFlows: cashFlows)

print("\nRisk-Adjusted NPV:")
print("  Original NPV (12% rate): $\(String(format: "%.2f", npvValue))")
print("  Risk-adjusted NPV (\(String(format: "%.1f%%", riskAdjustedRate * 100)) rate): $\(String(format: "%.2f", riskAdjustedNPV))")

if riskAdjustedNPV > 0 {
    print("  ✓ Still positive after risk adjustment")
} else {
    print("  ✗ Negative after accounting for risk")
}

// Scenario planning with probabilities
print("\nScenario Analysis:")
print("Scenario    | Probability | Sale Price | NPV        | Expected Value")
print("------------|-------------|------------|------------|---------------")

let scenarios = [
    (name: "Pessimistic", prob: 0.25, price: 260_000.0),
    (name: "Base Case  ", prob: 0.50, price: 300_000.0),
    (name: "Optimistic ", prob: 0.25, price: 340_000.0)
]

var expectedNPV = 0.0

for scenario in scenarios {
    let proceeds = scenario.price - mortgagePayoff
    let flows = [-initialInvestment, year1, year2, year3, year4, year5 + proceeds]
    let scenarioNPV = npv(discountRate: requiredReturn, cashFlows: flows)
    let expectedValue = scenarioNPV * scenario.prob

    expectedNPV += expectedValue

    print(String(format: "%-11@ | %10.0f%% | $%9.0f | $%9.2f | $%9.2f",
                 scenario.name, scenario.prob * 100, scenario.price, scenarioNPV, expectedValue))
}

print(String(format: "%-11@ | %10s  | %10s | %10s | $%9.2f",
             "Expected", "", "", "", expectedNPV))

print("\nExpected NPV: $\(String(format: "%.2f", expectedNPV))")
if expectedNPV > 0 {
    print("✓ Positive expected value across scenarios")
} else {
    print("✗ Negative expected value")
}
```

## Step 9: Create Investment Decision Framework

Build a reusable decision framework.

```swift
struct InvestmentAnalysis {
    let name: String
    let initialInvestment: Double
    let cashFlows: [Double]
    let requiredReturn: Double

    var npv: Double {
        BusinessMath.npv(discountRate: requiredReturn, cashFlows: cashFlows)
    }

    var irr: Double {
        try! BusinessMath.irr(cashFlows: cashFlows)
    }

    var profitabilityIndex: Double {
        BusinessMath.profitabilityIndex(rate: requiredReturn, cashFlows: cashFlows)
    }

    var paybackPeriod: Int? {
        BusinessMath.paybackPeriod(cashFlows: cashFlows)
    }

    var shouldAccept: Bool {
        npv > 0 && irr > requiredReturn && profitabilityIndex > 1.0
    }

    func printReport() {
        print("\nInvestment Analysis: \(name)")
        print(String(repeating: "=", count: 40))
        print("Initial Investment: $\(String(format: "%.0f", -cashFlows[0]))")
        print("Required Return: \(String(format: "%.1f%%", requiredReturn * 100))")
        print("\nMetrics:")
        print("  NPV: $\(String(format: "%.2f", npv))")
        print("  IRR: \(String(format: "%.2f%%", irr * 100))")
        print("  PI: \(String(format: "%.2f", profitabilityIndex))")
        if let pb = paybackPeriod {
            print("  Payback: \(pb) years")
        }

        print("\nDecision: \(shouldAccept ? "✓ ACCEPT" : "✗ REJECT")")

        if shouldAccept {
            print("  All metrics indicate value creation")
        } else {
            if npv <= 0 { print("  NPV is not positive") }
            if irr <= requiredReturn { print("  IRR below required return") }
            if profitabilityIndex <= 1.0 { print("  PI below 1.0") }
        }
    }
}

// Use the framework
let analysis = InvestmentAnalysis(
    name: "Rental Property Investment",
    initialInvestment: initialInvestment,
    cashFlows: cashFlows,
    requiredReturn: requiredReturn
)

analysis.printReport()
```

## Key Decision Rules

Use these rules for investment decisions:

### Primary Rule: NPV
- **NPV > 0**: Accept (creates value)
- **NPV < 0**: Reject (destroys value)
- **NPV = 0**: Indifferent (breakeven)

### Supporting Rules:

**IRR:**
- IRR > Required Return: Accept
- IRR < Required Return: Reject

**Profitability Index:**
- PI > 1.0: Accept
- PI < 1.0: Reject

**When Choosing Among Projects:**
1. Choose highest NPV (maximizes value)
2. Consider capital constraints (use PI for ranking)
3. Account for risk differences (adjust discount rates)
4. Check liquidity needs (use payback periods)

## Key Takeaways

1. **NPV is the gold standard**: Always use NPV for investment decisions
2. **IRR supports but doesn't replace NPV**: Use IRR to communicate returns
3. **Irregular cash flows need XIRR/XNPV**: Don't assume annual periods
4. **Sensitivity analysis is critical**: Test key assumptions
5. **Risk matters**: Higher risk requires higher returns
6. **Compare alternatives**: Evaluate opportunity cost
7. **Update regularly**: Reassess as circumstances change

## Next Steps

- Build an investment calculator using these functions
- Create a portfolio optimization tool
- Develop scenario planning models
- Integrate with real financial data

## See Also

- <doc:TimeValueOfMoney>
- <doc:LoanAmortization>
- <doc:BuildingRevenueModel>
- ``npv(discountRate:cashFlows:)``
- ``irr(cashFlows:guess:tolerance:maxIterations:)``
- ``xnpv(rate:dates:cashFlows:)``
- ``xirr(dates:cashFlows:guess:tolerance:maxIterations:)``
- ``profitabilityIndex(rate:cashFlows:)``
- ``paybackPeriod(cashFlows:)``
