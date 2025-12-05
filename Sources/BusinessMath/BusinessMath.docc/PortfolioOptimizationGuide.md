# Portfolio Optimization

Build optimal investment portfolios using Modern Portfolio Theory, risk parity strategies, and efficient frontier analysis.

## Overview

Portfolio optimization helps you build investment portfolios that maximize returns for a given level of risk, or minimize risk for a target return. BusinessMath implements Modern Portfolio Theory (Markowitz optimization), risk parity strategies, and efficient frontier generation as part of **Phase 3: Multivariate Optimization**.

This guide covers:
- Modern Portfolio Theory (mean-variance optimization)
- Efficient frontier generation
- Maximum Sharpe ratio portfolios
- Minimum variance portfolios
- Target return portfolios
- Risk parity allocation
- Constrained portfolios (long-only, leverage limits)

## Quick Start

```swift
import BusinessMath

// Define 4 assets with expected returns and covariance
let optimizer = PortfolioOptimizer()

let expectedReturns = VectorN([0.12, 0.15, 0.18, 0.05])
let covariance = [
    [0.04, 0.01, 0.02, 0.00],
    [0.01, 0.09, 0.03, 0.01],
    [0.02, 0.03, 0.16, 0.02],
    [0.00, 0.01, 0.02, 0.01]
]

// Maximum Sharpe ratio (best risk-adjusted return)
let portfolio = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    constraintSet: .longOnly
)

print("Sharpe Ratio: \(portfolio.sharpeRatio)")
print("Expected Return: \(portfolio.expectedReturn * 100)%")
print("Volatility: \(portfolio.volatility * 100)%")
print("Weights: \(portfolio.weights)")
```

## Modern Portfolio Theory

Modern Portfolio Theory, developed by Harry Markowitz, shows how to combine assets to achieve optimal risk-return tradeoffs.

### Minimum Variance Portfolio

Find the portfolio with the lowest risk:

```swift
// Minimum variance (lowest risk possible)
let minVar = try optimizer.minimumVariancePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    allowShortSelling: false  // long-only
)

print("Minimum Variance Portfolio:")
print("  Expected Return: \(minVar.expectedReturn * 100)%")
print("  Volatility (Std Dev): \(minVar.volatility * 100)%")
print("  Weights: \(minVar.weights)")
```

### Maximum Sharpe Ratio

Find the portfolio with the best risk-adjusted return:

```swift
// Maximum Sharpe ratio (optimal portfolio)
let maxSharpe = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    constraintSet: .longOnly
)

print("Maximum Sharpe Portfolio:")
print("  Sharpe Ratio: \(maxSharpe.sharpeRatio)")
print("  Expected Return: \(maxSharpe.expectedReturn * 100)%")
print("  Volatility: \(maxSharpe.volatility * 100)%")
```

### Target Return Portfolio

Find the minimum risk portfolio that achieves a specific return. This requires Phase 4's constrained optimization (see Custom Constraints section below), or you can use the efficient frontier to find portfolios at specific return levels:

```swift
// Generate efficient frontier and find portfolio closest to target return
let frontier = try optimizer.efficientFrontier(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    numberOfPoints: 50
)

// Find portfolio closest to 12% target return
let targetReturn = 0.12
let targetPortfolio = frontier.portfolios.min(by: { portfolio in
    abs(portfolio.expectedReturn - targetReturn) < abs($1.expectedReturn - targetReturn)
})!

print("Target Return Portfolio (≈12%):")
print("  Expected Return: \(targetPortfolio.expectedReturn * 100)%")
print("  Volatility: \(targetPortfolio.volatility * 100)%")
print("  Weights: \(targetPortfolio.weights)")
```

## Efficient Frontier

The efficient frontier shows all optimal portfolios - those with maximum return for each risk level.

### Generating the Frontier

```swift
let frontier = try optimizer.efficientFrontier(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    numberOfPoints: 20
)

print("Efficient Frontier:")
print("Volatility | Return   | Sharpe")
print("-----------|----------|-------")

for portfolio in frontier.portfolios {
    let vol = portfolio.volatility * 100
    let ret = portfolio.expectedReturn * 100
    let sharpe = portfolio.sharpeRatio

    print(String(format: "%8.2f%% | %6.2f%% | %6.2f", vol, ret, sharpe))
}
```

### Finding Specific Points

```swift
// Minimum volatility portfolio on frontier
let minVol = frontier.minimumVariancePortfolio
print("\nMinimum Volatility:")
print("  Volatility: \(minVol.volatility * 100)%")
print("  Return: \(minVol.expectedReturn * 100)%")

// Maximum Sharpe ratio portfolio on frontier
let maxSharpe = frontier.maximumSharpePortfolio
print("\nMaximum Sharpe:")
print("  Sharpe Ratio: \(maxSharpe.sharpeRatio)")
print("  Volatility: \(maxSharpe.volatility * 100)%")
print("  Return: \(maxSharpe.expectedReturn * 100)%")
```

## Risk Parity

Risk parity allocates capital so each asset contributes equally to portfolio risk.

### Equal Risk Contribution

```swift
// Each asset contributes equally to total risk
let riskParity = try optimizer.riskParityPortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    constraintSet: .longOnly
)

print("Risk Parity Portfolio:")
print("Weights:")
for (i, weight) in riskParity.weights.toArray().enumerated() {
    print("  Asset \(i): \(weight * 100)%")
}

print("\nExpected Return: \(riskParity.expectedReturn * 100)%")
print("Volatility: \(riskParity.volatility * 100)%")
print("Sharpe Ratio: \(riskParity.sharpeRatio)")
```

### When to Use Risk Parity

**Use risk parity when:**
- You believe risk, not return, drives portfolio performance
- You want equal diversification across all positions
- You're skeptical of return forecasts but confident in risk estimates

**Use mean-variance optimization when:**
- You have strong return forecasts
- You want to maximize risk-adjusted returns
- Some assets clearly dominate others

## Constrained Portfolios

Real-world portfolios often have constraints on allocations.

### Long-Only (No Short-Selling)

```swift
// No short-selling: all weights ≥ 0
let longOnly = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    constraintSet: .longOnly
)

print("Long-Only Portfolio:")
print("  Sharpe: \(longOnly.sharpeRatio)")
print("  Weights: \(longOnly.weights)")
```

### Long-Short with Leverage Limit

```swift
// 130/30 strategy: 130% long, 30% short
let longShort = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    constraintSet: .longShort(maxLeverage: 1.3)
)

print("130/30 Portfolio:")
print("  Sharpe: \(longShort.sharpeRatio)")
print("  Weights: \(longShort.weights)")
```

### Box Constraints

```swift
// Minimum 5%, maximum 40% per position
let boxConstrained = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    constraintSet: .boxConstrained(min: 0.05, max: 0.40)
)

print("Box Constrained Portfolio:")
print("  Weights: \(boxConstrained.weights)")
```

### Custom Constraints

For complex constraints, use Phase 4's constrained optimization:

```swift
import BusinessMath

let constrainedOptimizer = InequalityOptimizer<VectorN<Double>>()

// Portfolio variance function
func portfolioVariance(_ weights: VectorN<Double>) -> Double {
    var variance = 0.0
    for i in 0..<weights.dimension {
        for j in 0..<weights.dimension {
            variance += weights[i] * weights[j] * covarianceMatrix[i][j]
        }
    }
    return variance
}

let result = try constrainedOptimizer.minimize(
    portfolioVariance,
    from: VectorN([0.25, 0.25, 0.25, 0.25]),
    subjectTo: [
        // Fully invested
        .equality { w in w.sum() - 1.0 },
        // Target return ≥ 12%
        .inequality { w in
            let ret = w.dot(VectorN(expectedReturns))
            return 0.12 - ret  // ≤ 0 means ret ≥ 12%
        },
        // Long-only
        .inequality { w in -w[0] },
        .inequality { w in -w[1] },
        .inequality { w in -w[2] },
        .inequality { w in -w[3] }
    ]
)

print("Custom Constrained Portfolio: \(result.solution.toArray())")
```

## Real-World Example

### Complete Portfolio Construction

```swift
import BusinessMath

// $1M portfolio with 5 asset classes
let assets = [
    "US Large Cap",
    "US Small Cap",
    "International",
    "Bonds",
    "Real Estate"
]

let expectedReturns = VectorN([0.10, 0.12, 0.11, 0.04, 0.09])

let covariance = [
    [0.0225, 0.0180, 0.0150, 0.0020, 0.0100],
    [0.0180, 0.0400, 0.0200, 0.0010, 0.0150],
    [0.0150, 0.0200, 0.0400, 0.0030, 0.0120],
    [0.0020, 0.0010, 0.0030, 0.0016, 0.0010],
    [0.0100, 0.0150, 0.0120, 0.0010, 0.0256]
]

let optimizer = PortfolioOptimizer()

// Conservative investor (minimum variance)
let conservative = try optimizer.minimumVariancePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    allowShortSelling: false
)

print("Conservative Portfolio ($1M):")
for (i, asset) in assets.enumerated() {
    let weight = conservative.weights.toArray()[i]
    if weight > 0.01 {
        let allocation = 1_000_000 * weight
        print("  \(asset): $\(String(format: "%.0f", allocation)) (\(String(format: "%.1f%%", weight * 100)))")
    }
}
print("  Expected Return: \(String(format: "%.2f%%", conservative.expectedReturn * 100))")
print("  Volatility: \(String(format: "%.2f%%", conservative.volatility * 100))")

// Moderate investor (max Sharpe)
let moderate = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.03,
    constraintSet: .longOnly
)

print("\nModerate Portfolio ($1M):")
for (i, asset) in assets.enumerated() {
    let weight = moderate.weights.toArray()[i]
    if weight > 0.01 {
        let allocation = 1_000_000 * weight
        print("  \(asset): $\(String(format: "%.0f", allocation)) (\(String(format: "%.1f%%", weight * 100)))")
    }
}
print("  Sharpe Ratio: \(String(format: "%.2f", moderate.sharpeRatio))")
print("  Expected Return: \(String(format: "%.2f%%", moderate.expectedReturn * 100))")
print("  Volatility: \(String(format: "%.2f%%", moderate.volatility * 100))")
```

## Understanding Portfolio Metrics

### Expected Return

Weighted average of asset returns:
```
E[R_p] = Σ w_i × E[R_i]
```

### Portfolio Risk (Volatility)

Standard deviation of portfolio returns:
```
σ_p = √(w^T Σ w)
```

Where Σ is the covariance matrix.

### Sharpe Ratio

Risk-adjusted return:
```
Sharpe = (E[R_p] - R_f) / σ_p
```

Higher is better. Typical values:
- < 1.0: Poor risk-adjusted return
- 1.0-2.0: Good
- 2.0-3.0: Very good
- \> 3.0: Exceptional

## Rebalancing

```swift
// Check if rebalancing is needed
func needsRebalancing(
    current: [Double],
    target: [Double],
    threshold: Double = 0.05
) -> Bool {
    for (curr, targ) in zip(current, target) {
        if abs(curr - targ) > threshold {
            return true
        }
    }
    return false
}

let currentWeights = [0.28, 0.32, 0.25, 0.15]  // After market moves
let targetWeights = [0.25, 0.30, 0.25, 0.20]   // Original allocation

if needsRebalancing(current: currentWeights, target: targetWeights) {
    print("Rebalancing needed:")
    for i in 0..<currentWeights.count {
        let diff = currentWeights[i] - targetWeights[i]
        let diffPercent = diff * 100
        let action = diff > 0 ? "Sell" : "Buy"
        print("  \(assets[i]): \(action) \(String(format: "%.1f%%", abs(diffPercent)))")
    }
}
```

## Complete Documentation

### Phase 3: Portfolio Optimization

The portfolio optimization features are part of Phase 3: Multivariate Optimization.

**Comprehensive documentation:**
- **Tutorial**: `Instruction Set/PHASE_3_TUTORIAL.md`
  - Modern Portfolio Theory overview
  - Efficient frontier theory
  - Risk parity allocation
  - Algorithm selection guide

- **Examples**: `Examples/PortfolioOptimizationExample.swift`
  - Basic portfolio optimization (min variance, max Sharpe, target return)
  - Efficient frontier generation (20 portfolios)
  - Risk parity portfolio (equal risk contribution)
  - Constrained portfolios (long-only, 130/30, box constraints)
  - Real-world portfolio ($1M across 5 asset classes)

**Related optimization topics:**
- **Phase 1**: Goal-seeking for IRR and breakeven analysis
- **Phase 4**: Advanced constraints for complex portfolio rules
- **Phase 5**: Resource allocation for project selection

## Practical Tips

### Data Requirements

Minimum data for reliable optimization:
- At least 36-60 months of return data
- Daily, weekly, or monthly returns (monthly most common)
- Handle outliers and data quality issues
- Consider regime changes

### Estimation Error

Optimization is sensitive to inputs:
```swift
// Black-Litterman views can improve estimation
// Robust optimization handles uncertainty
// Resampled efficient frontier reduces sensitivity
```

### Transaction Costs

Account for trading costs:
```swift
// Implement minimum trade sizes
// Add turnover constraints
// Consider tax implications
```

### Monitoring

Regular portfolio review:
```swift
// Monthly: Check if rebalancing needed (>5% drift)
// Quarterly: Review assumptions and forecasts
// Annually: Full optimization with updated data
```

## Next Steps

- Explore <doc:OptimizationGuide> for the complete optimization framework
- Learn <doc:RiskAnalyticsGuide> for comprehensive risk analysis
- See <doc:ScenarioAnalysisGuide> for stress testing portfolios

## See Also

### Portfolio Optimization
- ``PortfolioOptimizer``
- ``PortfolioAllocation``
- ``EfficientFrontier``
- ``PortfolioConstraints``

### Related Optimization
- ``MultivariateGradientDescent``
- ``MultivariateNewtonRaphson``
- ``ConstrainedOptimizer``
- ``InequalityOptimizer``

### Vector Operations (Phase 2)
- ``VectorN``
- ``VectorSpace``
