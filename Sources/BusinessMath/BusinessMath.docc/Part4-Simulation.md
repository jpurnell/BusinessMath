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
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	let baseRevenue = inputs[0]
	let growthRate = inputs[1]
	return baseRevenue * (1 + growthRate)
}

simulation.addInput(SimulationInput(
	name: "Base Revenue",
	distribution: DistributionNormal(1_000_000, 100_000)
))

simulation.addInput(SimulationInput(
	name: "Growth Rate",
	distribution: DistributionNormal(0.15, 0.05)
))

let results = try simulation.run()
let mean = results.statistics.mean
let confidence90 = (results.percentiles.p5, results.percentiles.p95)
let probabilityPositive = results.probabilityAbove(0)
```

This gives you a complete probability distribution instead of a single point estimate.

### Scenario Analysis

Structure thinking around discrete, internally consistent future states:

```swift
var analysis = ScenarioAnalysis(
    inputNames: ["Revenue Growth", "Margin Expansion"],
    model: { inputs in
        let revenue = 1_000_000 * (1 + inputs[0])
        let margin = 0.20 + inputs[1]
        return revenue * margin
    },
    iterations: 1_000
)

analysis.addScenario(Scenario(name: "Base Case") { config in
    config.setValue(0.10, forInput: "Revenue Growth")
    config.setValue(0.02, forInput: "Margin Expansion")
})

analysis.addScenario(Scenario(name: "Upside") { config in
    config.setValue(0.20, forInput: "Revenue Growth")
    config.setValue(0.04, forInput: "Margin Expansion")
})

analysis.addScenario(Scenario(name: "Downside") { config in
    config.setValue(0.02, forInput: "Revenue Growth")
    config.setValue(-0.01, forInput: "Margin Expansion")
})

let results = try analysis.run()
let comparison = ScenarioComparison(results: results)
let best = comparison.bestScenario(by: .mean)
```

### Probabilistic Forecasting

Create forecasts that communicate uncertainty clearly:

```swift
// Forecast next 12 months with uncertainty
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	let baseRevenue = inputs[0]
	let growthRate = inputs[1]
	let volatility = inputs[2]

	// Simple revenue forecast with uncertainty
	let trend = baseRevenue * (1 + growthRate)
	let randomShock = volatility * (Double.random(in: -1...1))
	return trend + randomShock
}

simulation.addInput(SimulationInput(
	name: "Base Revenue",
	distribution: DistributionNormal(100_000, 5_000)
))
simulation.addInput(SimulationInput(
	name: "Growth Rate",
	distribution: DistributionNormal(0.10, 0.03)
))
simulation.addInput(SimulationInput(
	name: "Volatility",
	distribution: DistributionNormal( 0, 2_000)
))

let results = try simulation.run()
let median = results.percentiles.p50
let confidence90 = (results.percentiles.p5, results.percentiles.p95)
```

### Stress Testing

Test how models perform under extreme but plausible conditions:

```swift
var stressTest = ScenarioAnalysis(
	inputNames: ["Revenue", "Costs"],
	model: { inputs in inputs[0] - inputs[1] },  // Profit
	iterations: 1_000
)

// Recession scenario
stressTest.addScenario(Scenario(name: "Recession") { config in
	config.setValue(700_000, forInput: "Revenue")      // -30% revenue
	config.setValue(650_000, forInput: "Costs")        // Costs stay high
})

// Credit crisis scenario
stressTest.addScenario(Scenario(name: "Credit Crisis") { config in
	config.setValue(900_000, forInput: "Revenue")
	config.setValue(800_000, forInput: "Costs")        // +40% financing costs
})

// Supply shock scenario
stressTest.addScenario(Scenario(name: "Supply Shock") { config in
	config.setValue(1_000_000, forInput: "Revenue")
	config.setValue(900_000, forInput: "Costs")        // +40% costs
})

let results = try stressTest.run()
// Analyze worst-case outcomes across scenarios
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
