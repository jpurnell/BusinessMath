# Part II: Analysis & Statistics

Learn the statistical and analytical techniques that power data-driven business decisions.

## Overview

Part II focuses on the analytical foundation of BusinessMath—the statistical methods and metrics that help you understand your data, measure risk, and communicate insights effectively. This is where raw numbers become actionable intelligence.

While Part I taught you the mechanics of working with time series and financial calculations, Part II teaches you how to *analyze* that data. You'll learn sensitivity analysis techniques that reveal which assumptions matter most, financial ratio calculations that benchmark performance, risk analytics that quantify uncertainty, and visualization methods that communicate your findings clearly.

This section bridges the gap between calculation and insight. Whether you're evaluating business performance, assessing investment risk, or presenting findings to stakeholders, these analytical tools are essential.

## What You'll Learn

- **Sensitivity Analysis**: How to identify which inputs have the greatest impact on your results
- **Regression Modeling**: Building predictive models with multiple linear regression and comprehensive diagnostics
- **Financial Ratios**: Industry-standard metrics for evaluating business performance and health
- **Risk Analytics**: Quantifying uncertainty with VaR, CVaR, stress testing, and risk aggregation
- **Visualization**: Creating publication-quality charts and diagrams for your analyses
- **Model Validation**: Verifying that statistical models work correctly using fake-data simulation

## Chapters in This Part

### Analytical Techniques
- <doc:2.1-DataTableAnalysis>
- <doc:MultipleLinearRegressionGuide>

### Financial Metrics
- <doc:2.2-FinancialRatiosGuide>

### Risk Measurement
- <doc:2.3-RiskAnalyticsGuide>

### Communication
- <doc:2.4-VisualizationGuide>

### Model Validation
- <doc:2.5-ModelValidationGuide>

## Prerequisites

Before diving into Part II, you should be comfortable with time series operations, basic financial calculations, and the fluent API patterns from Part I. If you skipped Part I, at minimum review chapters 1.1-1.3 before proceeding.

## Suggested Reading Order

The chapters in this part can be read in any order based on your needs:

**For Financial Analysts:**
1. <doc:2.2-FinancialRatiosGuide>
2. <doc:MultipleLinearRegressionGuide>
3. <doc:2.1-DataTableAnalysis>
4. <doc:2.3-RiskAnalyticsGuide>
5. <doc:2.4-VisualizationGuide>

**For Risk Managers:**
1. <doc:2.3-RiskAnalyticsGuide>
2. <doc:2.1-DataTableAnalysis>
3. <doc:2.2-FinancialRatiosGuide>
4. <doc:2.4-VisualizationGuide>

**For Quantitative Developers:**
1. <doc:MultipleLinearRegressionGuide>
2. <doc:2.5-ModelValidationGuide>
3. <doc:2.1-DataTableAnalysis>
4. <doc:2.3-RiskAnalyticsGuide>
5. <doc:2.4-VisualizationGuide>
6. <doc:2.2-FinancialRatiosGuide>

## Key Concepts

### Sensitivity Analysis

Understanding which inputs matter most is crucial for any financial model. Data table analysis lets you systematically vary one or two inputs and observe the impact on outputs—just like Excel's data tables but with programmatic control:

```swift
import BusinessMath

// Vary the revenue growth assumption and watch NPV respond
let growthRates = [0.05, 0.08, 0.11, 0.14, 0.17, 0.20]

let npvTable = DataTable<Double, Double>.oneVariable(
    inputs: growthRates,
    calculate: { growth in
        let cashFlows = (1...5).map { year in
            1_000_000.0 * pow(1.0 + growth, Double(year))
        }
        return npv(discountRate: 0.10, cashFlows: cashFlows)
    }
)

for (growth, value) in npvTable {
    print("Growth \(growth): NPV \(value)")
}
```

### Regression Modeling

Build predictive models to understand relationships between variables with GPU-accelerated performance and comprehensive diagnostics:

```swift
// Model: Sales = β₀ + β₁×Advertising + β₂×Price
let advertising = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0]
let price = [50.0, 48.0, 52.0, 49.0, 51.0, 47.0]
let sales = [120.0, 145.0, 168.0, 195.0, 218.0, 245.0]

// Create predictor matrix: each row = [advertising, price]
let X = zip(advertising, price).map { [$0, $1] }

let result = try multipleLinearRegression(X: X, y: sales)

// Comprehensive diagnostics
print("R² = \(result.rSquared)")  // Model fit
print("F-statistic p-value = \(result.fStatisticPValue)")  // Overall significance
print("VIF = \(result.vif)")  // Multicollinearity check

// Check individual predictors
for i in 0..<result.coefficients.count {
    if result.pValues[i+1] < 0.05 {
        print("Predictor \(i) is significant (p = \(result.pValues[i+1]))")
    }
}

// Make predictions
let prediction = result.intercept +
                result.coefficients[0] * 40.0 +  // $40k advertising
                result.coefficients[1] * 50.0    // $50 price
```

**Performance**: Automatically uses Accelerate BLAS for 40-13,000× speedup on Apple platforms. A 500×500 regression completes in 2.5ms instead of 20 seconds.

### Financial Ratios

Ratios transform raw financial data into comparable metrics that reveal business health:

```swift
let annualRevenue = 5_000_000.0
let netIncome = 750_000.0
let shareholderEquity = 3_000_000.0
let totalLiabilities = 2_000_000.0

let margin = try profitMargin(netIncome: netIncome, revenue: annualRevenue)
let returnOnEquity = try roe(netIncome: netIncome, shareholderEquity: shareholderEquity)
let leverage = try debtToEquity(
    totalLiabilities: totalLiabilities,
    shareholderEquity: shareholderEquity
)

print("Profit margin: \(margin)")
print("ROE: \(returnOnEquity)")
print("Debt/equity: \(leverage)")
```

### Risk Analytics

Quantifying risk lets you move from "what if?" questions to probabilistic statements about outcomes:

```swift
// Simulate a 60/40 portfolio, then read the tail off the distribution
// `seed:` makes the run reproducible; omit it for a fresh draw each time
var portfolio = MonteCarloSimulation(iterations: 10_000, seed: 1042) { inputs in
    0.6 * inputs[0] + 0.4 * inputs[1]
}
portfolio.addInput(SimulationInput(
    name: "Stocks",
    distribution: DistributionNormal(0.12, 0.20)
))
portfolio.addInput(SimulationInput(
    name: "Bonds",
    distribution: DistributionNormal(0.04, 0.05)
))

let riskMetrics = try portfolio.run()
let var95 = riskMetrics.valueAtRisk(confidenceLevel: 0.95)
let cvar95 = riskMetrics.conditionalValueAtRisk(confidenceLevel: 0.95)

// Named stress scenarios describe the shocks to apply to your drivers
let stressScenarios = [
    StressScenario<Double>.recession,
    StressScenario<Double>.crisis
]

print("95% VaR: \(var95), 95% CVaR: \(cvar95)")
for scenario in stressScenarios {
    // `shocks` is a Dictionary, and Swift randomises hash order per process — printing
    // one directly gives a different order on every run. Sort at the print site.
    let shocks = scenario.shocks
        .sorted { $0.key < $1.key }
        .map { "\($0.key): \($0.value)" }
        .joined(separator: ", ")
    print("\(scenario.name): [\(shocks)]")
}
```

### Visualization

BusinessMath provides command-line visualization for quick data exploration:

```swift
// Histogram visualization for distributions.
// `next()` with no argument draws from the system generator, which would give a
// different histogram on every run. `next(using:)` sources every draw from a
// generator you own, so a seeded one reproduces the figure below exactly.
let revenueDistribution = DistributionNormal(5_000_000.0, 750_000.0)
var revenueRNG = SplitMix64(seed: 20726)
let revenueData = (0..<1_000).map { _ in revenueDistribution.next(using: &revenueRNG) }
let revenueResults = SimulationResults(values: revenueData)
let histogram = revenueResults.histogram(bins: 20)
let plot = plotHistogram(histogram)
print(plot)
```

Tornado diagrams rank sensitivity across drivers. The call below assumes a
`baseCase` scenario, `entity`, `periods`, and statement `builder` already in
hand — see <doc:2.4-VisualizationGuide> for the full setup:

<!-- docs:illustrative -->
```swift
let tornado = try runTornadoAnalysis(
    baseCase: baseCase,
    entity: entity,
    periods: periods,
    inputDrivers: ["Revenue", "COGS", "OpEx"],
    variationPercent: 0.20,
    steps: 2,
    builder: builder
) { projection in
    projection.incomeStatement.netIncome[q4]!
}
print(plotTornadoDiagram(tornado))
```

For graphical charts, export data to external tools like Swift Charts, Excel, or Python:

```swift
// Export for external visualization
let csvData = DataTable<Double, Double>.toCSV(
    npvTable,
    inputHeader: "Growth Rate",
    outputHeader: "NPV"
)
try csvData.write(to: URL(fileURLWithPath: "npv.csv"), atomically: true, encoding: .utf8)
```

### Model Validation

Before using any statistical model on real data, verify it works correctly by simulating fake data and checking parameter recovery:

```swift
// Simulate data with known parameters, then check that fitting recovers them.
//
// ``ReciprocalParameterRecoveryCheck/run(trueA:trueB:trueSigma:n:xRange:tolerance:learningRate:maxIterations:)``
// packages this workflow, but it draws its fake data with `Double.random(in:)` and the
// free `distributionNormal(mean:stdDev:)` — neither takes a seed, so its verdict is a
// different one each run. Simulating from a generator you own fixes that, and running
// several replicates turns a single pass/fail into something you can actually read: one
// sample of 100 points is not enough evidence to convict a fitting procedure.
let trueParameters = ReciprocalRegressionModel<Double>.Parameters(a: 0.2, b: 0.3, sigma: 0.2)
let fitter = ReciprocalRegressionFitter<Double>()
let replicates = 20

var recoveredCount = 0
for replicate in 0..<replicates {
    var rng = SplitMix64(seed: 90_210 + UInt64(replicate))

    let fakeData = (0..<100).map { _ -> ReciprocalRegressionModel<Double>.DataPoint in
        let x = Double.random(in: 1.0...10.0, using: &rng)
        let mean = ReciprocalRegressionModel<Double>.predictedMean(x: x, params: trueParameters)
        return ReciprocalRegressionModel<Double>.DataPoint(
            x: x,
            y: DistributionNormal(mean, trueParameters.sigma).next(using: &rng)
        )
    }

    let fit = try fitter.fit(data: fakeData)
    let relativeErrors = [
        abs(fit.parameters.a - trueParameters.a) / trueParameters.a,
        abs(fit.parameters.b - trueParameters.b) / trueParameters.b,
        abs(fit.parameters.sigma - trueParameters.sigma) / trueParameters.sigma
    ]

    // Did we recover the true parameters, all three within 10%?
    if relativeErrors.allSatisfy({ $0 <= 0.1 }) { recoveredCount += 1 }
}

print("Recovered all three parameters within 10% in \(recoveredCount) of \(replicates) replicates")
```

Read that number before you trust the model on real data. A high rate means the fitting
procedure works. This one recovers all three parameters in 4 of 20 replicates, and the
parameter it misses is nearly always the intercept `a` — so on a sample of this size,
a single run of the check is close to a coin toss and should not be read as a verdict.

Adding data does not rescue it, which is the useful diagnostic:
``ReciprocalRegressionFitter`` descends the *total* negative log-likelihood at a fixed
learning rate, and that gradient grows with `n`, so the same step size that works at 100
points overshoots at 400 (2 of 20) and runs out of iterations at 1,000 (0 of 20, none
converged). Lower `learningRate` as you raise `n`. This is exactly what fake-data
simulation is for: the failure is in the fitting procedure, and it is far cheaper to find
it here than in a fit whose true parameters you do not know.

## Real-World Applications

### Predictive Modeling
Use regression to forecast outcomes based on multiple factors. Model house prices from size and location, predict customer churn from usage patterns, or estimate sales from advertising spend and market conditions. Get comprehensive diagnostics (R², VIF, confidence intervals) to assess model quality.

### Investment Analysis
Combine financial ratios with risk metrics to evaluate potential investments. Calculate P/E ratios, debt levels, and volatility measures to make informed allocation decisions.

### Corporate Finance
Use sensitivity analysis to understand which business drivers have the greatest impact on profitability. Identify the key value drivers and focus management attention where it matters most.

### Risk Management
Quantify portfolio risk with VaR and stress testing. Communicate risk exposure to stakeholders with clear visualizations and scenario analysis.

### Performance Monitoring
Track financial ratios over time to monitor business health. Create dashboards that surface early warning signals and track progress against targets.

## Next Steps

After completing Part II, consider:

- **Building Models** (<doc:Part3-Modeling>): Apply your analytical skills to forecasting and valuation
- **Running Simulations** (<doc:Part4-Simulation>): Model uncertainty with Monte Carlo methods
- **Optimizing Decisions** (<doc:Part5-Optimization>): Find optimal solutions using mathematical optimization

Or explore specific modeling topics:
- <doc:3.3-BuildingRevenueModel>
- <doc:3.5-FinancialStatementsGuide>
- <doc:3.8-InvestmentAnalysis>

## Common Questions

**Do I need all of Part II for basic financial modeling?**

No. You can build models with just Part I knowledge. Part II becomes essential when you need to analyze sensitivity, measure risk, calculate performance metrics, or present findings professionally.

**Should I learn these techniques even if I use Excel?**

Absolutely. These programmatic approaches offer several advantages: repeatability, version control, integration with data pipelines, and the ability to scale analyses across hundreds of scenarios automatically.

**Can I combine these analytical techniques?**

Yes! The real power comes from combining techniques. For example: use data table analysis to identify key drivers, calculate financial ratios to benchmark performance, measure risk with VaR, and visualize everything clearly for stakeholders.

## Related Topics

- <doc:Part1-Basics>
- <doc:Part3-Modeling>
- <doc:Part4-Simulation>
