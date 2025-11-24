# BusinessMath

A comprehensive Swift library for business mathematics, time series analysis, and financial modeling.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

BusinessMath provides production-ready implementations of essential business and financial calculations. Built with modern Swift features including generics, strict concurrency (Swift 6), and comprehensive documentation, it's designed for financial analysts, business planners, data scientists, and software engineers building financial applications.

## ✨ What's New in v1.3.0

**Major Test Suite Expansion & Platform Compatibility**

- **🧪 2,062 Tests**: Expanded from 531 to 2,062 tests across 180 test suites (289% increase)
- **📊 DataTable Analysis**: New Excel-like data table functionality for sensitivity analysis and scenario planning
- **⚡ Performance Tests**: Enabled 19 performance benchmarking tests for large datasets and optimized exports
- **🔧 32-bit Compatibility**: Fixed overflow issues in distribution functions for Apple Watch and other 32-bit platforms
- **✅ 100% Pass Rate**: All tests passing with comprehensive coverage of distributions, statistics, and analysis tools

See [CHANGELOG.md](CHANGELOG.md) for complete release details.

## 🤖 MCP Server (v1.20.0 - Major Expansion)

BusinessMath includes a comprehensive **Model Context Protocol (MCP) server** that exposes all functionality to AI assistants like Claude Desktop, enabling natural language financial analysis, modeling, and advanced analytics.

### What's Included

**✨ 118 Computational Tools** across 24 categories:
- **Time Value of Money** (9 tools): NPV, IRR, PV, FV, payments, annuities, XNPV, XIRR
- **Time Series Analysis** (6 tools): Growth rates, moving averages, CAGR, comparisons
- **Forecasting** (8 tools): Trend analysis, seasonal adjustment, projections
- **Debt & Financing** (6 tools): Amortization, WACC, CAPM, coverage ratios
- **Statistical Analysis** (7 tools): Correlation, regression, confidence intervals, z-scores
- **Monte Carlo Simulation** (7 tools): Risk modeling, 15 distributions, sensitivity analysis
- **Hypothesis Testing** (6 tools): T-tests, chi-square, F-tests, sample size, A/B testing, p-values
- **Advanced Statistics** (13 tools): Combinatorics, statistical means, goal seek, data tables
- **Probability Distributions** (15 distributions): Normal, Uniform, Triangular, Exponential, Lognormal, Beta, Gamma, Weibull, Chi-Squared, F, T, Pareto, Logistic, Geometric, Rayleigh
- **Optimization & Solvers** (3 tools): Newton-Raphson, gradient descent, capital allocation
- **Portfolio Optimization** (3 tools): Modern Portfolio Theory, efficient frontier, risk parity
- **Real Options** (5 tools): Black-Scholes, binomial trees, Greeks, expansion/abandonment valuation
- **Risk Analytics** (4 tools): Stress testing, VaR/CVaR, risk aggregation, comprehensive metrics
- **Financial Ratios** (9 tools): Asset turnover, current ratio, quick ratio, D/E, interest coverage, inventory turnover, profit margin, ROE, ROI
- **Bayesian Statistics** (1 tool): Bayes' theorem with posterior probability calculations
- **Valuation Calculators** (12 tools): EPS, BVPS, P/E, P/B, P/S, market cap, enterprise value, EV/EBITDA, EV/Sales, working capital, debt-to-assets, free cash flow
- **Investment Metrics** (4 tools): Profitability index, payback period, discounted payback, Modified IRR
- **Loan Payment Analysis** (4 tools): Principal payment (PPMT), interest payment (IPMT), cumulative interest, cumulative principal
- **Growth Analysis** (2 tools): Simple growth rate, compound growth projections with various compounding frequencies
- **Trend Forecasting** (4 tools): Linear trend, exponential trend, logistic trend, time series decomposition
- **Seasonality** (3 tools): Calculate seasonal indices, seasonally adjust data, apply seasonal patterns
- **Advanced Options** (2 tools): Option Greeks (Delta, Gamma, Vega, Theta, Rho), binomial tree pricing (American & European)

**📚 14 Resources** providing comprehensive documentation:
- Time Value of Money formulas and examples
- Statistical analysis reference
- Monte Carlo simulation guide
- Forecasting techniques
- Optimization and solvers guide
- Portfolio optimization guide
- Real options valuation guide
- Risk analytics and stress testing guide
- Investment analysis examples
- Loan amortization examples
- Financial glossary (JSON)
- Distribution reference

**🎯 6 Prompt Templates** for guided workflows:
- Investment analysis
- Financing comparison
- Risk assessment
- Revenue forecasting
- Portfolio analysis
- Debt analysis

### Quick Start with MCP Server

**Using Claude Desktop** (Recommended - stdio mode):

1. Build the server:
```bash
swift build -c release
```

2. Configure Claude Desktop (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "businessmath": {
      "command": "/path/to/BusinessMath/.build/release/businessmath-mcp-server"
    }
  }
}
```

3. Restart Claude Desktop and start using natural language:
   - "Calculate the NPV of an investment with initial cost $100,000 and annual returns of $30,000 for 5 years at 10% discount rate"
   - "What's the profitability index for this investment?"
   - "Calculate the payback period and discounted payback period"
   - "Show me the MIRR with 8% financing rate and 6% reinvestment rate"
   - "Break down the first payment on a $300,000 mortgage at 6% - how much is principal vs interest?"
   - "Run a Monte Carlo simulation with 10,000 iterations for a revenue model with normal distribution (mean: $1M, stddev: $200K)"
   - "Forecast my quarterly revenue using exponential trend with historical data: [100, 120, 145, 175]"
   - "Calculate seasonal indices for my monthly sales data with annual seasonality"
   - "Calculate the option Greeks for a call option: spot $100, strike $105, 6 months expiry, 20% volatility"
   - "Price this American put option using binomial tree with 100 steps"
   - "Optimize a portfolio across 3 assets to maximize Sharpe ratio"
   - "Calculate VaR at 95% confidence for my portfolio returns"
   - "What's the P/E ratio if EPS is $5.50 and stock price is $82.50?"
   - "Run a stress test on baseline revenue of $10M and costs of $7M using a recession scenario"

**HTTP Mode** (Experimental):
```bash
.build/release/businessmath-mcp-server --http 8080
```

See [HTTP_MODE_README.md](HTTP_MODE_README.md) for details and limitations. HTTP mode is experimental; stdio mode is recommended for production use.

### Technical Details

- Built with the **official MCP Swift SDK** (v0.10.2)
- Full support for MCP capabilities: tools, resources, prompts, logging
- macOS 13.0+ required
- Comprehensive error handling and validation
- Strict concurrency (Swift 6) for thread safety

### Documentation

- **[CHANGELOG.md](CHANGELOG.md)** - Complete version history and release notes
- **[HTTP_MODE_README.md](HTTP_MODE_README.md)** - HTTP transport documentation
- **MCP Resources** - Access via `resources/read` in Claude Desktop for comprehensive guides

## Library Features

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
- See [PERFORMANCE.md](Examples/PERFORMANCE.md) for details

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath.git", from: "1.0.0")
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
- **[Data Table Analysis](Sources/BusinessMath/BusinessMath.docc/DataTableAnalysis.md)** - Excel-like sensitivity analysis ✨ **NEW**
- **[Monte Carlo with Time Series](Sources/BusinessMath/BusinessMath.docc/MonteCarloTimeSeriesGuide.md)** - Probabilistic forecasting & confidence intervals ✨ **NEW**

Total documentation: 5,300+ lines across 11 comprehensive guides with real-world examples.

## Requirements

- Swift 6.0 or later
- macOS 10.15+ / Linux
- Dependencies:
  - [Swift Numerics](https://github.com/apple/swift-numerics) (for `Real` protocol)

## Testing

The library includes comprehensive test coverage:

- **2,062 tests** across 180 test suites ✨ **NEW in v1.3.0**
- **Functional tests**: Core library operations and features
- **Performance tests**: 19 tests benchmarking large datasets and optimized exports
- **Integration tests**: End-to-end workflows
- **Distribution tests**: Comprehensive coverage of all 15 probability distributions
- **Advanced Statistics tests**: GoalSeek, DataTable, and analysis tools

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

See [PERFORMANCE.md](Examples/PERFORMANCE.md) for detailed benchmarks and optimization guidance.

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
- **Test-Driven**: TDD approach with 2,062 tests ensuring correctness

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
- **Performance**: Check [PERFORMANCE.md](Examples/PERFORMANCE.md) for optimization tips

---

**Made with ❤️ using Swift 6.0**
