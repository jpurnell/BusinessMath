# BusinessMath v2.0.0 Release Notes

**Release Date:** March 10, 2026

We're excited to announce **BusinessMath 2.0**—a major milestone bringing production-ready financial modeling, GPU-accelerated optimization, comprehensive security hardening, and industry-standard implementations to Swift.

---

## Highlights

| Feature | Description |
|---------|-------------|
| **Role-Based Financial Statements** | Accounts can now have multiple roles across Income Statement, Balance Sheet, and Cash Flow Statement |
| **GPU Acceleration** | 10-100x speedup for genetic algorithms on Apple Silicon via Metal |
| **100% Documentation** | All 198+ public APIs fully documented with DocC |
| **Security Hardening** | Division-by-zero safety, force unwrap elimination, type safety fixes |
| **4,558+ Tests** | Comprehensive test suite with strict Swift 6 concurrency compliance |
| **Linux Support** | Full cross-platform compatibility with swift-crypto fallback |

---

## Role-Based Financial Statements

**The Big Change:** Financial statements now use a **role-based architecture** that accurately reflects real-world accounting.

**Before (v1.x):**
```swift
let revenue = Account(name: "Revenue", type: .revenue, ...)
let cogs = Account(name: "COGS", type: .expense, expenseType: .cogs, ...)
```

**After (v2.0):**
```swift
let revenue = Account(name: "Revenue", incomeStatementRole: .revenue, ...)
let depreciation = Account(
    name: "Depreciation",
    incomeStatementRole: .operatingExpense,  // IS: expense
    cashFlowRole: .nonCashExpense            // CFS: add-back
)
```

**Why This Matters:**
- **Multi-statement accounts**: Depreciation, inventory changes, and other accounts can now appear in multiple statements with different roles
- **Accuracy**: Matches real-world financial reporting practices
- **Flexibility**: Add roles to accounts without breaking existing code

---

## GPU Acceleration for Optimization

Genetic algorithms now automatically use **Metal acceleration** on Apple Silicon, delivering **10-100x speedups** for large-scale problems.

```swift
let optimizer = GeneticAlgorithmOptimizer(
    objective: portfolioSharpeRatio,
    populationSize: 5000,        // Large populations benefit most
    useGPU: true                 // Automatic Metal acceleration
)
```

| Population Size | CPU Time | GPU Time | Speedup |
|-----------------|----------|----------|---------|
| 1,000 | 850ms | 85ms | **10x** |
| 5,000 | 4.2s | 95ms | **44x** |
| 10,000 | 8.5s | 102ms | **83x** |

---

## New Operator Helpers

### Contribution Margin Analysis
```swift
let is = IncomeStatement(...)
is.contributionMargin        // Revenue - Variable Costs
is.contributionMarginRatio   // CM / Revenue
is.breakEvenUnits            // Fixed Costs / CM per Unit
is.operatingLeverage         // CM / Operating Income
```

### Debt Classification
```swift
// New debt subtypes for sophisticated capital structure modeling
.revolvingCreditFacility, .termLoanShortTerm, .termLoanLongTerm,
.subordinatedDebt, .seniorSecuredDebt

let bs = BalanceSheet(...)
bs.interestBearingDebtByType  // Breakdown by debt instrument
```

### Pro Forma Adjustments
```swift
let synergy = AccountAdjustment(name: "Cost Synergies", mode: .add, value: -5_000_000)
let proFormaIS = incomeStatement.withProFormaEBITDA(adjustments: [synergy])
```

### Working Capital Tracking
```swift
let bs = BalanceSheet(...)
bs.netWorkingCapital                    // Current Assets - Current Liabilities
bs.workingCapitalComponents             // AR, Inventory, AP breakdown
bs.workingCapitalTurnover(revenue: ...)  // Efficiency ratio
```

---

## Security & Safety Improvements

### Division by Zero Safety
All financial calculations now safely handle edge cases:
```swift
// Before: Could return NaN or Infinity
let ratio = revenue / expenses  // If expenses = 0...

// After: Throws descriptive error
let ratio = try safeDivide(revenue, expenses)
// Throws: FinancialModelError.divisionByZero(numerator: 100000, denominator: 0)
```

### Force Unwrap Elimination
- **Phase 4 Complete**: All force unwraps (`!`) eliminated from production code
- Type-safe optionals throughout the API
- Descriptive errors instead of crashes

### Memory Safety
- Kahan summation algorithm for large dataset accumulation (prevents floating-point overflow)
- Bounded recursion in all algorithms
- Array bounds checking

---

## 61 Comprehensive Guides

Documentation completely reorganized into a **book-style structure** with specialized learning tracks:

**Five Parts:**
1. **Basics & Foundations** (7 guides) - Time series, TVM, core concepts
2. **Analysis & Statistics** (4 guides) - Sensitivity, ratios, risk metrics
3. **Modeling** (14 guides) - Growth, forecasting, valuations, statements
4. **Simulation & Uncertainty** (2 guides) - Monte Carlo, scenarios
5. **Optimization** (17 guides) - Portfolio optimization, algorithms, tutorials

**Four Learning Tracks:**
- **Financial Analyst** (15-20 hours): DCF, statements, forecasting
- **Risk Manager** (12-15 hours): VaR, Monte Carlo, stress testing
- **Quantitative Developer** (20-25 hours): Optimization, algorithms, validation
- **General Business** (10-12 hours): TVM, growth, budgeting

---

## New Features Summary

### Multiple Linear Regression
```swift
let regression = MultipleLinearRegression(
    predictors: featureMatrix,
    response: targetVector,
    backend: .accelerate  // CPU, Accelerate, or Metal
)
let coefficients = try regression.fit()
let predictions = regression.predict(newData)
```

### Four New Optimizers
- **AdaptiveOptimizer**: Automatically selects best algorithm based on problem characteristics
- **MultiStartOptimizer**: Global optimization with multiple starting points
- **AsyncOptimizer**: Streaming results for long-running optimizations
- **PerformanceBenchmark**: Profile and compare optimizer performance

### Async Streaming
```swift
// Stream Monte Carlo results as they compute
for try await partial in simulation.runStreaming() {
    updateProgressBar(partial.completedIterations)
    displayPreliminaryStats(partial.statistics)
}
```

---

## Test Suite & Quality

| Metric | v1.21.0 | v2.0.0 |
|--------|---------|--------|
| Total Tests | 2,062 | **4,558+** |
| Test Suites | 180 | **285+** |
| Pass Rate | 99.9% | **100%** |
| Documentation Coverage | ~60% | **100%** |
| Swift 6 Concurrency | Partial | **Full** |

---

## Linux Compatibility

Full cross-platform support with automatic fallbacks:
- Uses `swift-crypto` instead of CommonCrypto on Linux
- OSLog gracefully disabled on non-Apple platforms
- Compile-time platform detection (more reliable than runtime)
- All 4,558+ tests pass on Linux

---

## Migration from v1.x

### Breaking Changes

1. **Financial Statement Accounts**: Use role-based API
   ```swift
   // Old: type: .expense, expenseType: .cogs
   // New: incomeStatementRole: .costOfGoodsSold
   ```

2. **Optimization Parameters**: `initialGuess` replaces `x0` / `startingPoint`

3. **Error Types**: Consolidated into `FinancialModelError`

### Migration Time Estimates
- **Small projects** (< 10 files): ~1 hour
- **Medium projects** (10-50 files): ~2-3 hours
- **Large projects** (50+ files): ~4-6 hours

**Most changes are mechanical find-and-replace operations.**

See **[MIGRATION_GUIDE_v2.0.md](MIGRATION_GUIDE_v2.0.md)** for complete details.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath.git", from: "2.0.0")
]
```

**Requirements:**
- Swift 6.0+
- iOS 14+ / macOS 13+ / tvOS 14+ / watchOS 7+ / visionOS 1+ / Linux

---

## Resources

- **[Documentation Home](Sources/BusinessMath/BusinessMath.docc/BusinessMath.md)** - Complete guide structure
- **[Learning Paths](Sources/BusinessMath/BusinessMath.docc/LearningPath.md)** - Role-specific tracks
- **[Quick Start Example](QUICK_START_EXAMPLE.swift)** - Copy-paste investment analysis
- **[Examples](EXAMPLES.md)** - Code examples for common workflows
- **[Changelog](CHANGELOG.md)** - Complete version history

---

## Acknowledgments

BusinessMath 2.0 represents thousands of hours of development, testing, and documentation. Thank you to:
- The Swift community for excellent tooling and support
- Early adopters who provided feedback and bug reports
- Contributors who helped improve the library

---

## Reporting Issues

- **Issues**: [github.com/jpurnell/BusinessMath/issues](https://github.com/jpurnell/BusinessMath/issues)
- **Discussions**: [github.com/jpurnell/BusinessMath/discussions](https://github.com/jpurnell/BusinessMath/discussions)

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

*BusinessMath v2.0.0 - Production-ready financial modeling for Swift*
