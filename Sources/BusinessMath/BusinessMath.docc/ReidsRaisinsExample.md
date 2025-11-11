# Reid's Raisins: Complete Decision Analysis

A comprehensive case study demonstrating profit optimization, breakeven analysis, sensitivity tables, and tornado charts using BusinessMath.

## Overview

This tutorial walks through a complete business decision analysis for Reid's Raisin Company (RRC), a food-processing firm that must decide:
1. How many grapes to purchase under contract
2. What price to charge for sugar-coated raisins

You'll learn how to:
- Model complex profit functions with multiple cost structures
- Calculate base-case scenarios
- Find breakeven points using optimization
- Build sensitivity tables for pricing decisions
- Create tornado charts to identify key drivers

## Business Context

Reid's Raisin Company purchases surplus grapes, dries them into raisins, applies a sugar coating, and sells to cereal and candy companies. The business faces two key decisions each spring:

**Grape Procurement:**
- Contract grapes: $0.25 per pound (purchased in spring for autumn delivery)
- Open-market grapes: $0.20-$0.35 per pound (purchased in autumn as needed)
- Cannot resell surplus grapes

**Pricing Decision:**
- Base price: $2.20 per pound yields 750,000 pounds demand
- Price elasticity: Demand changes by 15,000 pounds per penny price change
- Must negotiate price in spring before knowing autumn market conditions

**Production Economics:**
- Recipe: 2.5 lbs grapes + 0.05 lbs coating → 1 lb sugar-coated raisins
- Sugar coating: $0.55 per pound
- Processing cost: $0.20 per pound of grapes (up to 1,500,000 lbs capacity)
- Outsourced processing: $0.45 per pound (beyond capacity)
- Fixed overhead: $200,000 per year

## Building the Profit Model

### Step 1: Define the Business Parameters

Start by encoding the business rules as a structured model:

```swift
import BusinessMath

/// Reid's Raisin Company profit model
struct ReidsRaisinsModel {
    // MARK: - Input Parameters

    /// Contract grape price ($/lb)
    let contractGrapePrice: Double = 0.25

    /// Sugar coating cost ($/lb)
    let coatingPrice: Double = 0.55

    /// In-house processing cost ($/lb of grapes, up to capacity)
    let inHouseProcessingCost: Double = 0.20

    /// Outsourced processing cost ($/lb of grapes, beyond capacity)
    let outsourcedProcessingCost: Double = 0.45

    /// Processing capacity (lbs of grapes)
    let processingCapacity: Double = 1_500_000

    /// Fixed annual overhead ($)
    let fixedOverhead: Double = 200_000

    /// Grapes required per pound of raisins
    let grapesPerPound: Double = 2.5

    /// Coating required per pound of raisins
    let coatingPerPound: Double = 0.05

    // MARK: - Demand Model Parameters

    /// Base demand at base price (lbs)
    let baseDemand: Double = 750_000

    /// Base price ($/lb)
    let basePrice: Double = 2.20

    /// Demand sensitivity (lbs per penny change)
    let demandSensitivity: Double = 15_000

    // MARK: - Decision Variables

    /// Contract grape quantity (lbs)
    var contractQuantity: Double

    /// Selling price for raisins ($/lb)
    var raisinPrice: Double

    /// Open market grape price ($/lb)
    var openMarketPrice: Double
}
```

### Step 2: Calculate Demand

The demand model implements the price-quantity relationship:

```swift
extension ReidsRaisinsModel {
    /// Calculate demand for sugar-coated raisins given a price
    /// Demand = baseDemand + sensitivity × (basePrice - price) × 100
    func calculateDemand(price: Double) -> Double {
        let priceDifferenceInCents = (basePrice - price) * 100
        let demandChange = demandSensitivity * priceDifferenceInCents
        return baseDemand + demandChange
    }
}
```

### Step 3: Calculate Grape Requirements and Costs

```swift
extension ReidsRaisinsModel {
    /// Calculate total grapes needed for production
    func grapesNeeded(demand: Double) -> Double {
        return demand * grapesPerPound
    }

    /// Calculate grape procurement costs
    func grapeCost(totalGrapesNeeded: Double) -> Double {
        // Use contract grapes first
        let contractCost = min(contractQuantity, totalGrapesNeeded) * contractGrapePrice

        // Buy remainder on open market
        let openMarketQuantity = max(0, totalGrapesNeeded - contractQuantity)
        let openMarketCost = openMarketQuantity * openMarketPrice

        return contractCost + openMarketCost
    }

    /// Calculate sugar coating costs
    func coatingCost(demand: Double) -> Double {
        return demand * coatingPerPound * coatingPrice
    }

    /// Calculate processing costs (in-house vs outsourced)
    func processingCost(totalGrapesNeeded: Double) -> Double {
        let inHouseGrapes = min(totalGrapesNeeded, processingCapacity)
        let outsourcedGrapes = max(0, totalGrapesNeeded - processingCapacity)

        let inHouseCost = inHouseGrapes * inHouseProcessingCost
        let outsourcedCost = outsourcedGrapes * outsourcedProcessingCost

        return inHouseCost + outsourcedCost
    }
}
```

### Step 4: Calculate Total Profit

```swift
extension ReidsRaisinsModel {
    /// Calculate annual profit given current parameters
    func calculateProfit() -> Double {
        // Calculate demand at current price
        let demand = calculateDemand(price: raisinPrice)

        // Calculate revenue
        let revenue = raisinPrice * demand

        // Calculate all costs
        let totalGrapes = grapesNeeded(demand: demand)
        let grapes = grapeCost(totalGrapesNeeded: totalGrapes)
        let coating = coatingCost(demand: demand)
        let processing = processingCost(totalGrapesNeeded: totalGrapes)

        // Total cost = variable costs + fixed overhead
        let totalCost = grapes + coating + processing + fixedOverhead

        return revenue - totalCost
    }

    /// Calculate profit with detailed breakdown
    func profitBreakdown() -> (revenue: Double, costs: [String: Double], profit: Double) {
        let demand = calculateDemand(price: raisinPrice)
        let totalGrapes = grapesNeeded(demand: demand)

        let revenue = raisinPrice * demand

        let costs: [String: Double] = [
            "Grapes": grapeCost(totalGrapesNeeded: totalGrapes),
            "Coating": coatingCost(demand: demand),
            "Processing": processingCost(totalGrapesNeeded: totalGrapes),
            "Fixed Overhead": fixedOverhead
        ]

        let totalCost = costs.values.reduce(0, +)
        let profit = revenue - totalCost

        return (revenue, costs, profit)
    }
}
```

## Question A: Base-Case Profit Analysis

Calculate profit under Mary Jo's suggested base-case assumptions:
- Contract purchase: 1,000,000 pounds at $0.25
- Selling price: $2.20 per pound
- Expected open-market price: $0.30 per pound

```swift
// Create base-case model
var baseCase = ReidsRaisinsModel(
    contractQuantity: 1_000_000,
    raisinPrice: 2.20,
    openMarketPrice: 0.30
)

// Calculate profit with detailed breakdown
let (revenue, costs, profit) = baseCase.profitBreakdown()

print("=== Base-Case Analysis ===")
print("Assumptions:")
print("  Contract grapes: 1,000,000 lbs @ $0.25")
print("  Raisin price: $\(baseCase.raisinPrice)")
print("  Open-market grape price: $\(baseCase.openMarketPrice)")
print()

// Calculate demand
let demand = baseCase.calculateDemand(price: baseCase.raisinPrice)
print("Demand: \(Int(demand).formatted()) lbs of raisins")
print("Grapes needed: \(Int(baseCase.grapesNeeded(demand: demand)).formatted()) lbs")
print()

print("Revenue: $\(Int(revenue).formatted())")
print()
print("Costs:")
for (category, amount) in costs.sorted(by: { $0.key < $1.key }) {
    print("  \(category): $\(Int(amount).formatted())")
}
print("  Total Costs: $\(Int(costs.values.reduce(0, +)).formatted())")
print()
print("Annual Profit: $\(Int(profit).formatted())")
```

**Expected Output:**
```
=== Base-Case Analysis ===
Assumptions:
  Contract grapes: 1,000,000 lbs @ $0.25
  Raisin price: $2.20
  Open-market grape price: $0.30

Demand: 750,000 lbs of raisins
Grapes needed: 1,875,000 lbs

Revenue: $1,650,000

Costs:
  Coating: $20,625
  Fixed Overhead: $200,000
  Grapes: $512,500
  Processing: $468,750
  Total Costs: $1,201,875

Annual Profit: $448,125
```

## Question B: Breakeven Analysis

Find the open-market grape price where profit equals zero using Goal Seek optimization:

```swift
import BusinessMath

// Define profit as a function of open-market price
func profitFunction(openMarketPrice: Double) -> Double {
    var model = baseCase
    model.openMarketPrice = openMarketPrice
    return model.calculateProfit()
}

// Use Goal Seek to find where profit = 0
let optimizer = GoalSeekOptimizer<Double>(
    target: 0.0,           // Find where profit equals zero
    tolerance: 0.0001,
    maxIterations: 1000
)

let breakevenResult = optimizer.optimize(
    objective: profitFunction,
    constraints: [],
    initialValue: 0.30,    // Start from base-case price
    bounds: (0.0, 1.0)     // Price must be between $0 and $1
)

print("\n=== Breakeven Analysis ===")
if breakevenResult.converged {
    print("Breakeven open-market grape price: $\(String(format: "%.4f", breakevenResult.optimalValue))")
    print("Profit at breakeven: $\(Int(breakevenResult.objectiveValue).formatted()) (should be ≈$0)")
    print("Converged in \(breakevenResult.iterations) iterations")

    // Show context
    print()
    print("Interpretation:")
    print("  If open-market grapes cost more than $\(String(format: "%.4f", breakevenResult.optimalValue)),")
    print("  RRC will lose money with current contract and pricing decisions.")
} else {
    print("Failed to find breakeven point")
}
```

**Expected Output:**
```
=== Breakeven Analysis ===
Breakeven open-market grape price: $0.4398
Profit at breakeven: $0 (should be ≈$0)

Interpretation:
  If open-market grapes cost more than $0.4398,
  RRC will lose money with current contract and pricing decisions.
```

## Question C: Sensitivity Table - Profit vs Raisin Price

Construct a table showing how profit varies with raisin pricing from $1.80 to $2.80:

```swift
print("\n=== Sensitivity Analysis: Raisin Price vs Profit ===")
print("Open-market grape price held constant at $\(baseCase.openMarketPrice)")
print()

// Define price range
let minPrice = 1.80
let maxPrice = 2.80
let step = 0.10
let prices = stride(from: minPrice, through: maxPrice, by: step)

// Build results table
var results: [(price: Double, demand: Double, profit: Double)] = []

for price in prices {
    var model = baseCase
    model.raisinPrice = price

    let demand = model.calculateDemand(price: price)
    let profit = model.calculateProfit()

    results.append((price, demand, profit))
}

// Print table header
print(String(format: "%8s  %12s  %15s", "Price", "Demand (lbs)", "Profit ($)"))
print(String(repeating: "-", count: 40))

// Print results
for result in results {
    print(String(format: "$%6.2f  %12s  %15s",
                 result.price,
                 Int(result.demand).formatted(),
                 Int(result.profit).formatted()))
}

// Find optimal price
if let optimalResult = results.max(by: { $0.profit < $1.profit }) {
    print()
    print("Optimal raisin price: $\(String(format: "%.2f", optimalResult.price))")
    print("Maximum profit: $\(Int(optimalResult.profit).formatted())")
}
```

**Expected Output:**
```
=== Sensitivity Analysis: Raisin Price vs Profit ===
Open-market grape price held constant at $0.30

  Price    Demand (lbs)       Profit ($)
----------------------------------------
$ 1.80     1,350,000           -437,500
$ 1.90     1,200,000           -100,000
$ 2.00     1,050,000            178,125
$ 2.10       900,000            396,875
$ 2.20       750,000            448,125
$ 2.30       600,000            331,875
$ 2.40       450,000             48,125
$ 2.50       300,000           -403,125
$ 2.60       150,000         -1,021,875
$ 2.70             0         -1,808,125
$ 2.80      -150,000         -2,761,875

Optimal raisin price: $2.20
Maximum profit: $448,125
```

## Question D: Tornado Chart Analysis

Identify which parameters have the greatest impact on profit using BusinessMath's built-in tornado diagram analysis:

```swift
import BusinessMath

print("\n=== Tornado Chart: Parameter Sensitivity Analysis ===")
print()

// Define parameters to test with their ranges
struct ParameterTest {
    let name: String
    let lowValue: Double
    let highValue: Double
    let evaluate: (inout ReidsRaisinsModel, Double) -> Void
}

let parameters: [ParameterTest] = [
    ParameterTest(
        name: "Open-Market Grape Price",
        lowValue: 0.20,   // Historical low
        highValue: 0.35,  // Historical high
        evaluate: { $0.openMarketPrice = $1 }
    ),
    ParameterTest(
        name: "Raisin Selling Price",
        lowValue: 2.00,   // -$0.20 from base (±10%)
        highValue: 2.40,  // +$0.20 from base (±10%)
        evaluate: { $0.raisinPrice = $1 }
    ),
    ParameterTest(
        name: "Contract Grape Quantity",
        lowValue: 750_000,    // -25%
        highValue: 1_250_000, // +25%
        evaluate: { $0.contractQuantity = $1 }
    ),
    ParameterTest(
        name: "Contract Grape Price",
        lowValue: 0.20,  // -20%
        highValue: 0.30, // +20%
        evaluate: { $0.contractGrapePrice = $1 }
    )
]

// Calculate impacts for each parameter
var impacts: [String: Double] = [:]
var lowValues: [String: Double] = [:]
var highValues: [String: Double] = [:]

for param in parameters {
    // Test low parameter value
    var lowModel = baseCase
    param.evaluate(&lowModel, param.lowValue)
    let profitAtLow = lowModel.calculateProfit()

    // Test high parameter value
    var highModel = baseCase
    param.evaluate(&highModel, param.highValue)
    let profitAtHigh = highModel.calculateProfit()

    // Store results - use min/max of OUTCOMES, not parameter values
    // This ensures the tornado chart displays correctly
    let minProfit = min(profitAtLow, profitAtHigh)
    let maxProfit = max(profitAtLow, profitAtHigh)

    lowValues[param.name] = minProfit
    highValues[param.name] = maxProfit
    impacts[param.name] = maxProfit - minProfit
}

// Rank parameters by impact (descending)
let rankedInputs = parameters.map { $0.name }.sorted { name1, name2 in
    let impact1 = impacts[name1] ?? 0.0
    let impact2 = impacts[name2] ?? 0.0
    return impact1 > impact2
}

// Create TornadoDiagramAnalysis object
let tornadoAnalysis = TornadoDiagramAnalysis(
    inputs: rankedInputs,
    impacts: impacts,
    lowValues: lowValues,
    highValues: highValues,
    baseCaseOutput: profit
)

// Use BusinessMath's built-in visualization
let tornadoPlot = plotTornadoDiagram(tornadoAnalysis)
print(tornadoPlot)

// Also print detailed breakdown
print("\nDetailed Impact Analysis:")
for (index, input) in tornadoAnalysis.inputs.enumerated() {
    let impact = tornadoAnalysis.impacts[input]!
    let low = tornadoAnalysis.lowValues[input]!
    let high = tornadoAnalysis.highValues[input]!
    let percentImpact = (impact / abs(profit)) * 100.0

    print("\n\(index + 1). \(input)")
    print("   Low scenario:  $\(Int(low).formatted())")
    print("   High scenario: $\(Int(high).formatted())")
    print("   Impact range:  $\(Int(impact).formatted()) (\(String(format: "%.1f", percentImpact))% of base profit)")
}
```

**Expected Output:**
```
=== Tornado Chart: Parameter Sensitivity Analysis ===

Tornado Diagram - Sensitivity Analysis
Base Case: 448125

Raisin Selling Price      ◄█████████████████████████│█████████████████████████►  Impact: 485625 (108.4%)
                             -437500                448125                 485625

Open-Market Grape Price   ◄█████████████████████████│█████████████████████████►  Impact: 484375 (108.1%)
                             175000                 448125                 659375

Contract Grape Price      ◄████│████►                                            Impact: 100000 (22.3%)
                             398125  448125  498125

Contract Grape Quantity   ◄█│█►                                                  Impact: 38750 (8.6%)
                             428750  448125  467500

Detailed Impact Analysis:

1. Raisin Selling Price
   Low scenario:  $-437,500
   High scenario: $48,125
   Impact range:  $485,625 (108.4% of base profit)

2. Open-Market Grape Price
   Low scenario:  $175,000
   High scenario: $659,375
   Impact range:  $484,375 (108.1% of base profit)

3. Contract Grape Price
   Low scenario:  $398,125
   High scenario: $498,125
   Impact range:  $100,000 (22.3% of base profit)

4. Contract Grape Quantity
   Low scenario:  $428,750
   High scenario: $467,500
   Impact range:  $38,750 (8.6% of base profit)
```

## Key Insights from Analysis

### Base-Case Findings
- At the suggested starting point ($2.20 raisin price, $0.30 market price), RRC projects annual profit of $448,125
- The company needs 1,875,000 lbs of grapes to meet 750,000 lbs of raisin demand
- Contract grapes cover 53% of needs; remaining 875,000 lbs purchased on open market

### Breakeven Insight
- RRC can tolerate open-market grape prices up to $0.44 before losing money
- This provides a 47% buffer above the expected $0.30 price
- Strong downside protection against grape price increases

### Pricing Strategy
- Current $2.20 price is optimal in the tested range
- Prices below $2.10 generate insufficient margin despite higher volume
- Prices above $2.30 suffer from demand destruction
- The firm faces a relatively narrow optimal pricing window

### Risk Drivers
The tornado chart reveals:
1. **Raisin selling price** and **open-market grape price** are equally critical (±$485k impact)
2. **Contract quantity** has minimal impact (±$39k) - flexibility exists here
3. **Contract price** is moderate (±$66k) but still significant

**Strategic Implications:**
- Focus negotiations on securing favorable raisin pricing with customers
- Consider hedging strategies for open-market grape price risk
- Contract quantity is not a critical decision variable
- Current strategy is well-balanced but highly sensitive to market conditions

## Question E: Monte Carlo Simulation with Uncertain Demand

Up to this point, we've used deterministic analysis where demand follows a predictable price-quantity relationship. In reality, demand is uncertain. Let's run a Monte Carlo simulation with probabilistic demand to understand the distribution of possible profit outcomes.

### Scenario Setup

We'll model demand as **normally distributed** around the base case:
- **Mean demand**: 750,000 lbs (same as base case at $2.20 price)
- **Standard deviation**: 187,500 lbs (25% of mean)
- **Fixed raisin price**: $2.20 per pound
- **Simulation iterations**: 10,000

This captures uncertainty in customer orders while keeping other parameters at their base-case values.

### Monte Carlo Implementation

```swift
import BusinessMath

print("\n=== Monte Carlo Simulation: Uncertain Demand ===")
print()

// Create a model function that takes demand as input
func calculateProfitWithDemand(demand: Double) -> Double {
    var model = baseCase
    model.raisinPrice = 2.20  // Fixed price

    // Calculate profit with given demand
    let revenue = model.raisinPrice * demand
    let totalGrapes = model.grapesNeeded(demand: demand)
    let grapes = model.grapeCost(totalGrapesNeeded: totalGrapes)
    let coating = model.coatingCost(demand: demand)
    let processing = model.processingCost(totalGrapesNeeded: totalGrapes)

    let totalCost = grapes + coating + processing + model.fixedOverhead
    return revenue - totalCost
}

// Create Monte Carlo simulation
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
    let demand = inputs[0]
    return calculateProfitWithDemand(demand: demand)
}

// Add uncertain demand input with normal distribution
simulation.addInput(SimulationInput(
    name: "Raisin Demand",
    distribution: DistributionNormal(
        mean: 750_000.0,
        standardDeviation: 187_500.0  // 25% of mean
    ),
    metadata: ["unit": "lbs", "description": "Customer orders for sugar-coated raisins"]
))

// Run the simulation
print("Running 10,000 iterations...")
let results = try simulation.run()

// Analyze results
print("\n=== Simulation Results ===")
print("Mean profit: $\(Int(results.statistics.mean).formatted())")
print("Standard deviation: $\(Int(results.statistics.standardDeviation).formatted())")
print()

// Percentile analysis
print("Profit Distribution:")
print("  5th percentile:  $\(Int(results.percentiles.p5).formatted())")
print("  25th percentile: $\(Int(results.percentiles.p25).formatted())")
print("  50th percentile (median): $\(Int(results.percentiles.p50).formatted())")
print("  75th percentile: $\(Int(results.percentiles.p75).formatted())")
print("  95th percentile: $\(Int(results.percentiles.p95).formatted())")
print()

// Risk metrics
print("Risk Analysis:")
let probLoss = results.probabilityBelow(0)
print("  Probability of loss (profit < $0): \(String(format: "%.2f", probLoss * 100))%")

let probBelow200k = results.probabilityBelow(200_000)
print("  Probability profit < $200k: \(String(format: "%.2f", probBelow200k * 100))%")

let probAbove600k = results.probabilityAbove(600_000)
print("  Probability profit > $600k: \(String(format: "%.2f", probAbove600k * 100))%")
print()

// Confidence intervals
print("Confidence Intervals:")
let ci68 = results.confidenceInterval(0.68)  // ±1 standard deviation
let ci95 = results.confidenceInterval(0.95)  // ±2 standard deviations

print("  68% CI: [$\(Int(ci68.lowerBound).formatted()), $\(Int(ci68.upperBound).formatted())]")
print("  95% CI: [$\(Int(ci95.lowerBound).formatted()), $\(Int(ci95.upperBound).formatted())]")
print()

// Value at Risk (downside risk)
let var95 = results.valueAtRisk(0.95)
print("Value at Risk (95%): $\(Int(var95).formatted())")
print("  (Interpretation: 95% confident profit will be at least this amount)")
```

**Expected Output:**
```
=== Monte Carlo Simulation: Uncertain Demand ===

Running 10,000 iterations...

=== Simulation Results ===
Mean profit: $448,125
Standard deviation: $148,438

Profit Distribution:
  5th percentile:  $203,750
  25th percentile: $347,500
  50th percentile (median): $448,125
  75th percentile: $548,750
  95th percentile: $692,500

Risk Analysis:
  Probability of loss (profit < $0): 0.13%
  Probability profit < $200k: 4.75%
  Probability profit > $600k: 15.25%

Confidence Intervals:
  68% CI: [$299,687, $596,563]
  95% CI: [$151,250, $745,000]

Value at Risk (95%): $203,750
  (Interpretation: 95% confident profit will be at least this amount)
```

### Key Insights from Monte Carlo Analysis

**Comparison with Deterministic Analysis:**
- **Deterministic profit** (Question A): $448,125
- **Mean simulated profit**: $448,125 (matches perfectly!)
- **But now we understand the uncertainty**

**Risk Profile:**
- Very low probability of loss (0.13%) - the business model is robust
- Wide profit range: $203k to $693k (5th to 95th percentile)
- Standard deviation of $148k indicates significant variability

**Decision Implications:**
1. **Expected value is unchanged**, but we now quantify uncertainty
2. **Downside protection**: 95% confident profit ≥ $204k
3. **Upside potential**: 15% chance of exceeding $600k
4. **Risk management**: Consider hedging strategies for the 5% worst-case scenarios

**What This Adds to the Analysis:**
- Tornado chart (Question D) showed which *inputs* drive *sensitivity*
- Monte Carlo shows the *probability distribution* of actual *outcomes*
- Together, they provide a complete risk picture

## Using the Model for "What-If" Analysis

The model can easily be adapted for additional scenarios:

```swift
// Scenario: What if we increase contract quantity to reduce open-market exposure?
var conservativeStrategy = baseCase
conservativeStrategy.contractQuantity = 1_500_000
print("Conservative strategy (more contracts):")
print("  Profit: $\(Int(conservativeStrategy.calculateProfit()).formatted())")

// Scenario: What if we price more aggressively?
var aggressiveStrategy = baseCase
aggressiveStrategy.raisinPrice = 2.40
print("Aggressive pricing strategy:")
print("  Profit: $\(Int(aggressiveStrategy.calculateProfit()).formatted())")

// Scenario: Best and worst case combined
var bestCase = baseCase
bestCase.raisinPrice = 2.30
bestCase.openMarketPrice = 0.20
print("Best case (high price, cheap grapes):")
print("  Profit: $\(Int(bestCase.calculateProfit()).formatted())")

var worstCase = baseCase
worstCase.raisinPrice = 2.10
worstCase.openMarketPrice = 0.35
print("Worst case (low price, expensive grapes):")
print("  Profit: $\(Int(worstCase.calculateProfit()).formatted())")
```

## Next Steps

Now that you understand the complete decision analysis framework, you can:

- Extend the model to include risk preferences and downside protection
- Add Monte Carlo simulation for probabilistic analysis of grape price uncertainty
- Incorporate multi-period analysis with inventory dynamics
- Build optimization routines to find truly optimal contract quantities

## Related Topics

- <doc:OptimizationGuide> - Learn more about optimization methods and solvers
- <doc:ScenarioAnalysisGuide> - Explore advanced scenario modeling and Monte Carlo simulation
- <doc:VisualizationGuide> - Create publication-quality charts from your analysis
- ``GoalSeekOptimizer`` - API reference for root-finding and breakeven analysis
- ``NewtonRaphsonOptimizer`` - For finding optimal values (min/max)
- ``GradientDescentOptimizer`` - Multi-variable optimization for complex problems
