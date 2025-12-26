import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

struct ReidsRaisinsModel {
	// MARK: - Input Parameters

	/// Contract grape price ($/lb)
	var contractGrapePrice: Double = 0.25

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

extension ReidsRaisinsModel {
	/// Calculate demand for sugar-coated raisins given a price
	/// Demand = baseDemand + sensitivity × (basePrice - price) × 100
	func calculateDemand(price: Double) -> Double {
		let priceDifferenceInCents = (basePrice - price) * 100
		let demandChange = demandSensitivity * priceDifferenceInCents
		return baseDemand + demandChange
	}
}

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

//	## Question A: Base-Case Profit Analysis
//
//	Calculate profit under Mary Jo's suggested base-case assumptions:
//	- Contract purchase: 1,000,000 pounds at $0.25
//	- Selling price: $2.20 per pound
//	- Expected open-market price: $0.30 per pound

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

//	## Question B: Breakeven Analysis
//
//	Find the open-market grape price where profit equals zero using Goal Seek optimization:

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
		initialValue: 0.30,    // Start from base-case price
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


//## Question C: Sensitivity Table - Profit vs Raisin Price
//
//Construct a table showing how profit varies with raisin pricing from $1.80 to $2.80:

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


//## Question D: Tornado Chart Analysis
//
//Identify which parameters have the greatest impact on profit using tornado diagram analysis. Following standard practice, we'll vary each parameter by **±10% from its base-case value**.

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

//	## Question E: Monte Carlo Simulation with Uncertain Demand
//
//	Up to this point, we've used deterministic analysis where demand follows a predictable price-quantity relationship. In reality, demand is uncertain. Let's run a Monte Carlo simulation with probabilistic demand to understand the distribution of possible profit outcomes.
//
//	### Scenario Setup
//
//	We'll model demand as **normally distributed** around the base case:
//	- **Mean demand**: 750,000 lbs (same as base case at $2.20 price)
//	- **Standard deviation**: 187,500 lbs (25% of mean)
//	- **Fixed raisin price**: $2.20 per pound
//	- **Simulation iterations**: 10,000
//
//	This captures uncertainty in customer orders while keeping other parameters at their base-case values.
//
//	### Monte Carlo Implementation

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


//	## Using the Model for "What-If" Analysis
//
//	The model can easily be adapted for additional scenarios:

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
