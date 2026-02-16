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
- <doc:2.1-DataTableAnalysis> - Excel-style data tables for sensitivity and scenario analysis
- <doc:MultipleLinearRegressionGuide> - Multiple linear regression with GPU acceleration and comprehensive diagnostics

### Financial Metrics
- <doc:2.2-FinancialRatiosGuide> - Profitability, leverage, efficiency, and other key ratios

### Risk Measurement
- <doc:2.3-RiskAnalyticsGuide> - VaR, CVaR, stress testing, and portfolio risk metrics

### Communication
- <doc:2.4-VisualizationGuide> - Creating charts, diagrams, and visual analytics

### Model Validation
- <doc:2.5-ModelValidationGuide> - Fake-data simulation and parameter recovery validation

## Prerequisites

Before diving into Part II, you should be comfortable with:

- Time series operations (<doc:1.2-TimeSeries>)
- Basic financial calculations (<doc:1.3-TimeValueOfMoney>)
- The fluent API patterns (<doc:1.4-FluentAPIGuide>)

If you skipped Part I, at minimum review chapters 1.1-1.3 before proceeding.

## Suggested Reading Order

The chapters in this part can be read in any order based on your needs:

**For Financial Analysts:**
1. <doc:2.2-FinancialRatiosGuide> - Start with familiar territory
2. <doc:MultipleLinearRegressionGuide> - Predictive modeling with regression
3. <doc:2.1-DataTableAnalysis> - Excel-like sensitivity analysis
4. <doc:2.3-RiskAnalyticsGuide> - Risk measurement techniques
5. <doc:2.4-VisualizationGuide> - Presentation and reporting

**For Risk Managers:**
1. <doc:2.3-RiskAnalyticsGuide> - Core risk metrics
2. <doc:2.1-DataTableAnalysis> - Sensitivity and stress testing
3. <doc:2.2-FinancialRatiosGuide> - Performance metrics
4. <doc:2.4-VisualizationGuide> - Risk dashboards

**For Quantitative Developers:**
1. <doc:MultipleLinearRegressionGuide> - GPU-accelerated regression with numerical stability
2. <doc:2.5-ModelValidationGuide> - Essential for verifying implementations
3. <doc:2.1-DataTableAnalysis> - Systematic sensitivity analysis
4. <doc:2.3-RiskAnalyticsGuide> - Statistical risk measures
5. <doc:2.4-VisualizationGuide> - Programmatic visualization
6. <doc:2.2-FinancialRatiosGuide> - Metrics for validation

## Key Concepts

### Sensitivity Analysis

Understanding which inputs matter most is crucial for any financial model. Data table analysis lets you systematically vary one or two inputs and observe the impact on outputs—just like Excel's data tables but with programmatic control:

```swift
let dataTable = DataTable()
    .input(variable: revenueGrowth, range: 0.05...0.20, steps: 10)
    .output { growth in
        revenueModel.setGrowthRate(growth).calculate().npv()
    }
    .calculate()
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
let ratios = FinancialRatios(
    revenue: revenue,
    costs: costs,
    assets: assets,
    liabilities: liabilities
)

let profitMargin = ratios.profitMargin()
let roe = ratios.returnOnEquity()
let debtRatio = ratios.debtToEquity()
```

### Risk Analytics

Quantifying risk lets you move from "what if?" questions to probabilistic statements about outcomes:

```swift
let riskMetrics = portfolio.risk()
let var95 = riskMetrics.valueAtRisk(confidence: 0.95)
let cvar = riskMetrics.conditionalVaR(confidence: 0.95)
let stressScenario = riskMetrics.stressTest(scenarios: [recession, crisis])
```

### Visualization

BusinessMath provides command-line visualization for quick data exploration:

```swift
// Histogram visualization for distributions
let results = SimulationResults(values: revenueData)
let histogram = results.histogram(bins: 20)
let plot = plotHistogram(histogram)
print(plot)

// Tornado diagram for sensitivity analysis
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
let csvData = revenue.toCSV()
try csvData.write(to: URL(fileURLWithPath: "revenue.csv"))
```

### Model Validation

Before using any statistical model on real data, verify it works correctly by simulating fake data and checking parameter recovery:

```swift
// Simulate data with known parameters
let report = try ReciprocalParameterRecoveryCheck.run(
    trueA: 0.2,
    trueB: 0.3,
    trueSigma: 0.2,
    n: 100,
    xRange: 1.0...10.0
)

// Did we recover the true parameters?
if report.passed {
    print("✓ Model fitting works correctly!")
} else {
    print("✗ Problem detected - investigate before using real data")
}
```

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

- **Building Models** (<doc:Part3-Modeling>) - Apply your analytical skills to forecasting and valuation
- **Running Simulations** (<doc:Part4-Simulation>) - Model uncertainty with Monte Carlo methods
- **Optimizing Decisions** (<doc:Part5-Optimization>) - Find optimal solutions using mathematical optimization

Or explore specific modeling topics:
- <doc:3.3-BuildingRevenueModel> - Revenue forecasting with sensitivity analysis
- <doc:3.5-FinancialStatementsGuide> - Complete financial statement modeling
- <doc:3.8-InvestmentAnalysis> - Investment evaluation and valuation

## Common Questions

**Do I need all of Part II for basic financial modeling?**

No. You can build models with just Part I knowledge. Part II becomes essential when you need to analyze sensitivity, measure risk, calculate performance metrics, or present findings professionally.

**Should I learn these techniques even if I use Excel?**

Absolutely. These programmatic approaches offer several advantages: repeatability, version control, integration with data pipelines, and the ability to scale analyses across hundreds of scenarios automatically.

**Can I combine these analytical techniques?**

Yes! The real power comes from combining techniques. For example: use data table analysis to identify key drivers, calculate financial ratios to benchmark performance, measure risk with VaR, and visualize everything clearly for stakeholders.

## Related Topics

- <doc:Part1-Basics> - Foundation concepts and time series operations
- <doc:Part3-Modeling> - Building revenue models and financial forecasts
- <doc:Part4-Simulation> - Monte Carlo simulation and uncertainty quantification
