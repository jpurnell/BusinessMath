import BusinessMath

/// Reid's Raisin Company profit model
/// Complete example from the case study tutorial
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

func runReidsRaisinsDemo() {
    print("=== Reid's Raisins Complete Case Study Demo ===\n")

    // Create base-case model
    var baseCase = ReidsRaisinsModel(
        contractQuantity: 1_000_000,
        raisinPrice: 2.20,
        openMarketPrice: 0.30
    )

    // Question A: Base-Case Analysis
    print("QUESTION A: Base-Case Profit Analysis")
    print("=" * 50)

    let (revenue, costs, profit) = baseCase.profitBreakdown()
    let demand = baseCase.calculateDemand(price: baseCase.raisinPrice)
    let grapesNeeded = baseCase.grapesNeeded(demand: demand)

    print("Assumptions:")
    print("  Contract grapes: 1,000,000 lbs @ $0.25")
    print("  Raisin price: $\(baseCase.raisinPrice)")
    print("  Open-market grape price: $\(baseCase.openMarketPrice)")
    print()
    print("Results:")
    print("  Demand: \(Int(demand).formatted()) lbs of raisins")
    print("  Grapes needed: \(Int(grapesNeeded).formatted()) lbs")
    print("  Revenue: $\(Int(revenue).formatted())")
    print("  Total Costs: $\(Int(costs.values.reduce(0, +)).formatted())")
    print("  Annual Profit: $\(Int(profit).formatted())")
    print()

    // Question B: Breakeven Analysis
    print("\nQUESTION B: Breakeven Open-Market Grape Price")
    print("=" * 50)

    func profitFunction(openMarketPrice: Double) -> Double {
        var model = baseCase
        model.openMarketPrice = openMarketPrice
        return model.calculateProfit()
    }

    let optimizer = NewtonRaphsonOptimizer<Double>(
        tolerance: 0.0001,
        maxIterations: 100
    )

    let breakevenResult = optimizer.optimize(
        objective: profitFunction,
        initialValue: 0.30
    )

    print("Breakeven open-market grape price: $\(String(format: "%.4f", breakevenResult.optimalValue))")

    var breakevenModel = baseCase
    breakevenModel.openMarketPrice = breakevenResult.optimalValue
    let breakevenProfit = breakevenModel.calculateProfit()
    print("Profit at breakeven: $\(Int(breakevenProfit).formatted())")
    print()

    // Question C: Sensitivity Table
    print("\nQUESTION C: Profit vs Raisin Price Sensitivity")
    print("=" * 50)

    let minPrice = 1.80
    let maxPrice = 2.80
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

    print(String(format: "%8s  %12s  %15s", "Price", "Demand (lbs)", "Profit ($)"))
    print(String(repeating: "-", count: 40))

    for result in results {
        print(String(format: "$%6.2f  %12s  %15s",
                     result.price,
                     Int(result.demand).formatted(),
                     Int(result.profit).formatted()))
    }

    if let optimalResult = results.max(by: { $0.profit < $1.profit }) {
        print()
        print("Optimal raisin price: $\(String(format: "%.2f", optimalResult.price))")
        print("Maximum profit: $\(Int(optimalResult.profit).formatted())")
    }
    print()

    // Question D: Tornado Chart
    print("\nQUESTION D: Tornado Chart Analysis")
    print("=" * 50)

    struct ParameterTest {
        let name: String
        let lowValue: Double
        let highValue: Double
        let evaluate: (inout ReidsRaisinsModel, Double) -> Void
    }

    let parameters: [ParameterTest] = [
        ParameterTest(
            name: "Open-Market Grape Price",
            lowValue: 0.20,
            highValue: 0.35,
            evaluate: { $0.openMarketPrice = $1 }
        ),
        ParameterTest(
            name: "Raisin Selling Price",
            lowValue: 1.80,
            highValue: 2.60,
            evaluate: { $0.raisinPrice = $1 }
        ),
        ParameterTest(
            name: "Contract Grape Quantity",
            lowValue: 750_000,
            highValue: 1_250_000,
            evaluate: { $0.contractQuantity = $1 }
        ),
        ParameterTest(
            name: "Contract Grape Price",
            lowValue: 0.20,
            highValue: 0.30,
            evaluate: { $0.contractGrapePrice = $1 }
        )
    ]

    // Calculate impacts for each parameter
    var impacts: [String: Double] = [:]
    var lowValues: [String: Double] = [:]
    var highValues: [String: Double] = [:]

    for param in parameters {
        var lowModel = baseCase
        param.evaluate(&lowModel, param.lowValue)
        let profitAtLow = lowModel.calculateProfit()

        var highModel = baseCase
        param.evaluate(&highModel, param.highValue)
        let profitAtHigh = highModel.calculateProfit()

        // Store results - use min/max of OUTCOMES, not parameter values
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
        let percentImpact = (impact / abs(profit)) * 100.0

        print("\n\(index + 1). \(input)")
        print("   Low scenario:  $\(Int(low).formatted())")
        print("   High scenario: $\(Int(high).formatted())")
        print("   Impact range:  $\(Int(impact).formatted()) (\(String(format: "%.1f", percentImpact))% of base profit)")
    }

    print("\n" + "=" * 50)
    print("Demo complete! See ReidsRaisinsExample.md for full tutorial.")
}

// Run the demo if this file is executed directly
runReidsRaisinsDemo()
