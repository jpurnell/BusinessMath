# Nightly Conformance Audit — 2026-04-13

## Summary
- Auto-fixes applied: 8
- Items deferred for review: 68
- Test status after fixes: UNABLE TO RUN (sandbox restrictions blocked `swift build` and `swift test`)

## Auto-fixes applied
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:331` — `try!` → `try` in `multiplied(by:)` (already a `throws` function)
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:391` — `try!` → `try` in `+` operator (already a `throws` function)
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:421` — `try!` → `try` in `-` operator (already a `throws` function)
- `Tests/BusinessMathTests/Template Tests/StandardTemplatesTests.swift:54` — `as!` force cast → `try #require(model as? SaaSModel)`
- `Tests/BusinessMathTests/Template Tests/StandardTemplatesTests.swift:135` — `as!` force cast → `try #require(model as? RetailModel)`
- `Tests/BusinessMathTests/Template Tests/StandardTemplatesTests.swift:177` — `as!` force cast → `try #require(model as? ManufacturingModel)`
- `Tests/BusinessMathTests/Template Tests/StandardTemplatesTests.swift:203` — `as!` force cast → `try #require(model as? MarketplaceModel)`
- `Tests/BusinessMathTests/Template Tests/StandardTemplatesTests.swift:227` — `as!` force cast → `try #require(model as? SubscriptionBoxModel)`

## Deferred items

### XCTest migration
- No `import XCTest`, `XCTAssert*`, or `XCTestCase` found anywhere in `Tests/`. Migration to Swift Testing is complete.

### Strict concurrency warnings
- **Unable to run.** The CI sandbox blocked `swift build -Xswiftc -strict-concurrency=complete`. This check must be performed manually or in a CI job with build permissions.

### Missing DocC
- No undocumented public symbols found. All public declarations in `Sources/BusinessMath/` have `///` doc comments.

### Forbidden patterns — deferred

#### `try!` in source code (non-throwing context — cannot simply replace with `try`)
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:148` — `try! DenseMatrix(matrix)` in `identity(size:)` (non-throwing static func)
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:164` — `try! DenseMatrix(matrix)` in `diagonal(_:)` (non-throwing static func)
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:296` — `try! DenseMatrix(result)` in `transposed()` (non-throwing func)
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift:442` — `try! DenseMatrix(result)` in `*` operator (non-throwing func)

#### `try!` in test helpers (non-throwing context)
- `Tests/BusinessMathTests/Financial Statement Tests/DebtCovenantsTests.swift:28,35,42,49,56,63` — `try!` in `createTestIncomeStatement()` (returns non-optional, not `throws`)
- `Tests/BusinessMathTests/Financial Statement Tests/DebtCovenantsTests.swift:88,95,102,109,116,123,130` — `try!` in `createTestBalanceSheet()` (returns non-optional, not `throws`)
- `Tests/BusinessMathTests/Financial Statement Tests/DebtCovenantsTests.swift:1041-1046` — `try!` in `income()` helper (not `throws`)
- `Tests/BusinessMathTests/Financial Statement Tests/DebtCovenantsTests.swift:1052-1059` — `try!` in `balance()` helper (not `throws`)
- `Tests/BusinessMathTests/Optimization Tests/ConstrainedOptimizerTests.swift:170` — `try!` in non-throwing closure

#### Force unwraps (`!`) in source code
**Time Series:**
- `Sources/BusinessMath/Time Series/FiscalCalendar.swift:151-153,210` — `components.year!`, `.month!`, `.day!`
- `Sources/BusinessMath/Time Series/Period.swift:401-407,411-431,447,452,509-510,621-624,666-670,712-717,758-763,809-815,824-829,838-842,851-854,868,875,877,884` — Extensive `DateComponents` property force unwraps (~40 sites)
- `Sources/BusinessMath/Time Series/TimeSeriesOperations.swift:256-257,305-306` — dictionary subscript and component force unwraps
- `Sources/BusinessMath/Time Series/Growth/TrendModel.swift:277,716,1100-1101` — force unwrap of fitted model parameters

**Core/Collections:**
- `Sources/BusinessMath/Core/Collections/RingBuffer.swift:103,134` — `storage[actualIndex]!`

**Performance:**
- `Sources/BusinessMath/Performance/CalculationCache.swift:440,588` — `inflight[k]!`, `inflight[key]!`

**Financial Statements:**
- `Sources/BusinessMath/Financial Statements/CreditMetrics.swift:224-242,395-455,473,480,486` — timeSeries subscript force unwraps
- `Sources/BusinessMath/Financial Statements/TimeSeriesExtensions.swift:59,67,108-109` — timeSeries subscript force unwraps
- `Sources/BusinessMath/Financial Statements/BalanceSheet.swift:626,705,709,713-714` — aggregated dictionary force unwraps
- `Sources/BusinessMath/Financial Statements/AccountAdjustment.swift:417` — `self.ebitda[period]!`

**Operational Drivers:**
- `Sources/BusinessMath/Operational Drivers/DriverProjection.swift:265,290,341` — dictionary subscript force unwraps

**Simulation:**
- `Sources/BusinessMath/Simulation/MonteCarlo/ScenarioAnalysis.swift:428,449,456` — dictionary force unwraps
- `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift:463` — `gpuDevice!`

**Streaming:**
- `Sources/BusinessMath/Streaming/StreamingComposition.swift:264,469,590,712,1101,1594` — `box!` force unwraps
- `Sources/BusinessMath/Streaming/StreamingAnomalyDetection.swift:637,640,981` — `ewma!`, `bestBreakpoint!`
- `Sources/BusinessMath/Streaming/StreamingForecasting.swift:529` — `level!`, `trend!`
- `Sources/BusinessMath/Streaming/FFTBackend.swift:353-354,359` — `baseAddress!` on unsafe buffer pointers

#### `String(format:)` and `as!` in documentation only
- All `String(format:)` occurrences (50+) are in `.docc` markdown code examples, not executable source. No action needed.
- All `as!` occurrences in `Sources/` are in `///` doc comment examples in `StandardTemplates.swift:63,319,369`. No action needed.

### Hardcoded constants
**Optimization convergence thresholds:**
- `Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift:268` — `100` (convergence history window) → `convergenceHistoryWindowSize`
- `Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift:273` — `1_000_000` (1e-6 threshold) → `stagnationImprovementThreshold`
- `Sources/BusinessMath/Optimization/Heuristic/NelderMead.swift:262` — `50` (convergence window) → `convergenceCheckWindowSize`
- `Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift:253` — `1_000_000` (1e-6 threshold) → `stagnationImprovementThreshold`
- `Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift:254` — `10` (max stale iterations) → `maxIterationsWithoutImprovement`
- `Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift:222` — `1_000_000` (1e-6 threshold) → `stagnationImprovementThreshold`
- `Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift:223` — `10` (max stale generations) → `maxGenerationsWithoutImprovement`

**GPU/backend thresholds:**
- `Sources/BusinessMath/Optimization/Heuristic/GPU/MetalDevice.swift:555` — `1000` (GPU population threshold) → `gpuPopulationSizeThreshold`
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/MatrixBackend.swift:124` — `1000` (Metal threshold) → `metalGPUMatrixSizeThreshold`
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/MatrixBackend.swift:131` — `100` (Accelerate threshold) → `accelerateBackendMatrixSizeThreshold`
- `Sources/BusinessMath/Optimization/Heuristic/KMeansClustering.swift:493` — `1000`, `100`, `10` (GPU eligibility) → `gpuDataSizeThreshold`, `gpuMixedModeClusterThreshold`

**Numerical tolerances:**
- `Sources/BusinessMath/Statistics/Regression/MultipleLinearRegression.swift:239,328,330` — `1e-15`, `1e-10` → `varianceFloor`, `singularityTolerance`
- `Sources/BusinessMath/Statistics/Regression/MatrixOperations/CPUMatrixBackend.swift:142,182,190` — `1e-10`, `1e-15` → `pivotTolerance`, `singularMatrixTolerance`
- `Sources/BusinessMath/Finance/Portfolio/PortfolioOptimizer.swift:354,492,649` — `1e-10` → `volatilityFloor`

### Division safety
**Fluent API template models (all unguarded):**
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:223` — `annualCOGS / initialInventoryValue`
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:242` — `365.0 / turnover`
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:270` — `calculateNetProfit() / monthlyRevenue`
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:280` — `netProfit / revenue`
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:295` — `(1.0 - costOfGoodsSoldPercentage) / costOfGoodsSoldPercentage`
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:308` — `operatingExpenses / calculateGrossMargin()`
- `Sources/BusinessMath/Fluent API/Templates/RetailModel.swift:321,333,335` — `monthlyRevenue / squareFootage`, `avgRevenue / squareFootage`
- `Sources/BusinessMath/Fluent API/Templates/MarketplaceModel.swift:309,321,338,346` — divisions by `sellers` (could be zero)
- `Sources/BusinessMath/Fluent API/Templates/SaaSModel.swift:198` — `(arpu * margin) / churnRate`
- `Sources/BusinessMath/Fluent API/Templates/SaaSModel.swift:210` — `cac / averageRevenuePerUser`
- `Sources/BusinessMath/Fluent API/Templates/SaaSModel.swift:222` — `calculateLTV() / cac`
- `Sources/BusinessMath/Fluent API/Templates/ManufacturingModel.swift:144,153` — `monthlyOverhead / unitsProduced`, `/ production`
- `Sources/BusinessMath/Fluent API/Templates/ManufacturingModel.swift:182` — `margin / sellingPricePerUnit`
- `Sources/BusinessMath/Fluent API/Templates/ManufacturingModel.swift:193` — `monthlyOverhead / contributionMargin`
- `Sources/BusinessMath/Fluent API/Templates/ManufacturingModel.swift:214,224,237` — divisions by `productionCapacity`, `target`
- `Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:270,364` — `cashFlow / initialInvestment`
- `Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:372` — `year1NOI / purchasePrice`
- `Sources/BusinessMath/Fluent API/Templates/RealEstateModel.swift:384,388` — `principal / numberOfPayments`, denominator `(factor - 1)` could be zero

**Math/Options:**
- `Sources/BusinessMath/Options/BlackScholes.swift:161-163` — `log(spotPrice / strikePrice)` and `/ (volatility * sqrt(timeToExpiry))` — strikePrice, volatility, or timeToExpiry could be zero

### Dead code
- No unreferenced `private`/`fileprivate` symbols detected. The codebase is clean.

## Notes
- **Build/test sandbox restriction**: The CI environment did not permit running `swift build` or `swift test`. The strict concurrency audit could not be performed, and the auto-fixes could not be verified by a test run. **A follow-up CI job with build permissions should run `swift test` to confirm the 8 auto-fixes are safe.**
- **Documentation files excluded from auto-fix**: All `try!` and `String(format:)` occurrences in `.docc` markdown files were intentionally left untouched — these are tutorial code examples, not compiled source.
- **Test `try!` deferred**: The `try!` usages in `DebtCovenantsTests.swift` and `ConstrainedOptimizerTests.swift` are in non-throwing helper functions/closures. Converting them requires changing function signatures, which cascades to all callers. This is not a trivial fix.
- **Force unwraps are pervasive in `Period.swift`**: The `DateComponents` property unwraps (`.year!`, `.month!`, etc.) are the single largest category (~40 sites). A project-wide `DateComponents` safe-access extension could address all of them at once.
- **Division safety in template models**: The Fluent API business model templates (`SaaSModel`, `RetailModel`, `ManufacturingModel`, `MarketplaceModel`, `RealEstateModel`) have ~27 unguarded divisions. These are the highest-risk items for runtime crashes with user-provided inputs.
