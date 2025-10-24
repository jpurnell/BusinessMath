# Financial Ratios & Metrics

Learn how to analyze financial performance using key ratios and metrics.

## Overview

BusinessMath provides comprehensive financial ratio analysis to evaluate profitability, efficiency, liquidity, solvency, and valuation. This tutorial shows you how to calculate and interpret key metrics for investment analysis and business performance evaluation.

## Content

## Understanding Financial Ratios

Financial ratios fall into five main categories:

- **Profitability**: How efficiently does the company generate profits?
- **Efficiency**: How effectively does the company use its assets?
- **Liquidity**: Can the company meet short-term obligations?
- **Solvency**: Can the company meet long-term obligations?
- **Valuation**: What is the company worth relative to earnings/assets?

## Profitability Ratios

Measure how well a company generates profit from its operations:

```swift
import BusinessMath

// Assume we have an IncomeStatement and BalanceSheet
let periods = [q1, q2, q3, q4]

// Return on Assets (ROA): Net Income / Average Assets
let roaTimeSeries = returnOnAssets(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)
print("Q1 ROA: \(roaTimeSeries[q1]! * 100)%")

// Return on Equity (ROE): Net Income / Average Equity
let roeTimeSeries = returnOnEquity(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)
print("Q1 ROE: \(roeTimeSeries[q1]! * 100)%")

// Return on Invested Capital (ROIC)
let roicTimeSeries = returnOnInvestedCapital(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)
print("Q1 ROIC: \(roicTimeSeries[q1]! * 100)%")

// Get all profitability ratios at once
let profitability = profitabilityRatios(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)

print("\n=== Profitability Analysis ===")
print("Gross Margin: \(profitability.grossMargin[q1]! * 100)%")
print("Operating Margin: \(profitability.operatingMargin[q1]! * 100)%")
print("Net Margin: \(profitability.netMargin[q1]! * 100)%")
print("EBITDA Margin: \(profitability.ebitdaMargin[q1]! * 100)%")
print("ROA: \(profitability.roa[q1]! * 100)%")
print("ROE: \(profitability.roe[q1]! * 100)%")
print("ROIC: \(profitability.roic[q1]! * 100)%")
```

**Interpretation:**
- **High margins** indicate pricing power or cost advantages
- **ROA > 5%** is generally good (varies by industry)
- **ROE > 15%** indicates strong shareholder returns
- **ROIC > WACC** means the company creates value

## Efficiency Ratios

Measure how well a company uses its assets:

```swift
// Get all efficiency ratios
let efficiency = efficiencyRatios(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)

print("\n=== Efficiency Analysis ===")
print("Asset Turnover: \(efficiency.assetTurnover[q1]!)")
print("Inventory Turnover: \(efficiency.inventoryTurnover[q1]!)")
print("Receivables Turnover: \(efficiency.receivablesTurnover[q1]!)")
print("Days Sales Outstanding: \(efficiency.daysSalesOutstanding[q1]!) days")
print("Days Inventory Outstanding: \(efficiency.daysInventoryOutstanding[q1]!) days")
print("Days Payable Outstanding: \(efficiency.daysPayableOutstanding[q1]!) days")

// Cash Conversion Cycle
let ccc = efficiency.cashConversionCycle[q1]!
print("Cash Conversion Cycle: \(ccc) days")
```

**Interpretation:**
- **Higher turnover** = more efficient use of assets
- **Lower DSO** = faster cash collection
- **Shorter CCC** = less cash tied up in operations
- Compare to industry benchmarks

## Liquidity Ratios

Measure ability to meet short-term obligations:

```swift
// Get all liquidity ratios
let liquidity = liquidityRatios(balanceSheet: balanceSheet)

print("\n=== Liquidity Analysis ===")
print("Current Ratio: \(liquidity.currentRatio[q1]!)")
print("Quick Ratio: \(liquidity.quickRatio[q1]!)")
print("Cash Ratio: \(liquidity.cashRatio[q1]!)")
print("Working Capital: $\(liquidity.workingCapital[q1]!)")

// Assess liquidity health
let currentRatio = liquidity.currentRatio[q1]!
if currentRatio < 1.0 {
    print("⚠️  Warning: Current ratio < 1.0 indicates potential liquidity issues")
} else if currentRatio > 3.0 {
    print("ℹ️  Note: High current ratio may indicate inefficient use of assets")
} else {
    print("✓ Current ratio in healthy range")
}
```

**Interpretation:**
- **Current Ratio > 1.5** indicates good short-term health
- **Quick Ratio > 1.0** means company can pay bills without selling inventory
- **Cash Ratio > 0.5** is strong
- Too high may indicate poor asset utilization

## Solvency Ratios

Measure ability to meet long-term obligations:

```swift
// Get all solvency ratios
let solvency = solvencyRatios(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)

print("\n=== Solvency Analysis ===")
print("Debt-to-Equity: \(solvency.debtToEquity[q1]!)")
print("Debt-to-Assets: \(solvency.debtToAssets[q1]!)")
print("Equity Ratio: \(solvency.equityRatio[q1]!)")
print("Interest Coverage: \(solvency.interestCoverage[q1]!)x")
print("Debt Service Coverage: \(solvency.debtServiceCoverage[q1]!)x")

// Assess leverage
let debtToEquity = solvency.debtToEquity[q1]!
if debtToEquity > 2.0 {
    print("⚠️  High leverage - company relies heavily on debt")
} else if debtToEquity < 0.5 {
    print("ℹ️  Conservative capital structure - may be underlevered")
} else {
    print("✓ Balanced capital structure")
}

// Check interest coverage
let interestCoverage = solvency.interestCoverage[q1]!
if interestCoverage < 2.0 {
    print("⚠️  Low interest coverage - may struggle to pay interest")
} else if interestCoverage > 5.0 {
    print("✓ Strong interest coverage")
}
```

**Interpretation:**
- **Lower D/E** = less risky, but may miss growth opportunities
- **Higher D/E** = more leverage, higher risk and return potential
- **Interest Coverage > 3x** is generally safe
- Industry context matters (utilities vs tech)

## Valuation Metrics

Determine market value relative to fundamentals:

```swift
// Market data needed for valuation
let sharesOutstanding: Double = 1_000_000
let marketPrice: Double = 50.0  // Stock price

// Create valuation metrics
let valuation = valuationMetrics(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet,
    sharesOutstanding: sharesOutstanding,
    marketPrice: marketPrice
)

print("\n=== Valuation Metrics ===")
print("Market Cap: $\(valuation.marketCap[q1]!)")
print("Price-to-Earnings (P/E): \(valuation.priceToEarnings[q1]!)")
print("Price-to-Book (P/B): \(valuation.priceToBook[q1]!)")
print("Price-to-Sales (P/S): \(valuation.priceToSales[q1]!)")
print("Enterprise Value: $\(valuation.enterpriseValue[q1]!)")
print("EV/EBITDA: \(valuation.evToEbitda[q1]!)")
print("EV/Sales: \(valuation.evToSales[q1]!)")

// Earnings yield (inverse of P/E)
let earningsYield = 1.0 / valuation.priceToEarnings[q1]!
print("Earnings Yield: \(earningsYield * 100)%")
```

**Interpretation:**
- **P/E Ratio**:
  - Low (< 15): May be undervalued or low growth
  - High (> 25): Expensive or high growth expected
- **P/B Ratio**:
  - < 1.0: Trading below book value
  - > 3.0: Premium valuation
- **EV/EBITDA**: Better than P/E for comparing companies with different capital structures

## DuPont Analysis

Decompose ROE to understand its drivers:

```swift
// 3-Way DuPont Analysis
let dupont = dupontAnalysis(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)

print("\n=== 3-Way DuPont Analysis ===")
print("ROE = Net Margin × Asset Turnover × Equity Multiplier")
print()
print("Net Margin: \(dupont.netMargin[q1]! * 100)%")
print("Asset Turnover: \(dupont.assetTurnover[q1]!)")
print("Equity Multiplier: \(dupont.equityMultiplier[q1]!)")
print("ROE: \(dupont.roe[q1]! * 100)%")

// Verify the formula
let calculated = dupont.netMargin[q1]! *
                 dupont.assetTurnover[q1]! *
                 dupont.equityMultiplier[q1]!
print("\nVerification: \(calculated * 100)% ≈ \(dupont.roe[q1]! * 100)%")

// 5-Way DuPont Analysis (more detailed)
let dupont5 = dupontAnalysis5Way(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)

print("\n=== 5-Way DuPont Analysis ===")
print("ROE = Tax Burden × Interest Burden × Operating Margin × Asset Turnover × Equity Multiplier")
print()
print("Tax Burden: \(dupont5.taxBurden[q1]!)")
print("Interest Burden: \(dupont5.interestBurden[q1]!)")
print("Operating Margin: \(dupont5.operatingMargin[q1]! * 100)%")
print("Asset Turnover: \(dupont5.assetTurnover[q1]!)")
print("Equity Multiplier: \(dupont5.equityMultiplier[q1]!)")
print("ROE: \(dupont5.roe[q1]! * 100)%")
```

**Interpretation:**
- **High Net Margin**: Company has pricing power (luxury goods)
- **High Asset Turnover**: Efficient operations (retail)
- **High Equity Multiplier**: Using leverage (banks)
- Use to compare companies and identify ROE drivers

## Credit Metrics

Assess bankruptcy risk and financial strength:

```swift
// Altman Z-Score (bankruptcy prediction)
let altmanZ = altmanZScore(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet
)

print("\n=== Altman Z-Score ===")
print("Z-Score: \(altmanZ[q1]!)")

let zScore = altmanZ[q1]!
if zScore > 2.99 {
    print("✓ Safe zone - low bankruptcy risk")
} else if zScore > 1.81 {
    print("⚠️  Grey zone - moderate risk")
} else {
    print("⚠️  Distress zone - high bankruptcy risk")
}

// Piotroski F-Score (fundamental strength, 0-9)
let piotroski = piotroskiFScore(
    incomeStatement: incomeStatement,
    balanceSheet: balanceSheet,
    cashFlowStatement: cashFlowStatement
)

print("\n=== Piotroski F-Score ===")
print("F-Score: \(Int(piotroski[q1]!)) / 9")

let fScore = Int(piotroski[q1]!)
if fScore >= 7 {
    print("✓ Strong fundamentals")
} else if fScore >= 4 {
    print("ℹ️  Moderate fundamentals")
} else {
    print("⚠️  Weak fundamentals")
}
```

**Interpretation:**
- **Altman Z-Score**:
  - > 3.0: Financially sound
  - 1.8-3.0: Watch zone
  - < 1.8: High bankruptcy risk
- **Piotroski F-Score**:
  - 8-9: Very strong
  - 5-7: Solid
  - 0-4: Weak

## Comparing Companies

Analyze multiple companies side-by-side:

```swift
struct CompanyAnalysis {
    let name: String
    let profitability: ProfitabilityRatios
    let efficiency: EfficiencyRatios
    let liquidity: LiquidityRatios
    let solvency: SolvencyRatios

    func printSummary(for period: Period) {
        print("\n=== \(name) ===")
        print("ROE: \(profitability.roe[period]! * 100)%")
        print("ROA: \(profitability.roa[period]! * 100)%")
        print("Asset Turnover: \(efficiency.assetTurnover[period]!)")
        print("Current Ratio: \(liquidity.currentRatio[period]!)")
        print("D/E: \(solvency.debtToEquity[period]!)")
    }
}

let company1 = CompanyAnalysis(
    name: "TechCo",
    profitability: profitabilityRatios(
        incomeStatement: techIncomeStatement,
        balanceSheet: techBalanceSheet
    ),
    efficiency: efficiencyRatios(
        incomeStatement: techIncomeStatement,
        balanceSheet: techBalanceSheet
    ),
    liquidity: liquidityRatios(balanceSheet: techBalanceSheet),
    solvency: solvencyRatios(
        incomeStatement: techIncomeStatement,
        balanceSheet: techBalanceSheet
    )
)

let company2 = CompanyAnalysis(
    name: "RetailCo",
    profitability: profitabilityRatios(
        incomeStatement: retailIncomeStatement,
        balanceSheet: retailBalanceSheet
    ),
    efficiency: efficiencyRatios(
        incomeStatement: retailIncomeStatement,
        balanceSheet: retailBalanceSheet
    ),
    liquidity: liquidityRatios(balanceSheet: retailBalanceSheet),
    solvency: solvencyRatios(
        incomeStatement: retailIncomeStatement,
        balanceSheet: retailBalanceSheet
    )
)

company1.printSummary(for: q1)
company2.printSummary(for: q1)

// Compare key metrics
print("\n=== Comparison ===")
let tech_roe = company1.profitability.roe[q1]!
let retail_roe = company2.profitability.roe[q1]!

if tech_roe > retail_roe {
    print("TechCo has higher ROE (\(tech_roe * 100)% vs \(retail_roe * 100)%)")
} else {
    print("RetailCo has higher ROE")
}
```

## Tracking Trends Over Time

Monitor how ratios change:

```swift
// Analyze trends across quarters
print("\n=== Profitability Trends ===")
print("Period        ROE     ROA    Net Margin")
for period in periods {
    let roe = profitability.roe[period]!
    let roa = profitability.roa[period]!
    let margin = profitability.netMargin[period]!

    print(String(format: "%-12s  %5.1f%%  %5.1f%%  %5.1f%%",
        String(describing: period),
        roe * 100,
        roa * 100,
        margin * 100
    ))
}

// Calculate quarter-over-quarter growth
let q1_roe = profitability.roe[q1]!
let q2_roe = profitability.roe[q2]!
let qoq_growth = ((q2_roe - q1_roe) / q1_roe) * 100
print("\nQ2 ROE growth vs Q1: \(qoq_growth)%")

// Year-over-year comparison
// (Requires prior year data)
```

## Industry Benchmarks

Typical ranges by industry:

## Technology Companies
- **Gross Margin**: 60-80%
- **ROE**: 15-30%
- **D/E**: 0.1-0.5 (low leverage)
- **Asset Turnover**: 0.5-1.0

## Retail Companies
- **Gross Margin**: 25-40%
- **ROE**: 15-25%
- **D/E**: 0.5-1.5
- **Asset Turnover**: 2.0-4.0 (high)

## Manufacturing
- **Gross Margin**: 30-50%
- **ROE**: 10-20%
- **D/E**: 0.8-1.5
- **Asset Turnover**: 1.0-2.0

## Financial Services
- **Net Margin**: 15-25%
- **ROE**: 10-15%
- **D/E**: 5.0-10.0 (high leverage)
- **Equity Multiplier**: 10-20x

## Best Practices

1. **Use Multiple Ratios**: No single ratio tells the full story
2. **Compare to Peers**: Absolute values matter less than relative performance
3. **Track Trends**: Look for improving or deteriorating patterns
4. **Understand Context**: Industry, size, and life cycle matter
5. **Verify Calculations**: Check that numbers make sense
6. **Look for Red Flags**:
   - Deteriorating margins
   - Rising D/E with falling coverage
   - Negative cash flow with positive earnings
   - Z-Score in distress zone

## Next Steps

- Learn about <doc:ScenarioAnalysis> to model ratio sensitivity
- Explore <doc:VisualizationGuide> for charting trends
- See <doc:FinancialStatements> for building the underlying data

## Related Topics

- ``profitabilityRatios(incomeStatement:balanceSheet:)``
- ``efficiencyRatios(incomeStatement:balanceSheet:)``
- ``liquidityRatios(balanceSheet:)``
- ``solvencyRatios(incomeStatement:balanceSheet:)``
- ``valuationMetrics(incomeStatement:balanceSheet:sharesOutstanding:marketPrice:)``
- ``dupontAnalysis(incomeStatement:balanceSheet:)``
- ``dupontAnalysis5Way(incomeStatement:balanceSheet:)``
- ``altmanZScore(incomeStatement:balanceSheet:)``
- ``piotroskiFScore(incomeStatement:balanceSheet:cashFlowStatement:)``
