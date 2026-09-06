# BusinessMath

**Production-ready Swift library for financial analysis, forecasting, and quantitative modeling.**

Build DCF models, optimize portfolios, run Monte Carlo simulations, and value securities—with industry-standard implementations (ISDA, Black-Scholes) that work out of the box.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20|%20macOS%20|%20Linux-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Latest release: 2.13.0

2.7.0 is additive: no signature changes, no deletions, no behaviour changes to existing calls.
It adds `Statistics/Experiment/` — two-arm experiment design with `sampleSizePerArm`,
`achievedPower`, `minimumDetectableEffect` and `analyze` — and completes `Sendable` on nine
distribution types.

It also **deprecates two functions in `AB Test.swift`**, both of which were wrong rather than
merely dated. `pValue` returned `normSDist(|z|)`, always ≥ 0.5, so a `p < 0.05` test could
never be true; `sampleSize` is Cochran's single-sample survey formula, which understates a
two-arm A/B test by roughly 4.1×. Each carries a migration message naming its replacement.
Deprecations are warnings, not errors — but a consumer building with warnings-as-errors that
calls either function will need to migrate before upgrading.

### Previous release: 2.6.0

2.6.0 is a correctness release. It changes very few signatures and a great many *numbers* —
`poissonCDF` returned `P(X ≤ k−1)` at every integer argument, `normalCDF` lost its entire lower
tail to cancellation, `DriverProjection.percentile(0.10)` returned the p5 value, and one branch of
`correctedStdErr` had never executed in any released version. The CHANGELOG opens with a table of
every result that moved and by how much; read that before upgrading.

**It also breaks compatibility in four places**, each small and each worth knowing
before you upgrade rather than after:

- `FormulaError` gains a case, `nestingTooDeep(limit:)`. A switch over it that was
  exhaustive no longer compiles. The case exists because a long enough formula —
  `((((…))))` or `-----…1` — overflowed the stack and took the process, which no caller
  could catch.
- `@MCPTool` and `@BuilderInitializable` are removed. Neither had ever worked: the first
  generated an extension on a function name and referenced three types this package does
  not contain, the second an attribute it never emitted.
- The validation macros throw `MacroValidationError` from `BusinessMathMacros`. They
  previously threw a type declared inside the compiler plugin, which vends nothing to
  compiled code, so `@Validated` could not be used by anyone in any module.
- `VectorN` arithmetic on mismatched dimensions returns `NaN` instead of a vector of
  zeros, and `VectorN.zero` is now the additive identity rather than an annihilator —
  `zero + v` was `[0, 0]`, which made `var sum = VectorN.zero` silently drop the first
  element it was given.

| | |
|---|---|
| tests | 6,716 in 592 suites, all passing under strict concurrency |
| build | 0 warnings, library and test target |
| documentation coverage | 100% — 6,530 of 6,530 public APIs documented |
| DocC catalogue | 73 articles, every code block compiled against the module |
| toolchain | Swift 6.2 (`swift-tools-version: 6.2`) |

**See what's new:** [CHANGELOG.md](CHANGELOG.md)

---

## Why BusinessMath?

**Type-Safe & Concurrent**: Full Swift 6 compliance with generics (`TimeSeries<T: Real & Sendable>`) and strict concurrency for thread safety. Model closures are `@Sendable`. As of 2.6.0 the vector and optimizer types require `Real & BinaryFloatingPoint` rather than `Real` alone — the conversion that constraint supplies used to be faked with a runtime-cast ladder that answered `0.0` when it failed.

**Complete**: 73 comprehensive guides, 6,716 tests, and production implementations of valuation models, optimization algorithms, and risk analytics. **Every code block in the guides is compiled against the module** by the `doc-code` auditor (`quality-gate --check doc-code`), so an example that no longer matches the API fails the check rather than the reader.

**Accurate**: Calendar-aware calculations (365.25 days/year), industry-standard formulas (ISDA CDS pricing, Black-Scholes), and — where a result is an approximation — a measured accuracy recorded in the doc comment rather than an assurance. `inverseNormalCDF` is 2 ulp over `1e-12 ≤ p ≤ 1 − 1e-12`; `normalCDF` holds ~1e-14 relative down to `x = −37`. Numbers that changed in 2.6.0 are tabulated in the CHANGELOG with the measurement that found them.

**Fast**: GPU-accelerated genetic algorithms (10-100× for populations ≥ 1,000 on Apple Silicon), parallel and adaptive optimizer selection, and a benchmarking guide that shows how to measure your own workload rather than trusting a headline number — see [Performance Benchmarking](Sources/BusinessMath/BusinessMath.docc/5.11-PerformanceBenchmarking.md) and [Monte Carlo Performance](Sources/BusinessMath/BusinessMath.docc/4.4-MonteCarloPerformanceGuide.md).

**Ergonomic**: Fluent APIs that read like financial prose. Risk-aware examples that demonstrate real tradeoffs, not trivial solutions. Clear error messages and comprehensive debugging guides.

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
//
// Pass a `seed` unless you have a reason not to. If any input can't honor it —
// a custom-closure input, or correlated sampling — `run()` throws
// `SimulationError.seedingUnsupported` rather than quietly handing back a
// non-reproducible answer that looks fine.
var simulation = MonteCarloSimulation(iterations: 10_000, seed: 42) { inputs in
  // Model uncertain cash flows with ±20% volatility
  let year1 = 30_000 * (1 + inputs[0])
  let year2 = 40_000 * (1 + inputs[1])
  let year3 = 50_000 * (1 + inputs[2])
  let year4 = 60_000 * (1 + inputs[3])

  return npv(discountRate: 0.10, cashFlows: [-100_000, year1, year2, year3, year4])
}

// Add uncertainty inputs (normal distribution with 20% std dev).
// `DistributionNormal` conforms to `SeedableDistribution`, so each input draws
// from the run's generator and the seed above actually reaches the samples.
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

// Reproducibility is guaranteed per execution path: a seeded GPU run and a
// seeded CPU run are each internally reproducible but produce different
// streams, and a GPU failure falls back to the seeded CPU path, recorded in
// `results.executionNotes`. Set `enableGPU: false` to pin one path.

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

→ [Portfolio Optimization](Sources/BusinessMath/BusinessMath.docc/5.2-PortfolioOptimizationGuide.md) | [Optimization Guide](Sources/BusinessMath/BusinessMath.docc/5.1-OptimizationGuide.md) | [GPU Acceleration](Sources/BusinessMath/BusinessMath.docc/5.16-GPUAccelerationTutorial.md)

---

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath.git", from: "2.7.0")
]
```

**Or in Xcode:** File → Add Package Dependencies → Enter repository URL

The package vends three products: **`BusinessMath`** (the library), **`BusinessMathDSL`** (a declarative result-builder surface for expressing models and scenarios), and **`BusinessMathMacros`** (macro declarations backed by a SwiftSyntax plugin; not built on Linux). `BusinessMath` does not depend on the macros, so a Playground can import it without loading a compiler plugin.

---

## Getting Started

### 📚 Documentation
**73 comprehensive guides** organized into 5 parts (Basics, Analysis, Modeling, Simulation, Optimization):

- **[Documentation Home](Sources/BusinessMath/BusinessMath.docc/BusinessMath.md)** - Complete structure and index
- **[Learning Path Guide](Sources/BusinessMath/BusinessMath.docc/LearningPath.md)** - Four specialized tracks:
  - Financial Analyst (15-20 hours)
  - Risk Manager (12-15 hours)
  - Quantitative Developer (20-25 hours)
  - General Business (10-12 hours)
- **[Getting Started](Sources/BusinessMath/BusinessMath.docc/1.1-GettingStarted.md)** - Quick introduction with examples

### 💻 Code Examples
**Detailed examples** for common workflows:

- **[QUICK_START_EXAMPLE.swift](Examples/QUICK_START_EXAMPLE.swift)** - 🚀 Copy-paste investment analysis example (start here!)
- **[EXAMPLES.md](Documentation/EXAMPLES.md)** - Time series, forecasting, loans, securities, risk, optimization
- **[All DocC Tutorials](Sources/BusinessMath/BusinessMath.docc/)** - 73 comprehensive guides with compiled examples

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
- ✅ **Multiple linear regression** (OLS with QR decomposition; CPU, Accelerate, and Metal matrix backends)
- ✅ **Data envelopment analysis** (CCR and BCC, super-efficiency, async solver)
- ✅ **Hypothesis testing** (t-tests, chi-square, F-tests, A/B testing)
- ✅ **Model validation** (fake-data simulation, parameter recovery)
- ✅ **Reproducible simulation** (`seed: UInt64?` or `using: inout G` across the distribution family, Monte Carlo, scenario generation and the GPU path; unseeded paths are documented as non-reproducible by contract rather than left ambiguous)
- ✅ **Dependency cycles** (detection over formula-holding models, decidable linear/nonlinear classification, and exact solution of linear cycles rather than iteration)

### Documentation & Testing
- 📚 **73 comprehensive guides** (~50,900 lines of DocC documentation), every code block compiled against the module
- ✅ **100% documentation coverage** — 6,530 of 6,530 public APIs documented
- ✅ **6,716 tests** across 592 test suites (100% pass rate, 0 known issues)
- ✅ **Quality gate at 0 errors, 0 warnings** across 44 checkers, enforced by a pre-commit hook
- 📊 **Performance benchmarks** for typical use cases
- 🎓 **Learning paths** for different roles

## Requirements

- **Swift 6.2** or later — the manifest declares `swift-tools-version: 6.2`
- **Platforms**: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+, as declared in `Package.swift`. Linux and Android build too, with `BusinessMathMacros` excluded on Linux; Metal-backed GPU paths require Apple Silicon and fall back to CPU elsewhere.
- **Dependencies**: [Swift Numerics](https://github.com/apple/swift-numerics) (for `Real`), [Swift Collections](https://github.com/apple/swift-collections), [swift-docc-plugin](https://github.com/swiftlang/swift-docc-plugin), SwiftDeterminism (seeded generators), and [swift-crypto](https://github.com/apple/swift-crypto) — linked only where CryptoKit is absent (Linux, Android)

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

📢 **[Release history](CHANGELOG.md)** - Every release back to 1.0.0. The 2.6.0 entry opens with a table of the results that changed, since most of that release moves numbers without moving signatures.

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
- **Examples**: [QUICK_START_EXAMPLE.swift](Examples/QUICK_START_EXAMPLE.swift) | [EXAMPLES.md](Documentation/EXAMPLES.md)

---
