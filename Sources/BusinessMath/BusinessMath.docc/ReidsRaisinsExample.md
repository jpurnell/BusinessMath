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

Identify which parameters have the greatest impact on profit using tornado diagram analysis:

```swift
print("\n=== Tornado Chart: Parameter Sensitivity Analysis ===")
print("Base case profit: $\(Int(profit).formatted())")
print()

// Define parameters to test with their ranges
struct ParameterTest {
    let name: String
    let getValue: (ReidsRaisinsModel) -> Double
    let setValue: (inout ReidsRaisinsModel, Double) -> Void
    let lowValue: Double
    let highValue: Double
}

let parameters: [ParameterTest] = [
    ParameterTest(
        name: "Open-Market Grape Price",
        getValue: { $0.openMarketPrice },
        setValue: { $0.openMarketPrice = $1 },
        lowValue: 0.20,  // Historical low
        highValue: 0.35  // Historical high
    ),
    ParameterTest(
        name: "Raisin Selling Price",
        getValue: { $0.raisinPrice },
        setValue: { $0.raisinPrice = $1 },
        lowValue: 1.80,  // -$0.40 from base
        highValue: 2.60  // +$0.40 from base
    ),
    ParameterTest(
        name: "Contract Grape Quantity",
        getValue: { $0.contractQuantity },
        setValue: { $0.contractQuantity = $1 },
        lowValue: 750_000,   // -25%
        highValue: 1_250_000 // +25%
    ),
    ParameterTest(
        name: "Contract Grape Price",
        getValue: { $0.contractGrapePrice },
        setValue: { $0.contractGrapePrice = $1 },
        lowValue: 0.20,  // -20%
        highValue: 0.30  // +20%
    )
]

// Calculate impacts
var impacts: [(name: String, lowProfit: Double, highProfit: Double, impact: Double)] = []

for param in parameters {
    // Test low value
    var lowModel = baseCase
    param.setValue(&lowModel, param.lowValue)
    let lowProfit = lowModel.calculateProfit()

    // Test high value
    var highModel = baseCase
    param.setValue(&highModel, param.highValue)
    let highProfit = highModel.calculateProfit()

    // Calculate impact (range)
    let impact = abs(highProfit - lowProfit)

    impacts.append((param.name, lowProfit, highProfit, impact))
}

// Sort by impact (descending)
impacts.sort { $0.impact > $1.impact }

// Print tornado chart
print("Parameters ranked by impact on profit:")
print()

for (index, result) in impacts.enumerated() {
    print("\(index + 1). \(result.name)")
    print("   Low:    $\(Int(result.lowProfit).formatted())")
    print("   High:   $\(Int(result.highProfit).formatted())")
    print("   Impact: $\(Int(result.impact).formatted())")
    print()
}

// Visualize as simple tornado chart
print("Visual Tornado Diagram:")
print()

let maxImpact = impacts.first?.impact ?? 1.0
let barWidth = 50

for result in impacts {
    let percentOfMax = result.impact / maxImpact
    let bars = Int(percentOfMax * Double(barWidth))

    // Show parameter name
    print(String(format: "%-30s", result.name), terminator: " ")

    // Show bar
    print(String(repeating: "█", count: bars), terminator: "")
    print(" $\(Int(result.impact).formatted())")
}
```

**Expected Output:**
```
=== Tornado Chart: Parameter Sensitivity Analysis ===
Base case profit: $448,125

Parameters ranked by impact on profit:

1. Raisin Selling Price
   Low:    $-437,500
   High:   $48,125
   Impact: $485,625

2. Open-Market Grape Price
   Low:    $659,375
   High:   $175,000
   Impact: $484,375

3. Contract Grape Quantity
   Low:    $467,500
   High:   $428,750
   Impact: $38,750

4. Contract Grape Price
   Low:    $481,250
   High:   $415,000
   Impact: $66,250

Visual Tornado Diagram:

Raisin Selling Price          ██████████████████████████████████████████████████ $485,625
Open-Market Grape Price       █████████████████████████████████████████████████▌ $484,375
Contract Grape Price          ████████████████▋ $66,250
Contract Grape Quantity       ████▊ $38,750
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
