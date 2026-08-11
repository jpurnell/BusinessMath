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
- <doc:4.1-MonteCarloTimeSeriesGuide>

### Structured Scenarios
- <doc:4.2-ScenarioAnalysisGuide>

### Reproducibility & Concurrency
- <doc:4.5-DeterministicSimulationGuide>

## Prerequisites

Before diving into simulation and uncertainty quantification, you should complete Part I (especially time series), understand financial modeling from Part III (you need models to simulate), and review risk analytics for risk measurement concepts. Familiarity with basic probability and statistics is helpful but not required.

## Suggested Reading Order

**For Most Users:**
1. <doc:4.2-ScenarioAnalysisGuide>
2. <doc:4.1-MonteCarloTimeSeriesGuide>

**For Risk Managers:**
1. <doc:4.1-MonteCarloTimeSeriesGuide>
2. <doc:4.2-ScenarioAnalysisGuide>

**For Financial Modelers:**
1. <doc:4.2-ScenarioAnalysisGuide>
2. <doc:4.1-MonteCarloTimeSeriesGuide>

## Key Concepts

### Monte Carlo Simulation

Instead of a single forecast, generate thousands of possible futures:

```swift
// `seed:` makes the run reproducible; omit it for a fresh draw each time
var simulation = MonteCarloSimulation(iterations: 10_000, seed: 2317) { inputs in
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
// The model lives in its own `let` so the reproducible runner below can be handed the
// same function `ScenarioAnalysis` was built with
let growthModel: @Sendable ([Double]) -> Double = { inputs in
    let revenue = 1_000_000 * (1 + inputs[0])
    let margin = 0.20 + inputs[1]
    return revenue * margin
}

var analysis = ScenarioAnalysis(
    inputNames: ["Revenue Growth", "Margin Expansion"],
    model: growthModel,
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

/// Runs one `Scenario` reproducibly.
///
/// `ScenarioAnalysis.run()` builds each scenario's `MonteCarloSimulation` without a
/// seed — `ScenarioAnalysis` has no `seed:` parameter and samples its distributions
/// through the unseeded `DistributionRandom.next()` — so its figures move on every run.
/// A `Scenario` is only data, though, so you can run it yourself: one seed per
/// scenario, and every input added through `SimulationInput(name:distribution:)`, whose
/// `SeedableDistribution` overload draws from the simulation's seeded generator. A fixed
/// value becomes a degenerate uniform, which honors the seed and always returns
/// that value.
func runReproducibly(
    _ scenario: Scenario,
    inputNames: [String],
    iterations: Int,
    seed: UInt64,
    model: @escaping @Sendable ([Double]) -> Double
) throws -> SimulationResults {
    var simulation = MonteCarloSimulation(iterations: iterations, seed: seed, model: model)
    for name in inputNames {
        if let fixedValue = scenario.inputValues[name] {
            simulation.addInput(SimulationInput(
                name: name,
                distribution: DistributionUniform(fixedValue, fixedValue)
            ))
        } else if let normal = scenario.inputDistributions[name] as? DistributionNormal {
            simulation.addInput(SimulationInput(name: name, distribution: normal))
        }
    }
    return try simulation.run()
}

// A seed per scenario, so adding one never renumbers the others
let growthSeeds: [String: UInt64] = [
    "Base Case": 5101,
    "Upside": 5102,
    "Downside": 5103
]

var scenarioResults: [String: SimulationResults] = [:]
for scenario in analysis.scenarios {
    scenarioResults[scenario.name] = try runReproducibly(
        scenario,
        inputNames: analysis.inputNames,
        iterations: analysis.iterations,
        seed: growthSeeds[scenario.name]!,
        model: growthModel
    )
}

let scenarioComparison = ScenarioComparison(results: scenarioResults)
let best = scenarioComparison.bestScenario(by: .mean)
print("Best scenario: \(best.name)")

// Each scenario runs 1,000 iterations, sampling from distributions
print("Base Case mean: \(scenarioResults["Base Case"]!.statistics.mean.currency(0))")
print("Upside mean: \(scenarioResults["Upside"]!.statistics.mean.currency(0))")
print("Downside mean: \(scenarioResults["Downside"]!.statistics.mean.currency(0))")
```

**★ Insight ─────────────────────────────────────**
Note the use of `setDistribution()` versus `setValue()`?

We offer the ability to use a single value _or_ a distributed variable. Both
lines below are fragments from inside a `Scenario` configuration closure, where
`config` is the ``ScenarioConfiguration`` handed to you:

<!-- docs:illustrative -->
```swift
config.setValue(distributionNormal(mean: 0.10, stdDev: 0.01), forInput: "Revenue Growth")
```

This samples the distribution **once** when defining the scenario, then uses that single value for all 1,000 iterations. 

**Dynamic approach:**

<!-- docs:illustrative -->
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
var forecastSimulation = MonteCarloSimulation(iterations: 10_000, seed: 2318) { inputs in
	let baseRevenue = inputs[0]
	let growthRate = inputs[1]

	// Every random quantity the model uses comes from `inputs`, so the seed
	// above governs the whole run. A `Double.random` call inside this closure
	// would draw from the system generator instead and silently break that.
	let randomShock = inputs[2]

	// Simple revenue forecast with uncertainty
	let trend = baseRevenue * (1 + growthRate)
	return trend + randomShock
}

forecastSimulation.addInput(SimulationInput(
	name: "Base Revenue",
	distribution: DistributionNormal(100_000, 5_000)
))
forecastSimulation.addInput(SimulationInput(
	name: "Growth Rate",
	distribution: DistributionNormal(0.10, 0.03)
))
forecastSimulation.addInput(SimulationInput(
	name: "Revenue Shock",
	distribution: DistributionNormal(0, 2_000)
))

let forecastResults = try forecastSimulation.run()
let forecastMedian = forecastResults.percentiles.p50
let forecastConfidence90 = (forecastResults.percentiles.p5, forecastResults.percentiles.p95)
print("Median revenue: \(forecastMedian), 90% range: \(forecastConfidence90)")
```

### Stress Testing

Test how models perform under extreme but plausible conditions. Real stress tests model **cascading effects** where one shock triggers others:

```swift
import BusinessMath

// Realistic business model with multiple revenue streams and cost components
let stressModel: @Sendable ([Double]) -> Double = { inputs in
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
}

var stressTest = ScenarioAnalysis(
    inputNames: ["Sales Volume", "Unit Price", "COGS Margin", "OpEx", "Interest Rate"],
    model: stressModel,
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

// Run all scenarios, each from its own seed (see `runReproducibly` above)
let stressSeeds: [String: UInt64] = [
    "Base Case": 5201,
    "Recession": 5202,
    "Supply Shock": 5203,
    "Price War": 5204
]

var results_stress: [String: SimulationResults] = [:]
for scenario in stressTest.scenarios {
    results_stress[scenario.name] = try runReproducibly(
        scenario,
        inputNames: stressTest.inputNames,
        iterations: stressTest.iterations,
        seed: stressSeeds[scenario.name]!,
        model: stressModel
    )
}

// `results_stress` is a Dictionary, and Swift randomises hash order per process — walking
// it directly would print the scenarios in a different order on every run. Walk them in
// the order they were defined instead, which is also the order a reader expects.
let scenarioOrder = stressTest.scenarios.map(\.name)

// MARK: - Analysis & Interpretation

print("=== STRESS TEST RESULTS ===\n")

// 1. Compare expected outcomes
print("Expected Net Income by Scenario:")
for name in scenarioOrder {
    let result = results_stress[name]!
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
let stressComparison = ScenarioComparison(results: results_stress)
let worstCase = stressComparison.worstScenario(by: .mean)
let worstP5 = stressComparison.worstScenario(by: .p5)

print("Worst-Case Analysis:")
print("  Lowest mean outcome: \(worstCase.name) \(worstCase.results.statistics.mean.currency(0))")
print("  Worst 5th percentile: \(worstP5.name) \(worstP5.results.percentiles.p5.currency(0))")
print()

// 3. Calculate probability of losses in each scenario
print("Probability of Negative Net Income:")
for name in scenarioOrder {
    let result = results_stress[name]!
    let probLoss = result.probabilityBelow(0)
    print("  \(name): \(probLoss.percent(1))")
}
print()

// 4. Check survival thresholds (e.g., minimum cash flow needed)
let minimumRequired = 100_000.0
print("Probability of Meeting Minimum Threshold (\(minimumRequired.currency(0))):")
for name in scenarioOrder {
    let result = results_stress[name]!
    let probSurvive = result.probabilityAbove(minimumRequired)
    print("  \(name): \(probSurvive.percent(1))")
}
print()

// 5. Risk-adjusted metrics
print("Risk-Adjusted Metrics:")
for name in scenarioOrder {
    let result = results_stress[name]!
    let mean = result.statistics.mean
    let stdDev = result.statistics.stdDev
    let sharpeRatio = stdDev > 0 ? mean / stdDev : 0

    print("  \(name): Sharpe-like ratio = \(sharpeRatio.number(2))")
}
```

**Expected Output** (reproducible from the seeds above):
```
=== STRESS TEST RESULTS ===

Expected Net Income by Scenario:
Base Case:
  Mean: $237,991
  90% CI: [$168,266, $308,699]
  Std Dev: $43,109

Recession:
  Mean: ($93,762)
  90% CI: [($206,783), $32,349]
  Std Dev: $73,114

Supply Shock:
  Mean: $63,605
  90% CI: [($45,972), $181,757]
  Std Dev: $69,591

Price War:
  Mean: $71,876
  90% CI: [($22,984), $168,803]
  Std Dev: $58,312

Worst-Case Analysis:
  Lowest mean outcome: Recession ($93,762)
  Worst 5th percentile: Recession ($206,783)

Probability of Negative Net Income:
  Base Case: 0.0%
  Recession: 89.4%
  Supply Shock: 18.6%
  Price War: 10.9%

Probability of Meeting Minimum Threshold ($100,000):
  Base Case: 100.0%
  Recession: 0.9%
  Supply Shock: 29.2%
  Price War: 31.4%

Risk-Adjusted Metrics:
  Base Case: Sharpe-like ratio = 5.52
  Recession: Sharpe-like ratio = -1.28
  Supply Shock: Sharpe-like ratio = 0.91
  Price War: Sharpe-like ratio = 1.23
```

Sanity-check the base case by hand before trusting any of the rest: 50,000 units at
$25 is $1.25M of revenue, 55% of which survives COGS ($687,500), less $350,000 of OpEx
and $100,000 of interest, leaves $237,500. The simulated mean sits $491 away from that,
which is the sampling error you would expect from 5,000 draws.

**★ Insight ─────────────────────────────────────**
Why this stress test is more realistic:

1. **Cascading Effects:** In a recession, you don't just lose revenue - you also face margin compression (COGS up), higher interest rates, and need to cut OpEx. Real shocks trigger **correlated changes** across multiple inputs.

2. **Distributions Within Scenarios:** Even within the "Recession" scenario, there's uncertainty. Sales might be down 20-40% (not exactly 30%), creating a **distribution of outcomes within each scenario**.

3. **Asymmetric Risks:** Notice the wide confidence intervals in stress scenarios (Recession: -$207K to +$32K, a $239K span) versus base case ($168K to $309K, a $141K span). Stress does not just move the mean down; it widens the range around it.

4. **Multiple Risk Metrics:** We analyze:
   - Mean (expected outcome)
   - 5th percentile (tail risk)
   - Probability of loss (survival analysis)
   - Threshold crossing (liquidity requirements)
   - Risk-adjusted returns (reward per unit of risk)

5. **Business Interpretation:**
   - Recession is catastrophic (89% chance of losses, and only a 0.9% chance of clearing the $100K threshold)
   - Supply shock is manageable (19% loss probability, because the price increase passes most of the cost on)
   - Price war rarely produces an outright loss (11%), but it costs 70% of expected profit — $238K down to $72K. A scenario can be dangerous without being loss-making
   - Base case has nearly zero loss probability but plan for stress scenarios!

This is how CFOs present stress tests to boards: "Under recession, we have an 89% probability of losses with expected negative $94K, and less than a 1% chance of meeting our minimum cash flow target."
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

- **Optimize Under Uncertainty** (<doc:Part5-Optimization>): Find optimal decisions considering risk
- **Apply to Models** (<doc:Part3-Modeling>): Add probabilistic thinking to valuation and forecasting
- **Measure Risk** (<doc:2.3-RiskAnalyticsGuide>): Calculate VaR, CVaR, and other risk metrics
- **Analyze Sensitivity** (<doc:2.1-DataTableAnalysis>): Identify which uncertainties matter most

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

- <doc:Part3-Modeling>
- <doc:2.3-RiskAnalyticsGuide>
- <doc:2.1-DataTableAnalysis>
- <doc:5.2-PortfolioOptimizationGuide>
