# Part IV: Simulation & Uncertainty

Model risk and uncertainty with Monte Carlo methods and scenario analysis.

## Overview

Part IV addresses a fundamental reality of finance: the future is uncertain. While Parts I-III taught you to build models and forecasts, Part IV teaches you to quantify the uncertainty around those forecasts and make better decisions in the face of that uncertainty.

This section focuses on two powerful approaches: Monte Carlo simulation, which uses random sampling to model probability distributions of outcomes, and scenario analysis, which structures thinking around discrete future states. Together, these techniques transform point estimates into probability distributions and help you understand the full range of possible outcomes.

Uncertainty isn't something to fear or ignore—it's information. By quantifying uncertainty, you can make more informed decisions, communicate risk effectively, and avoid the false precision that comes from treating forecasts as certainties.

## What You'll Learn

- **Monte Carlo Simulation**: Generate probability distributions of outcomes through random sampling
- **Probabilistic Forecasting**: Create confidence intervals and forecast distributions
- **Scenario Analysis**: Structure thinking around discrete future states (base, upside, downside)
- **Risk Quantification**: Measure the probability and magnitude of adverse outcomes
- **Uncertainty Communication**: Present uncertain forecasts clearly to stakeholders

## Chapters in This Part

### Probabilistic Methods
- <doc:4.1-MonteCarloTimeSeriesGuide> - Monte Carlo simulation for time series forecasting and risk analysis

### Structured Scenarios
- <doc:4.2-ScenarioAnalysisGuide> - Building and analyzing discrete scenarios with stress testing

## Prerequisites

Before diving into simulation and uncertainty quantification:

- Complete Part I (<doc:Part1-Basics>) - Especially time series (<doc:1.2-TimeSeries>)
- Understand financial modeling (<doc:Part3-Modeling>) - You need models to simulate
- Review risk analytics (<doc:2.3-RiskAnalyticsGuide>) - Risk measurement concepts
- Familiarity with basic probability and statistics is helpful but not required

## Suggested Reading Order

**For Most Users:**
1. <doc:4.2-ScenarioAnalysisGuide> - Start with discrete scenarios (easier conceptually)
2. <doc:4.1-MonteCarloTimeSeriesGuide> - Progress to continuous probability distributions

**For Risk Managers:**
1. <doc:4.1-MonteCarloTimeSeriesGuide> - Monte Carlo for VaR and tail risk
2. <doc:4.2-ScenarioAnalysisGuide> - Stress testing and scenario planning

**For Financial Modelers:**
1. <doc:4.2-ScenarioAnalysisGuide> - Three-scenario analysis (base/upside/downside)
2. <doc:4.1-MonteCarloTimeSeriesGuide> - Full probability distributions when needed

## Key Concepts

### Monte Carlo Simulation

Instead of a single forecast, generate thousands of possible futures:

```swift
let simulation = revenue.monteCarlo()
    .baseGrowth(mean: 0.15, standardDeviation: 0.05)
    .volatility(0.12)
    .simulations(10_000)
    .run()

let forecast = simulation.forecast
let confidence90 = forecast.confidenceInterval(0.90)
let probabilityOfPositiveGrowth = forecast.probability { $0 > 0 }
```

This gives you a complete probability distribution instead of a single point estimate.

### Scenario Analysis

Structure thinking around discrete, internally consistent future states:

```swift
let scenarios = ScenarioAnalysis()
    .baseCase {
        revenueGrowth = 0.10
        marginExpansion = 0.02
        probability = 0.60
    }
    .upsideCase {
        revenueGrowth = 0.20
        marginExpansion = 0.04
        probability = 0.20
    }
    .downsideCase {
        revenueGrowth = 0.02
        marginExpansion = -0.01
        probability = 0.20
    }
    .analyze()

let expectedValue = scenarios.probabilityWeightedAverage()
let downside = scenarios.worstCase
```

### Probabilistic Forecasting

Create forecasts that communicate uncertainty clearly:

```swift
let forecast = revenue.forecastWithUncertainty()
    .historicalVolatility(periods: 20)
    .confidenceIntervals([0.50, 0.75, 0.90])
    .periods(12)
    .generate()

// Forecast includes median, confidence bands, and full distribution
chart.show(forecast, showBands: true)
```

### Stress Testing

Test how models perform under extreme but plausible conditions:

```swift
let stressScenarios = [
    .recession(duration: quarters(6), severity: 0.30),
    .creditCrisis(spreadWidening: 300),  // basis points
    .supplyShock(costIncrease: 0.40)
]

let stressResults = portfolio.stress(scenarios: stressScenarios)
// How does portfolio perform in each scenario?
```

## When to Use Each Approach

### Use Monte Carlo When:
- You need full probability distributions
- Risks are continuous (market movements, growth rates)
- You have enough data to calibrate distributions
- Stakeholders want probabilistic statements
- Calculating VaR, CVaR, or tail risk

### Use Scenario Analysis When:
- Risks are discrete or event-driven (regulatory change, competitor entry)
- You want to tell coherent "stories" about the future
- Stakeholders prefer concrete scenarios over probability distributions
- Time/resources don't permit full Monte Carlo analysis
- You need to stress test specific concerns

### Use Both When:
- Building comprehensive risk frameworks
- Addressing different stakeholder preferences
- Scenarios provide structure, Monte Carlo adds granularity within scenarios

## Real-World Applications

### Revenue Forecasting
Replace single-point revenue forecasts with probability distributions. Communicate to leadership: "70% confidence revenue will be between $8M and $12M, with a median of $10M."

### Risk Management
Quantify portfolio risk with Monte Carlo VaR. Run stress scenarios for board presentations. Model the probability of breaching debt covenants.

### Project Evaluation
Evaluate capital projects probabilistically. Instead of "NPV = $5M," report "70% probability NPV exceeds $3M, 30% probability exceeds $8M."

### Strategic Planning
Create multiple strategic scenarios (digital disruption, market consolidation, regulatory change). Model financial implications of each. Build contingency plans.

## Communicating Uncertainty

### Do:
- Use confidence intervals: "90% confidence the outcome will be between X and Y"
- Show distributions visually: fan charts, probability cones, histograms
- Provide context: "There's a 1 in 10 chance we underperform by 20% or more"
- Emphasize ranges over point estimates

### Don't:
- Present point estimates without uncertainty bounds
- Use overly precise probabilities ("37.4% chance") without strong justification
- Hide uncertainty to appear more confident
- Forget to explain what confidence intervals mean

## Common Pitfalls

**Garbage In, Garbage Out**: Monte Carlo can't fix bad assumptions. If your base model is flawed, simulating it 10,000 times won't help.

**Underestimating Correlation**: Assuming independence when variables are correlated produces overly optimistic results. Model correlations explicitly.

**Ignoring Tail Risk**: Normal distributions underestimate extreme events. Consider fat-tailed distributions for financial modeling.

**Too Many Scenarios**: More than 3-5 scenarios overwhelms stakeholders. Keep it simple unless building comprehensive risk frameworks.

## Next Steps

After mastering simulation and uncertainty:

- **Optimize Under Uncertainty** (<doc:Part5-Optimization>) - Find optimal decisions considering risk
- **Apply to Models** (<doc:Part3-Modeling>) - Add probabilistic thinking to valuation and forecasting
- **Measure Risk** (<doc:2.3-RiskAnalyticsGuide>) - Calculate VaR, CVaR, and other risk metrics
- **Analyze Sensitivity** (<doc:2.1-DataTableAnalysis>) - Identify which uncertainties matter most

## Common Questions

**How many simulations should I run?**

For most applications, 10,000 simulations provides stable results. Use fewer (1,000-5,000) for quick analysis. Run more (50,000-100,000) if you're calculating tail probabilities or need high precision.

**How do I choose probability distributions?**

Start with historical data when available. Normal distributions work for many financial variables. Consider lognormal for strictly positive variables (prices, revenues). Use beta or triangular when you only have min/most likely/max estimates.

**Should I use Monte Carlo for everything?**

No. It adds complexity and requires additional assumptions about distributions. Use it when uncertainty is material to the decision and stakeholders need probabilistic thinking. Simple scenarios often suffice.

**How do I handle correlated variables?**

Use correlation matrices or copulas to model dependencies. Don't assume independence—correlated risks compound. Historical correlations provide a starting point, but consider how correlations might change in stress scenarios.

## Related Topics

- <doc:Part3-Modeling> - Financial models that can be simulated
- <doc:2.3-RiskAnalyticsGuide> - Risk metrics (VaR, CVaR) calculated from simulations
- <doc:2.1-DataTableAnalysis> - Sensitivity analysis complements uncertainty modeling
- <doc:5.2-PortfolioOptimizationGuide> - Optimization considering risk and uncertainty
