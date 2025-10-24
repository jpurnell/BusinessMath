# Scenario & Sensitivity Analysis

Learn how to model multiple scenarios and analyze which inputs have the greatest impact on your outcomes.

## Overview

BusinessMath provides powerful tools for scenario planning and sensitivity analysis. This tutorial shows you how to:
- Create multiple financial scenarios (base, best, worst case)
- Analyze how outputs change when inputs vary (sensitivity analysis)
- Identify the most impactful drivers (tornado diagrams)
- Run Monte Carlo simulations for risk analysis

## Content

## Understanding Scenarios

A scenario represents a complete set of assumptions about the future. Businesses typically model:
- **Base Case**: Most likely outcome
- **Best Case**: Optimistic assumptions
- **Worst Case**: Conservative assumptions
- **Custom Scenarios**: Specific situations (e.g., "Economic Recession")

## Creating Your First Scenario

Start with operational drivers and a builder function:

```swift
import BusinessMath

// Define the company and periods
let company = Entity(
    id: "TECH001",
    primaryType: .ticker,
    name: "TechCo",
    ticker: "TECH"
)

let q1 = Period.quarter(year: 2025, quarter: 1)
let quarters = [q1, q1 + 1, q1 + 2, q1 + 3]

// Create base case drivers
let baseRevenue = DeterministicDriver(name: "Revenue", value: 1_000_000)
let baseCosts = DeterministicDriver(name: "Costs", value: 600_000)
let baseOpEx = DeterministicDriver(name: "OpEx", value: 200_000)

var baseOverrides: [String: AnyDriver<Double>] = [:]
baseOverrides["Revenue"] = AnyDriver(baseRevenue)
baseOverrides["Costs"] = AnyDriver(baseCosts)
baseOverrides["OpEx"] = AnyDriver(baseOpEx)

// Create base case scenario
let baseCase = FinancialScenario(
    name: "Base Case",
    description: "Expected performance",
    driverOverrides: baseOverrides
)

// Define how to build financial statements from drivers
let builder: ScenarioRunner.StatementBuilder = { drivers, entity, periods in
    // Extract driver values
    let revenue = drivers["Revenue"]!.sample(for: periods[0])
    let costs = drivers["Costs"]!.sample(for: periods[0])
    let opex = drivers["OpEx"]!.sample(for: periods[0])

    // Build Income Statement
    let revenueAccount = Account(
        name: "Revenue",
        timeSeries: TimeSeries(periods: periods, values: Array(repeating: revenue, count: periods.count)),
        type: .revenue
    )

    let cogsAccount = Account(
        name: "COGS",
        timeSeries: TimeSeries(periods: periods, values: Array(repeating: costs, count: periods.count)),
        type: .costOfRevenue
    )

    let opexAccount = Account(
        name: "Operating Expenses",
        timeSeries: TimeSeries(periods: periods, values: Array(repeating: opex, count: periods.count)),
        type: .operatingExpense
    )

    let incomeStatement = IncomeStatement(
        entity: entity,
        revenueAccounts: [revenueAccount],
        expenseAccounts: [cogsAccount, opexAccount]
    )

    // Build simple Balance Sheet (required for complete projection)
    let cashAccount = Account(
        name: "Cash",
        timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000, 600_000, 650_000]),
        type: .asset
    )

    let equityAccount = Account(
        name: "Equity",
        timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000, 600_000, 650_000]),
        type: .equity
    )

    let balanceSheet = BalanceSheet(
        entity: entity,
        assetAccounts: [cashAccount],
        liabilityAccounts: [],
        equityAccounts: [equityAccount]
    )

    // Build simple Cash Flow Statement
    let cfAccount = Account(
        name: "Operating Cash Flow",
        timeSeries: incomeStatement.netIncome,
        type: .cashFlow,
        metadata: AccountMetadata(category: "Operating Activities")
    )

    let cashFlowStatement = CashFlowStatement(
        entity: entity,
        accounts: [cfAccount]
    )

    return (incomeStatement, balanceSheet, cashFlowStatement)
}

// Run the base case
let runner = ScenarioRunner()
let baseProjection = try runner.run(
    scenario: baseCase,
    entity: company,
    periods: quarters,
    builder: builder
)

print("Base Case Q1 Net Income: $\(baseProjection.incomeStatement.netIncome[q1]!)")
```

## Creating Multiple Scenarios

Build best and worst case scenarios:

```swift
// Best Case: Higher revenue, lower costs
let bestRevenue = DeterministicDriver(name: "Revenue", value: 1_200_000)  // +20%
let bestCosts = DeterministicDriver(name: "Costs", value: 540_000)        // -10%
let bestOpEx = DeterministicDriver(name: "OpEx", value: 180_000)          // -10%

var bestOverrides: [String: AnyDriver<Double>] = [:]
bestOverrides["Revenue"] = AnyDriver(bestRevenue)
bestOverrides["Costs"] = AnyDriver(bestCosts)
bestOverrides["OpEx"] = AnyDriver(bestOpEx)

let bestCase = FinancialScenario(
    name: "Best Case",
    description: "Optimistic performance",
    driverOverrides: bestOverrides
)

// Worst Case: Lower revenue, higher costs
let worstRevenue = DeterministicDriver(name: "Revenue", value: 800_000)   // -20%
let worstCosts = DeterministicDriver(name: "Costs", value: 660_000)       // +10%
let worstOpEx = DeterministicDriver(name: "OpEx", value: 220_000)         // +10%

var worstOverrides: [String: AnyDriver<Double>] = [:]
worstOverrides["Revenue"] = AnyDriver(worstRevenue)
worstOverrides["Costs"] = AnyDriver(worstCosts)
worstOverrides["OpEx"] = AnyDriver(worstOpEx)

let worstCase = FinancialScenario(
    name: "Worst Case",
    description: "Conservative performance",
    driverOverrides: worstOverrides
)

// Run all scenarios
let bestProjection = try runner.run(
    scenario: bestCase,
    entity: company,
    periods: quarters,
    builder: builder
)

let worstProjection = try runner.run(
    scenario: worstCase,
    entity: company,
    periods: quarters,
    builder: builder
)

// Compare results
print("=== Q1 Net Income Comparison ===")
print("Best Case:  $\(bestProjection.incomeStatement.netIncome[q1]!)")
print("Base Case:  $\(baseProjection.incomeStatement.netIncome[q1]!)")
print("Worst Case: $\(worstProjection.incomeStatement.netIncome[q1]!)")

let range = bestProjection.incomeStatement.netIncome[q1]! -
            worstProjection.incomeStatement.netIncome[q1]!
print("Range: $\(range)")
```

## One-Way Sensitivity Analysis

Analyze how one input affects the output:

```swift
// How does Revenue affect Net Income?
let revenueSensitivity = try runSensitivity(
    baseCase: baseCase,
    entity: company,
    periods: quarters,
    inputDriver: "Revenue",
    inputRange: 800_000...1_200_000,  // ±20%
    steps: 9,  // Test 9 evenly-spaced values
    builder: builder
) { projection in
    // Extract Q1 Net Income as our output metric
    return projection.incomeStatement.netIncome[q1]!
}

// View results
print("\n=== Revenue Sensitivity Analysis ===")
for (revenue, netIncome) in zip(revenueSensitivity.inputValues, revenueSensitivity.outputValues) {
    print("Revenue: $\(Int(revenue)) → Net Income: $\(Int(netIncome))")
}

// Calculate slope (sensitivity)
let deltaRevenue = revenueSensitivity.inputValues.last! - revenueSensitivity.inputValues.first!
let deltaIncome = revenueSensitivity.outputValues.last! - revenueSensitivity.outputValues.first!
let sensitivity = deltaIncome / deltaRevenue
print("\nSensitivity: For every $1 increase in revenue, net income increases by $\(sensitivity)")
```

## Tornado Diagram Analysis

Identify which drivers have the greatest impact:

```swift
// Analyze all key drivers at once
let tornado = try runTornadoAnalysis(
    baseCase: baseCase,
    entity: company,
    periods: quarters,
    inputDrivers: ["Revenue", "Costs", "OpEx"],
    variationPercent: 0.20,  // Vary each by ±20%
    steps: 2,  // Just test high and low values
    builder: builder
) { projection in
    return projection.incomeStatement.netIncome[q1]!
}

// Results are ranked by impact
print("\n=== Tornado Diagram (Ranked by Impact) ===")
for input in tornado.inputs {
    let impact = tornado.impacts[input]!
    let low = tornado.lowValues[input]!
    let high = tornado.highValues[input]!
    let percentImpact = (impact / tornado.baseCaseOutput) * 100

    print("\(input):")
    print("  Low:    $\(Int(low))")
    print("  High:   $\(Int(high))")
    print("  Impact: $\(Int(impact)) (\(String(format: "%.1f", percentImpact))%)")
}

// Visualize with command-line tornado diagram
let plot = plotTornadoDiagram(tornado)
print("\n" + plot)
```

## Two-Way Sensitivity Analysis

Analyze interactions between two inputs:

```swift
// How do Revenue and Costs interact?
let twoWaySensitivity = try runTwoWaySensitivity(
    baseCase: baseCase,
    entity: company,
    periods: quarters,
    inputDriver1: "Revenue",
    inputRange1: 800_000...1_200_000,
    steps1: 5,
    inputDriver2: "Costs",
    inputRange2: 540_000...660_000,
    steps2: 5,
    builder: builder
) { projection in
    return projection.incomeStatement.netIncome[q1]!
}

// Print data table
print("\n=== Two-Way Sensitivity: Revenue × Costs ===")
print(String(format: "%12s", ""), terminator: "")
for cost in twoWaySensitivity.inputValues2 {
    print(String(format: "%10.0f", cost), terminator: "")
}
print()

for (i, revenue) in twoWaySensitivity.inputValues1.enumerated() {
    print(String(format: "%12.0f", revenue), terminator: "")
    for j in 0..<twoWaySensitivity.inputValues2.count {
        let netIncome = twoWaySensitivity.results[i][j]
        print(String(format: "%10.0f", netIncome), terminator: "")
    }
    print()
}
```

## Monte Carlo Simulation

Model uncertainty with probabilistic inputs:

```swift
// Create probabilistic drivers (using existing deterministic seed)
let uncertainRevenue = ProbabilisticDriver(
    name: "Revenue",
    mean: 1_000_000,
    standardDeviation: 100_000,
    distribution: .normal
)

let uncertainCosts = ProbabilisticDriver(
    name: "Costs",
    mean: 600_000,
    standardDeviation: 50_000,
    distribution: .normal
)

var monteCarloOverrides: [String: AnyDriver<Double>] = [:]
monteCarloOverrides["Revenue"] = AnyDriver(uncertainRevenue)
monteCarloOverrides["Costs"] = AnyDriver(uncertainCosts)
monteCarloOverrides["OpEx"] = AnyDriver(baseOpEx)  // Keep OpEx fixed

let uncertainScenario = FinancialScenario(
    name: "Monte Carlo",
    description: "Probabilistic scenario",
    driverOverrides: monteCarloOverrides
)

// Run simulation (10,000 iterations)
let simulation = FinancialSimulation(
    baseScenario: uncertainScenario,
    iterations: 10_000,
    randomSeed: 42  // For reproducibility
)

let results = try simulation.run(
    entity: company,
    periods: quarters,
    builder: builder
) { projection in
    return projection.incomeStatement.netIncome[q1]!
}

// Analyze results
print("\n=== Monte Carlo Simulation Results (10,000 iterations) ===")
print("Mean Net Income: $\(Int(results.statistics.mean))")
print("Std Deviation: $\(Int(results.statistics.stdDev))")
print("Min: $\(Int(results.statistics.min))")
print("Max: $\(Int(results.statistics.max))")
print("\nPercentiles:")
print("  5th:  $\(Int(results.percentiles.p5))")
print("  25th: $\(Int(results.percentiles.p25))")
print("  50th: $\(Int(results.percentiles.p50)) (median)")
print("  75th: $\(Int(results.percentiles.p75))")
print("  95th: $\(Int(results.percentiles.p95))")

// Risk metrics
print("\nRisk Metrics:")
let var95 = results.riskMetrics.valueAtRisk(confidenceLevel: 0.95)
let cvar95 = results.riskMetrics.conditionalValueAtRisk(confidenceLevel: 0.95)
print("Value at Risk (95%): $\(Int(var95))")
print("CVaR (95%): $\(Int(cvar95))")

// Probability analysis
let probLoss = results.probabilityBelow(0)
let probAbove200k = results.probabilityAbove(200_000)
print("\nProbability Analysis:")
print("Probability of loss (NI < $0): \(probLoss * 100)%")
print("Probability NI > $200k: \(probAbove200k * 100)%")

// Visualize distribution
let histogram = results.histogram(bins: 20)
let histPlot = plotHistogram(histogram)
print("\n" + histPlot)
```

## Best Practices

## Scenario Design

1. **Start Simple**: Begin with 3 scenarios (base, best, worst)
2. **Be Realistic**: Base assumptions on historical data and market research
3. **Document Assumptions**: Clearly state what each scenario represents
4. **Test Extremes**: Include stress tests for extreme but plausible events

## Sensitivity Analysis

1. **Focus on Key Drivers**: Don't test every input - focus on the most uncertain
2. **Use Consistent Ranges**: ±10%, ±20%, or ±30% are common choices
3. **Interpret Results**: Large impact + high uncertainty = highest risk
4. **Update Regularly**: Rerun as new information becomes available

## Monte Carlo Simulation

1. **Choose Appropriate Distributions**:
   - Revenue: Normal or Log-Normal
   - Costs: Normal
   - Percentages: Beta distribution
   - Count data: Poisson
2. **Set Reasonable Parameters**: Base σ on historical volatility
3. **Run Enough Iterations**: 10,000 is usually sufficient
4. **Validate Results**: Check that mean matches base case

## Next Steps

- Learn about <doc:FinancialRatiosGuide> for analyzing scenario results
- Explore <doc:VisualizationGuide> for creating charts and diagrams
- See <doc:BuildingRevenueModel> for more complex drivers

## Related Topics

- ``FinancialScenario``
- ``ScenarioRunner``
- ``FinancialProjection``
- ``runSensitivity(baseCase:entity:periods:inputDriver:inputRange:steps:builder:outputExtractor:)``
- ``runTornadoAnalysis(baseCase:entity:periods:inputDrivers:variationPercent:steps:builder:outputExtractor:)``
- ``FinancialSimulation``
- ``SimulationResults``
- ``plotTornadoDiagram(_:)``
- ``plotHistogram(_:)``
