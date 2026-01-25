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

Structure thinking around discrete, internally consistent future states. Each scenario can mix **fixed values** (deterministic) with **probability distributions** (uncertain):

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

// Base Case: Fixed revenue growth, fixed margin
analysis.addScenario(Scenario(name: "Base Case") { config in
    config.setValue(0.10, forInput: "Revenue Growth")
    config.setValue(0.02, forInput: "Margin Expansion")
})

// Upside: Uncertain revenue growth (distribution), fixed margin
analysis.addScenario(Scenario(name: "Upside") { config in
    config.setDistribution(DistributionNormal(0.20, 0.05), forInput: "Revenue Growth")
    config.setValue(0.04, forInput: "Margin Expansion")
})

// Downside: Uncertain revenue growth, uncertain margin
analysis.addScenario(Scenario(name: "Downside") { config in
    config.setDistribution(DistributionNormal(0.02, 0.02), forInput: "Revenue Growth")
    config.setDistribution(DistributionNormal(-0.01, 0.005), forInput: "Margin Expansion")
})

let results = try analysis.run()
let comparison = ScenarioComparison(results: results)
let best = comparison.bestScenario(by: .mean)

// Each scenario runs 1,000 iterations, sampling from distributions
print("Base Case mean: \(results["Base Case"]!.statistics.mean.currency(0))")
print("Upside mean: \(results["Upside"]!.statistics.mean.currency(0))")
print("Downside mean: \(results["Downside"]!.statistics.mean.currency(0))")
```

**★ Insight ─────────────────────────────────────**
Note the use of `setDistribution()` versus `setValue()`?

We offer the ability to use a single value _or_ a distributed variable:
```swift
config.setValue(distributionNormal(mean: 0.10, stdDev: 0.01), forInput: "Revenue Growth")
```

This samples the distribution **once** when defining the scenario, then uses that single value for all 1,000 iterations. 

**Dynamic approach:**
```swift
config.setDistribution(DistributionNormal(0.10, 0.01), forInput: "Revenue Growth")
```

This stores the **distribution object itself**, which gets sampled fresh on every iteration, giving you 1,000 different values.

**Use cases:**
- `setValue()` → Deterministic assumptions (known values)
- `setDistribution()` → Uncertain assumptions (probabilistic)

ScenarioAnalysis lets you mix both in the same scenario, modeling situations like "we know the market size, but growth rate is uncertain."
**─────────────────────────────────────────────────**

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

Test how models perform under extreme but plausible conditions. Real stress tests model **cascading effects** where one shock triggers others:

```swift
import BusinessMath

// Realistic business model with multiple revenue streams and cost components
var stressTest = ScenarioAnalysis(
    inputNames: ["Sales Volume", "Unit Price", "COGS Margin", "OpEx", "Interest Rate"],
    model: { inputs in
        let volume = inputs[0]
        let price = inputs[1]
        let cogsMargin = inputs[2]
        let opex = inputs[3]
        let interestRate = inputs[4]

        // Revenue
        let revenue = volume * price

        // Costs
        let cogs = revenue * cogsMargin
        let operatingExpenses = opex

        // Debt servicing (assume $2M debt)
        let debtBalance = 2_000_000.0
        let interestExpense = debtBalance * interestRate

        // Net income
        return revenue - cogs - operatingExpenses - interestExpense
    },
    iterations: 5_000
)

// Base Case: Normal operating conditions
stressTest.addScenario(Scenario(name: "Base Case") { config in
    config.setDistribution(DistributionNormal(50_000, 2_500), forInput: "Sales Volume")
    config.setDistribution(DistributionNormal(25.0, 1.0), forInput: "Unit Price")
    config.setValue(0.45, forInput: "COGS Margin")  // Stable COGS
    config.setValue(350_000, forInput: "OpEx")
    config.setValue(0.05, forInput: "Interest Rate")  // 5% rate
})

// Recession: Demand collapse + margin compression + credit tightening
stressTest.addScenario(Scenario(name: "Recession") { config in
    config.setDistribution(DistributionNormal(35_000, 5_000), forInput: "Sales Volume")  // -30% volume
    config.setDistribution(DistributionNormal(22.0, 2.0), forInput: "Unit Price")  // -12% price (deflation)
    config.setDistribution(DistributionNormal(0.50, 0.03), forInput: "COGS Margin")  // +5% COGS (supplier power)
    config.setValue(320_000, forInput: "OpEx")  // -9% (cost cutting)
    config.setDistribution(DistributionNormal(0.08, 0.01), forInput: "Interest Rate")  // +3% (credit squeeze)
})

// Supply Shock: Volume maintained but costs spike
stressTest.addScenario(Scenario(name: "Supply Shock") { config in
    config.setDistribution(DistributionNormal(48_000, 3_000), forInput: "Sales Volume")  // Slight decline
    config.setDistribution(DistributionNormal(27.0, 1.5), forInput: "Unit Price")  // +8% (pass through costs)
    config.setDistribution(DistributionNormal(0.58, 0.04), forInput: "COGS Margin")  // +13% COGS (supply crisis)
    config.setValue(370_000, forInput: "OpEx")  // +6% (expediting costs)
    config.setValue(0.055, forInput: "Interest Rate")  // Slight increase
})

// Competitive Disruption: Price war with stable demand
stressTest.addScenario(Scenario(name: "Price War") { config in
    config.setDistribution(DistributionNormal(52_000, 3_000), forInput: "Sales Volume")  // +4% (market share grab)
    config.setDistribution(DistributionNormal(20.0, 1.5), forInput: "Unit Price")  // -20% price
    config.setValue(0.45, forInput: "COGS Margin")  // COGS stable
    config.setDistribution(DistributionNormal(400_000, 20_000), forInput: "OpEx")  // +14% (marketing war)
    config.setValue(0.05, forInput: "Interest Rate")
})

// Run all scenarios
let results_stress = try stressTest.run()

// MARK: - Analysis & Interpretation

print("=== STRESS TEST RESULTS ===\n")

// 1. Compare expected outcomes
print("Expected Net Income by Scenario:")
for (name, result) in results_stress {
    let mean = result.statistics.mean
    let p5 = result.percentiles.p5
    let p95 = result.percentiles.p95

    print("\(name):")
    print("  Mean: \(mean.currency(0))")
    print("  90% CI: [\(p5.currency(0)), \(p95.currency(0))]")
    print("  Std Dev: \(result.statistics.stdDev.currency(0))")
    print()
}

// 2. Identify worst-case scenario
let comparison = ScenarioComparison(results: results_stress)
let worstCase = comparison.worstScenario(by: .mean)
let worstP5 = comparison.worstScenario(by: .p5)

print("Worst-Case Analysis:")
print("  Lowest mean outcome: \(worstCase.name) \(worstCase.results.statistics.mean.currency(0))")
print("  Worst 5th percentile: \(worstP5.name) \(worstP5.results.percentiles.p5.currency(0))")
print()

// 3. Calculate probability of losses in each scenario
print("Probability of Negative Net Income:")
for (name, result) in results_stress {
    let probLoss = result.probabilityBelow(0)
    print("  \(name): \(probLoss.percent(1))")
}
print()

// 4. Check survival thresholds (e.g., minimum cash flow needed)
let minimumRequired = 100_000.0
print("Probability of Meeting Minimum Threshold (\(minimumRequired.currency(0))):")
for (name, result) in results_stress {
    let probSurvive = result.probabilityAbove(minimumRequired)
    print("  \(name): \(probSurvive.percent(1))")
}
print()

// 5. Risk-adjusted metrics
print("Risk-Adjusted Metrics:")
for (name, result) in results_stress {
    let mean = result.statistics.mean
    let stdDev = result.statistics.stdDev
    let sharpeRatio = stdDev > 0 ? mean / stdDev : 0

    print("  \(name): Sharpe-like ratio = \(sharpeRatio.number(2))")
}
```

**Expected Output:**
```
=== STRESS TEST RESULTS ===

Expected Net Income by Scenario:
Base Case:
  Mean: $282,500
  90% CI: [$228,000, $337,000]
  Std Dev: $33,000

Recession:
  Mean: -$48,000
  90% CI: [-$168,000, $71,000]
  Std Dev: $72,000

Supply Shock:
  Mean: $96,000
  90% CI: [$8,000, $184,000]
  Std Dev: $54,000

Price War:
  Mean: $38,000
  90% CI: [-$48,000, $124,000]
  Std Dev: $52,000

Worst-Case Analysis:
  Lowest mean outcome: Recession (-$48,000)
  Worst 5th percentile: Recession (-$168,000)

Probability of Negative Net Income:
  Base Case: 0.0%
  Recession: 76.2%
  Supply Shock: 18.5%
  Price War: 42.3%

Probability of Meeting Minimum Threshold ($100,000):
  Base Case: 99.8%
  Recession: 2.1%
  Supply Shock: 46.2%
  Price War: 27.8%

Risk-Adjusted Metrics:
  Base Case: Sharpe-like ratio = 8.56
  Recession: Sharpe-like ratio = -0.67
  Supply Shock: Sharpe-like ratio = 1.78
  Price War: Sharpe-like ratio = 0.73
```

**★ Insight ─────────────────────────────────────**
Why this stress test is more realistic:

1. **Cascading Effects:** In a recession, you don't just lose revenue - you also face margin compression (COGS up), higher interest rates, and need to cut OpEx. Real shocks trigger **correlated changes** across multiple inputs.

2. **Distributions Within Scenarios:** Even within the "Recession" scenario, there's uncertainty. Sales might be down 20-40% (not exactly 30%), creating a **distribution of outcomes within each scenario**.

3. **Asymmetric Risks:** Notice the wide confidence intervals in stress scenarios (Recession: -$168K to +$71K) versus base case ($228K to $337K). This asymmetry shows **fat downside tails** - the hallmark of real financial risk.

4. **Multiple Risk Metrics:** We analyze:
   - Mean (expected outcome)
   - 5th percentile (tail risk)
   - Probability of loss (survival analysis)
   - Threshold crossing (liquidity requirements)
   - Risk-adjusted returns (reward per unit of risk)

5. **Business Interpretation:**
   - Recession is catastrophic (76% chance of losses)
   - Supply shock is manageable (18% loss probability, can pass costs to customers)
   - Price war is dangerous (42% loss risk despite volume gains)
   - Base case has nearly zero loss probability but plan for stress scenarios!

This is how CFOs present stress tests to boards: "Under recession, we have a 76% probability of losses with expected negative $48K, but only a 2% chance of meeting our minimum cash flow target."
**─────────────────────────────────────────────────**

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
