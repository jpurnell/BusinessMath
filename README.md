# BusinessMath

**Production-ready Swift library for financial analysis, forecasting, and quantitative modeling.**

Build DCF models, optimize portfolios, run Monte Carlo simulations, and value securities—with industry-standard implementations (ISDA, Black-Scholes) that work out of the box.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20|%20macOS%20|%20Linux-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🎉 Version 2.0 Released!

**Major milestone:** Production-ready API with role-based financial statements, GPU-accelerated optimization, and unified parameter naming.

- ✅ **Role-Based Financial Statements:** Multi-statement account support for accurate financial modeling
- ✅ **GPU Acceleration:** 10-100× speedup for genetic algorithms (populations ≥ 1,000) on Apple Silicon
- ✅ **Consistent API:** `initialGuess` parameter everywhere
- ✅ **Constraint Support:** Equality and inequality constraints via penalty method
- ✅ **Stable:** Semantic versioning guarantees (see [STABILITY.md](STABILITY.md))
- ✅ **3,552+ Tests:** 99.9% pass rate across 278 test suites

**Upgrading from 1.x?** Financial statements now use role-based API (accounts can appear in multiple statements). [Full migration guide →](MIGRATION_GUIDE_v2.0.md)

**New to GPU acceleration?** [Get started with the GPU tutorial →](GPU_ACCELERATION_TUTORIAL.md)

---

## Why BusinessMath?

**Type-Safe & Concurrent**: Full Swift 6 compliance with generics (`TimeSeries<T: Real>`) and strict concurrency for thread safety.

**Complete**: 44 comprehensive guides, 2,000+ tests, and production implementations of valuation models, optimization algorithms, and risk analytics.

**Accurate**: Calendar-aware calculations (365.25 days/year), industry-standard formulas (ISDA CDS pricing, Black-Scholes), and validated against real-world use cases.

**Fast**: Sub-millisecond NPV/IRR calculations, complete forecasts in <50ms, optimized for interactive dashboards and real-time analysis.

---

## Quick Example: Investment Analysis

```swift
import BusinessMath

// Complete investment analysis workflow
let cashFlows = [-100_000.0, 30_000, 40_000, 50_000, 60_000]

// 1. Evaluate profitability
let npvValue = npv(discountRate: 0.10, cashFlows: cashFlows)
// → $38,877 ✓ Positive NPV

let irrValue = try irr(cashFlows: cashFlows)
// → 24.9% return ✓ Exceeds hurdle rate

let pi = profitabilityIndex(rate: 0.10, cashFlows: cashFlows)
// → 1.389 ✓ Good investment (> 1.0)

// 2. Sensitivity analysis: How sensitive is NPV to discount rate?
let rates = [0.05, 0.07, 0.10, 0.12, 0.15]
let sensitivityTable = DataTable<Double, Double>.oneVariable(
  inputs: rates,
  calculate: { rate in npv(discountRate: rate, cashFlows: cashFlows) }
)

for (rate, npvResult) in sensitivityTable {
  print("Rate: \((rate * 100).smartRounded())%: NPV: \(npvResult.currency())")
}
// Shows NPV ranges from $57K (5% rate) to $23K (15% rate)

// 3. Risk assessment: Monte Carlo simulation for uncertain cash flows
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
  // Model uncertain cash flows with ±20% volatility
  let year1 = 30_000 * (1 + inputs[0])
  let year2 = 40_000 * (1 + inputs[1])
  let year3 = 50_000 * (1 + inputs[2])
  let year4 = 60_000 * (1 + inputs[3])

  return npv(discountRate: 0.10, cashFlows: [-100_000, year1, year2, year3, year4])
}

// Add uncertainty inputs (normal distribution with 20% std dev)
for year in 1...4 {
  simulation.addInput(SimulationInput(
    name: "Year \(year) Return Variance",
    distribution: DistributionNormal(0.0, 0.20)
  ))
}

let results = try simulation.run()
let var95 = results.valueAtRisk(confidenceLevel: 0.95)

print("\nRisk Analysis:")
print("Expected NPV: \(results.statistics.mean.currency())")
print("95% VaR: \(abs(var95).currency()) (worst case with 95% confidence)")
print("Probability of loss: \((results.probabilityBelow(0) * 100).number())%")

// → Decision: Approve investment ✓
//    Strong positive NPV, profitable across rate scenarios, low probability of loss
```

This shows the power of BusinessMath: **calculate, analyze, and decide** in one workflow.

---

## What You Can Build

### 📊 Financial Modeling & Forecasting
Build revenue models, forecast cash flows, and model business scenarios with calendar-aware time series operations. Supports daily through annual periods with fiscal calendar alignment (Apple, Australia, UK, etc.).

→ [Guide: Building Revenue Models](Sources/BusinessMath/BusinessMath.docc/3.3-BuildingRevenueModel.md) | [Forecasting Guide](Sources/BusinessMath/BusinessMath.docc/3.2-ForecastingGuide.md)

### 💰 Investment Evaluation
Calculate NPV, IRR, MIRR, profitability index, and payback periods. Handle irregular cash flows with XNPV/XIRR. Includes loan amortization with payment breakdowns (PPMT, IPMT).

→ [Guide: Investment Analysis](Sources/BusinessMath/BusinessMath.docc/3.8-InvestmentAnalysis.md) | [Time Value of Money](Sources/BusinessMath/BusinessMath.docc/1.3-TimeValueOfMoney.md)

### 📈 Securities Valuation
Value equities (DCF, DDM, FCFE, residual income), price bonds (duration, convexity, credit spreads), and analyze credit derivatives (CDS pricing with ISDA Standard Model, Merton structural model).

→ [Equity Valuation](Sources/BusinessMath/BusinessMath.docc/3.9-EquityValuationGuide.md) | [Bond Valuation](Sources/BusinessMath/BusinessMath.docc/3.10-BondValuationGuide.md) | [Credit Derivatives](Sources/BusinessMath/BusinessMath.docc/3.11-CreditDerivativesGuide.md)

### 📉 Risk & Simulation
Run Monte Carlo simulations with 15 probability distributions. Calculate VaR/CVaR, perform stress testing, and aggregate portfolio risks. Model uncertainty with scenario analysis.

→ [Monte Carlo Guide](Sources/BusinessMath/BusinessMath.docc/4.1-MonteCarloTimeSeriesGuide.md) | [Risk Analytics](Sources/BusinessMath/BusinessMath.docc/2.3-RiskAnalyticsGuide.md)

### ⚡ Optimization
Optimize portfolios (efficient frontier, Sharpe ratio maximization), solve integer programming problems (branch-and-bound, cutting planes), and allocate capital optimally. **GPU-accelerated genetic algorithms** provide 10-100× speedup for large-scale optimization (populations ≥ 1,000) with automatic Metal acceleration on Apple Silicon.

→ [Portfolio Optimization](Sources/BusinessMath/BusinessMath.docc/5.2-PortfolioOptimizationGuide.md) | [Optimization Guide](Sources/BusinessMath/BusinessMath.docc/5.1-OptimizationGuide.md) | **[GPU Acceleration Tutorial](GPU_ACCELERATION_TUTORIAL.md)**

### 🤖 AI Assistant Integration
BusinessMath includes an MCP server that lets AI assistants (like Claude Desktop) perform financial analysis using natural language. **167 tools** across time value of money, forecasting, optimization, and valuation—all accessible through conversation.

```
"Calculate NPV for a $100k investment with $30k annual returns over 5 years at 10%"
"Optimize a 3-asset portfolio to maximize Sharpe ratio"
"Forecast quarterly revenue with exponential trend and seasonality"
```

→ [Full MCP Server Documentation](MCP_README.md)

---

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath.git", from: "2.0.0")
]
```

**Or in Xcode:** File → Add Package Dependencies → Enter repository URL

---

## Getting Started

### 📚 Documentation
**44 comprehensive guides** organized into 5 parts (Basics, Analysis, Modeling, Simulation, Optimization):

- **[Documentation Home](Sources/BusinessMath/BusinessMath.docc/BusinessMath.md)** - Complete structure and index
- **[Learning Path Guide](Sources/BusinessMath/BusinessMath.docc/LearningPath.md)** - Four specialized tracks:
  - Financial Analyst (15-20 hours)
  - Risk Manager (12-15 hours)
  - Quantitative Developer (20-25 hours)
  - General Business (10-12 hours)
- **[Getting Started](Sources/BusinessMath/BusinessMath.docc/1.1-GettingStarted.md)** - Quick introduction with examples

### 💻 Code Examples
**Detailed examples** for common workflows:

- **[QUICK_START_EXAMPLE.swift](QUICK_START_EXAMPLE.swift)** - 🚀 Copy-paste investment analysis example (start here!)
- **[EXAMPLES.md](EXAMPLES.md)** - Time series, forecasting, loans, securities, risk, optimization
- **[GPU_ACCELERATION_TUTORIAL.md](GPU_ACCELERATION_TUTORIAL.md)** - GPU-accelerated optimization tutorial
- **[Examples Folder](Examples/)** - Complete financial models and case studies
- **[PERFORMANCE.md](Examples/PERFORMANCE.md)** - Benchmarks and optimization tips

## What's Included

### Core Library
- ✅ **Generic time series** with calendar-aware operations
- ✅ **Time value of money** (NPV, IRR, MIRR, XNPV, XIRR, annuities)
- ✅ **Forecasting** (trend models: linear, exponential, logistic)
- ✅ **Seasonal decomposition** (additive and multiplicative)
- ✅ **Growth modeling** (CAGR, trend fitting)
- ✅ **Loan amortization** (payment schedules, PPMT, IPMT)
- ✅ **Financial statements** (role-based architecture with multi-statement account support)
- ✅ **Securities valuation** (equity: DCF, DDM, FCFE; bonds: pricing, duration, convexity; credit: CDS, Merton model)
- ✅ **Risk analytics** (VaR, CVaR, stress testing)
- ✅ **Monte Carlo simulation** (15 distributions, sensitivity analysis)
- ✅ **Portfolio optimization** (efficient frontier, Sharpe ratio, risk parity)
- ✅ **Genetic algorithms** (GPU-accelerated for populations ≥ 1,000, automatic Metal acceleration)
- ✅ **Integer programming** (branch-and-bound, cutting planes)
- ✅ **Financial ratios** (profitability, leverage, efficiency)
- ✅ **Real options** (Black-Scholes, binomial trees, Greeks)
- ✅ **Hypothesis testing** (t-tests, chi-square, F-tests, A/B testing)
- ✅ **Model validation** (fake-data simulation, parameter recovery)

### Documentation & Testing
- 📚 **44 comprehensive guides** (8,500+ lines of DocC documentation)
- ✅ **3,552 tests** across 278 test suites (99.9% pass rate)
- 📊 **Performance benchmarks** for typical use cases
- 🎓 **Learning paths** for different roles

### MCP Server
- 🤖 **169 computational tools** for AI assistants
- 📚 **14 resources** with comprehensive documentation
- 🎯 **6 prompt templates** for guided workflows
- 🔗 **Stdio & HTTP modes** (stdio recommended for production)

See [MCP_README.md](MCP_README.md) for full AI integration details.

---

## Requirements

- **Swift 6.0** or later
- **Platforms**: iOS 14+ / macOS 13+ / tvOS 14+ / watchOS 7+ / visionOS 1+ / Linux
- **Dependencies**: [Swift Numerics](https://github.com/apple/swift-numerics) (for `Real` protocol)
- **MCP Server**: macOS 13+ (for AI assistant integration)

---

## Real-World Applications

- **Financial Analysts**: Revenue forecasting, DCF valuation, scenario analysis
- **Risk Managers**: VaR/CVaR calculation, Monte Carlo simulation, stress testing
- **Corporate Finance**: Capital allocation, WACC, financing decisions, lease accounting
- **Portfolio Managers**: Efficient frontier, Sharpe ratio optimization, risk parity
- **Quantitative Developers**: Algorithm implementation, model validation, backtesting
- **FP&A Teams**: Budget planning, KPI tracking, executive dashboards

---

## Release Notes

📢 **[v2.0.0 Release Notes](RELEASE_NOTES_v2.0.0.md)** - Complete what's new guide for the 2.0 release

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Ensure all tests pass (`swift test`)
4. Add tests for new functionality
5. Update documentation
6. Open a Pull Request

📖 See **[CONTRIBUTING.md](CONTRIBUTING.md)** for detailed guidelines and code standards.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

- **Documentation**: [BusinessMath.docc](Sources/BusinessMath/BusinessMath.docc/)
- **Issues**: [GitHub Issues](https://github.com/jpurnell/BusinessMath/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jpurnell/BusinessMath/discussions)
- **Examples**: [EXAMPLES.md](EXAMPLES.md) | [Examples Folder](Examples/)

---
