import Cocoa
import Foundation
@testable import BusinessMath

///REID's RAISIN COMPANY
//Located in wine country, Reid’s Raisin Company (RRC) is a food-processing firm that purchases surplus grapes from grape growers, dries them into raisins, applies a layer of sugar, and sells the sugar-coated raisins to major cereal and candy companies. At the beginning of the grape-growing season, RRC has two decisions to make. The first involves how many grapes to buy under contract, and the second involves how much to charge for the sugar-coated raisins it sells.
//
//In the spring, RRC typically contracts with a grower who will supply a given amount of grapes in the autumn at a fixed cost of $0.25 per pound. The balance between RRC’s grape requirements and those supplied by the grower must be purchased in the autumn, on the open market, at a price that could vary from a historical low of $0.20 per pound to a high of $0.35 per pound. (RRC cannot, however, sell grapes on the open market in the autumn if it has a surplus in inventory, because it has no distribution system for such purposes.)
//
//The other major decision facing RRC is the price to charge for sugar-coated raisins. RRC has several customer who buy RRC’s output in price-dependent quantities. RRC negotiates with these processors as a group to arrive at a price for the sugar-coated raisins and the quantity to be bought at that price. The negotiations take place in the spring, long before the open market price of grapes is known.
//
//Based on prior years’ experience, Mary Jo Reid, RRC’s general manager, believes that if RRC prices the sugar- coated raisins at $2.20 per pound, the processors’ orders will total 750,000 pounds of sugar-coated raisins. Furthermore, this total will increase by 15,000 pounds for each penny reduction in sugar-coated raisin price below $2.20. The same relationship holds in the other direction: demand will drop by 15,000 for each penny increase. The price of $2.20 is a tentative starting point in the negotiations.
//
//Sugar-coated raisins are made by washing and drying grapes into raisins, followed by spraying the raisins with a sugar coating that RRC buys for $0.55 per pound. It takes 2.5 pounds of grapes plus 0.05 pound of coating to make one pound of sugar-coated raisins, the balance being water that evaporates during grape drying. In addition to the raw materials cost for the grapes and the coating, RRC’s proces- sing plant incurs a variable cost of $0.20 to process one pound of grapes into raisins, up to its capacity of 1,500,000 pounds of grapes. For volumes above 1,500,000 pounds of grapes, RRC outsources grape processing to another food processor, which charges RRC $0.45 per pound. This price includes just the processing cost, as RRC supplies both the grapes and the coating required. RRC also incurs fixed (overhead) costs in its grape-processing plant of $200,000 per year.
//
//Mary Jo has asked you to analyze the situation in order to guide her in the upcoming negotiations. Her goal is to examine the effect of various ‘‘What-if?’’ scenarios on RRC’s profits. As a basis for the analysis, she suggests using a contract purchase price of $0.25, with a supply quantity of 1 million pounds from the grower, along with a selling price of $2.20 for sugar-coated raisins. She is primarily interested in evaluating annual pretax profit as a function of the selling price and the open-market grape price. She believes that the open-market grape price is most likely to be $0.30.
	
	/// Reid's Raisin Company profit model
/// Complete example from the case study tutorial
struct ReidsRaisinsModel: Sendable {
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

	// MARK: - Calculations

	/// Calculate demand for sugar-coated raisins given a price
	func calculateDemand(price: Double) -> Double {
		let priceDifferenceInCents = (basePrice - price) * 100
		let demandChange = demandSensitivity * priceDifferenceInCents
		return baseDemand + demandChange
	}

	/// Calculate total grapes needed for production
	func grapesNeeded(demand: Double) -> Double {
		return demand * grapesPerPound
	}

	/// Calculate grape procurement costs
	func grapeCost(totalGrapesNeeded: Double) -> Double {
		let contractCost = min(contractQuantity, totalGrapesNeeded) * contractGrapePrice
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

	/// Calculate annual profit given current parameters
	func calculateProfit() -> Double {
		let demand = calculateDemand(price: raisinPrice)
		let revenue = raisinPrice * demand

		let totalGrapes = grapesNeeded(demand: demand)
		let grapes = grapeCost(totalGrapesNeeded: totalGrapes)
		let coating = coatingCost(demand: demand)
		let processing = processingCost(totalGrapesNeeded: totalGrapes)

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

// MARK: - Demo Execution

func runReidsRaisinsDemo() throws {
	print("=== Reid's Raisins Complete Case Study Demo ===\n")

	// Create base-case model
	var baseCase = ReidsRaisinsModel(
		contractQuantity: 1_000_000,
		raisinPrice: 2.20,
		openMarketPrice: 0.30
	)

	// Question A: Base-Case Analysis
	print("QUESTION A: Base-Case Profit Analysis")
	print(String(repeating: "=", count: 60))

	let (revenue, costs, profit) = baseCase.profitBreakdown()
	let demand = baseCase.calculateDemand(price: baseCase.raisinPrice)
	let grapesNeeded = baseCase.grapesNeeded(demand: demand)

	print("Assumptions:")
	print("  Contract grapes: 1,000,000 lbs @ $0.25")
	print("  Raisin price: \(baseCase.raisinPrice.currency())")
	print("  Open-market grape price: \(baseCase.openMarketPrice.currency())")
	print()
	print("Results:")
	print("  Demand: \(Int(demand).formatted()) lbs of raisins")
	print("  Grapes needed: \(Int(grapesNeeded).formatted()) lbs")
	print("  Revenue: \(revenue.currency(0))")
	print("  Total Costs: \(costs.values.reduce(0, +).currency(0))")
	print("  Annual Profit: \(profit.currency(0))")
	print()

	// Question B: Breakeven Analysis
	print("\nQUESTION B: Breakeven Open-Market Grape Price")
	print(String(repeating: "=", count: 60))

	func profitFunction(openMarketPrice: Double) -> Double {
		var model = baseCase
		model.openMarketPrice = openMarketPrice
		return model.calculateProfit()
	}

	let optimizer = GoalSeekOptimizer(
		target: 0.0,
		tolerance: 0.0001,
		maxIterations: 1000,
		stepSize: 0.001
	)
	
	let breakevenResult = optimizer.optimize(
		objective: profitFunction,
		constraints: [],
		initialValue: 0.30,
		bounds: nil
	)

	print("Breakeven open-market grape price: \(breakevenResult.optimalValue.currency())")

	var breakevenModel = baseCase
	breakevenModel.openMarketPrice = breakevenResult.optimalValue
	let breakevenProfit = breakevenModel.calculateProfit()
	print("Profit at breakeven: \(breakevenProfit.currency(0))")
	print()

	// Question C: Sensitivity Table
	print("\nQUESTION C: Profit vs Raisin Price Sensitivity")
	print(String(repeating: "=", count: 60))

	let minPrice = 1.80
	let maxPrice = 3.60
	let step = 0.10
	let prices = stride(from: minPrice, through: maxPrice, by: step)

	var results: [(price: Double, demand: Double, profit: Double)] = []

	for price in prices {
		var model = baseCase
		model.raisinPrice = price
		let demand = model.calculateDemand(price: price)
		let profit = model.calculateProfit()
		results.append((price, demand, profit))
	}

	print("\("Price".padding(toLength: 8, withPad: " ", startingAt: 0))  \("Demand (lbs)".paddingLeft(toLength: 12, withPad: " ")) \("Profit ($)".paddingLeft(toLength: 15, withPad: " "))")
	print(String(repeating: "-", count: 40))

	for result in results {
		print("\(result.price.currency())  \(result.demand.formatted(.number.precision(.fractionLength(0))).paddingLeft(toLength: 15))  \(result.profit.currency(0).paddingLeft(toLength: 14))")
	}

	if let optimalResult = results.max(by: { $0.profit < $1.profit }) {
		print()
		print("Optimal raisin price: \(optimalResult.price.currency())")
		print("Maximum profit: \(optimalResult.profit.currency(0))")
	}
	print()

	// Question D: Tornado Chart
	print("\nQUESTION D: Tornado Chart Analysis")
	print("Using ±10% variation for all parameters")
	print(String(repeating: "=", count: 60))

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

	// Print detailed breakdown
	print("\nDetailed Impact Analysis:")
	for (index, input) in tornadoAnalysis.inputs.enumerated() {
		let impact = tornadoAnalysis.impacts[input]!
		let low = tornadoAnalysis.lowValues[input]!
		let high = tornadoAnalysis.highValues[input]!
		let percentImpact = (impact / abs(profit))

		print("\n\(index + 1). \(input)")
		print("   Low scenario:  \(low.currency(0))")
		print("   High scenario: \(high.currency(0))")
		print("   Impact range:  \(impact.currency(0)) (\(percentImpact.percent())% of base profit)")
	}

	// Question E: Monte Carlo Simulation
	print("\nQUESTION E: Monte Carlo Simulation with Uncertain Demand")
	print(String(repeating: "*", count: 60))

	// Create Monte Carlo simulation
	// Capture the base case model for use in the closure
	let modelForSimulation = baseCase
	var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
		let demand = inputs[0]
		var model = modelForSimulation
		model.raisinPrice = 2.20  // Fixed price

		let revenue = model.raisinPrice * demand
		let totalGrapes = model.grapesNeeded(demand: demand)
		let grapes = model.grapeCost(totalGrapesNeeded: totalGrapes)
		let coating = model.coatingCost(demand: demand)
		let processing = model.processingCost(totalGrapesNeeded: totalGrapes)

		let totalCost = grapes + coating + processing + model.fixedOverhead
		return revenue - totalCost
	}

	// Add uncertain demand input
	simulation.addInput(SimulationInput(
		name: "Raisin Demand",
		distribution: DistributionNormal(750_000.0, 187_500.0),  // Std Dev as 25% of mean
		metadata: ["unit": "lbs", "description": "Customer orders for sugar-coated raisins"]
	))

	print("Running 10,000 Monte Carlo iterations...")
	let monteCarloResults = try simulation.run()

	print("\n=== Simulation Results ===")
	print("Mean profit: \(monteCarloResults.statistics.mean.currency())")
	print("Standard deviation: \(monteCarloResults.statistics.stdDev.currency())")
	print()

	print("Profit Distribution:")
	print("  5th percentile:  \((monteCarloResults.percentiles.p5).currency())")
	print("  25th percentile: \((monteCarloResults.percentiles.p25).currency())")
	print("  50th percentile (median): \((monteCarloResults.percentiles.p50).currency())")
	print("  75th percentile: \((monteCarloResults.percentiles.p75).currency())")
	print("  95th percentile: \((monteCarloResults.percentiles.p95).currency())")
	print()

	print("Risk Analysis:")
	print(monteCarloResults.riskAnalysis([0, 200_000, 600_000]))

	print("Confidence Intervals:")
	let ci68 = monteCarloResults.confidenceInterval(level: 0.68)
	let ci95 = monteCarloResults.confidenceInterval(level: 0.95)
	print("  68% CI: [\((ci68.low).currency()), \((ci68.high).currency())]")
	print("  95% CI: [\((ci95.low).currency()), \((ci95.high).currency())]")
	print()

	let var95 = monteCarloResults.valueAtRisk(confidenceLevel: 0.95)
	print("Value at Risk (95%): \((var95).currency())")

	print("\n" + String(repeating: "*", count: 60))
	print("Demo complete! See ReidsRaisinsExample.md for full tutorial.")
}

// Run the demo if this file is executed directly
do {
	try runReidsRaisinsDemo()
} catch {
	print("Error running demo: \(error)")
}
