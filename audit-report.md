# Nightly Conformance Audit — 2026-04-12

## Summary
- Auto-fixes applied: 2
- Items deferred for review: 143
- Test status after fixes: UNABLE TO RUN (CI sandbox blocked Swift toolchain execution; fixes verified by code review only)

## Auto-fixes applied
- Sources/BusinessMathDSL/ScenarioAnalysis.swift:235-236 — Replaced `values.first!` / `values.last!` with `values.first ?? 0` / `values.last ?? 0` (guard on line 213 already ensures non-empty, so `?? 0` is a no-op safety net)
- Sources/BusinessMathDSL/LiquidationWaterfall.swift:122-124 — Changed `if let _ = tier.proRata` + `tier.proRata!.participants` to `if let proRata = tier.proRata` + `proRata.participants` (use the binding instead of re-unwrapping)

## Deferred items

### XCTest migration
No `import XCTest`, `XCTAssert*`, or `XCTestCase` found in Tests/. Migration to Swift Testing appears complete.

### Strict concurrency warnings
CI sandbox blocked `swift build -Xswiftc -strict-concurrency=complete`. Unable to capture concurrency diagnostics this run. Note: Package.swift already enables `StrictConcurrency` on Swift 6+.

### Missing DocC
Documentation coverage is excellent overall (~99% in BusinessMathDSL, strong coverage in BusinessMath). The following public symbols lack `///` doc comments but are **trivially documentable** (purpose obvious from name):
- Sources/BusinessMathDSL/CashFlowModel.swift:150 — `public let revenue: Revenue?`
- Sources/BusinessMathDSL/CashFlowModel.swift:152 — `public let expenses: Expenses?`
- Sources/BusinessMathDSL/CashFlowModel.swift:154 — `public let depreciation: Depreciation?`
- Sources/BusinessMathDSL/CashFlowModel.swift:156 — `public let taxes: Taxes?`
- Sources/BusinessMathDSL/TerminalValue.swift:52 — `public let method: TerminalValueMethod`
- Sources/BusinessMathDSL/Tier.swift:16 — `public let name: String`
- Sources/BusinessMathDSL/Tier.swift:18 — `public let priority: Int`
- Sources/BusinessMathDSL/ScenarioAnalysis.swift:151 — `public let scenarios: [Scenario]`
- Sources/BusinessMathDSL/Forecast.swift:117 — `public let years: Int`
- Sources/BusinessMathDSL/TierComponents.swift:138 — `public let participants: [(name: String, percentage: Double)]`

### Forbidden patterns — force unwraps (deferred)

#### `try!` in Sources/ (7 occurrences)
All in DenseMatrix.swift — constructing provably-rectangular arrays. Safe rewrite requires a non-throwing internal init (non-trivial refactor):
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:148 — `try! DenseMatrix(matrix)` in `identity(size:)`
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:164 — `try! DenseMatrix(matrix)` in `diagonal(_:)`
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:296 — `try! DenseMatrix(result)` in `transposed()`
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:331 — `try! DenseMatrix(result)` in `multiplied(by:)`
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:391 — `try! DenseMatrix(result)` in `+` operator
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:421 — `try! DenseMatrix(result)` in `-` operator
- Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:442 — `try! DenseMatrix(result)` in `*` scalar operator

**Suggested fix**: Add a `private init(unchecked data: [[T]])` that skips rectangularity validation, then replace all 7 `try!` calls with it.

#### `!` force unwraps in Sources/ (100+ occurrences)

**DateComponents unwraps** (~80+ in Period.swift, 4 in FiscalCalendar.swift):
- Sources/BusinessMath/Time Series/Period.swift: lines 338-339, 343-344, 348-349, 353-354, 361, 367-368, 374-375, 381-382, 401-431, 447, 452, 509, 621-624, 666-670, 712-717, 758-763, 809-814, 824-829, 838-842, 851-854, 868, 875, 877, 884
- Sources/BusinessMath/Time Series/FiscalCalendar.swift:151, 152, 153, 210

**VectorN.fromArray()! unwraps** (24 occurrences across optimization heuristics):
- Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift:344, 360
- Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift:450, 745, 780
- Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift:215, 351, 430, 444
- Sources/BusinessMath/Optimization/Heuristic/NelderMead.swift:327, 358, 383, 408, 433, 458
- Sources/BusinessMath/Optimization/Heuristic/IslandModel.swift:249
- Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift:246, 609, 635, 685, 698, 711
- Sources/BusinessMath/Optimization/IntegerProgramming/IntegerSpecification.swift:127
- Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift:1183

**Financial statement force unwraps** (~35 in CreditMetrics.swift, 5 in BalanceSheet.swift, 4 in TimeSeriesExtensions.swift, 1 in AccountAdjustment.swift):
- Sources/BusinessMath/Financial Statements/CreditMetrics.swift:224, 225, 229, 233, 238, 242, 395, 399, 403, 404, 406, 423, 424, 427, 428, 434, 435, 439, 440, 450, 451, 454, 455, 473, 480, 486
- Sources/BusinessMath/Financial Statements/BalanceSheet.swift:626, 705, 709, 713, 714
- Sources/BusinessMath/Financial Statements/TimeSeriesExtensions.swift:59, 67, 108, 109
- Sources/BusinessMath/Financial Statements/AccountAdjustment.swift:417

**Other Sources/ force unwraps**:
- Sources/BusinessMath/Time Series/TimeSeriesOperations.swift:256, 257
- Sources/BusinessMath/Core/Collections/RingBuffer.swift:103, 134
- Sources/BusinessMath/Operational Drivers/DriverProjection.swift:265, 290, 341
- Sources/BusinessMath/Performance/CalculationCache.swift:440, 588
- Sources/BusinessMath/Simulation/MonteCarlo/ScenarioAnalysis.swift:428, 449, 456
- Sources/BusinessMath/Time Series/Growth/TrendModel.swift:277, 716, 1080, 1100, 1101
- Sources/BusinessMath/Finance/Portfolio/PortfolioOptimizer.swift:106, 111

#### `as!` force casts in Sources/
All occurrences are in `///` doc comment examples only (Sources/BusinessMath/Fluent API/Templates/StandardTemplates.swift:63, 319, 369). No code-level `as!` found.

#### `try!` in Tests/ (27 occurrences — not auto-fixed per rules)
- Tests/BusinessMathTests/Optimization Tests/ConstrainedOptimizerTests.swift:170
- Tests/BusinessMathTests/Financial Statement Tests/DebtCovenantsTests.swift:28, 35, 42, 49, 56, 63, 88, 95, 102, 109, 116, 123, 130, 1041-1046, 1052, 1055-1059

#### `as!` force casts in Tests/ (5 occurrences — not auto-fixed per rules)
- Tests/BusinessMathTests/Template Tests/StandardTemplatesTests.swift:54, 135, 177, 203, 227

#### `try!` in QUICK_START_EXAMPLE.swift (5 occurrences)
- QUICK_START_EXAMPLE.swift:35, 36, 58, 80, 92

### Hardcoded constants
Top 20 magic numbers in computation paths:

1. Sources/BusinessMathDSL/Forecast.swift:197 — `365.0` (days per year in working capital calc) -> `daysPerYear`
2. Sources/BusinessMathDSL/CashFlowModel.swift:247 — `4.0` (quarters per year) -> `quartersPerYear`
3. Sources/BusinessMathDSL/Revenue.swift:159 — `4.0` (quarters per year) -> `quartersPerYear`
4. Sources/BusinessMath/Time Series/PeriodType.swift:145-149 — `365.25`, `12.0`, `4.0` (calendar constants) -> `daysPerYearAccounting`, `monthsPerYear`, `quartersPerYear`
5. Sources/BusinessMath/Time Series/PeriodType.swift:215-221 — `86_400_000.0`, `86_400.0`, `1_440.0`, `24.0` (time conversion factors) -> `millisecondsPerDay`, `secondsPerDay`, `minutesPerDay`, `hoursPerDay`
6. Sources/BusinessMathDSL/ScenarioAnalysis.swift:250 — `100.0` (percentile scale) -> `percentileScale`
7. Sources/BusinessMathDSL/Revenue.swift:110 — `0.001` (seasonality tolerance) -> `seasonalityTolerance`
8. Sources/BusinessMathDSL/TierComponents.swift:149 — `0.001` (pro-rata tolerance) -> `proRataTolerance`
9. Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:102 — `0.05` (default vacancy rate) -> `defaultVacancyRate`
10. Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:105 — `0.03` (default closing costs) -> `defaultClosingCostsRate`
11. Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:106 — `0.025` (default rent growth) -> `defaultRentGrowthRate`
12. Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:107 — `27.5` (IRS residential depreciation years) -> `residentialDepreciationYears`
13. Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:108 — `0.24` (default tax rate) -> `defaultTaxRate`
14. Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:135 — `2.0` (initial inventory months of COGS) -> `defaultInventoryMonthsOfCogs`
15. Sources/BusinessMath/Error Handling/ValidationFramework.swift:314 — `1.5` (IQR outlier multiplier) -> `iqrOutlierMultiplier`
16. Sources/BusinessMath/Fluent API/ScenarioBuilder.swift:556 — `0.001` (probability tolerance) -> `probabilityTolerance`
17. Sources/BusinessMath/Valuation/Debt/NelsonSiegel.swift:47 — `2.5` (default lambda) -> `nelsonSiegelDefaultLambda`
18. Sources/BusinessMath/Valuation/Debt/NelsonSiegel.swift:373, 379, 382 — `0.03`, `0.10`, `-0.03`, `0.005` (beta bounds) -> `nsBeta0Min`, `nsBeta0Max`, `nsBeta1Min`, `nsBeta2Initial`
19. Sources/BusinessMath/Statistics/Comparison Statistics/nemenyiCD.swift:85-86 — Statistical q-values (Nemenyi critical values) -> `nemenyiQCriticalAlpha005`, `nemenyiQCriticalAlpha010`
20. Sources/BusinessMath/Statistics/Regression/MultipleLinearRegression.swift:477-481 — Beasley-Springer-Moro coefficients (unnamed arrays) -> `beasleySpringerMoroCoefficientsA/B/C`

### Division safety
Top 30 unguarded divisions where the divisor is a variable without a zero-guard in scope:

**Critical — parameter-based divisors in financial calculations:**
1. Sources/BusinessMath/Valuation/Debt/BondPricing.swift:341 — `annualCoupon / price` (price param, no guard)
2. Sources/BusinessMath/Valuation/Debt/BondPricing.swift:390 — `weightedTime / bondPrice` (no zero check)
3. Sources/BusinessMath/Valuation/Debt/BondPricing.swift:620 — `faceValue / price` (price param, no guard)
4. Sources/BusinessMath/Valuation/Debt/BondPricing.swift:478 — `convexitySum / (denominator * m * m)` (denominator includes price)
5. Sources/BusinessMath/Valuation/Debt/BondPricing.swift:980 — `weightedTime / bondPrice`
6. Sources/BusinessMath/Valuation/Debt/BondPricing.swift:1024 — `convexitySum / denominator`
7. Sources/BusinessMath/Valuation/Debt/NelsonSiegel.swift:367 — `(bond.faceValue - bond.marketPrice) / bond.marketPrice / bond.maturity`
8. Sources/BusinessMath/Valuation/Equity/FCFEModel.swift:290 — `totalEquityValue / sharesOutstanding`
9. Sources/BusinessMath/Valuation/Equity/ResidualIncomeModel.swift:397 — `totalEquityValue / sharesOutstanding`
10. Sources/BusinessMath/Valuation/Equity/EnterpriseValueBridge.swift:268 — `equity / sharesOutstanding`

**Moderate — TimeSeries / ratio calculations:**
11. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:115 — `netIncome / averageAssets`
12. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:169 — `netIncome / averageEquity`
13. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:243 — `nopat / averageInvestedCapital`
14. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:298 — `revenue / averageAssets`
15. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:367 — `cogsTimeSeries / averageInventory`
16. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:429 — `daysPerYear / $0` (turnover could be zero)
17. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:489 — `revenue / averageReceivables`
18. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:550 — `daysPerYear / $0` (turnover could be zero)
19. Sources/BusinessMath/Financial Statements/FinancialRatios.swift:628 — `averagePayables / cogsTimeSeries`

**Lower — computed divisors:**
20. Sources/BusinessMath/Valuation/Debt/CallableBond.swift:469 — `numerator / denominator` (includes bond price)
21. Sources/BusinessMath/Valuation/Debt/CallableBond.swift:371 — `(priceUp - modelPrice) / bump`
22. Sources/BusinessMath/Valuation/Debt/RecoveryModel.swift:291 — `numerator / denominator` (PD*T could be zero)
23. Sources/BusinessMath/Bayes/Bayes.swift:33 — `(probabilityTrueGivenD * probabilityD) / pT`
24. Sources/BusinessMath/Simulation/MonteCarlo/Compilation/ExpressionFunction.swift:184 — `(newValue - oldValue) / oldValue` (% change)
25. Sources/BusinessMath/Simulation/MonteCarlo/Compilation/ExpressionFunction.swift:296 — `(portfolioReturn - riskFreeRate) / volatility` (Sharpe ratio)
26. Sources/BusinessMath/Simulation/MonteCarlo/Compilation/ExpressionMatrix.swift:360 — `weightedVolSum / portfolioVol`
27. Sources/BusinessMath/Simulation/MonteCarlo/Compilation/ExpressionMatrix.swift:369 — `covariance / (sigma1 * sigma2)`
28. Sources/BusinessMath/Scenario Analysis/SensitivityAnalysis.swift:877 — `(to - from) / Double(steps - 1)` (steps=1 -> div by zero)
29. Sources/BusinessMath/Streaming/StreamingAnomalyDetection.swift:1330 — `totalScore / Double(methods.count)` (empty methods)
30. Sources/BusinessMathDSL/TerminalValue.swift:77 — `finalFCF * (1.0 + growth.rate) / (wacc - growth.rate)` (wacc == growth.rate -> div by zero)

### Dead code
1. Sources/BusinessMath/Validation/FinancialValidation.swift:27 — `private func total(_ accounts: [Account<T>], _ period: Period) -> T` — declared with `@inline(__always)` but never called within the file. The `validate` method computes sums directly instead.

## Notes
- **Swift toolchain unavailable**: The CI sandbox blocked all `swift build` / `swift test` / `swift build -Xswiftc -strict-concurrency=complete` commands. The two auto-fixes are syntactically trivial and semantically verified by code review, but build/test confirmation was not possible. A follow-up CI run should verify.
- **XCTest migration complete**: No legacy XCTest imports found — the test suite has fully migrated to Swift Testing.
- **DocC coverage is strong**: ~99% of public API has doc comments. Only a handful of trivial stored properties lack them.
- **`String(format:)` not used**: No occurrences found anywhere in the codebase.
- **`as!` in code**: No `as!` force casts in executable code; only in doc comment examples.
- **Force unwraps are concentrated**: Period.swift alone accounts for ~80 of the 100+ force unwraps in Sources/ (all DateComponents/Calendar.date() unwraps). The optimization heuristics account for another 24 (VectorN.fromArray()!). A targeted refactor of these two patterns would eliminate the majority.
- **DenseMatrix `try!` pattern**: All 7 `try!` occurrences construct provably-rectangular arrays. The recommended fix is a `private init(unchecked:)` initializer — a one-time refactor that would cleanly eliminate all 7.
- **Division safety in financial ratios**: FinancialRatios.swift has 9 unguarded divisions by TimeSeries values. These are standard financial ratio calculations where zero denominators indicate degenerate inputs. Consider adding a `guardedDivide` helper or returning `nil`/`.nan` for zero-denominator cases.
- **QUICK_START_EXAMPLE.swift**: Contains 5 `try!` usages. Since this is example code (not Sources/ or Tests/), it was not auto-fixed, but should be updated for pedagogical reasons.
