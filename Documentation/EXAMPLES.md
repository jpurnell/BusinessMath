# BusinessMath Code Examples

Comprehensive code examples demonstrating BusinessMath capabilities across different use cases.

## Table of Contents

- [Time Series Analysis](#time-series-analysis)
- [Financial Calculations](#financial-calculations)
- [Revenue Forecasting](#revenue-forecasting)
- [Loan Amortization](#loan-amortization)
- [Irregular Cash Flows](#irregular-cash-flows)
- [Seasonal Patterns](#seasonal-patterns)
- [Securities Valuation](#securities-valuation)
- [Risk Analysis](#risk-analysis)
- [Portfolio Optimization](#portfolio-optimization)

---

## Time Series Analysis

### Basic Time Series Operations

```swift
import BusinessMath

// Create monthly revenue time series
let periods = [
    Period.month(year: 2024, month: 1),
    Period.month(year: 2024, month: 2),
    Period.month(year: 2024, month: 3),
    Period.month(year: 2024, month: 4)
]
let revenue: [Double] = [100_000, 120_000, 115_000, 130_000]

let ts = TimeSeries(periods: periods, values: revenue)

// Calculate growth rates
let growth = ts.growthRate(lag: 1)
print(growth.valuesArray)  // [0.20, -0.042, 0.130]

// Calculate moving average
let smoothed = ts.movingAverage(window: 2)
print(smoothed.valuesArray)  // [110_000, 117_500, 122_500]

// Calculate CAGR (Compound Annual Growth Rate)
if let cagr = ts.cagr() {
    print("Annual growth rate: \(cagr * 100)%")
}
```

### Working with Different Periods

```swift
// Quarterly data
let quarters = [
    Period.quarter(year: 2024, quarter: 1),
    Period.quarter(year: 2024, quarter: 2),
    Period.quarter(year: 2024, quarter: 3),
    Period.quarter(year: 2024, quarter: 4)
]
let quarterlyRevenue: [Double] = [250_000, 280_000, 265_000, 320_000]
let qts = TimeSeries(periods: quarters, values: quarterlyRevenue)

// Daily data
let today = Date()
let dailyPeriods = (0..<7).map { Period.day(date: Calendar.current.date(byAdding: .day, value: $0, to: today)!) }
let dailySales: [Double] = [5_000, 6_200, 5_800, 6_500, 7_100, 5_900, 6_300]
let dts = TimeSeries(periods: dailyPeriods, values: dailySales)
```

### Aggregation

```swift
// Monthly to quarterly aggregation
let monthlyData = TimeSeries(periods: monthlyPeriods, values: monthlyRevenue)
let quarterlyData = try monthlyData.aggregate(to: .quarterly, using: .sum)

// Daily to weekly
let weeklyData = try dailyData.aggregate(to: .weekly, using: .average)
```

---

## Financial Calculations

### Time Value of Money Basics

```swift
import BusinessMath

// Future Value: What will $1,000 grow to in 5 years at 8%?
let fv = futureValue(
    presentValue: 1_000,
    rate: 0.08,
    periods: 5
)
print(fv)  // $1,469.33

// Present Value: What is $1,000 in 5 years worth today at 8%?
let pv = presentValue(
    futureValue: 1_000,
    rate: 0.08,
    periods: 5
)
print(pv)  // $680.58

// Annuity: What's the future value of saving $1,000/year for 10 years at 6%?
let annuityFV = futureValue(
    presentValue: 0,
    rate: 0.06,
    periods: 10,
    payment: -1_000,
    type: .ordinary
)
print(annuityFV)  // $13,180.79
```

### Mortgage Payment Calculation

```swift
// Calculate monthly mortgage payment
let principal = 300_000.0
let annualRate = 0.06
let monthlyRate = annualRate / 12
let periods = 360  // 30 years * 12 months

let monthlyPayment = payment(
    presentValue: principal,
    rate: monthlyRate,
    periods: periods,
    futureValue: 0,
    type: .ordinary
)

print("Monthly payment: $\(String(format: "%.2f", -monthlyPayment))")
// Result: $1,798.65
```

### Investment Analysis

```swift
// Evaluate an investment project
let cashFlows = [-100_000.0, 30_000, 40_000, 50_000, 60_000]

// Net Present Value
let npvValue = npv(discountRate: 0.10, cashFlows: cashFlows)
print("NPV: $\(String(format: "%.2f", npvValue))")
// Result: $37,907.87

// Internal Rate of Return
let irrValue = try irr(cashFlows: cashFlows)
print("IRR: \(String(format: "%.2f", irrValue * 100))%")
// Result: 28.65%

// Profitability Index
let pi = profitabilityIndex(discountRate: 0.10, cashFlows: cashFlows)
print("Profitability Index: \(String(format: "%.2f", pi))")
// Result: 1.38 (> 1.0 means good investment)

// Payback Period
let payback = paybackPeriod(cashFlows: cashFlows)
print("Payback: \(payback) years")
// Result: 2.67 years

// Discounted Payback Period
let discountedPayback = discountedPaybackPeriod(discountRate: 0.10, cashFlows: cashFlows)
print("Discounted Payback: \(String(format: "%.2f", discountedPayback)) years")
// Result: 3.24 years
```

### Modified IRR (MIRR)

```swift
// When reinvestment rates differ from financing rates
let cashFlows = [-100_000.0, 30_000, 40_000, 50_000, 60_000]

let mirrValue = try mirr(
    cashFlows: cashFlows,
    financingRate: 0.08,      // Cost of capital
    reinvestmentRate: 0.06    // Reinvestment assumption
)

print("MIRR: \(String(format: "%.2f", mirrValue * 100))%")
// Result: 19.29% (more conservative than IRR)
```

---

## Revenue Forecasting

### Complete Forecasting Workflow

```swift
import BusinessMath

// Step 1: Historical quarterly revenue data
let historicalPeriods = [
    Period.quarter(year: 2022, quarter: 1),
    Period.quarter(year: 2022, quarter: 2),
    Period.quarter(year: 2022, quarter: 3),
    Period.quarter(year: 2022, quarter: 4),
    Period.quarter(year: 2023, quarter: 1),
    Period.quarter(year: 2023, quarter: 2),
    Period.quarter(year: 2023, quarter: 3),
    Period.quarter(year: 2023, quarter: 4)
]

let historicalRevenue: [Double] = [
    100_000, 120_000, 110_000, 150_000,  // 2022
    105_000, 125_000, 115_000, 160_000   // 2023
]

let historical = TimeSeries(periods: historicalPeriods, values: historicalRevenue)

// Step 2: Extract seasonal pattern (4 quarters per year)
let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)
print("Seasonal indices: \(seasonalIndices)")
// Result: [~0.84, ~1.01, ~0.93, ~1.22]
// Q1: 16% below average, Q4: 22% above (holiday spike)

// Step 3: Deseasonalize the data
let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

// Step 4: Fit trend model to deseasonalized data
var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)

print("Trend: slope = \(trend.slope), intercept = \(trend.intercept)")

// Step 5: Project trend forward
let futurePeriods = [
    Period.quarter(year: 2024, quarter: 1),
    Period.quarter(year: 2024, quarter: 2),
    Period.quarter(year: 2024, quarter: 3),
    Period.quarter(year: 2024, quarter: 4)
]

let trendForecast = try trend.project(periods: futurePeriods)

// Step 6: Reapply seasonality to forecast
let forecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)

print("2024 Forecast:")
for (period, value) in zip(forecast.periodsArray, forecast.valuesArray) {
    print("\(period): $\(String(format: "%.0f", value))")
}
```

### Exponential Trend

```swift
// For rapidly growing businesses
var expTrend = ExponentialTrend<Double>()
try expTrend.fit(to: historical)

let expForecast = try expTrend.project(periods: 4)
print("Exponential growth rate: \(String(format: "%.2f", expTrend.growthRate * 100))%")
```

### Logistic Trend

```swift
// For markets approaching saturation
var logisticTrend = LogisticTrend<Double>()
try logisticTrend.fit(to: historical, capacity: 200_000)  // Market cap estimate

let logisticForecast = try logisticTrend.project(periods: 4)
```

---

## Loan Amortization

### Complete Amortization Schedule

```swift
import BusinessMath

let principal = 300_000.0
let annualRate = 0.06
let monthlyRate = annualRate / 12
let periods = 360  // 30 years

let monthlyPayment = payment(
    presentValue: principal,
    rate: monthlyRate,
    periods: periods,
    futureValue: 0,
    type: .ordinary
)

print("Monthly Payment: $\(String(format: "%.2f", -monthlyPayment))")

// Amortization schedule for first year
print("\nFirst Year Amortization:")
print("Month | Payment    | Principal  | Interest   | Balance")
print("------|------------|------------|------------|------------")

var balance = principal

for month in 1...12 {
    let interestPmt = interestPayment(
        rate: monthlyRate,
        period: month,
        totalPeriods: periods,
        presentValue: principal,
        futureValue: 0,
        type: .ordinary
    )

    let principalPmt = principalPayment(
        rate: monthlyRate,
        period: month,
        totalPeriods: periods,
        presentValue: principal,
        futureValue: 0,
        type: .ordinary
    )

    balance += principalPmt  // principalPmt is negative

    print(String(format: "%5d | $%9.2f | $%9.2f | $%9.2f | $%10.2f",
        month, -monthlyPayment, -principalPmt, -interestPmt, balance))
}
```

### Cumulative Interest and Principal

```swift
// Total interest paid in first 5 years
let totalInterest = cumulativeInterest(
    rate: monthlyRate,
    startPeriod: 1,
    endPeriod: 60,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

print("Interest paid in years 1-5: $\(String(format: "%.2f", -totalInterest))")
// Result: ~$87,000

// Total principal paid in first 5 years
let totalPrincipal = cumulativePrincipal(
    rate: monthlyRate,
    startPeriod: 1,
    endPeriod: 60,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

print("Principal paid in years 1-5: $\(String(format: "%.2f", -totalPrincipal))")
// Result: ~$21,000
```

### Refinancing Analysis

```swift
// Current loan: 25 years remaining at 6%
let currentBalance = 280_000.0
let currentRate = 0.06 / 12
let currentPeriods = 300

let currentPayment = payment(
    presentValue: currentBalance,
    rate: currentRate,
    periods: currentPeriods,
    futureValue: 0,
    type: .ordinary
)

// Refinance option: 30 years at 4.5%
let newRate = 0.045 / 12
let newPeriods = 360

let newPayment = payment(
    presentValue: currentBalance,
    rate: newRate,
    periods: newPeriods,
    futureValue: 0,
    type: .ordinary
)

print("Current payment: $\(String(format: "%.2f", -currentPayment))")
print("New payment: $\(String(format: "%.2f", -newPayment))")
print("Monthly savings: $\(String(format: "%.2f", -(newPayment - currentPayment)))")
```

---

## Irregular Cash Flows

### XNPV and XIRR

```swift
import BusinessMath

// Investment with irregular timing
let dates = [
    Date(),  // Today: Initial investment
    Date(timeIntervalSinceNow: 100 * 86400),   // 100 days
    Date(timeIntervalSinceNow: 250 * 86400),   // 250 days
    Date(timeIntervalSinceNow: 400 * 86400),   // 400 days
    Date(timeIntervalSinceNow: 600 * 86400)    // 600 days
]

let cashFlows = [-100_000.0, 30_000, 50_000, 40_000, 35_000]

// XNPV: NPV with specific dates
let xnpvValue = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
print("XNPV: $\(String(format: "%.2f", xnpvValue))")

// XIRR: IRR with specific dates
let xirrValue = try xirr(dates: dates, cashFlows: cashFlows)
print("XIRR: \(String(format: "%.2f", xirrValue * 100))%")
```

### Real Estate Investment Example

```swift
// Property acquisition
let purchaseDate = Date()
let purchasePrice = -500_000.0

// Rental income (monthly)
var rentalDates: [Date] = [purchaseDate]
var rentalCashFlows: [Double] = [purchasePrice]

let calendar = Calendar.current
for month in 1...60 {  // 5 years of rental income
    let rentalDate = calendar.date(byAdding: .month, value: month, to: purchaseDate)!
    rentalDates.append(rentalDate)
    rentalCashFlows.append(2_500)  // $2,500/month rent
}

// Property sale after 5 years
let saleDate = calendar.date(byAdding: .year, value: 5, to: purchaseDate)!
rentalDates.append(saleDate)
rentalCashFlows[rentalCashFlows.count - 1] += 600_000  // Add sale proceeds to last month

let realEstateIRR = try xirr(dates: rentalDates, cashFlows: rentalCashFlows)
print("Real estate investment IRR: \(String(format: "%.2f", realEstateIRR * 100))%")
```

---

## Seasonal Patterns

### Retail Sales with Seasonality

```swift
import BusinessMath

// Monthly sales data for a retail business (2 years)
let months = (0..<24).map { monthIndex in
    let year = 2022 + monthIndex / 12
    let month = (monthIndex % 12) + 1
    return Period.month(year: year, month: month)
}

// Sales with clear Q4 holiday spike
let monthlySales: [Double] = [
    // 2022
    80, 75, 85, 90, 95, 100, 105, 110, 100, 95, 120, 140,
    // 2023
    85, 80, 90, 95, 100, 105, 110, 115, 105, 100, 125, 150
]

let salesTS = TimeSeries(periods: months, values: monthlySales)

// Calculate seasonal indices (12 months per year)
let monthlyIndices = try seasonalIndices(timeSeries: salesTS, periodsPerYear: 12)

print("Monthly Seasonal Indices:")
let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
for (month, index) in zip(monthNames, monthlyIndices) {
    let percentage = (index - 1.0) * 100
    let direction = percentage >= 0 ? "above" : "below"
    print("\(month): \(String(format: "%+.1f", abs(percentage)))% \(direction) average")
}

// Forecast next year with seasonality
let deseasonalized = try seasonallyAdjust(timeSeries: salesTS, indices: monthlyIndices)
var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)

let nextYearPeriods = (0..<12).map { Period.month(year: 2024, month: $0 + 1) }
let trendForecast = try trend.project(periods: nextYearPeriods)
let forecast = try applySeasonal(timeSeries: trendForecast, indices: monthlyIndices)

print("\n2024 Sales Forecast:")
for (period, value) in zip(forecast.periodsArray, forecast.valuesArray) {
    print("\(period): $\(String(format: "%.0f", value))")
}
```

### Quarterly Revenue Pattern

```swift
// Quarterly revenue with Q4 spike
let quarters = (0..<12).map { Period.quarter(year: 2021 + $0/4, quarter: ($0 % 4) + 1) }
let revenue: [Double] = [
    100, 120, 110, 150,  // 2021
    105, 125, 115, 160,  // 2022
    110, 130, 120, 170   // 2023
]

let revenueTS = TimeSeries(periods: quarters, values: revenue)

let quarterlyIndices = try seasonalIndices(timeSeries: revenueTS, periodsPerYear: 4)
print("Quarterly indices: \(quarterlyIndices)")
// Result: [~0.84, ~1.01, ~0.93, ~1.22]
// Q1: 16% below average
// Q2: 1% above average
// Q3: 7% below average
// Q4: 22% above average (holiday spike)
```

---

## Securities Valuation

### Equity Valuation

```swift
import BusinessMath

// 1. Gordon Growth Model (Constant DDM)
let stockValue = try gordonGrowthModel(
    currentDividend: 2.50,
    growthRate: 0.05,       // 5% perpetual growth
    requiredReturn: 0.12    // 12% required return
)
print("Stock value (Gordon): $\(String(format: "%.2f", stockValue))")
// Result: $37.50 per share

// 2. Two-Stage DDM (High growth then stable)
let twoStageValue = try twoStageDDM(
    currentDividend: 2.00,
    highGrowthRate: 0.15,   // 15% for first 5 years
    stableGrowthRate: 0.05, // 5% thereafter
    requiredReturn: 0.12,
    highGrowthYears: 5
)
print("Stock value (Two-Stage): $\(String(format: "%.2f", twoStageValue))")

// 3. Free Cash Flow to Equity (FCFE)
let fcfeValue = try fcfeModel(
    currentFCFE: 50_000_000,  // $50M current FCFE
    growthRate: 0.06,         // 6% growth
    requiredReturn: 0.11,     // 11% cost of equity
    sharesOutstanding: 10_000_000
)
print("Value per share (FCFE): $\(String(format: "%.2f", fcfeValue))")
```

### Bond Valuation

```swift
// 1. Price a coupon bond
let bondPrice = try priceCouponBond(
    faceValue: 1000,
    couponRate: 0.05,      // 5% annual coupon
    yield: 0.06,           // 6% market yield
    years: 5,
    frequency: .semiannual
)
print("Bond price: $\(String(format: "%.2f", bondPrice))")
// Result: $957.35 (trades at discount since yield > coupon)

// 2. Calculate yield to maturity
let ytm = try bondYieldToMaturity(
    price: 950,
    faceValue: 1000,
    couponRate: 0.05,
    years: 5,
    frequency: .semiannual
)
print("Yield to maturity: \(String(format: "%.2f", ytm * 100))%")

// 3. Duration and convexity
let duration = try bondDuration(
    faceValue: 1000,
    couponRate: 0.05,
    yield: 0.06,
    years: 5,
    frequency: .semiannual
)
print("Macaulay duration: \(String(format: "%.2f", duration)) years")

let modDuration = try bondModifiedDuration(
    faceValue: 1000,
    couponRate: 0.05,
    yield: 0.06,
    years: 5,
    frequency: .semiannual
)
print("Modified duration: \(String(format: "%.2f", modDuration))")

// 4. Price sensitivity: How much does price change for 1% yield increase?
let priceChange = -modDuration * 0.01 * bondPrice
print("Price change for 1% yield increase: $\(String(format: "%.2f", priceChange))")
```

### Credit Derivatives

```swift
// 1. CDS Fair Spread
let cdsSpread = try cdsFairSpread(
    notional: 10_000_000,      // $10M notional
    defaultProbability: 0.02,   // 2% annual default probability
    recoveryRate: 0.40,         // 40% recovery
    tenor: 5                    // 5-year contract
)
print("CDS spread: \(String(format: "%.0f", cdsSpread * 10000)) basis points")
// Result: ~120 bps

// 2. Merton Structural Model
let defaultProbability = try mertonDefaultProbability(
    assetValue: 100_000_000,    // $100M firm value
    debtValue: 80_000_000,      // $80M debt
    assetVolatility: 0.25,      // 25% volatility
    timeToMaturity: 1.0,        // 1 year
    riskFreeRate: 0.05
)
print("Default probability: \(String(format: "%.2f", defaultProbability * 100))%")

// 3. Credit Spread
let creditSpread = try creditSpread(
    corporateYield: 0.08,       // 8% corporate bond yield
    riskFreeRate: 0.05,         // 5% risk-free rate
    expectedLoss: 0.012         // 1.2% expected loss
)
print("Credit spread: \(String(format: "%.0f", creditSpread * 10000)) bps")
```

---

## Risk Analysis

### Value at Risk (VaR)

```swift
import BusinessMath

// Portfolio returns (daily)
let returns: [Double] = [0.01, -0.02, 0.015, -0.005, 0.02, -0.01, 0.008, -0.015]
let portfolioValue = 1_000_000.0

// Calculate VaR at 95% confidence
let var95 = valueAtRisk(returns: returns, confidence: 0.95, portfolioValue: portfolioValue)
print("VaR (95%): $\(String(format: "%.0f", var95))")
// Interpretation: 95% confident we won't lose more than this amount

// Calculate CVaR (Conditional VaR / Expected Shortfall)
let cvar95 = conditionalVaR(returns: returns, confidence: 0.95, portfolioValue: portfolioValue)
print("CVaR (95%): $\(String(format: "%.0f", cvar95))")
// Interpretation: If we exceed VaR, average loss is this amount
```

### Stress Testing

```swift
// Base case financial metrics
let baseRevenue = 10_000_000.0
let baseCosts = 7_000_000.0
let baseProfit = baseRevenue - baseCosts

// Define stress scenarios
struct Scenario {
    let name: String
    let revenueShock: Double
    let costShock: Double
}

let scenarios = [
    Scenario(name: "Mild Recession", revenueShock: -0.10, costShock: 0.05),
    Scenario(name: "Severe Recession", revenueShock: -0.25, costShock: 0.10),
    Scenario(name: "Supply Shock", revenueShock: -0.05, costShock: 0.20),
    Scenario(name: "Best Case", revenueShock: 0.15, costShock: -0.05)
]

print("Stress Test Results:")
print("Scenario           | Revenue    | Costs      | Profit     | Change")
print("-------------------|------------|------------|------------|---------")

for scenario in scenarios {
    let stressedRevenue = baseRevenue * (1 + scenario.revenueShock)
    let stressedCosts = baseCosts * (1 + scenario.costShock)
    let stressedProfit = stressedRevenue - stressedCosts
    let profitChange = (stressedProfit - baseProfit) / baseProfit

    print(String(format: "%-18s | $%9.0fK | $%9.0fK | $%9.0fK | %+6.1f%%",
        scenario.name,
        stressedRevenue / 1000,
        stressedCosts / 1000,
        stressedProfit / 1000,
        profitChange * 100))
}
```

---

## Portfolio Optimization

### Modern Portfolio Theory

```swift
import BusinessMath

// Three assets with different risk/return profiles
let expectedReturns = [0.08, 0.12, 0.10]  // 8%, 12%, 10%
let volatilities = [0.15, 0.25, 0.18]     // 15%, 25%, 18%

// Correlation matrix
let correlations = [
    [1.0, 0.3, 0.5],
    [0.3, 1.0, 0.4],
    [0.5, 0.4, 1.0]
]

// Find efficient frontier
let efficientFrontier = try calculateEfficientFrontier(
    returns: expectedReturns,
    volatilities: volatilities,
    correlations: correlations,
    points: 50
)

// Find maximum Sharpe ratio portfolio (assuming 3% risk-free rate)
let optimalPortfolio = try maximizeSharpeRatio(
    returns: expectedReturns,
    volatilities: volatilities,
    correlations: correlations,
    riskFreeRate: 0.03
)

print("Optimal Portfolio (Max Sharpe Ratio):")
print("Allocations: \(optimalPortfolio.weights.map { String(format: "%.1f%%", $0 * 100) })")
print("Expected return: \(String(format: "%.2f%%", optimalPortfolio.expectedReturn * 100))")
print("Expected volatility: \(String(format: "%.2f%%", optimalPortfolio.volatility * 100))")
print("Sharpe ratio: \(String(format: "%.2f", optimalPortfolio.sharpeRatio))")
```

### Risk Parity

```swift
// Risk parity: Equal risk contribution from each asset
let riskParityWeights = try riskParity(
    volatilities: [0.15, 0.25, 0.18],
    correlations: correlations
)

print("Risk Parity Allocations:")
for (i, weight) in riskParityWeights.enumerated() {
    print("Asset \(i+1): \(String(format: "%.1f%%", weight * 100))")
}
```

---

## Additional Resources

- **[Main README](README.md)** - Library overview and quick start
- **[Documentation](Sources/BusinessMath/BusinessMath.docc/)** - Comprehensive guides (44 chapters)
- **[Learning Path](Sources/BusinessMath/BusinessMath.docc/LearningPath.md)** - Guided learning tracks
- **[PERFORMANCE](Examples/PERFORMANCE.md)** - Performance benchmarks
- **[MCP Server](MCP_README.md)** - AI assistant integration

---

**Need more examples?** Check the `/Examples` directory in the repository for:
- Complete financial models
- Revenue forecasting workflows
- Monte Carlo simulations
- Optimization case studies
- Model validation examples
