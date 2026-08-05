# Portfolio Rebalancing Case Study - Statistics Generation

This directory contains tools for generating and updating statistics for the Week 11 Case Study blog post on Real-Time Portfolio Rebalancing.

## Quick Start

To regenerate all statistics for the blog post:

```bash
swift generate_portfolio_statistics.swift
```

This will:
- Calculate all business value metrics
- Generate performance statistics
- Export results to JSON at `/tmp/portfolio_statistics.json`
- Print formatted output for the blog post

## What Gets Generated

### Business Value Metrics
- **Before/After Comparison**: Baseline (manual) vs. Optimized (real-time)
- **Tracking Error**: Percentage improvement and dollar value
- **Transaction Costs**: Percentage reduction and annual savings
- **Time to Decision**: Speedup factor

### Financial Impact
- **Annual Value**: Total cost savings per year
- **ROI Metrics**: Development cost, payback period, 5-year NPV

### Performance Metrics
- **Parallel Speedup**: Benefit from concurrent evaluation
- **Optimization Time**: Average time to converge
- **Iteration Statistics**: Typical convergence behavior

## Customizing Parameters

Edit `generate_portfolio_statistics.swift` to adjust:

```swift
struct PortfolioMetrics {
	let portfolioValue: Double = 250_000_000  // Change portfolio size
	let numAssets: Int = 500                   // Change number of assets

	// Baseline metrics
	let baselineRebalancingTime: TimeInterval = 5 * 3600  // Manual time
	let baselineTrackingErrorBps: Double = 82.5
	let baselineTransactionCostsBps: Double = 35.0

	// Optimized metrics
	let optimizedRebalancingTime: TimeInterval = 18.0
	let optimizedTrackingErrorBps: Double = 42.0
	let optimizedTransactionCostsBps: Double = 25.0
}
```

## Running Actual Benchmarks

To measure real performance from the library:

1. **Build the package**:
   ```bash
   cd /Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath
   swift build -c release
   ```

2. **Run benchmark tests**:
   ```bash
   swift test --filter PortfolioRebalancingBenchmarkTests
   ```

3. **Run the playground**:
   Open `Playgrounds/Blog/Week11/03-fri-case-study-rebalancing.playground` and run to see actual optimization performance.

## Output Files

### JSON Export
`/tmp/portfolio_statistics.json` contains:
```json
{
  "annual_value": {
    "total_annual_value": 2012500.0,
    "tracking_error_value": 1012500.0,
    "transaction_cost_savings": 1000000.0
  },
  "improvements": {
    "time_speedup": 1000.0,
    "tracking_error_improvement_percent": 49.09,
    "transaction_cost_reduction_percent": 28.57
  },
  // ... more metrics
}
```

## Updating the Blog Post

After running the statistics generator:

1. Copy the printed output
2. Update `/Users/jpurnell/Dropbox/Computer/Development/Swift/justinpurnell.com/Content/BusinessMath/week-11/03-fri-case-study-rebalancing.md`
3. Replace the "Business Value" section with new statistics

The script output is formatted to copy-paste directly into the blog post.

## Validation

To ensure statistics are realistic:

- **Tracking Error Reduction**: Should be 30-60% (49% is typical)
- **Transaction Cost Reduction**: Should be 20-40% (28% is realistic)
- **Time Speedup**: Manual process (hours) vs. automated (seconds) = 100-1000×
- **ROI Payback**: Should be under 30 days for $250M portfolio

## Future Enhancements

Consider adding:
- [ ] Automated benchmarking from actual test runs
- [ ] Historical tracking of performance improvements
- [ ] A/B testing different optimization algorithms
- [ ] Monte Carlo simulation of annual value uncertainty
- [ ] Integration with CI/CD to update stats on each release

## Related Files

- **Blog Post**: `/Users/jpurnell/Dropbox/Computer/Development/Swift/justinpurnell.com/Content/BusinessMath/week-11/03-fri-case-study-rebalancing.md`
- **Playground**: `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Playgrounds/Blog/Week11/03-fri-case-study-rebalancing.playground/Contents.swift`
- **Benchmark Tests**: `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Tests/BusinessMathTests/Benchmarks/PortfolioRebalancingBenchmarkTests.swift`
