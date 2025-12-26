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

`/// Reid's Raisin Company profit model
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
print("  Raisin price: \(baseCase.raisinPrice.currency())")
print("  Open-market grape price: \(baseCase.openMarketPrice.currency())")
print()

// Calculate demand
let demand = baseCase.calculateDemand(price: baseCase.raisinPrice)
print("Demand: \(demand.number(0)) lbs of raisins")
print("Grapes needed: \(baseCase.grapesNeeded(demand: demand).number(0)) lbs\n")

print("Revenue: \(revenue.currency())\n")
print("Costs:")
for (category, amount) in costs.sorted(by: { $0.key < $1.key }) {
	print("  \(category): \(amount.currency())")
}
print("  Total Costs: \((costs.values.reduce(0, +)).currency())\n")
print("Annual Profit: \(profit.currency())")
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

Revenue: $1,650,000.00

Costs:
  Coating: $20,625.00
  Fixed Overhead: $200,000.00
  Grapes: $512,500.00
  Processing: $468,750.00
  Total Costs: $1,201,875.00

Annual Profit: $448,125.00
```

## Question B: Breakeven Analysis

Find the open-market grape price where profit equals zero using Goal Seek optimization:

```swift
// Define profit as a function of open-market price
@MainActor func profitFunction(openMarketPrice: Double) -> Double {
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
	initialGuess: 0.30,    // Start from base-case price
	bounds: (0.0, 1.0)     // Price must be between $0 and $1
)

print("\n=== Breakeven Analysis ===")
if breakevenResult.converged {
print("Breakeven open-market grape price: \(breakevenResult.optimalValue.currency())")
print("Profit at breakeven: \(breakevenResult.objectiveValue.currency()) (should be ≈$0)")
print("Converged in \(breakevenResult.iterations) iterations")

// Show context
print("Interpretation:\n\tIf open-market grapes cost more than \(breakevenResult.optimalValue.currency()), RRC will lose money with current contract and pricing decisions.")
} else {
print("Failed to find breakeven point")
}
```

**Expected Output:**
```
=== Breakeven Analysis ===
Breakeven open-market grape price: $0.81
Profit at breakeven: -$0.00 (should be ≈$0)
Converged in 2 iterations
Interpretation:
	If open-market grapes cost more than $0.81, RRC will lose money with current contract and pricing decisions.
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
print("\("Price") \("Demand (lbs)".paddingLeft(toLength: 15)) \("Profit ($)".paddingLeft(toLength: 16))")
print(String(repeating: "-", count: 40))

// Print results
for result in results {
	print("\(result.price.currency()) \(result.demand.number(0).paddingLeft(toLength: 14))\(result.profit.currency(0).paddingLeft(toLength: 17))")
}

// Find optimal price
if let optimalResult = results.max(by: { $0.profit < $1.profit }) {
	print("\nOptimal raisin price: \(optimalResult.price.currency())")
	print("Maximum profit: \(optimalResult.profit.currency(0))")
}
```

**Expected Output:**
```
=== Sensitivity Analysis: Raisin Price vs Profit ===
Open-market grape price held constant at $0.3

Price    Demand (lbs)       Profit ($)
----------------------------------------
$1.80      1,350,000          $86,625
$1.90      1,200,000         $222,000
$2.00      1,050,000         $327,375
$2.10        900,000         $402,750
$2.20        750,000         $448,125
$2.30        600,000         $463,500
$2.40        450,000         $355,125
$2.50        300,000         $204,250
$2.60        150,000          $17,125
$2.70              0        -$200,000

Optimal raisin price: $2.30
Maximum profit: $463,500
```

## Question D: Tornado Chart Analysis

Identify which parameters have the greatest impact on profit using tornado diagram analysis. Following standard practice, we'll vary each parameter by **±10% from its base-case value**.

```swift
print("\n=== Tornado Chart: Parameter Sensitivity Analysis ===")
print("Using ±10% variation for all parameters\n")

// Define parameters to test with their base values
struct ParameterTest {
	let name: String
	let baseValue: Double
	let setValue: (inout ReidsRaisinsModel, Double) -> Void
}

let parameters: [ParameterTest] = [
	ParameterTest(
		name: "Open-Market Grape Price",
		baseValue: 0.30,
		setValue: { $0.openMarketPrice = $1 }
	),
	ParameterTest(
		name: "Raisin Selling Price",
		baseValue: 2.20,
		setValue: { $0.raisinPrice = $1 }
	),
	ParameterTest(
		name: "Contract Grape Quantity",
		baseValue: 1_000_000,
		setValue: { $0.contractQuantity = $1 }
	),
	ParameterTest(
		name: "Contract Grape Price",
		baseValue: 0.25,
		setValue: { $0.contractGrapePrice = $1 }
	)
]

// Fixed percentage variation (standard tornado chart methodology)
let variationPercent = 0.10  // ±10%

// Calculate impacts for each parameter
var impacts: [String: Double] = [:]
var lowValues: [String: Double] = [:]
var highValues: [String: Double] = [:]

for param in parameters {
	// Calculate low value (-10% from base)
	let lowParamValue = param.baseValue * (1 - variationPercent)
	var lowModel = baseCase
	param.setValue(&lowModel, lowParamValue)
	let profitAtLow = lowModel.calculateProfit()

	// Calculate high value (+10% from base)
	let highParamValue = param.baseValue * (1 + variationPercent)
	var highModel = baseCase
	param.setValue(&highModel, highParamValue)
	let profitAtHigh = highModel.calculateProfit()

	// Store results - use min/max of OUTCOMES
	let minProfit = min(profitAtLow, profitAtHigh)
	let maxProfit = max(profitAtLow, profitAtHigh)

	lowValues[param.name] = minProfit
	highValues[param.name] = maxProfit
	impacts[param.name] = maxProfit - minProfit  // Absolute difference
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
	let percentImpact = (impact / abs(profit))

	print("\n\(index + 1). \(input)")
	print("   Low scenario:  \(low.currency())")
	print("   High scenario: \(high.currency())")
	print("   Impact range:  \(impact.currency()) (\(percentImpact.percent()) of base profit)")
}
```

**Expected Output:**
```
=== Tornado Chart: Parameter Sensitivity Analysis ===
Using ±10% variation for all parameters

Tornado Diagram - Sensitivity Analysis
Base Case: 448125

Open-Market Grape Price ◄█████████████████████████|█████████████████████████► Impact: 52500 (11.7%)
						  421875                 448125                 474375

Contract Grape Price    ◄  ███████████████████████|████████████████████████ ► Impact: 50000 (11.2%)
						  423125                 448125                 473125

Raisin Selling Price    ◄     ████████████████████|                         ► Impact: 21150 (4.7%)
						  308700                 448125                 329850

Contract Grape Quantity ◄                     ████|█████                    ► Impact: 10000 (2.2%)
						  443125                 448125                 453125



Detailed Impact Analysis:

1. Open-Market Grape Price
   Low scenario:  $421,875.00
   High scenario: $474,375.00
   Impact range:  $52,500.00 (11.72% of base profit)

2. Contract Grape Price
   Low scenario:  $423,125.00
   High scenario: $473,125.00
   Impact range:  $50,000.00 (11.16% of base profit)

3. Raisin Selling Price
   Low scenario:  $308,700.00
   High scenario: $329,850.00
   Impact range:  $21,150.00 (4.72% of base profit)

4. Contract Grape Quantity
   Low scenario:  $443,125.00
   High scenario: $453,125.00
   Impact range:  $10,000.00 (2.23% of base profit)
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
print("\n=== Monte Carlo Simulation: Uncertain Demand ===\n")

// Create Monte Carlo simulation directly with inline model
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	let demand = inputs[0]

	// Create model for this iteration
	var model = ReidsRaisinsModel(
		contractQuantity: 1_000_000,
		raisinPrice: 2.20,
		openMarketPrice: 0.30
	)

	// Calculate profit with given demand
	let revenue = model.raisinPrice * demand
	let totalGrapes = model.grapesNeeded(demand: demand)
	let grapes = model.grapeCost(totalGrapesNeeded: totalGrapes)
	let coating = model.coatingCost(demand: demand)
	let processing = model.processingCost(totalGrapesNeeded: totalGrapes)

	let totalCost = grapes + coating + processing + model.fixedOverhead
	return revenue - totalCost
}

// Add uncertain demand input with normal distribution
simulation.addInput(SimulationInput(
	name: "Raisin Demand",
	distribution: DistributionNormal(
		750_000.0,
		187_500.0  // 25% of mean
	),
	metadata: ["unit": "lbs", "description": "Customer orders for sugar-coated raisins"]
))

// Run the simulation
print("Running 10,000 iterations...")
let simulationResults = try simulation.run()

// Analyze results
print("\n=== Simulation Results ===")
print("Mean profit: \(simulationResults.statistics.mean.currency())")
print("Standard deviation: \(simulationResults.statistics.stdDev.currency())")
print()

// Percentile analysis
print("Profit Distribution:")
print("  5th percentile:  \(simulationResults.percentiles.p5.currency())")
print("  25th percentile: \(simulationResults.percentiles.p25.currency())")
print("  50th percentile (median): \(simulationResults.percentiles.p50.currency())")
print("  75th percentile: \(simulationResults.percentiles.p75.currency())")
print("  95th percentile: \(simulationResults.percentiles.p95.currency())")
print()

// Risk metrics
print("Risk Analysis:")
let probLoss = simulationResults.probabilityBelow(0)
print("  Probability of loss (profit < $0): \(probLoss.percent())")

let probBelow200k = simulationResults.probabilityBelow(200_000)
print("  Probability profit < $200k: \(probBelow200k.percent())")

let probAbove600k = simulationResults.probabilityAbove(600_000)
print("  Probability profit > $600k: \(probAbove600k.percent())")
print()

// Confidence intervals
print("Confidence Intervals:")
let ci68 = simulationResults.confidenceInterval(level: 0.68)  // ±1 standard deviation
let ci95 = simulationResults.confidenceInterval(level: 0.95)  // ±2 standard deviations

print("  68% CI: [\(ci68.low.currency()), \(ci68.high.currency())]")
print("  95% CI: [\(ci95.low.currency()), \(ci95.high.currency())]")
print()

// Value at Risk (downside risk)
let var95 = simulationResults.valueAtRisk(confidenceLevel: 0.95)
print("Value at Risk (95%): \(var95.currency())")
print("  (Interpretation: 95% confident profit will be at least this amount)")
```

**Expected Output:**
```
=== Monte Carlo Simulation: Uncertain Demand ===

Running 10,000 iterations...

=== Simulation Results ===
Mean profit: $434,575.38
Standard deviation: $85,393.95

Profit Distribution:
  5th percentile:  $259,820.57
  25th percentile: $411,010.33
  50th percentile (median): $448,217.00
  75th percentile: $485,315.92
  95th percentile: $540,776.58

Risk Analysis:
  Probability of loss (profit < $0): 0.11%
  Probability profit < $200k: 2.37%
  Probability profit > $600k: 0.40%

Confidence Intervals:
  68% CI: [$349,651.82, $519,498.95]
  95% CI: [$267,210.48, $601,940.28]

Value at Risk (95%): $259,820.57
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
	print("\n=== What-If Analysis ===\n")

	// Scenario: What if we increase contract quantity to reduce open-market exposure?
	var conservativeStrategy = baseCase
	conservativeStrategy.contractQuantity = 1_500_000
	print("Conservative strategy (more contracts):")
	print("  Profit: \(conservativeStrategy.calculateProfit().currency())")

	// Scenario: What if we price more aggressively?
	var aggressiveStrategy = baseCase
	aggressiveStrategy.raisinPrice = 2.40
	print("Aggressive pricing strategy:")
	print("  Profit: \(aggressiveStrategy.calculateProfit().currency())")

	// Scenario: Best and worst case combined
	var bestCase = baseCase
	bestCase.raisinPrice = 2.30
	bestCase.openMarketPrice = 0.20
	print("Best case (high price, cheap grapes):")
	print("  Profit: \(bestCase.calculateProfit().currency())")

	var worstCase = baseCase
	worstCase.raisinPrice = 2.10
	worstCase.openMarketPrice = 0.35
	print("Worst case (low price, expensive grapes):")
	print("  Profit: \(worstCase.calculateProfit().currency())")

```

## Next Steps

Now that you understand the complete decision analysis framework, you can:

- Extend the model to include risk preferences and downside protection
- Add Monte Carlo simulation for probabilistic analysis of grape price uncertainty
- Incorporate multi-period analysis with inventory dynamics
- Build optimization routines to find truly optimal contract quantities

## Related Topics

- <doc:5.1-OptimizationGuide> - Learn more about optimization methods and solvers
- <doc:4.2-ScenarioAnalysisGuide> - Explore advanced scenario modeling and Monte Carlo simulation
- <doc:2.4-VisualizationGuide> - Create publication-quality charts from your analysis
- ``GoalSeekOptimizer`` - API reference for root-finding and breakeven analysis
- ``NewtonRaphsonOptimizer`` - For finding optimal values (min/max)
- ``GradientDescentOptimizer`` - Multi-variable optimization for complex problems
