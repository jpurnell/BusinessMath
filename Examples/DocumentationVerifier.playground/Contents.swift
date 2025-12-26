import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	/// Reid's Raisin Company profit model
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

	// Create base-case model
var baseCase = ReidsRaisinsModel(
	contractQuantity: 1_000_000,
	raisinPrice: 2.20,
	openMarketPrice: 0.30
)

print("\n=== Sensitivity Analysis: Raisin Price vs Profit ===")
print("Open-market grape price held constant at \(baseCase.openMarketPrice.currency())")
print()

// Define price range
let minPrice = 1.80
let maxPrice = 2.80
let step = 0.10
let prices = stride(from: minPrice, through: maxPrice, by: step)

// MARK: - Question D

print("\n=== Tornado Chart: Parameter Sensitivity Analysis ===")
print("Using ±10% variation for all parameters")
print()

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

let profit = baseCase.calculateProfit()

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


// MARK: - Question E

print("\n=== Monte Carlo Simulation: Uncertain Demand ===")
print()

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
let results = try simulation.run()

// Analyze results
print("\n=== Simulation Results ===")
print("Mean profit: \(results.statistics.mean.currency())")
print("Standard deviation: \(results.statistics.stdDev.currency())")
print()

// Percentile analysis
print("Profit Distribution:")
print("  5th percentile:  \(results.percentiles.p5.currency())")
print("  25th percentile: \(results.percentiles.p25.currency())")
print("  50th percentile (median): \(results.percentiles.p50.currency())")
print("  75th percentile: \(results.percentiles.p75.currency())")
print("  95th percentile: \(results.percentiles.p95.currency())")
print()

// Risk metrics
print("Risk Analysis:")
let probLoss = results.probabilityBelow(0)
print("  Probability of loss (profit < $0): \(probLoss.percent())")

let probBelow200k = results.probabilityBelow(200_000)
print("  Probability profit < $200k: \(probBelow200k.percent())")

let probAbove600k = results.probabilityAbove(600_000)
print("  Probability profit > $600k: \(probAbove600k.percent())")
print()

// Confidence intervals
print("Confidence Intervals:")
let ci68 = results.confidenceInterval(level: 0.68)  // ±1 standard deviation
let ci95 = results.confidenceInterval(level: 0.95)  // ±2 standard deviations

print("  68% CI: [\(ci68.low.currency()), \(ci68.high.currency())]")
print("  95% CI: [\(ci95.low.currency()), \(ci95.high.currency())]")
print()

// Value at Risk (downside risk)
let var95 = results.valueAtRisk(confidenceLevel: 0.95)
print("Value at Risk (95%): \(var95.currency())")
print("  (Interpretation: 95% confident profit will be at least this amount)")


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
