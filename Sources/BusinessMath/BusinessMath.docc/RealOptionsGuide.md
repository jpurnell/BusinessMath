# Real Options Valuation

Value strategic flexibility and managerial decisions using option pricing theory.

## Overview

Real options apply financial option pricing methods to strategic business decisions. Unlike traditional NPV, real options capture the value of flexibility: the ability to expand, abandon, delay, or switch strategies as uncertainty resolves.

This guide covers:
- Black-Scholes option pricing for European options
- Binomial tree models for American options
- Real options applications (expansion, abandonment)
- Decision tree analysis for complex scenarios
- Option Greeks for sensitivity analysis

## Black-Scholes Model

The Black-Scholes model prices European options (exercisable only at expiration) using a closed-form solution.

### Basic Option Pricing

```swift
import BusinessMath

// Price a call option
let callPrice = BlackScholesModel<Double>.price(
    optionType: .call,
    spotPrice: 100.0,       // Current stock price
    strikePrice: 105.0,     // Exercise price
    timeToExpiry: 0.5,      // 6 months
    riskFreeRate: 0.05,     // 5% annual rate
    volatility: 0.30        // 30% annual volatility
)

print("Call option value: $\(callPrice)")

// Price a put option
let putPrice = BlackScholesModel<Double>.price(
    optionType: .put,
    spotPrice: 100.0,
    strikePrice: 105.0,
    timeToExpiry: 0.5,
    riskFreeRate: 0.05,
    volatility: 0.30
)

print("Put option value: $\(putPrice)")
```

### Put-Call Parity

Verify the fundamental relationship between call and put prices:

```swift
// Put-Call Parity: C - P = S - K*e^(-rT)
let S = 100.0
let K = 105.0
let T = 0.5
let r = 0.05

let leftSide = callPrice - putPrice
let rightSide = S - K * exp(-r * T)

print("Put-Call Parity check:")
print("  C - P = \(leftSide)")
print("  S - Ke^(-rT) = \(rightSide)")
print("  Difference: \(abs(leftSide - rightSide))")  // Should be near zero
```

## Option Greeks

Greeks measure how option prices change with market conditions.

### Calculating All Greeks

```swift
let greeks = BlackScholesModel<Double>.greeks(
    optionType: .call,
    spotPrice: 100.0,
    strikePrice: 105.0,
    timeToExpiry: 0.5,
    riskFreeRate: 0.05,
    volatility: 0.30
)

print("Option Greeks:")
print("  Delta: \(greeks.delta)")      // Price sensitivity to stock price
print("  Gamma: \(greeks.gamma)")      // Delta sensitivity to stock price
print("  Vega: \(greeks.vega)")        // Price sensitivity to volatility
print("  Theta: \(greeks.theta)")      // Price decay with time
print("  Rho: \(greeks.rho)")          // Sensitivity to interest rates
```

### Interpreting Greeks

```swift
// Delta: if stock goes up $1, option goes up $delta
let stockIncrease = 1.0
let optionIncrease = greeks.delta * stockIncrease
print("If stock rises $\(stockIncrease), call rises $\(optionIncrease)")

// Theta: daily time decay
let dailyDecay = greeks.theta / 365
print("Option loses $\(abs(dailyDecay)) per day from time decay")

// Vega: if volatility increases 1%, option price changes by vega/100
let volIncrease = 0.01  // 1% volatility increase
let priceIncrease = greeks.vega * volIncrease
print("If volatility rises 1%, option rises $\(priceIncrease)")
```

## Binomial Tree Model

Binomial trees handle American options (early exercise allowed) and are more flexible than Black-Scholes.

### American Put Option

```swift
// American put: can exercise early if stock drops
let americanPut = BinomialTreeModel<Double>.price(
    optionType: .put,
    americanStyle: true,
    spotPrice: 100.0,
    strikePrice: 110.0,  // In-the-money put
    timeToExpiry: 1.0,
    riskFreeRate: 0.05,
    volatility: 0.25,
    steps: 100  // More steps = more accurate
)

print("American put value: $\(americanPut)")

// Compare to European (no early exercise)
let europeanPut = BinomialTreeModel<Double>.price(
    optionType: .put,
    americanStyle: false,
    spotPrice: 100.0,
    strikePrice: 110.0,
    timeToExpiry: 1.0,
    riskFreeRate: 0.05,
    volatility: 0.25,
    steps: 100
)

print("European put value: $\(europeanPut)")
print("Early exercise premium: $\(americanPut - europeanPut)")
```

### Convergence to Black-Scholes

```swift
// Binomial tree converges to Black-Scholes with more steps
let bsPrice = BlackScholesModel<Double>.price(
    optionType: .call,
    spotPrice: 100.0,
    strikePrice: 100.0,
    timeToExpiry: 1.0,
    riskFreeRate: 0.05,
    volatility: 0.20
)

for steps in [10, 50, 100, 200] {
    let binomialPrice = BinomialTreeModel<Double>.price(
        optionType: .call,
        americanStyle: false,
        spotPrice: 100.0,
        strikePrice: 100.0,
        timeToExpiry: 1.0,
        riskFreeRate: 0.05,
        volatility: 0.20,
        steps: steps
    )

    let error = abs(binomialPrice - bsPrice) / bsPrice * 100
    print("\(steps) steps: $\(binomialPrice) (error: \(String(format: "%.2f", error))%)")
}
```

## Real Options Applications

Real options apply option pricing to strategic business decisions.

### Option to Expand

Model the value of growth opportunities as a call option.

```swift
// Software company: option to expand into new market
let baseNPV = 10_000_000.0         // Current business NPV
let expansionCost = 5_000_000.0    // Cost to enter new market
let expansionNPV = 8_000_000.0     // NPV of new market opportunity
let volatility = 0.35              // Market uncertainty (high)
let timeToDecision = 2.0           // Must decide in 2 years
let riskFreeRate = 0.05

let projectValue = RealOptionsAnalysis<Double>.expansionOption(
    baseNPV: baseNPV,
    expansionCost: expansionCost,
    expansionNPV: expansionNPV,
    volatility: volatility,
    timeToDecision: timeToDecision,
    riskFreeRate: riskFreeRate
)

let optionValue = projectValue - baseNPV

print("Expansion Option Analysis:")
print("  Base business NPV: $\(baseNPV)")
print("  Expansion option value: $\(optionValue)")
print("  Total project value: $\(projectValue)")

// Traditional NPV misses this option value
let traditionalNPV = baseNPV + max(0, expansionNPV - expansionCost)
let valueMissed = projectValue - traditionalNPV
print("  Value missed by traditional NPV: $\(valueMissed)")
```

### Option to Abandon

Model the safety net of being able to exit a project as a put option.

```swift
// Manufacturing project with abandonment option
let projectNPV = 5_000_000.0       // NPV if continued
let salvageValue = 3_000_000.0     // Equipment resale value
let projectVolatility = 0.40        // Project uncertainty
let timeToAbandonDecision = 1.0    // Decide after 1 year

let valueWithAbandonOption = RealOptionsAnalysis<Double>.abandonmentOption(
    projectNPV: projectNPV,
    salvageValue: salvageValue,
    volatility: projectVolatility,
    timeToDecision: timeToAbandonDecision,
    riskFreeRate: riskFreeRate
)

let abandonmentOptionValue = valueWithAbandonOption - projectNPV

print("\nAbandonment Option Analysis:")
print("  Project NPV (no option): $\(projectNPV)")
print("  Abandonment option value: $\(abandonmentOptionValue)")
print("  Total value with option: $\(valueWithAbandonOption)")
```

## Decision Tree Analysis

For complex decisions with multiple stages and outcomes, use decision trees.

### Simple Decision Tree

```swift
// Launch new product: succeed or fail?
let successOutcome = DecisionNode<Double>(type: .terminal, value: 5_000_000)
let failureOutcome = DecisionNode<Double>(type: .terminal, value: -1_000_000)

let marketOutcome = DecisionNode<Double>(
    type: .chance,
    branches: [
        Branch(probability: 0.6, node: successOutcome),  // 60% chance success
        Branch(probability: 0.4, node: failureOutcome)   // 40% chance failure
    ]
)

let launchValue = RealOptionsAnalysis<Double>.decisionTree(root: marketOutcome)
print("\nExpected value of launch: $\(launchValue)")
// = 0.6 × $5M + 0.4 × (-$1M) = $2.6M
```

### Multi-Stage Decision

```swift
// Stage 1: Invest in R&D ($2M)
// Stage 2: If R&D succeeds (70%), decide to launch or not
// Stage 3: If launch, market determines success

let marketSuccess = DecisionNode<Double>(type: .terminal, value: 10_000_000)
let marketFailure = DecisionNode<Double>(type: .terminal, value: -500_000)

let launchOutcome = DecisionNode<Double>(
    type: .chance,
    branches: [
        Branch(probability: 0.5, node: marketSuccess),
        Branch(probability: 0.5, node: marketFailure)
    ]
)

let doNotLaunch = DecisionNode<Double>(type: .terminal, value: 0)

// After R&D success, choose best option
let launchDecision = DecisionNode<Double>(
    type: .decision,
    branches: [
        Branch(probability: 1.0, node: launchOutcome),
        Branch(probability: 1.0, node: doNotLaunch)
    ]
)

let rdFailure = DecisionNode<Double>(type: .terminal, value: 0)

// R&D outcome
let rdOutcome = DecisionNode<Double>(
    type: .chance,
    branches: [
        Branch(probability: 0.7, node: launchDecision),  // 70% R&D success
        Branch(probability: 0.3, node: rdFailure)        // 30% R&D failure
    ]
)

let projectValue = RealOptionsAnalysis<Double>.decisionTree(root: rdOutcome)
let rdCost = 2_000_000.0
let netValue = projectValue - rdCost

print("\nMulti-Stage Project:")
print("  Expected value (before R&D cost): $\(projectValue)")
print("  R&D cost: $\(rdCost)")
print("  Net project value: $\(netValue)")

if netValue > 0 {
    print("  Decision: Proceed with R&D")
} else {
    print("  Decision: Do not invest")
}
```

## Practical Applications

### When to Use Real Options

Real options are valuable when:
1. **High Uncertainty**: Future is unpredictable (new markets, R&D)
2. **Managerial Flexibility**: Can adjust strategy as information arrives
3. **Staged Investments**: Can invest in phases, learning along the way
4. **Strategic Value**: Option to grow, switch, or exit has value

### Key Inputs

Critical parameters for real options:
```swift
// Volatility: most important and hardest to estimate
// Use:
// - Historical stock volatility (public companies)
// - Comparable company volatility
// - Analyst estimates
// - Scenario analysis

// Time to expiration: when must you decide?
// - Patent expiration
// - Lease terms
// - Technology obsolescence
// - Competitive window

// Interest rate: use risk-free rate
// - Treasury rate matching time horizon
// - Adjust for country risk if needed
```

## Next Steps

- Learn <doc:RiskAnalyticsGuide> for comprehensive risk measurement with VaR and stress testing
- Explore <doc:PortfolioOptimizationGuide> for portfolio-level option strategies
- See <doc:ScenarioAnalysisGuide> for modeling different option exercise scenarios

## See Also

- ``BlackScholesModel``
- ``BinomialTreeModel``
- ``RealOptionsAnalysis``
- ``Greeks``
- ``DecisionNode``
- ``Branch``
