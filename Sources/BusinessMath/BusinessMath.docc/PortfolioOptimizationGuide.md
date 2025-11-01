# Portfolio Optimization

Build optimal investment portfolios using Modern Portfolio Theory and risk parity strategies.

## Overview

Portfolio optimization helps you build investment portfolios that maximize returns for a given level of risk, or minimize risk for a target return. BusinessMath implements Modern Portfolio Theory (Markowitz optimization) and Risk Parity allocation strategies.

This guide covers:
- Building portfolios from historical returns
- Calculating the efficient frontier
- Optimizing for maximum Sharpe ratio
- Risk parity allocation
- Practical portfolio construction

## Modern Portfolio Theory

Modern Portfolio Theory, developed by Harry Markowitz, shows how to combine assets to achieve optimal risk-return tradeoffs.

### Creating a Portfolio

```swift
import BusinessMath

// Historical returns for 3 assets (monthly data for 1 year)
let periods = (1...12).map { Period.month(year: 2024, month: $0) }

let stockAReturns = [0.08, 0.05, -0.02, 0.10, 0.03, 0.07, 0.04, 0.06, -0.01, 0.09, 0.05, 0.08]
let stockBReturns = [0.06, 0.04, 0.02, 0.08, 0.05, 0.06, 0.03, 0.05, 0.04, 0.07, 0.06, 0.07]
let bondReturns = [0.02, 0.03, 0.02, 0.03, 0.02, 0.03, 0.02, 0.03, 0.02, 0.03, 0.02, 0.03]

let stockA = TimeSeries(periods: periods, values: stockAReturns)
let stockB = TimeSeries(periods: periods, values: stockBReturns)
let bonds = TimeSeries(periods: periods, values: bondReturns)

let portfolio = Portfolio(
    assets: ["Stock A", "Stock B", "Bonds"],
    returns: [stockA, stockB, bonds],
    riskFreeRate: 0.02 / 12  // 2% annual = 0.167% monthly
)
```

### Optimizing for Maximum Sharpe Ratio

The Sharpe ratio measures return per unit of risk. Higher is better.

```swift
// Find optimal weights that maximize risk-adjusted returns
let optimalAllocation = portfolio.optimizePortfolio()

print("Optimal Portfolio:")
print("  Expected Return: \(optimalAllocation.expectedReturn * 12 * 100)% annually")
print("  Risk (Volatility): \(optimalAllocation.risk * sqrt(12) * 100)% annually")
print("  Sharpe Ratio: \(optimalAllocation.sharpeRatio)")

print("\nOptimal Weights:")
for (asset, weight) in zip(portfolio.assets, optimalAllocation.weights) {
    print("  \(asset): \(weight * 100)%")
}
```

### Calculating Portfolio Metrics

```swift
// For any allocation, calculate risk and return
let customWeights = [0.40, 0.30, 0.30]  // 40% Stock A, 30% Stock B, 30% Bonds

let customReturn = portfolio.portfolioReturn(weights: customWeights)
let customRisk = portfolio.portfolioRisk(weights: customWeights)
let customSharpe = portfolio.sharpeRatio(weights: customWeights)

print("\nCustom Allocation (40/30/30):")
print("  Expected Return: \(customReturn * 12 * 100)% annually")
print("  Risk: \(customRisk * sqrt(12) * 100)% annually")
print("  Sharpe Ratio: \(customSharpe)")
```

## Efficient Frontier

The efficient frontier shows all optimal portfolios - those with maximum return for each risk level.

### Generating the Frontier

```swift
let efficientFrontier = portfolio.efficientFrontier(points: 20)

print("Efficient Frontier:")
print("Risk (σ) | Return (μ) | Sharpe")
print("---------|------------|-------")

for allocation in efficientFrontier {
    let annualReturn = allocation.expectedReturn * 12 * 100
    let annualRisk = allocation.risk * sqrt(12) * 100

    print(String(format: "%6.2f%% | %8.2f%% | %6.3f",
                 annualRisk, annualReturn, allocation.sharpeRatio))
}
```

### Finding Specific Points

```swift
// Minimum risk portfolio
let minRiskAllocation = efficientFrontier.min(by: { $0.risk < $1.risk })!
print("\nMinimum Risk Portfolio:")
print("  Risk: \(minRiskAllocation.risk * sqrt(12) * 100)%")
print("  Return: \(minRiskAllocation.expectedReturn * 12 * 100)%")

// Maximum Sharpe ratio (optimal)
let maxSharpeAllocation = efficientFrontier.max(by: { $0.sharpeRatio < $1.sharpeRatio })!
print("\nMaximum Sharpe Portfolio:")
print("  Sharpe Ratio: \(maxSharpeAllocation.sharpeRatio)")
print("  Risk: \(maxSharpeAllocation.risk * sqrt(12) * 100)%")
print("  Return: \(maxSharpeAllocation.expectedReturn * 12 * 100)%")
```

## Risk Parity Allocation

Risk parity allocates capital so each asset contributes equally to portfolio risk, rather than focusing on returns.

### Equal Risk Contribution

```swift
let riskParityOptimizer = RiskParityOptimizer<Double>()

let riskParityAllocation = riskParityOptimizer.optimize(
    assets: portfolio.assets,
    returns: [stockA, stockB, bonds]
)

print("\nRisk Parity Allocation:")
for (asset, weight) in zip(riskParityAllocation.assets, riskParityAllocation.weights) {
    print("  \(asset): \(weight * 100)%")
}

// Verify equal risk contributions
let riskContributions = riskParityOptimizer.calculateRiskContributions(
    allocation: riskParityAllocation
)

print("\nRisk Contributions:")
for (asset, contribution) in zip(riskParityAllocation.assets, riskContributions) {
    print("  \(asset): \(contribution * 100)% of total risk")
}
```

### When to Use Risk Parity

Risk parity is appropriate when:
- You believe risk, not return, is the key driver of portfolio performance
- You want diversification across all positions
- You're skeptical of return forecasts but confident in risk estimates

Traditional Markowitz is better when:
- You have strong return forecasts
- You want to maximize risk-adjusted returns
- Some assets clearly dominate others

## Practical Portfolio Construction

### Rebalancing

```swift
// Check how far current allocation drifts from target
func needsRebalancing(
    current: [Double],
    target: [Double],
    threshold: Double = 0.05  // 5% threshold
) -> Bool {
    for (curr, targ) in zip(current, target) {
        if abs(curr - targ) > threshold {
            return true
        }
    }
    return false
}

let currentWeights = [0.45, 0.28, 0.27]  // After market moves
let targetWeights = [0.40, 0.30, 0.30]

if needsRebalancing(current: currentWeights, target: targetWeights) {
    print("Rebalancing needed:")
    for i in 0..<currentWeights.count {
        let diff = (currentWeights[i] - targetWeights[i]) * 100
        print("  \(portfolio.assets[i]): \(diff > 0 ? "+" : "")\(diff)%")
    }
}
```

### Constraints

```swift
// Real-world portfolios have constraints
struct PortfolioConstraints {
    let minWeight: Double  // Minimum per asset
    let maxWeight: Double  // Maximum per asset
    let minBonds: Double   // Minimum in "safe" assets
}

let constraints = PortfolioConstraints(
    minWeight: 0.05,   // At least 5% in each
    maxWeight: 0.50,   // At most 50% in each
    minBonds: 0.20     // At least 20% in bonds
)

// Custom optimization with constraints
func optimizeWithConstraints(
    portfolio: Portfolio<Double>,
    constraints: PortfolioConstraints
) -> PortfolioAllocation<Double> {
    // Start with feasible allocation
    var weights = [0.40, 0.40, 0.20]

    // Iteratively improve while respecting constraints
    // (Simplified - real implementation uses Lagrange multipliers)

    return PortfolioAllocation(
        assets: portfolio.assets,
        weights: weights,
        expectedReturn: portfolio.portfolioReturn(weights: weights),
        risk: portfolio.portfolioRisk(weights: weights),
        sharpeRatio: portfolio.sharpeRatio(weights: weights)
    )
}
```

## Understanding Correlations

Correlation drives diversification benefits.

### Calculating Correlations

```swift
let correlationMatrix = portfolio.correlationMatrix()

print("Correlation Matrix:")
print("        Stock A  Stock B  Bonds")
for (i, asset) in portfolio.assets.enumerated() {
    print(asset, terminator: "")
    for j in 0..<portfolio.assets.count {
        print(String(format: " %7.3f", correlationMatrix[i][j]), terminator: "")
    }
    print()
}
```

### Diversification Benefits

```swift
// Compare diversified portfolio to individual assets
let equalWeights = [1.0/3.0, 1.0/3.0, 1.0/3.0]
let portfolioRisk = portfolio.portfolioRisk(weights: equalWeights)

let avgIndividualRisk = mean(portfolio.expectedReturns.map { stdDev($0.valuesArray) })

let diversificationBenefit = (avgIndividualRisk - portfolioRisk) / avgIndividualRisk

print("Diversification reduces risk by \(diversificationBenefit * 100)%")
```

## Next Steps

- Explore <doc:RealOptionsGuide> for valuing strategic flexibility in investments
- Learn <doc:RiskAnalyticsGuide> for comprehensive portfolio risk analysis
- See <doc:ScenarioAnalysisGuide> for stress testing portfolios

## See Also

- ``Portfolio``
- ``PortfolioAllocation``
- ``RiskParityOptimizer``
- ``expectedReturns``
- ``covarianceMatrix()``
- ``correlationMatrix()``
