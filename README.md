# BusinessMath

A comprehensive Swift library for business mathematics, time series analysis, and financial modeling.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

BusinessMath provides production-ready implementations of essential business and financial calculations. Built with modern Swift features including generics, strict concurrency (Swift 6), and comprehensive documentation, it's designed for financial analysts, business planners, data scientists, and software engineers building financial applications.

## Key Features

### 📅 Temporal Structures
- Period types (daily, monthly, quarterly, annual) with arithmetic operations
- Fiscal calendar support (custom year-ends: Apple, Australia, UK, etc.)
- Period ranges and iteration
- Date-based calculations with calendar awareness

### 📊 Time Series Analysis
- Generic time series container (`TimeSeries<T: Real>`)
- Operations: map, filter, zip, fill, interpolate, aggregate
- Analytics: growth rates, CAGR, moving averages, cumulative operations
- Seamless integration with temporal periods

### 💰 Time Value of Money
- Present and future value (single amounts and annuities)
- Loan payments and amortization schedules
- NPV, IRR, MIRR with iterative solvers
- XNPV, XIRR for irregular cash flows
- Profitability index and payback periods

### 📈 Growth & Forecasting
- Growth rate calculations (simple and compound)
- Trend models: Linear, Exponential, Logistic, Custom
- Seasonal decomposition (additive and multiplicative)
- Complete forecasting workflows

### ⚡ Performance
- Excellent performance for typical business use cases
- Sub-millisecond financial calculations
- Complete forecasts in < 50ms
- Handles datasets up to 50K periods
- See [PERFORMANCE.md](Time%20Series/PERFORMANCE.md) for details

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BusinessMath.git", from: "1.0.0")
]
```

Or in Xcode: **File** → **Add Package Dependencies** → Enter repository URL

## Quick Start

### Time Series Analysis

```swift
import BusinessMath

// Create monthly revenue time series
let periods = [
    Period.month(year: 2024, month: 1),
    Period.month(year: 2024, month: 2),
    Period.month(year: 2024, month: 3)
]
let revenue: [Double] = [100_000, 120_000, 115_000]

let ts = TimeSeries(periods: periods, values: revenue)

// Calculate growth rate
let growth = ts.growthRate(lag: 1)
print(growth.valuesArray)  // [0.20, -0.042]

// Moving average
let smoothed = ts.movingAverage(window: 2)
```

### Financial Calculations

```swift
// Calculate monthly mortgage payment
let payment = payment(
    presentValue: 300_000,    // Loan amount
    rate: 0.06 / 12,          // Monthly rate (6% annual)
    periods: 360,              // 30 years
    futureValue: 0,
    type: .ordinary
)
// Result: ~$1,799/month

// Evaluate an investment
let cashFlows = [-100_000.0, 30_000, 40_000, 50_000, 60_000]

let npv = npv(discountRate: 0.10, cashFlows: cashFlows)
// Result: ~$37,908 (positive → good investment)

let irr = try irr(cashFlows: cashFlows)
// Result: ~28.7% return
```

### Revenue Forecasting

```swift
// Historical data with seasonality
let historical = TimeSeries(periods: historicalPeriods, values: historicalRevenue)

// 1. Extract seasonal pattern
let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)

// 2. Deseasonalize
let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

// 3. Fit trend model
var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)

// 4. Project forward
let trendForecast = try trend.project(periods: 4)

// 5. Reapply seasonality
let forecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)
```

## Documentation

Comprehensive documentation is available in the package:

- **[Getting Started Guide](Sources/BusinessMath/BusinessMath.docc/GettingStarted.md)** - Quick introduction with examples
- **[Time Series Guide](Sources/BusinessMath/BusinessMath.docc/TimeSeries.md)** - Temporal data and operations
- **[Time Value of Money](Sources/BusinessMath/BusinessMath.docc/TimeValueOfMoney.md)** - Financial calculations reference
- **[Growth Modeling](Sources/BusinessMath/BusinessMath.docc/GrowthModeling.md)** - Forecasting and trends
- **[Building Revenue Model](Sources/BusinessMath/BusinessMath.docc/BuildingRevenueModel.md)** - Step-by-step tutorial
- **[Loan Amortization](Sources/BusinessMath/BusinessMath.docc/LoanAmortization.md)** - Complete loan analysis
- **[Investment Analysis](Sources/BusinessMath/BusinessMath.docc/InvestmentAnalysis.md)** - Investment evaluation

Total documentation: 3,676 lines across 9 comprehensive guides with real-world examples.

## Requirements

- Swift 6.0 or later
- macOS 10.15+ / Linux
- Dependencies:
  - [Swift Numerics](https://github.com/apple/swift-numerics) (for `Real` protocol)

## Testing

The library includes comprehensive test coverage:

- **531 tests** across 19 test suites
- **Functional tests**: 508 tests covering all operations
- **Performance tests**: 23 tests benchmarking large datasets
- **Integration tests**: 10 tests validating end-to-end workflows

Run tests:
```bash
swift test
```

## Performance

BusinessMath is optimized for real-world business applications:

| Operation | Performance | Use Case |
|-----------|-------------|----------|
| NPV/IRR calculations | < 1ms | ✅ Real-time analysis |
| Complete forecast workflow | < 50ms | ✅ Interactive dashboards |
| Trend fitting (1000 points) | ~170ms | ✅ User-initiated operations |
| Seasonal decomposition | ~150ms | ✅ Background processing |

See [PERFORMANCE.md](Time%20Series/PERFORMANCE.md) for detailed benchmarks and optimization guidance.

## Examples

### Loan Amortization Schedule

```swift
let principal = 300_000.0
let rate = 0.06 / 12
let periods = 360

let monthlyPayment = payment(presentValue: principal, rate: rate, periods: periods, futureValue: 0, type: .ordinary)

// Analyze specific payment
let payment1Interest = interestPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: principal, futureValue: 0, type: .ordinary)
let payment1Principal = principalPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: principal, futureValue: 0, type: .ordinary)

// First payment: ~$1,500 interest, ~$299 principal
```

### Investment with Irregular Cash Flows

```swift
let dates = [
    Date(),  // Today
    Date(timeIntervalSinceNow: 100 * 86400),  // 100 days
    Date(timeIntervalSinceNow: 250 * 86400),  // 250 days
    Date(timeIntervalSinceNow: 400 * 86400)   // 400 days
]
let cashFlows = [-100_000.0, 30_000, 50_000, 40_000]

let xnpvValue = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
let xirrValue = try xirr(dates: dates, cashFlows: cashFlows)
```

### Seasonal Revenue Pattern

```swift
// Quarterly revenue with Q4 spike
let quarters = (0..<12).map { Period.quarter(year: 2022 + $0/4, quarter: ($0 % 4) + 1) }
let revenue: [Double] = [100, 120, 110, 150, 105, 125, 115, 160, 110, 130, 120, 170]

let ts = TimeSeries(periods: quarters, values: revenue)

// Calculate seasonal indices
let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: 4)
// Result: [~0.84, ~1.01, ~0.93, ~1.22]
// Q1: 16% below average, Q4: 22% above average (holiday spike)
```

## Real-World Applications

- **Financial Modeling**: Revenue forecasting, budget planning, scenario analysis
- **Investment Analysis**: Portfolio valuation, IRR calculations, payback periods
- **Loan Management**: Amortization schedules, payment breakdowns, refinancing analysis
- **Business Intelligence**: Trend analysis, seasonal patterns, growth metrics
- **Risk Management**: Sensitivity analysis, Monte Carlo simulation setup
- **Reporting**: Financial dashboards, executive summaries, KPI tracking

## Architecture

BusinessMath follows modern Swift best practices:

- **Generic Programming**: `TimeSeries<T: Real>` works with any numeric type
- **Swift 6 Concurrency**: Full `Sendable` conformance for thread safety
- **Protocol-Oriented**: Flexible `TrendModel` protocol for custom implementations
- **Type Safety**: Strongly-typed periods prevent temporal mismatches
- **DocC Documentation**: Comprehensive inline documentation with examples
- **Test-Driven**: TDD approach with 531 tests ensuring correctness

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- All tests pass (`swift test`)
- New code has test coverage
- Documentation is updated
- Code follows Swift API design guidelines

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Justin Purnell

## Acknowledgments

- [Swift Numerics](https://github.com/apple/swift-numerics) for the `Real` protocol
- Swift community for excellent tools and documentation

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## Support

- **Documentation**: See the `.docc` folder for comprehensive guides
- **Issues**: Report bugs or request features via GitHub Issues
- **Performance**: Check [PERFORMANCE.md](Time%20Series/PERFORMANCE.md) for optimization tips

---

**Made with ❤️ using Swift 6.0**
