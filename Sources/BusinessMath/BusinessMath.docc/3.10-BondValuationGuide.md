# Bond Valuation & Credit Analysis Guide

Price bonds, analyze credit risk, and value embedded options using industry-standard models.

## Overview

This tutorial demonstrates how to value fixed income securities and assess credit risk. You'll learn how to:

- Price bonds and calculate yield to maturity (YTM)
- Measure interest rate risk using duration and convexity
- Convert credit metrics (Z-Scores) to default probabilities and credit spreads
- Value callable bonds and calculate Option-Adjusted Spread (OAS)
- Build credit curves and analyze default risk over time
- Calculate expected losses for bond portfolios
- Make informed fixed income investment decisions

**Time estimate:** 60-75 minutes

## Prerequisites

- Basic understanding of Swift
- Familiarity with financial statements
- Understanding of time value of money (see <doc:TimeValueOfMoney>)
- Knowledge of credit analysis basics

## Bond Valuation Approaches

There are several key components to bond analysis:

### 1. Bond Pricing
Calculate present value of future cash flows (coupons + principal)

### 2. Credit Risk Analysis
Assess probability of default and determine appropriate credit spreads

### 3. Embedded Options
Value call and put provisions using binomial trees

### 4. Portfolio Risk
Measure aggregate credit exposure and expected losses

## Step 1: Basic Bond Pricing

Let's start by pricing a simple corporate bond.

```swift
import BusinessMath
import Foundation

// Scenario: 5-year corporate bond
// - Face value: $1,000
// - Annual coupon: 6%
// - Semiannual payments
// - Current market yield: 5%

let calendar = Calendar.current
let today = Date()
let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

let bond = Bond(
    faceValue: 1000.0,
    couponRate: 0.06,
    maturityDate: maturity,
    paymentFrequency: .semiAnnual,
    issueDate: today
)

let marketPrice = bond.price(yield: 0.05, asOf: today)

print("Bond Pricing")
print("============")
print("Face Value: $1,000")
print("Coupon Rate: 6%")
print("Market Yield: 5%")
print("Price: $\(String(format: "%.2f", marketPrice))")
// Output: Price: $1,043.30 (trades at premium since coupon > yield)

// Calculate current yield
let currentYield = bond.currentYield(price: marketPrice)
print("Current Yield: \(String(format: "%.2f", currentYield * 100))%")
// Output: Current Yield: 5.75%
```

**Key Insight:** When the coupon rate exceeds the market yield, bonds trade at a **premium** to par. When yield exceeds coupon, bonds trade at a **discount**. This inverse relationship between price and yield is fundamental to fixed income.

## Step 2: Yield to Maturity (YTM)

Given a market price, we can solve for the internal rate of return (YTM).

```swift
// Scenario: Find YTM given market price

let observedPrice = 980.00  // Trading below par

do {
    let ytm = try bond.yieldToMaturity(price: observedPrice, asOf: today)

    print("\nYield to Maturity Analysis")
    print("=========================")
    print("Market Price: $\(String(format: "%.2f", observedPrice))")
    print("YTM: \(String(format: "%.2f", ytm * 100))%")

    // Verify round-trip: Price → YTM → Price
    let verifyPrice = bond.price(yield: ytm, asOf: today)
    print("Verification Price: $\(String(format: "%.2f", verifyPrice))")
    print("Difference: $\(String(format: "%.2f", abs(verifyPrice - observedPrice)))")

} catch {
    print("YTM calculation failed: \(error)")
}
```

**Key Insight:** YTM represents the total return if you buy the bond at the current price and hold to maturity, assuming all coupons are reinvested at the YTM rate. It's the most common measure of bond returns.

## Step 3: Duration and Convexity

Measure interest rate risk with duration and convexity.

```swift
// Duration measures price sensitivity to yield changes

let yield = 0.05

let macaulayDuration = bond.macaulayDuration(yield: yield, asOf: today)
let modifiedDuration = bond.modifiedDuration(yield: yield, asOf: today)
let convexity = bond.convexity(yield: yield, asOf: today)

print("\nInterest Rate Risk Metrics")
print("==========================")
print("Macaulay Duration: \(String(format: "%.2f", macaulayDuration)) years")
print("Modified Duration: \(String(format: "%.2f", modifiedDuration))")
print("Convexity: \(String(format: "%.2f", convexity))")

// Estimate price change from 1% yield increase
let yieldChange = 0.01  // 100 bps
let priceChange = -modifiedDuration * yieldChange * 100

print("\nIf yield increases by 100 bps:")
print("Estimated price change: \(String(format: "%.2f", priceChange))%")

// More accurate estimate using convexity
let convexityAdjustment = 0.5 * convexity * yieldChange * yieldChange * 100
let improvedEstimate = priceChange + convexityAdjustment

print("With convexity adjustment: \(String(format: "%.2f", improvedEstimate))%")

// Actual price change
let newPrice = bond.price(yield: yield + yieldChange, asOf: today)
let originalPrice = bond.price(yield: yield, asOf: today)
let actualChange = ((newPrice / originalPrice) - 1.0) * 100

print("Actual price change: \(String(format: "%.2f", actualChange))%")
```

**Key Insight:** **Duration** provides a linear approximation of price changes, while **convexity** captures the curvature of the price-yield relationship. For large yield changes, convexity significantly improves accuracy. Bonds with higher duration are more sensitive to interest rate changes.

## Step 4: Credit Risk Analysis

Convert company credit metrics to bond pricing.

```swift
// Scenario: Price a corporate bond given company fundamentals

// Step 1: Start with company credit metrics (Altman Z-Score)
let zScore = 2.3  // Grey zone (moderate credit risk)

// Step 2: Convert Z-Score to default probability
let creditModel = CreditSpreadModel<Double>()
let defaultProbability = creditModel.defaultProbability(zScore: zScore)

print("\nCredit Risk Analysis")
print("====================")
print("Z-Score: \(String(format: "%.2f", zScore))")
print("Default Probability: \(String(format: "%.2f", defaultProbability * 100))%")

// Step 3: Determine recovery rate based on seniority
let seniority = Seniority.seniorUnsecured
let recoveryRate = RecoveryModel<Double>.standardRecoveryRate(
    seniority: seniority
)

print("Seniority: Senior Unsecured")
print("Expected Recovery: \(String(format: "%.0f", recoveryRate * 100))%")

// Step 4: Calculate credit spread
let creditSpread = creditModel.creditSpread(
    defaultProbability: defaultProbability,
    recoveryRate: recoveryRate,
    maturity: 5.0
)

print("Credit Spread: \(String(format: "%.0f", creditSpread * 10000)) bps")

// Step 5: Calculate corporate bond yield
let riskFreeRate = 0.03  // 3% Treasury
let corporateYield = creditModel.corporateBondYield(
    riskFreeRate: riskFreeRate,
    creditSpread: creditSpread
)

print("Risk-Free Rate: \(String(format: "%.2f", riskFreeRate * 100))%")
print("Corporate Yield: \(String(format: "%.2f", corporateYield * 100))%")

// Step 6: Price the bond
let corporateBond = Bond(
    faceValue: 1000.0,
    couponRate: 0.05,  // 5% coupon
    maturityDate: maturity,
    paymentFrequency: .semiAnnual,
    issueDate: today
)

let corporatePrice = corporateBond.price(yield: corporateYield, asOf: today)
print("Bond Price: $\(String(format: "%.2f", corporatePrice))")
```

**Key Insight:** The complete workflow—**Z-Score → Default Probability → Credit Spread → Bond Yield → Bond Price**—bridges fundamental credit analysis to market pricing. The credit spread compensates investors for bearing default risk and is inversely related to credit quality.

## Step 5: Credit Deterioration Impact

See how credit changes affect bond values.

```swift
// Compare prices across credit quality spectrum

let scenarios = [
    (name: "Investment Grade", zScore: 3.5),
    (name: "Grey Zone", zScore: 2.0),
    (name: "Distress", zScore: 1.0)
]

print("\nCredit Deterioration Impact")
print("===========================")

for scenario in scenarios {
    let pd = creditModel.defaultProbability(zScore: scenario.zScore)
    let spread = creditModel.creditSpread(
        defaultProbability: pd,
        recoveryRate: recoveryRate,
        maturity: 5.0
    )
    let yld = riskFreeRate + spread
    let price = corporateBond.price(yield: yld, asOf: today)

    print("\n\(scenario.name):")
    print("  Z-Score: \(String(format: "%.1f", scenario.zScore))")
    print("  Default Prob: \(String(format: "%.1f", pd * 100))%")
    print("  Spread: \(String(format: "%.0f", spread * 10000)) bps")
    print("  Price: $\(String(format: "%.2f", price))")
}
```

**Key Insight:** Credit deterioration leads to **wider spreads** and **lower bond prices**. The relationship is non-linear—distressed credits see disproportionately large spread widening and price declines.

## Step 6: Callable Bonds and Option-Adjusted Spread

Value bonds with embedded call options.

```swift
// Scenario: High-coupon callable bond
// Issuer has option to refinance if rates fall

let highCouponBond = Bond(
    faceValue: 1000.0,
    couponRate: 0.07,  // 7% coupon (above market)
    maturityDate: calendar.date(byAdding: .year, value: 10, to: today)!,
    paymentFrequency: .semiAnnual,
    issueDate: today
)

// Callable after 3 years at 1040 (4% premium)
let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
let callSchedule = [CallProvision(date: callDate, callPrice: 1040.0)]

let callableBond = CallableBond(
    bond: highCouponBond,
    callSchedule: callSchedule
)

let volatility = 0.15  // 15% interest rate volatility

// Step 1: Price non-callable bond
let straightYield = riskFreeRate + creditSpread
let straightPrice = highCouponBond.price(yield: straightYield, asOf: today)

// Step 2: Price callable bond
let callablePrice = callableBond.price(
    riskFreeRate: riskFreeRate,
    spread: creditSpread,
    volatility: volatility,
    asOf: today
)

// Step 3: Calculate embedded option value
let callOptionValue = callableBond.callOptionValue(
    riskFreeRate: riskFreeRate,
    spread: creditSpread,
    volatility: volatility,
    asOf: today
)

print("\nCallable Bond Analysis")
print("======================")
print("Non-Callable Price: $\(String(format: "%.2f", straightPrice))")
print("Callable Price: $\(String(format: "%.2f", callablePrice))")
print("Call Option Value: $\(String(format: "%.2f", callOptionValue))")
print("Difference: $\(String(format: "%.2f", straightPrice - callablePrice))")

// Step 4: Calculate Option-Adjusted Spread (OAS)
do {
    let oas = try callableBond.optionAdjustedSpread(
        marketPrice: callablePrice,
        riskFreeRate: riskFreeRate,
        volatility: volatility,
        asOf: today
    )

    print("\nSpread Decomposition:")
    print("Nominal Spread: \(String(format: "%.0f", creditSpread * 10000)) bps")
    print("OAS (credit only): \(String(format: "%.0f", oas * 10000)) bps")
    print("Option Spread: \(String(format: "%.0f", (creditSpread - oas) * 10000)) bps")

} catch {
    print("OAS calculation failed: \(error)")
}

// Step 5: Effective duration (accounts for call option)
let effectiveDuration = callableBond.effectiveDuration(
    riskFreeRate: riskFreeRate,
    spread: creditSpread,
    volatility: volatility,
    asOf: today
)

let straightDuration = highCouponBond.macaulayDuration(
    yield: straightYield,
    asOf: today
)

print("\nDuration Comparison:")
print("Non-Callable Duration: \(String(format: "%.2f", straightDuration)) years")
print("Effective Duration: \(String(format: "%.2f", effectiveDuration)) years")
print("Duration Reduction: \(String(format: "%.1f", ((1 - effectiveDuration / straightDuration) * 100)))%")
```

**Key Insight:** Callable bonds trade at **lower prices** than non-callable bonds because the issuer holds a valuable refinancing option. **OAS isolates credit risk** from option risk, allowing apples-to-apples comparison across bonds with different embedded options. Callable bonds exhibit **negative convexity**—when rates fall, price appreciation is limited by the call price.

## Step 7: Credit Curves and Default Probabilities

Build term structures of credit spreads.

```swift
// Build credit curve from market observations

let periods = [
    Period.year(1),
    Period.year(3),
    Period.year(5),
    Period.year(10)
]

// Observed credit spreads (typically upward sloping)
let marketSpreads = TimeSeries(
    periods: periods,
    values: [0.005, 0.012, 0.018, 0.025]  // 50, 120, 180, 250 bps
)

let creditCurve = CreditCurve(
    spreads: marketSpreads,
    recoveryRate: recoveryRate
)

print("\nCredit Curve Analysis")
print("=====================")

// Interpolate spreads for any maturity
for years in [2.0, 7.0] {
    let spread = creditCurve.spread(maturity: years)
    print("\(Int(years))-Year Spread: \(String(format: "%.0f", spread * 10000)) bps")
}

// Calculate cumulative default probabilities
print("\nCumulative Default Probabilities:")
for year in [1, 3, 5, 10] {
    let cdp = creditCurve.cumulativeDefaultProbability(maturity: Double(year))
    let survival = 1.0 - cdp

    print("\(year)-Year: \(String(format: "%.2f", cdp * 100))% default, \(String(format: "%.2f", survival * 100))% survival")
}

// Extract hazard rates (forward default intensities)
print("\nHazard Rates (Default Intensity):")
for year in [1, 5, 10] {
    let hazard = creditCurve.hazardRate(maturity: Double(year))
    print("\(year)-Year: \(String(format: "%.2f", hazard * 100))% per year")
}
```

**Key Insight:** The **credit curve** shows how default risk evolves over time. Upward-sloping curves indicate increasing uncertainty at longer horizons. **Hazard rates** represent instantaneous default intensities and can be used to price credit derivatives.

## Step 8: Portfolio Credit Risk

Calculate expected losses for bond portfolios.

```swift
// Scenario: Bond portfolio with different seniorities
// All bonds from same issuer (Z-Score = 2.0)

let portfolioZScore = 2.0
let portfolioPD = creditModel.defaultProbability(zScore: portfolioZScore)

let recoveryModel = RecoveryModel<Double>()

let positions = [
    (name: "Senior Secured", exposure: 5_000_000.0, seniority: Seniority.seniorSecured),
    (name: "Senior Unsecured", exposure: 3_000_000.0, seniority: Seniority.seniorUnsecured),
    (name: "Subordinated", exposure: 2_000_000.0, seniority: Seniority.subordinated)
]

print("\nPortfolio Credit Risk")
print("=====================")
print("Issuer Z-Score: \(String(format: "%.1f", portfolioZScore))")
print("Default Probability: \(String(format: "%.2f", portfolioPD * 100))%\n")

var totalExposure = 0.0
var totalExpectedLoss = 0.0

for position in positions {
    let recovery = RecoveryModel<Double>.standardRecoveryRate(
        seniority: position.seniority
    )

    let expectedLoss = recoveryModel.expectedLoss(
        defaultProbability: portfolioPD,
        recoveryRate: recovery,
        exposure: position.exposure
    )

    let lossRate = (expectedLoss / position.exposure) * 100

    print("\(position.name):")
    print("  Exposure: $\(String(format: "%.0f", position.exposure))")
    print("  Recovery: \(String(format: "%.0f", recovery * 100))%")
    print("  Expected Loss: $\(String(format: "%.0f", expectedLoss))")
    print("  Loss Rate: \(String(format: "%.2f", lossRate))%\n")

    totalExposure += position.exposure
    totalExpectedLoss += expectedLoss
}

print("Portfolio Totals:")
print("Total Exposure: $\(String(format: "%.0f", totalExposure))")
print("Total Expected Loss: $\(String(format: "%.0f", totalExpectedLoss))")
print("Reserve Ratio: \(String(format: "%.2f", (totalExpectedLoss / totalExposure) * 100))%")
```

**Key Insight:** **Expected loss** = PD × LGD × Exposure. Higher seniority bonds have **lower loss rates** due to better recovery. Portfolio diversification across seniorities reduces overall risk.

## Step 9: Volatility Impact on Callable Bonds

See how interest rate volatility affects option values.

```swift
// Test callable bond pricing across volatility scenarios

let volatilityScenarios = [
    (name: "Low Vol", vol: 0.05),
    (name: "Normal Vol", vol: 0.15),
    (name: "High Vol", vol: 0.25)
]

print("\nVolatility Impact on Callable Bonds")
print("====================================")

for scenario in volatilityScenarios {
    let price = callableBond.price(
        riskFreeRate: riskFreeRate,
        spread: creditSpread,
        volatility: scenario.vol,
        asOf: today
    )

    let optionValue = callableBond.callOptionValue(
        riskFreeRate: riskFreeRate,
        spread: creditSpread,
        volatility: scenario.vol,
        asOf: today
    )

    print("\n\(scenario.name) (\(String(format: "%.0f", scenario.vol * 100))%):")
    print("  Bond Price: $\(String(format: "%.2f", price))")
    print("  Option Value: $\(String(format: "%.2f", optionValue))")
}

print("\nKey Relationship:")
print("Higher volatility → More valuable call option → Lower bond price")
```

**Key Insight:** **Higher volatility increases option value**, making callable bonds less valuable to investors (they receive less compensation if called). This creates **negative convexity**—bondholders bear the downside of rate increases but don't fully benefit from rate decreases.

## Step 10: Model Cross-Validation

Verify consistency across different approaches.

```swift
// Round-trip validation: Spread → Implied Recovery → Spread

print("\nModel Cross-Validation")
print("======================")

// Start with known parameters
let testPD = 0.02
let testRecovery = 0.40
let testMaturity = 5.0

// Calculate spread
let testSpread = creditModel.creditSpread(
    defaultProbability: testPD,
    recoveryRate: testRecovery,
    maturity: testMaturity
)

// Reverse-engineer recovery rate
let impliedRecovery = recoveryModel.impliedRecoveryRate(
    spread: testSpread,
    defaultProbability: testPD,
    maturity: testMaturity
)

print("Original Recovery: \(String(format: "%.1f", testRecovery * 100))%")
print("Implied Recovery: \(String(format: "%.1f", impliedRecovery * 100))%")
print("Difference: \(String(format: "%.2f", abs(impliedRecovery - testRecovery) * 100))%")

// Price → YTM → Price validation
do {
    let testBond = Bond(
        faceValue: 1000.0,
        couponRate: 0.05,
        maturityDate: maturity,
        paymentFrequency: .semiAnnual,
        issueDate: today
    )

    let price1 = testBond.price(yield: corporateYield, asOf: today)
    let ytmCalculated = try testBond.yieldToMaturity(price: price1, asOf: today)
    let price2 = testBond.price(yield: ytmCalculated, asOf: today)

    print("\nPrice → YTM → Price:")
    print("Original Price: $\(String(format: "%.2f", price1))")
    print("Calculated YTM: \(String(format: "%.4f", ytmCalculated * 100))%")
    print("Final Price: $\(String(format: "%.2f", price2))")
    print("Price Difference: $\(String(format: "%.4f", abs(price2 - price1)))")

} catch {
    print("Validation failed: \(error)")
}
```

**Key Insight:** **Round-trip validation** ensures mathematical consistency across models. Small differences (< 1%) are acceptable due to numerical approximations, but large discrepancies indicate implementation errors.

## Putting It All Together: Complete Bond Analysis

Here's a complete workflow analyzing a corporate bond from fundamentals to pricing:

```swift
print("\n" + String(repeating: "=", count: 60))
print("COMPLETE BOND ANALYSIS EXAMPLE")
print(String(repeating: "=", count: 60))

// Company Profile
print("\nCompany: ABC Manufacturing Corp")
print("Credit Rating Equivalent: BBB- (grey zone)")
print("Altman Z-Score: 2.2")

// Bond Specifications
print("\nBond Specifications:")
print("  Face Value: $1,000")
print("  Coupon: 5.5%")
print("  Maturity: 7 years")
print("  Payment Frequency: Semiannual")
print("  Seniority: Senior Unsecured")
print("  Callable: Yes, after 3 years at $1,030")

// Step 1: Credit Analysis
let companyZScore = 2.2
let companyPD = creditModel.defaultProbability(zScore: companyZScore)
let companySeniority = Seniority.seniorUnsecured
let companyRecovery = RecoveryModel<Double>.standardRecoveryRate(
    seniority: companySeniority
)

print("\nCredit Analysis:")
print("  Default Probability: \(String(format: "%.2f", companyPD * 100))%")
print("  Expected Recovery: \(String(format: "%.0f", companyRecovery * 100))%")

// Step 2: Spread Calculation
let maturityYears = 7.0
let companySpread = creditModel.creditSpread(
    defaultProbability: companyPD,
    recoveryRate: companyRecovery,
    maturity: maturityYears
)

print("  Credit Spread: \(String(format: "%.0f", companySpread * 10000)) bps")

// Step 3: Bond Pricing
let analysisMaturity = calendar.date(byAdding: .year, value: 7, to: today)!

let analysisBond = Bond(
    faceValue: 1000.0,
    couponRate: 0.055,
    maturityDate: analysisMaturity,
    paymentFrequency: .semiAnnual,
    issueDate: today
)

let riskFree = 0.030  // 3.0% Treasury
let fairYield = riskFree + companySpread
let fairValue = analysisBond.price(yield: fairYield, asOf: today)

print("\nValuation:")
print("  Risk-Free Rate: \(String(format: "%.2f", riskFree * 100))%")
print("  Fair Yield: \(String(format: "%.2f", fairYield * 100))%")
print("  Fair Value: $\(String(format: "%.2f", fairValue))")

// Step 4: Callable Bond Adjustment
let analysisCallDate = calendar.date(byAdding: .year, value: 3, to: today)!
let analysisCallSchedule = [CallProvision(date: analysisCallDate, callPrice: 1030.0)]

let analysisCallable = CallableBond(
    bond: analysisBond,
    callSchedule: analysisCallSchedule
)

let callableValue = analysisCallable.price(
    riskFreeRate: riskFree,
    spread: companySpread,
    volatility: 0.15,
    asOf: today
)

let callCost = fairValue - callableValue

print("\nCallable Bond:")
print("  Straight Value: $\(String(format: "%.2f", fairValue))")
print("  Callable Value: $\(String(format: "%.2f", callableValue))")
print("  Call Option Cost: $\(String(format: "%.2f", callCost))")

// Step 5: Risk Metrics
let bondDuration = analysisBond.macaulayDuration(yield: fairYield, asOf: today)
let bondConvexity = analysisBond.convexity(yield: fairYield, asOf: today)
let callableDuration = analysisCallable.effectiveDuration(
    riskFreeRate: riskFree,
    spread: companySpread,
    volatility: 0.15,
    asOf: today
)

print("\nRisk Metrics:")
print("  Duration (straight): \(String(format: "%.2f", bondDuration)) years")
print("  Duration (callable): \(String(format: "%.2f", callableDuration)) years")
print("  Convexity: \(String(format: "%.2f", bondConvexity))")

// Step 6: Investment Decision
let marketPrice = 1015.00  // Hypothetical market price

print("\nInvestment Decision:")
print("  Market Price: $\(String(format: "%.2f", marketPrice))")
print("  Fair Value: $\(String(format: "%.2f", callableValue))")

if callableValue > marketPrice {
    let upside = ((callableValue / marketPrice) - 1.0) * 100
    print("  Assessment: UNDERVALUED by \(String(format: "%.1f", upside))%")
    print("  Recommendation: BUY")
} else {
    let downside = (1.0 - (callableValue / marketPrice)) * 100
    print("  Assessment: OVERVALUED by \(String(format: "%.1f", downside))%")
    print("  Recommendation: AVOID or SELL")
}

print("\n" + String(repeating: "=", count: 60))
```

## Summary

You've learned how to:

✅ **Price bonds** using discounted cash flow analysis
✅ **Calculate YTM** and measure interest rate risk with duration/convexity
✅ **Assess credit risk** by converting Z-Scores to default probabilities and credit spreads
✅ **Value callable bonds** and decompose spreads into credit and option components with OAS
✅ **Build credit curves** to analyze default risk over time
✅ **Calculate expected losses** for bond portfolios
✅ **Make informed investment decisions** based on comprehensive bond analysis

## Next Steps

- Explore **<doc:RiskAnalyticsGuide>** for portfolio-level risk management
- See **<doc:TimeValueOfMoney>** for foundational present value concepts
- Review **<doc:InvestmentAnalysis>** for asset allocation strategies
- Study **<doc:ScenarioAnalysisGuide>** for stress testing bond portfolios

## Additional Resources

### Recovery Rates by Seniority

| Seniority | Typical Recovery | Range |
|-----------|------------------|-------|
| Senior Secured | 70% | 60-80% |
| Senior Unsecured | 50% | 40-60% |
| Subordinated | 30% | 20-40% |
| Junior | 10% | 0-20% |

### Z-Score Interpretation

| Z-Score Range | Zone | Default Risk |
|---------------|------|--------------|
| > 2.99 | Safe | Low (< 1%) |
| 1.81 - 2.99 | Grey | Moderate (1-10%) |
| < 1.81 | Distress | High (> 10%) |

### Duration Rules of Thumb

- **Zero-coupon bonds**: Duration = Maturity
- **Premium bonds**: Duration < Maturity
- **Discount bonds**: Duration < Maturity (but > premium bonds)
- **Callable bonds**: Effective duration < straight duration
- **Putable bonds**: Effective duration < straight duration

### Convexity Insights

- **Positive convexity**: Price increases more when yields fall than it decreases when yields rise (typical for option-free bonds)
- **Negative convexity**: Price increases less when yields fall due to embedded call options (callable bonds)
- **Higher convexity** = Better price performance in volatile markets

---

*This tutorial demonstrates BusinessMath's comprehensive bond valuation and credit analysis capabilities. All calculations use industry-standard methodologies and are suitable for production use.*
