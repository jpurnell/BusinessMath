# Command-Line Visualization

Learn how to create visual representations of data directly in the terminal.

## Overview

BusinessMath provides command-line visualization tools for exploring data and presenting results without external dependencies. This tutorial shows you how to create:
- Histograms for distribution analysis
- Tornado diagrams for sensitivity analysis

These visualizations work in any terminal environment and are perfect for CLI applications, scripts, and quick data exploration.

## Content

## Histogram Visualization

Histograms show the distribution of values, making it easy to see patterns, central tendency, and outliers.

#### Basic Histogram

Create a histogram from simulation results:

```swift
import BusinessMath

// Run a Monte Carlo simulation
var revenueValues: [Double] = []
for _ in 0..<10_000 {
    // Simulate revenue with uncertainty
    let revenue = distributionNormal(mean: 1_000_000, stdDev: 100_000)
    revenueValues.append(revenue)
}

// Create simulation results
let results = SimulationResults(values: revenueValues)

// Generate histogram
let histogram = results.histogram(bins: 20)

// Visualize
let plot = plotHistogram(histogram)
print(plot)
```

**Output:**
```
Histogram (20 bins, 10,000 samples):

[  750000 -   800000):  ████ 45 (  0.5%)
[  800000 -   850000):  ████████████ 234 (  2.3%)
[  850000 -   900000):  ████████████████████ 567 (  5.7%)
[  900000 -   950000):  ████████████████████████████ 892 (  8.9%)
[  950000 -  1000000):  ████████████████████████████████ 1234 ( 12.3%)
[ 1000000 -  1050000):  ████████████████████████████████ 1256 ( 12.6%)
[ 1050000 -  1100000):  ████████████████████████████ 1102 ( 11.0%)
[ 1100000 -  1150000):  ████████████████████ 678 (  6.8%)
...
```

#### Interpreting Histograms

- **Bar length**: Represents the number of values in that range
- **Percentage**: Shows what portion of total values fall in that bin
- **Shape**: Reveals the distribution pattern
  - Bell curve: Normal distribution
  - Skewed right: More low values, few high outliers
  - Skewed left: More high values, few low outliers
  - Bimodal: Two distinct peaks

#### Choosing Bin Count

```swift
// Too few bins (5) - loses detail
let coarseHistogram = results.histogram(bins: 5)

// Good balance (20) - shows pattern clearly
let goodHistogram = results.histogram(bins: 20)

// Too many bins (100) - too granular, hard to see pattern
let fineHistogram = results.histogram(bins: 100)

// Rule of thumb: sqrt(n) or between 10-30 bins for most datasets
let n = results.values.count
let suggestedBins = Int(sqrt(Double(n)))
let autoHistogram = results.histogram(bins: suggestedBins)
```

#### Using Histograms for Analysis

```swift
// Example: Analyzing project completion time
let completionDays = SimulationResults(values: projectDurations)
let hist = completionDays.histogram(bins: 20)

print(plotHistogram(hist))

// Find the mode (most common range)
let maxBin = hist.max { $0.count < $1.count }!
print("\nMost likely completion time: \(maxBin.range.lowerBound)-\(maxBin.range.upperBound) days")

// Check for outliers
let p95 = completionDays.percentiles.p95
let p5 = completionDays.percentiles.p5
print("Middle 90% of outcomes: \(p5) to \(p95) days")

// Risk analysis
let probDelay = completionDays.probabilityAbove(deadlineDays)
print("Probability of missing deadline: \(probDelay * 100)%")
```

## Tornado Diagram Visualization

Tornado diagrams show which inputs have the greatest impact on outputs, making them essential for sensitivity analysis.

#### Basic Tornado Diagram

Create a tornado diagram from sensitivity analysis:

```swift
// Assume we have a base case scenario and builder function
let tornado = try runTornadoAnalysis(
    baseCase: baseCase,
    entity: entity,
    periods: periods,
    inputDrivers: ["Revenue", "COGS", "OpEx", "Tax Rate", "Marketing"],
    variationPercent: 0.20,  // Vary each input by ±20%
    steps: 2,
    builder: builder
) { projection in
    // Extract the metric we care about (e.g., Q1 Net Income)
    return projection.incomeStatement.netIncome[q1]!
}

// Visualize
let plot = plotTornadoDiagram(tornado)
print(plot)
```

**Output:**
```
Tornado Diagram - Sensitivity Analysis
Base Case: 1000.0

Revenue   ◄█████████████████████████│█████████████████████████► Impact: 500.0 (50.0%)
            750                 1000                 1250

COGS      ◄          ███████████████│████████████████████     ► Impact: 350.0 (35.0%)
            1150                 1000                 800

OpEx      ◄               ██████████│██████████               ► Impact: 200.0 (20.0%)
            900                 1000                 1100

Tax Rate  ◄                    █████│█████                    ► Impact: 100.0 (10.0%)
            950                 1000                 1050

Marketing ◄                       ██│██                       ► Impact: 50.0 (5.0%)
            975                 1000                 1025
```

#### Interpreting Tornado Diagrams

**Structure:**
- **Vertical axis**: Input drivers, ranked by impact (largest first)
- **Horizontal axis**: Output values
- **Center line (│)**: Base case output
- **Left bars**: Output when input is decreased
- **Right bars**: Output when input is increased

**Insights:**
- **Bar length**: Shows total impact range
- **Symmetry**: Equal left/right bars = linear relationship
- **Asymmetry**: Unequal bars = non-linear relationship
- **Direction**:
  - Right-heavy: Input positively affects output (Revenue)
  - Left-heavy: Input negatively affects output (Costs)

#### Using Tornado Diagrams for Decision Making

```swift
// Identify key drivers
print("Top 3 Value Drivers:")
for (i, input) in tornado.inputs.prefix(3).enumerated() {
    let impact = tornado.impacts[input]!
    let percentImpact = (impact / tornado.baseCaseOutput) * 100
    print("\(i+1). \(input): ±\(Int(percentImpact))% impact on output")
}

// Focus management attention
let topDriver = tornado.inputs.first!
let topImpact = tornado.impacts[topDriver]!

print("\n💡 Key Insight:")
print("Focus on \(topDriver) - it has \(Int(topImpact)) impact,")
print("which is \(Int(topImpact / tornado.impacts[tornado.inputs.last!]!))x more than \(tornado.inputs.last!)")

// Risk vs. Opportunity
for input in tornado.inputs {
    let low = tornado.lowValues[input]!
    let high = tornado.highValues[input]!
    let base = tornado.baseCaseOutput

    let downside = base - low
    let upside = high - base

    if downside > upside {
        print("\n⚠️  \(input): More downside risk than upside")
    } else if upside > downside * 1.5 {
        print("\n📈 \(input): Significant upside opportunity")
    }
}
```

#### Comparing Scenarios

Use tornado diagrams to compare different scenarios:

```swift
// Base case
let baseTornado = try runTornadoAnalysis(...baseCase...)

// After improvement initiative
let improvedCase = // ... modified scenario with lower costs
let improvedTornado = try runTornadoAnalysis(...improvedCase...)

print("=== Before Improvement ===")
print(plotTornadoDiagram(baseTornado))

print("\n=== After Cost Reduction ===")
print(plotTornadoDiagram(improvedTornado))

// Compare sensitivities
for input in baseTornado.inputs {
    let baseImpact = baseTornado.impacts[input]!
    let improvedImpact = improvedTornado.impacts[input]!
    let change = ((improvedImpact - baseImpact) / baseImpact) * 100

    if abs(change) > 10 {
        print("\(input) sensitivity changed by \(Int(change))%")
    }
}
```

## Combining Visualizations

Use both histograms and tornado diagrams together for comprehensive analysis:

```swift
// 1. Identify key drivers with tornado diagram
let tornado = try runTornadoAnalysis(...)
print(plotTornadoDiagram(tornado))

let topDriver = tornado.inputs.first!
print("\n\(topDriver) is the most impactful driver")

// 2. Run Monte Carlo on top driver to see distribution
var results: [Double] = []
for _ in 0..<10_000 {
    // Simulate the top driver with uncertainty
    let value = distributionNormal(mean: baseValue, stdDev: uncertainty)

    // Calculate output
    // ... run scenario with this value ...
    results.append(output)
}

let simResults = SimulationResults(values: results)
let histogram = simResults.histogram(bins: 20)

print("\n\(topDriver) Impact Distribution:")
print(plotHistogram(histogram))

// 3. Analyze the combined insights
print("\nKey Insights:")
print("- \(topDriver) has ±\(tornado.impacts[topDriver]!) impact (tornado)")
print("- 90% of outcomes fall between \(simResults.percentiles.p5) and \(simResults.percentiles.p95) (histogram)")
print("- Probability of meeting target: \(simResults.probabilityAbove(target) * 100)%")
```

## Exporting Visualizations

Save visualizations to files for reports or documentation:

```swift
import Foundation

// Save histogram to file
let histogram = results.histogram(bins: 20)
let histogramPlot = plotHistogram(histogram)

let histogramPath = "outputs/revenue_distribution.txt"
try histogramPlot.write(toFile: histogramPath, atomically: true, encoding: .utf8)
print("Histogram saved to \(histogramPath)")

// Save tornado diagram to file
let tornado = try runTornadoAnalysis(...)
let tornadoPlot = plotTornadoDiagram(tornado)

let tornadoPath = "outputs/sensitivity_analysis.txt"
try tornadoPlot.write(toFile: tornadoPath, atomically: true, encoding: .utf8)
print("Tornado diagram saved to \(tornadoPath)")

// Combine into report
var report = """
# Financial Analysis Report
Generated: \(Date())

## Revenue Distribution Analysis

\(histogramPlot)

## Sensitivity Analysis

\(tornadoPlot)

## Summary
- Most impactful driver: \(tornado.inputs.first!)
- Expected revenue: $\(Int(results.statistics.mean))
- Risk (95% VaR): $\(Int(results.riskMetrics.valueAtRisk(confidenceLevel: 0.95)))
"""

try report.write(toFile: "outputs/full_report.txt", atomically: true, encoding: .utf8)
```

## Best Practices

#### Histograms
1. **Choose appropriate bin count**: Too few loses detail, too many adds noise
2. **Label your axes**: Make it clear what the values represent
3. **Show sample size**: Include the number of data points
4. **Highlight key percentiles**: Mark P5, P50, P95 on the output
5. **Compare distributions**: Plot multiple histograms side-by-side

#### Tornado Diagrams
1. **Use consistent variation**: ±10%, ±20%, or ±30% for all inputs
2. **Include base case**: Show the reference point clearly
3. **Rank by impact**: Keep drivers sorted (largest first)
4. **Show percentage impact**: Helps compare to base case
5. **Focus on top drivers**: Top 5-7 usually account for most variance

#### General
1. **Keep it simple**: Don't overload with information
2. **Use in context**: Explain what the chart shows
3. **Verify data**: Check that visualizations match expectations
4. **Combine insights**: Use multiple visualization types
5. **Document assumptions**: Note what went into the analysis

## Limitations

## Current Limitations
- Text-based only (no graphical plots)
- Fixed Unicode characters (requires Unicode terminal support)
- No interactive features
- No color coding (terminal-dependent)

## Future Enhancements
Planned for companion packages:
- **BusinessMathCharts**: Swift Charts integration for graphical plots
- **BusinessMathUI**: Optional SwiftUI interface for interactive visualization
- Color-coded outputs for modern terminals
- Interactive drill-down capabilities

## Next Steps

- Learn about <doc:ScenarioAnalysisGuide> to generate data for tornado diagrams
- Explore <doc:FinancialRatiosGuide> for metrics to visualize
- See <doc:GettingStarted> for simulation examples

## Related Topics

- ``plotHistogram(_:)``
- ``plotTornadoDiagram(_:)``
- ``SimulationResults``
- ``TornadoDiagramAnalysis``
- ``runTornadoAnalysis(baseCase:entity:periods:inputDrivers:variationPercent:steps:builder:outputExtractor:)``
