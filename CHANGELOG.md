# Changelog

All notable changes to BusinessMath will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-15

### Added

**Bayes' Theorem Implementation**
- New `bayes(_:_:_:)` function for calculating posterior probabilities
- Comprehensive DocC documentation with medical test example
- Formula: P(D|T) = [P(T|D) × P(D)] / [P(T|D) × P(D) + P(T|¬D) × P(¬D)]
- 5 comprehensive tests covering various scenarios:
  - Medical test with 1% disease prevalence
  - High prior probability cases
  - Perfect test accuracy
  - Low prior with imperfect test
  - Symmetric cases

**Rayleigh Distribution**
- `distributionRayleigh(mean:)` function using inverse transform method
- `DistributionRayleigh` struct conforming to `DistributionRandom` protocol
- Generates non-negative random values from Rayleigh distribution
- Use cases: modeling magnitude of 2D vectors, radio signal fading
- 3 comprehensive tests:
  - Function variant with statistical validation
  - Struct variant (random() and next() methods)
  - Edge cases with small mean values

### Fixed
- Removed incorrect `import Testing` from production Bayes.swift
- Fixed parameter typo: `probabiityTGivenNotD` → `probabilityTrueGivenNotD`
- Removed duplicate function definition in Bayes Tests
- Removed unnecessary `async/await` from Bayes tests
- Cleaned up "zzz In Process" directory (NPV now in production)

### Technical Details
- Total test count: 539 tests (531 previous + 5 Bayes + 3 Rayleigh)
- All tests passing
- No breaking changes
- Fully backward compatible with v1.0.0

## [1.0.0] - 2025-10-15

### Added - Complete BusinessMath Library

This is the initial production release of BusinessMath, featuring comprehensive business mathematics, time series analysis, and financial modeling capabilities.

#### Core Temporal Structures (Phase 1)

**PeriodType Enum**
- Four period types: daily, monthly, quarterly, annual
- Comparable ordering (daily < monthly < quarterly < annual)
- Period conversion with precise calendar calculations (365.25 days/year)
- Properties: `daysApproximate`, `monthsEquivalent`
- Codable, CaseIterable conformance
- 32 comprehensive tests

**Period Struct**
- Factory methods: `month(year:month:)`, `quarter(year:quarter:)`, `year(_:)`, `day(_:)`
- Properties: `startDate`, `endDate`, `label`
- Custom formatting via DateFormatter
- Period subdivision: `months()`, `quarters()`, `days()`
- Type-first comparison for consistent sorting
- Precondition validation (month 1-12, quarter 1-4)
- Sendable conformance for Swift 6 concurrency
- 56 comprehensive tests

**Period Arithmetic**
- Strideable conformance enabling ranges: `jan...dec`
- Operators: `Period + Int`, `Period - Int`
- Methods: `distance(to:)`, `advanced(by:)`, `next()`
- Handles month boundaries, year boundaries, and leap years correctly
- 46 comprehensive tests

**FiscalCalendar Struct**
- Support for custom fiscal year-ends (Apple, Australia, UK, etc.)
- Methods: `fiscalYear(for:)`, `fiscalQuarter(for:)`, `fiscalMonth(for:)`, `periodInFiscalYear(_:)`
- MonthDay helper struct with validation
- Static `standard` property for calendar year (Dec 31)
- Sendable, Codable, Equatable conformance
- 40 comprehensive tests

#### Time Series Container (Phase 2)

**TimeSeries Struct**
- Generic container: `TimeSeries<T: Real & Sendable>`
- Initializers: `init(periods:values:)`, `init(data:)` with automatic sorting
- Duplicate period handling (keeps last value)
- Subscript access with optional and default value variants
- Properties: `valuesArray`, `count`, `first`, `last`, `isEmpty`
- `range(from:to:)` for subset extraction
- Sequence conformance for iteration and standard library operations
- TimeSeriesMetadata for descriptive information
- Sendable conformance for thread safety
- 38 comprehensive tests (37 passing, 1 skipped due to Swift limitation)

**Time Series Operations**
- Transformations: `mapValues(_:)`, `filterValues(_:)`, `zip(with:_:)`
- Filling: `fillForward(over:)`, `fillBackward(over:)`, `fillMissing(with:over:)`, `interpolate(over:)`
- Aggregation: `aggregate(to:method:)` with six methods (sum, average, first, last, min, max)
- Supports monthly → quarterly → annual aggregation
- Period alignment in binary operations (intersection)
- 23 comprehensive tests

**Time Series Analytics**
- Growth analysis: `growthRate(lag:)`, `cagr(from:to:years:)`
- Moving averages: `movingAverage(window:)`, `exponentialMovingAverage(alpha:)`
- Cumulative operations: `cumulative()`, `rollingSum(window:)`, `rollingMin(window:)`, `rollingMax(window:)`
- Changes: `diff(lag:)`, `percentChange(lag:)`
- All operations preserve metadata
- 25 comprehensive tests

#### Time Value of Money (Phase 3)

**Present Value Functions**
- `presentValue(futureValue:rate:periods:)` - Single amount PV
- `presentValueAnnuity(payment:rate:periods:type:)` - Annuity PV with ordinary/due
- AnnuityType enum (ordinary, due)
- Handles edge cases: zero rate, zero periods, negative rates (deflation)
- Comprehensive DocC with formulas and real-world examples
- 25 comprehensive tests

**Future Value Functions**
- `futureValue(presentValue:rate:periods:)` - Single amount FV
- `futureValueAnnuity(payment:rate:periods:type:)` - Annuity FV with ordinary/due
- Reciprocal relationship with present value functions
- Handles edge cases and negative rates
- 28 comprehensive tests

**Payment Functions**
- `payment(presentValue:rate:periods:futureValue:type:)` - Loan payment calculation
- `principalPayment(rate:period:totalPeriods:presentValue:futureValue:type:)` - PPMT
- `interestPayment(rate:period:totalPeriods:presentValue:futureValue:type:)` - IPMT
- `cumulativeInterest(rate:startPeriod:endPeriod:totalPeriods:presentValue:futureValue:type:)` - CUMIPMT
- `cumulativePrincipal(rate:startPeriod:endPeriod:totalPeriods:presentValue:futureValue:type:)` - CUMPRINC
- Support for balloon payments via futureValue parameter
- 27 comprehensive tests

**IRR Functions**
- `irr(cashFlows:guess:tolerance:maxIterations:)` - Internal rate of return via Newton-Raphson
- `mirr(cashFlows:financeRate:reinvestmentRate:)` - Modified IRR
- IRRError enum (convergenceFailed, invalidCashFlows, insufficientData)
- Validates cash flows (requires positive and negative)
- Configurable convergence parameters
- 27 comprehensive tests

**XNPV/XIRR Functions**
- `xnpv(rate:dates:cashFlows:)` - NPV with irregular date intervals
- `xirr(dates:cashFlows:guess:tolerance:maxIterations:)` - IRR with irregular dates
- XNPVError enum with comprehensive error handling
- Fractional year calculations (365-day year basis)
- Newton-Raphson method with XNPV derivatives
- 20 comprehensive tests

**NPV Functions**
- `npv(discountRate:cashFlows:)` - Net present value
- `npv(rate:timeSeries:)` - TimeSeries variant
- `npvExcel(rate:cashFlows:)` - Excel-compatible NPV (t=1 for first flow)
- `profitabilityIndex(rate:cashFlows:)` - PI = (NPV + investment) / investment
- `paybackPeriod(cashFlows:)` - Simple payback (returns Int?)
- `discountedPaybackPeriod(rate:cashFlows:)` - Time-value adjusted payback
- Comprehensive documentation explaining differences from Excel
- 46 comprehensive tests

#### Growth & Trend Models (Phase 4)

**Growth Rate Functions**
- `growthRate(from:to:)` - Simple growth rate
- `cagr(beginningValue:endingValue:years:)` - Compound annual growth rate
- `applyGrowth(baseValue:rate:periods:compounding:)` - Project future values
- CompoundingFrequency enum (annual, semiannual, quarterly, monthly, daily, continuous)
- Handles zero/negative values appropriately
- 33 comprehensive tests

**Trend Models**
- TrendModel protocol with `fit(to:)` and `project(periods:)`
- LinearTrend: Constant absolute growth (y = mx + b)
- ExponentialTrend: Constant percentage growth (y = a × e^(bx))
- LogisticTrend: S-curve with capacity limit
- CustomTrend: Closure-based for custom functions
- TrendModelError enum (modelNotFitted, insufficientData, invalidData, projectionFailed)
- Sendable conformance throughout
- 20 comprehensive tests

**Seasonality Functions**
- `seasonalIndices(timeSeries:periodsPerYear:)` - Calculate seasonal factors
- `seasonallyAdjust(timeSeries:indices:)` - Remove seasonality
- `applySeasonal(timeSeries:indices:)` - Add seasonality back
- `decomposeTimeSeries(timeSeries:periodsPerYear:method:)` - Separate components
- DecompositionMethod enum (additive, multiplicative)
- TimeSeriesDecomposition struct (trend, seasonal, residual)
- SeasonalityError enum with comprehensive error handling
- Centered moving average for trend extraction
- 18 comprehensive tests

#### Testing & Documentation (Phase 5)

**Integration Tests**
- 10 end-to-end workflow tests:
  - Complete financial model (NPV, IRR, payback)
  - Time series to NPV workflow
  - Historical to forecast workflow
  - Revenue projection with seasonality
  - Monthly to quarterly aggregation
  - Multi-year business planning
  - Complete investment analysis
  - Loan amortization workflow
  - Multi-stage growth modeling
  - Real estate investment with XIRR
- All tests passing, validating component integration

**Documentation Catalog**
- 9 comprehensive DocC markdown files (3,676 lines):
  - BusinessMath.md: Landing page with navigation
  - GettingStarted.md: Comprehensive quickstart (7.3 KB)
  - TimeSeries.md: In-depth time series guide (12 KB)
  - TimeValueOfMoney.md: Complete TVM reference (15 KB)
  - GrowthModeling.md: Forecasting guide (16 KB)
  - BuildingRevenueModel.md: Step-by-step tutorial (14 KB)
  - LoanAmortization.md: Complete loan analysis (17 KB)
  - InvestmentAnalysis.md: Investment evaluation (18 KB)
  - Resources/ directory for future enhancements
- Every article includes real-world examples, formulas, and best practices
- Cross-references between related topics
- Hierarchical topic organization

**Performance Testing**
- 23 performance benchmark tests:
  - Large time series creation (10K, 50K periods)
  - Time series access patterns (random access, iteration)
  - Chained operations on large datasets
  - NPV benchmarks (100, 1000 cash flows)
  - IRR convergence (10, 50 cash flows)
  - XNPV/XIRR with irregular dates
  - Trend fitting (linear, exponential, logistic)
  - Trend projection (1000 periods)
  - Seasonal analysis (indices, adjustment, decomposition)
  - Moving average and EMA on large series
  - Complete workflow benchmarks
  - Memory usage with multiple large series
- PERFORMANCE.md documentation (12 KB):
  - Detailed metrics for all operations
  - Performance ratings (Excellent/Very Good/Acceptable)
  - Real-world performance guidance
  - Bottleneck identification
  - Optimization recommendations

### Technical Details

**Swift Features**
- Swift 6.0 with strict concurrency checking
- Full Sendable conformance for thread safety
- Generic programming with `Real` protocol from Swift Numerics
- Protocol-oriented design (TrendModel, Sequence conformance)
- Swift Testing framework (@Test, #expect syntax)
- DocC documentation throughout

**Quality Metrics**
- 531 total tests (all passing)
- 19 test suites
- 508 functional tests
- 23 performance tests
- 10 integration tests
- Test-Driven Development (TDD) approach throughout
- No compiler warnings
- Zero known bugs

**Performance Characteristics**
- NPV/IRR: < 1ms per operation (excellent for real-time)
- Complete forecasts: < 50ms (excellent for interactive use)
- Trend fitting: 40-170ms for 300-1000 points (very good)
- Seasonal decomposition: 14-160ms for 10 years (very good)
- Large time series: O(n²) initialization (acceptable, with optimization opportunities)

**Dependencies**
- Swift Numerics for `Real` protocol

### Known Limitations

1. **Time Series Initialization**: O(n²) complexity due to duplicate detection. Optimization opportunity identified (can be reduced to O(n)).
2. **Period.next()**: Uses Calendar.dateComponents each call. Optimization opportunity for monthly periods.
3. **Large Datasets**: Creation of 10K+ period time series takes 20-60s. Acceptable for typical business use (< 1000 periods).

### Migration Guide

This is the initial release. No migration required.

## [Unreleased]

### Planned Enhancements
- Optimize time series initialization (O(n²) → O(n))
- Optimize Period.next() with caching
- Moving average circular buffer implementation
- Hero images for documentation
- Web-hosted documentation export
- Additional statistical functions (correlation, covariance)
- Polynomial trend models
- Monte Carlo simulation framework
- CSV/JSON import/export for time series

---

## Release Notes

### What's New in 1.0.0

BusinessMath 1.0.0 is a comprehensive, production-ready library for business mathematics and financial modeling in Swift. Key highlights:

- **📅 Temporal Structures**: Complete period types with arithmetic and fiscal calendar support
- **📊 Time Series**: Generic container with 20+ operations and analytics functions
- **💰 TVM**: All standard financial functions (PV, FV, PMT, NPV, IRR, XIRR)
- **📈 Forecasting**: Trend models and seasonal decomposition for complete forecasting workflows
- **✅ Quality**: 531 tests, comprehensive documentation, excellent performance
- **🚀 Modern Swift**: Swift 6 concurrency, generics, protocol-oriented design

Perfect for:
- Financial analysts building valuation models
- Business planners doing revenue forecasting
- Data scientists analyzing temporal data
- Engineers building financial applications

### Breaking Changes

None (initial release).

### Deprecations

None (initial release).

### Bug Fixes

None (initial release - all tests passing).

---

**For detailed implementation history, see [04_IMPLEMENTATION_CHECKLIST.md](Time%20Series/04_IMPLEMENTATION_CHECKLIST.md)**
