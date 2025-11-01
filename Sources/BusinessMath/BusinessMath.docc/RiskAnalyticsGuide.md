# Risk Analytics and Stress Testing

Measure and manage risk with comprehensive analytics and scenario testing.

## Overview

Risk analytics help you understand and quantify uncertainty in financial decisions. BusinessMath provides industry-standard risk measures including Value at Risk (VaR), stress testing, and comprehensive risk metrics.

This guide covers:
- Stress testing with pre-defined and custom scenarios
- Value at Risk (VaR) calculation and aggregation
- Comprehensive risk metrics (Sharpe, Sortino, drawdown)
- Portfolio risk decomposition
- Practical risk management applications

## Stress Testing

Stress tests evaluate how portfolios or projects perform under adverse scenarios.

### Pre-Defined Scenarios

BusinessMath includes common stress scenarios based on historical crises.

```swift
import BusinessMath

// Define stress scenarios
let scenarios = [
    StressScenario<Double>.recession,      // Moderate economic downturn
    StressScenario<Double>.crisis,         // Severe financial crisis
    StressScenario<Double>.supplyShock     // Supply chain disruption
]

// Examine scenario parameters
for scenario in scenarios {
    print("\(scenario.name):")
    print("  Description: \(scenario.description)")
    print("  Shocks:")
    for (driver, shock) in scenario.shocks {
        let pct = shock * 100
        print("    \(driver): \(pct > 0 ? "+" : "")\(pct)%")
    }
}
```

Output:
```
Recession:
  Description: Economic recession scenario
  Shocks:
    Revenue: -15%
    COGS: +5%
    InterestRate: +2%

Financial Crisis:
  Description: Severe financial crisis (2008-style)
  Shocks:
    Revenue: -30%
    COGS: +10%
    InterestRate: +5%
    CustomerChurn: +20%

Supply Chain Shock:
  Description: Major supply chain disruption
  Shocks:
    COGS: +25%
    DeliveryTime: +50%
    InventoryLevel: -30%
```

### Custom Stress Scenarios

Create scenarios specific to your business.

```swift
// Pandemic scenario
let pandemic = StressScenario(
    name: "Global Pandemic",
    description: "Extended lockdowns and remote work transition",
    shocks: [
        "Revenue": -0.35,           // -35% revenue
        "RemoteWorkCosts": 0.20,    // +20% IT/remote costs
        "TravelExpenses": -0.80,    // -80% travel
        "RealEstateCosts": -0.15    // -15% office costs
    ]
)

// Regulatory change scenario
let regulation = StressScenario(
    name: "New Regulation",
    description: "Stricter compliance requirements",
    shocks: [
        "ComplianceCosts": 0.50,    // +50% compliance
        "Revenue": -0.05,            // -5% from restrictions
        "OperatingMargin": -0.03     // -3% margin compression
    ]
)

let allScenarios = scenarios + [pandemic, regulation]
```

### Running Stress Tests

```swift
let stressTest = StressTest(scenarios: allScenarios)

// Apply to your financial model
// (Simplified example - integrate with your actual model)
struct FinancialMetrics {
    let revenue: Double
    let costs: Double
    let npv: Double
}

let baseline = FinancialMetrics(
    revenue: 10_000_000,
    costs: 7_000_000,
    npv: 5_000_000
)

for scenario in stressTest.scenarios {
    // Apply shocks
    var stressed = baseline

    if let revenueShock = scenario.shocks["Revenue"] {
        stressed.revenue *= (1 + revenueShock)
    }

    if let cogsShock = scenario.shocks["COGS"] {
        stressed.costs *= (1 + cogsShock)
    }

    let stressedNPV = stressed.revenue - stressed.costs  // Simplified
    let impact = stressedNPV - baseline.npv
    let impactPct = (impact / baseline.npv) * 100

    print("\n\(scenario.name):")
    print("  Baseline NPV: $\(baseline.npv)")
    print("  Stressed NPV: $\(stressedNPV)")
    print("  Impact: $\(impact) (\(impactPct)%)")
}
```

## Value at Risk (VaR)

VaR measures the maximum loss expected over a time horizon at a given confidence level.

### Calculating VaR from Returns

```swift
// Portfolio returns (daily for 1 year)
let returns: [Double] = /* 250 daily returns */

let periods = (0..<returns.count).map { Period.day(Date().addingTimeInterval(Double($0) * 86400)) }
let timeSeries = TimeSeries(periods: periods, values: returns)

let riskMetrics = ComprehensiveRiskMetrics(
    returns: timeSeries,
    riskFreeRate: 0.02 / 250  // 2% annual = 0.008% daily
)

print("Value at Risk:")
print("  95% VaR: \(riskMetrics.var95 * 100)%")
print("  99% VaR: \(riskMetrics.var99 * 100)%")

// Interpret: "95% confidence we won't lose more than X% in a day"
let portfolioValue = 1_000_000.0
let var95Loss = abs(riskMetrics.var95) * portfolioValue

print("\nFor $\(portfolioValue) portfolio:")
print("  95% 1-day VaR: $\(var95Loss)")
print("  Meaning: 95% confident daily loss won't exceed $\(var95Loss)")
```

### Conditional VaR (CVaR / Expected Shortfall)

CVaR measures the average loss in the worst cases (beyond VaR).

```swift
print("\nConditional VaR (Expected Shortfall):")
print("  CVaR (95%): \(riskMetrics.cvar95 * 100)%")
print("  Tail Risk Ratio: \(riskMetrics.tailRisk)")

// CVaR is the expected loss if we're in the worst 5%
let cvarLoss = abs(riskMetrics.cvar95) * portfolioValue
print("  If in worst 5% of days, expect to lose: $\(cvarLoss)")
```

## Aggregating Risk Across Portfolios

Combine VaR across multiple portfolios accounting for correlations.

### Portfolio VaR Aggregation

```swift
// Three portfolios with individual VaRs
let portfolioVaRs = [100_000.0, 150_000.0, 200_000.0]

// Correlation matrix
let correlations = [
    [1.0, 0.6, 0.4],
    [0.6, 1.0, 0.5],
    [0.4, 0.5, 1.0]
]

// Aggregate VaR using variance-covariance method
let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
    individualVaRs: portfolioVaRs,
    correlations: correlations
)

let simpleSum = portfolioVaRs.reduce(0, +)
let diversificationBenefit = simpleSum - aggregatedVaR

print("VaR Aggregation:")
print("  Portfolio A VaR: $\(portfolioVaRs[0])")
print("  Portfolio B VaR: $\(portfolioVaRs[1])")
print("  Portfolio C VaR: $\(portfolioVaRs[2])")
print("  Simple sum: $\(simpleSum)")
print("  Aggregated VaR: $\(aggregatedVaR)")
print("  Diversification benefit: $\(diversificationBenefit)")
```

### Marginal VaR

Understand how much each portfolio contributes to total risk.

```swift
// Calculate marginal VaR for each portfolio
for i in 0..<portfolioVaRs.count {
    let marginal = RiskAggregator<Double>.marginalVaR(
        entity: i,
        individualVaRs: portfolioVaRs,
        correlations: correlations
    )

    print("\nPortfolio \(["A", "B", "C"][i]):")
    print("  Individual VaR: $\(portfolioVaRs[i])")
    print("  Marginal VaR: $\(marginal)")
    print("  Risk contribution: \(marginal / aggregatedVaR * 100)%")
}
```

### Component VaR

Allocate total VaR to each portfolio based on weights.

```swift
let weights = [0.3, 0.4, 0.3]  // Portfolio weights

let componentVaRs = RiskAggregator<Double>.componentVaR(
    individualVaRs: portfolioVaRs,
    weights: weights,
    correlations: correlations
)

print("\nComponent VaR (weighted contributions):")
for i in 0..<portfolioVaRs.count {
    print("  Portfolio \(["A", "B", "C"][i]): $\(componentVaRs[i])")
}

let totalComponent = componentVaRs.reduce(0, +)
print("  Sum of components: $\(totalComponent)")
print("  Equals aggregated VaR: \(abs(totalComponent - aggregatedVaR) < 1.0)")
```

## Comprehensive Risk Metrics

A complete risk profile includes multiple measures.

### Full Risk Assessment

```swift
print("\nComprehensive Risk Profile:")
print(riskMetrics.description)
```

Output:
```
Comprehensive Risk Metrics:
  VaR (95%): -2.45%
  VaR (99%): -3.89%
  CVaR (95%): -3.12%
  Max Drawdown: 15.3%
  Sharpe Ratio: 1.23
  Sortino Ratio: 1.67
  Tail Risk: 1.27
  Skewness: -0.34
  Kurtosis: 2.1
```

### Maximum Drawdown

Maximum drawdown measures the largest peak-to-trough decline.

```swift
let drawdown = riskMetrics.maxDrawdown

print("\nDrawdown Analysis:")
print("  Maximum drawdown: \(drawdown * 100)%")

if drawdown < 0.10 {
    print("  Risk level: Low")
} else if drawdown < 0.20 {
    print("  Risk level: Moderate")
} else {
    print("  Risk level: High")
}
```

### Sharpe and Sortino Ratios

Risk-adjusted return measures.

```swift
print("\nRisk-Adjusted Returns:")
print("  Sharpe Ratio: \(riskMetrics.sharpeRatio)")
print("    (return per unit of total volatility)")

print("  Sortino Ratio: \(riskMetrics.sortinoRatio)")
print("    (return per unit of downside volatility)")

// Sortino > Sharpe indicates asymmetric returns (positive skew)
if riskMetrics.sortinoRatio > riskMetrics.sharpeRatio {
    print("  Portfolio has limited downside with upside potential")
}
```

### Tail Statistics

Skewness and kurtosis describe return distribution shape.

```swift
print("\nTail Statistics:")
print("  Skewness: \(riskMetrics.skewness)")

if riskMetrics.skewness < -0.5 {
    print("    Negative skew: More frequent small gains, rare large losses")
    print("    Risk: Fat left tail")
} else if riskMetrics.skewness > 0.5 {
    print("    Positive skew: More frequent small losses, rare large gains")
    print("    Risk: Fat right tail")
} else {
    print("    Roughly symmetric distribution")
}

print("  Excess Kurtosis: \(riskMetrics.kurtosis)")

if riskMetrics.kurtosis > 1.0 {
    print("    Fat tails: More extreme events than normal distribution")
    print("    Risk: Higher probability of large moves")
}
```

## Practical Risk Management

### Setting Risk Limits

```swift
struct RiskLimits {
    let maxVaR95: Double         // Maximum 95% VaR
    let maxDrawdown: Double      // Maximum allowed drawdown
    let minSharpeRatio: Double   // Minimum acceptable Sharpe
}

let limits = RiskLimits(
    maxVaR95: 0.03,      // 3% daily VaR
    maxDrawdown: 0.20,   // 20% drawdown
    minSharpeRatio: 0.5  // 0.5 Sharpe
)

func checkRiskLimits(metrics: ComprehensiveRiskMetrics<Double>, limits: RiskLimits) -> [String] {
    var breaches: [String] = []

    if abs(metrics.var95) > limits.maxVaR95 {
        breaches.append("VaR limit breached: \(abs(metrics.var95) * 100)% > \(limits.maxVaR95 * 100)%")
    }

    if metrics.maxDrawdown > limits.maxDrawdown {
        breaches.append("Drawdown limit breached: \(metrics.maxDrawdown * 100)% > \(limits.maxDrawdown * 100)%")
    }

    if metrics.sharpeRatio < limits.minSharpeRatio {
        breaches.append("Sharpe below minimum: \(metrics.sharpeRatio) < \(limits.minSharpeRatio)")
    }

    return breaches
}

let breaches = checkRiskLimits(metrics: riskMetrics, limits: limits)
if breaches.isEmpty {
    print("✓ All risk limits satisfied")
} else {
    print("⚠️ Risk limit breaches:")
    for breach in breaches {
        print("  - \(breach)")
    }
}
```

### Monitoring Risk Over Time

```swift
// Track risk metrics daily/weekly
struct RiskSnapshot {
    let date: Date
    let var95: Double
    let sharpeRatio: Double
    let drawdown: Double
}

var riskHistory: [RiskSnapshot] = []

// Add current snapshot
riskHistory.append(RiskSnapshot(
    date: Date(),
    var95: riskMetrics.var95,
    sharpeRatio: riskMetrics.sharpeRatio,
    drawdown: riskMetrics.maxDrawdown
))

// Alert if risk increasing
if riskHistory.count >= 2 {
    let current = riskHistory.last!
    let previous = riskHistory[riskHistory.count - 2]

    let varIncrease = (abs(current.var95) - abs(previous.var95)) / abs(previous.var95)

    if varIncrease > 0.20 {  // VaR increased >20%
        print("⚠️ ALERT: VaR increased \(varIncrease * 100)% since last measurement")
    }
}
```

## Next Steps

- Explore <doc:PortfolioOptimizationGuide> for risk-aware portfolio construction
- Learn <doc:RealOptionsGuide> for valuing downside protection options
- See <doc:ScenarioAnalysisGuide> for modeling risk scenarios

## See Also

- ``StressTest``
- ``StressScenario``
- ``RiskAggregator``
- ``ComprehensiveRiskMetrics``
- ``aggregateVaR(individualVaRs:correlations:)``
- ``marginalVaR(entity:individualVaRs:correlations:)``
