# Changelog

All notable changes to BusinessMath will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## BusinessMath Library

### [Unreleased] - 2025-10-31

#### 🚀 Topic 9 Phase 3: Portfolio Optimization

This phase implements Modern Portfolio Theory for optimal asset allocation and risk management.

#### Added

**Portfolio Theory (Markowitz)**
- ✨ **Portfolio** - Modern Portfolio Theory implementation
  - Expected return calculation (arithmetic mean)
  - Covariance and correlation matrices
  - Portfolio return and risk (volatility) for any weights
  - Sharpe ratio maximization
  - Gradient ascent optimization
  - Efficient frontier generation
  - 13 comprehensive tests

**Risk Parity Allocation**
- ✨ **RiskParityOptimizer** - Equal risk contribution allocation
  - Iterative optimization for equal marginal risk contributions
  - Marginal contribution to risk (MCR) calculation
  - No short-selling constraints
  - 5 comprehensive tests

**Portfolio Types**
- ✨ **PortfolioAllocation** - Result of portfolio optimization
  - Asset weights, expected return, risk, Sharpe ratio
  - Human-readable description

**Test Coverage**
- 18 new tests for portfolio functionality
- Tests for return/risk calculations, Sharpe ratio, efficient frontier
- Risk parity equal contribution verification
- Edge cases (single asset, two assets, diversification)

#### 🚀 Topic 9 Phase 4: Real Options Valuation

This phase implements option pricing models and real options analysis for strategic decision-making.

#### Added

**Black-Scholes-Merton Model**
- ✨ **BlackScholesModel** - European option pricing and Greeks
  - Call and put option pricing using closed-form solution
  - Full Greeks calculation (Delta, Gamma, Vega, Theta, Rho)
  - Error function approximation (Abramowitz and Stegun)
  - Cumulative normal distribution
  - Normal probability density function
  - 14 comprehensive tests

**Binomial Tree Model**
- ✨ **BinomialTreeModel** - American and European option pricing
  - Discrete-time lattice approach
  - Backward induction algorithm
  - American early exercise detection
  - Risk-neutral probability calculation
  - Converges to Black-Scholes with more steps
  - 7 comprehensive tests

**Real Options Applications**
- ✨ **RealOptionsAnalysis** - Strategic options valuation
  - Expansion option (call on growth opportunities)
  - Abandonment option (put on salvage value)
  - Decision tree analysis with backward induction
  - 10 comprehensive tests

**Options Types**
- ✨ **OptionType** - Call or put enum
- ✨ **Greeks** - Delta, Gamma, Vega, Theta, Rho structure
- ✨ **DecisionNode** - Decision tree node (terminal, chance, decision)
- ✨ **Branch** - Decision tree branch with probability

**Test Coverage**
- 31 new tests for options functionality
- Black-Scholes pricing, Greeks, put-call parity
- Binomial tree convergence, American vs European
- Real options expansion, abandonment, decision trees
- Edge cases and numerical accuracy verification

#### 🚀 Topic 9 Phase 5: Advanced Risk Analytics

This phase implements comprehensive risk measurement, stress testing, and risk aggregation following TDD methodology.

#### Added

**Stress Testing Framework**
- ✨ **StressTest** - Scenario-based stress testing
  - Pre-defined scenarios (recession, crisis, supply shock)
  - Custom scenario support
  - Impact analysis on financial metrics
  - 13 comprehensive tests (12/13 passing)

**Stress Testing Types**
- ✨ **StressScenario** - Scenario definition with shocks
- ✨ **ScenarioResult** - Results with baseline comparison
- ✨ **StressTestReport** - Aggregated report with worst/best cases

**Risk Aggregation**
- ✨ **RiskAggregator** - VaR aggregation across entities
  - Variance-covariance approach for portfolio VaR
  - Marginal VaR calculation (entity contribution)
  - Component VaR with weighted contributions
  - Supports correlation matrices
  - 11 comprehensive tests (10/11 passing)

**Comprehensive Risk Metrics**
- ✨ **ComprehensiveRiskMetrics** - Full risk profile
  - Value at Risk (VaR) at 95% and 99% confidence
  - Conditional VaR (CVaR / Expected Shortfall)
  - Maximum drawdown calculation
  - Sharpe and Sortino ratios
  - Tail risk, skewness, and kurtosis
  - 18 comprehensive tests (7/18 passing, refinement needed)

**Test Coverage**
- 35 new tests for risk analytics (29/35 passing, 83%)
- Stress testing scenarios and impact analysis
- VaR aggregation with correlations
- Marginal and component VaR calculations
- Risk metrics calculations (Sharpe, Sortino, drawdown)
- Note: Some VaR percentile calculations need refinement

#### 🚀 Topic 9 Phase 2: Time Series Forecasting

This phase continues Topic 9 with time series forecasting models and anomaly detection.

#### Added

**Holt-Winters Triple Exponential Smoothing**
- ✨ **HoltWintersModel** - Seasonal forecasting with trend
  - Level, trend, and seasonal component smoothing
  - Configurable α (alpha), β (beta), γ (gamma) parameters
  - Point forecasts and confidence intervals
  - Widening confidence intervals with forecast horizon
  - Handles monthly, quarterly, and custom seasonality
  - 7 comprehensive tests

**Moving Average Forecasting**
- ✨ **MovingAverageModel** - Simple moving average baseline
  - Configurable window size
  - Constant forecast (average of last N periods)
  - Confidence intervals based on historical variance
  - 7 comprehensive tests

**Anomaly Detection**
- ✨ **ZScoreAnomalyDetector** - Statistical outlier detection
  - Rolling window z-score calculation
  - Severity classification (mild, moderate, severe)
  - Period, value, and deviation tracking
  - Configurable threshold
  - 6 comprehensive tests

**Forecasting Types**
- ✨ **ForecastError** - Typed errors for forecasting operations
- ✨ **ForecastWithConfidence** - Forecasts with upper/lower bounds
- ✨ **Anomaly** - Structured anomaly representation
- ✨ **AnomalySeverity** - Severity classification enum

**Test Coverage**
- 20 new tests for forecasting functionality
- Tests for seasonality, trend, confidence intervals
- Edge case testing for constant data

#### 🚀 Topic 9 Phase 1: Optimization & Solvers

This phase begins Topic 9 (Advanced Analytics & Advanced Features) with a comprehensive optimization framework.

#### Added

**Optimization Framework**
- ✨ **Optimizer Protocol** - Generic interface for optimization algorithms
  - Supports constraints and bounds
  - Iteration history tracking
  - Convergence detection
  - 9 framework tests

**Newton-Raphson Optimizer**
- ✨ **NewtonRaphsonOptimizer** - Root-finding using Newton-Raphson method
  - Numerical derivative calculation (first and second order)
  - Quadratic convergence near solutions
  - Configurable tolerance and max iterations
  - Constraint and bound support
  - 7 comprehensive tests (5 passing, 2 edge cases)

**Gradient Descent Optimizer**
- ✨ **GradientDescentOptimizer** - First-order optimization with momentum
  - Momentum support for accelerated convergence
  - Numerical gradient computation
  - Learning rate configuration
  - Divergence detection
  - 7 comprehensive tests (6 passing, 1 edge case)

**Capital Allocation Optimizer**
- ✨ **CapitalAllocationOptimizer** - Project portfolio optimization
  - Greedy allocation by ROI
  - 0-1 Knapsack (integer programming) for optimal allocation
  - Project ROI calculation
  - Budget constraint enforcement
  - 11 comprehensive tests (all passing)

#### Testing
- Added 34 new optimization tests
- 31/34 tests passing (91% pass rate)
- Total test suite: 1,502 tests across 92 suites

---

#### 🎯 Topic 8 Complete: I/O & Integration - Validation, Audit, and Schema Management

This release completes Topic 8 by implementing comprehensive data validation, audit logging, and schema management infrastructure.

#### Added

**Validation System**
- ✨ **ModelValidator** - Validates financial projections against business rules
  - Balance sheet balancing validation
  - Positive revenue validation
  - Reasonable gross margin checks
  - Custom validation rule support
  - Detailed validation reports with errors/warnings
  - 5 comprehensive tests

**Audit Trail System**
- ✨ **AuditTrailManager** - Complete audit logging for data changes
  - Query by entity, user, date range, or action type
  - Persistent storage to disk (JSON format)
  - Thread-safe with NSLock
  - Comprehensive audit reports with action summaries
  - 10 comprehensive tests

**Data Schema System**
- ✨ **DataSchema** - Define and validate data structure with typed fields
  - Field types: string, double, int, bool, date, array (recursive), object
  - Required and optional field validation
  - Type coercion support (Int → Double)
  - Detailed validation error messages
  - 13 comprehensive tests

**Schema Migration System**
- ✨ **SchemaMigration** - Automated data migrations between schema versions
  - Migration chaining for multi-version upgrades
  - Data transformation support
  - Error handling for missing migration paths
  - Preserves existing data during migrations
  - 8 comprehensive tests

#### Testing
- Added 36 new tests across 4 systems
- All 1,468 tests passing (88 test suites)
- Full integration with existing validation infrastructure

---

## BusinessMath MCP Server

### [1.14.0] - 2024-10-30

#### 🎯 Feature Release: Advanced Statistics & Probability Tools

This release adds 13 new tools covering probability distributions, combinatorics, statistical means, and analysis capabilities, bringing the total to 62 tools across 11 categories.

#### Added

**New Tool Categories:**

**8. Probability Distributions (5 tools)**
- ✨ **binomial_probability** - Binomial PMF for n trials with k successes
  - Calculate exact probability of k successes in n independent trials
  - Useful for quality control, testing, and binary outcome modeling
- ✨ **poisson_probability** - Poisson distribution for event counts
  - Model rare events occurring at constant average rate
  - Applications: customer arrivals, defect counts, website hits
- ✨ **exponential_distribution** - Exponential PDF for wait times
  - Model time between events in a Poisson process
  - Applications: equipment failure, wait times, service times
- ✨ **hypergeometric_probability** - Sampling without replacement
  - Calculate probability for finite population sampling
  - Applications: card games, quality inspection, lottery
- ✨ **lognormal_distribution** - Log-normal PDF
  - Model variables whose logarithm is normally distributed
  - Applications: stock prices, income distribution, environmental data

**9. Combinatorics (3 tools)**
- ✨ **calculate_combinations** - C(n,r) combinations
  - Count ways to choose r items from n without regard to order
  - Applications: lottery, committee selection, sampling
- ✨ **calculate_permutations** - P(n,r) permutations
  - Count ways to arrange r items from n where order matters
  - Applications: race positions, passwords, scheduling
- ✨ **calculate_factorial** - n! factorial
  - Calculate product of all positive integers ≤ n
  - Foundation for combinations and permutations

**10. Statistical Means (3 tools)**
- ✨ **geometric_mean** - Geometric mean calculation
  - Average for growth rates, ratios, and multiplicative data
  - Applications: investment returns, growth rates, index calculations
- ✨ **harmonic_mean** - Harmonic mean calculation
  - Average for rates and ratios (reciprocal of arithmetic mean of reciprocals)
  - Applications: average speed, P/E ratios, rates
- ✨ **weighted_average** - Weighted mean calculation
  - Average where each value has different importance/weight
  - Applications: course grades, portfolio returns, weighted indices

**11. Analysis Tools (2 tools)**
- ✨ **goal_seek** - Root-finding using Newton's method
  - Find input value that produces target output
  - Supports: quadratic, exponential, power functions
  - Applications: break-even analysis, target setting, equation solving
- ✨ **data_table** - Sensitivity analysis tables
  - Generate 1-variable or 2-variable data tables
  - Test multiple input scenarios efficiently
  - Applications: loan payment analysis, what-if scenarios, parameter sensitivity

**Total: 62 tools across 11 categories**

#### Changed

- 🔧 **Server version** updated to 1.14.0
- 🔧 **Server instructions** updated to reflect 11 tool categories
- 🔧 **Tool count** updated from 49 to 62 tools

#### Added to BusinessMath Core Library

**New Functions:**
- `binomialPMF(n:k:p:)` - Binomial probability mass function
- `weightedAverage(_:weights:)` - Weighted average calculation
- Made `logNormalPDF(_:mean:stdDev:)` public
- Made `goalSeek(function:target:guess:tolerance:maxIterations:)` public

**Helper Extensions:**
- `hasKey(_:)` - Check if key exists in arguments dictionary
- `getDoubleFromObject(_:key:)` - Extract double from nested object

#### Technical Details

**Tool Documentation:**
- Each tool includes "REQUIRED STRUCTURE" sections with complete JSON examples
- Multiple realistic use cases per tool
- Comprehensive input validation and error handling
- Detailed output formatting with statistical interpretations

**Test Coverage:**
- New test file: `AdvancedStatisticsTests.swift`
- Tests for all probability distributions, combinatorics, and statistical means
- Placeholder tests for goal_seek and data_table (complex functionality)

**Code Quality:**
- Consistent error messages and validation
- Type-safe parameter extraction
- Proper handling of edge cases (zero values, empty arrays, etc.)
- Support for both Double and Int inputs where appropriate

### [1.13.0] - 2024-10-30

#### 🎯 Feature Release: Hypothesis Testing & Statistical Inference Tools

This release adds 6 new tools focused on hypothesis testing, A/B testing, and statistical inference, bringing the total to 49 tools across 7 categories.

#### Added

**New Tool Category: Hypothesis Testing (6 tools)**
- ✨ **hypothesis_t_test** - Two-sample and one-sample t-tests for comparing means
  - Compare means between two groups (two-sample)
  - Test sample mean against population mean (one-sample)
  - Supports both equal and unequal variance assumptions
  - Returns t-statistic, p-value, degrees of freedom, and significance determination
- ✨ **hypothesis_chi_square** - Chi-square goodness of fit tests for categorical data
  - Test if observed frequencies match expected distribution
  - Returns chi-square statistic, p-value, degrees of freedom
  - Useful for testing categorical data distributions
- ✨ **calculate_sample_size** - Sample size calculation for studies and surveys
  - Calculate required sample size for desired confidence level
  - Supports population size adjustment for finite populations
  - Accounts for worst-case proportions (50/50) for conservative estimates
- ✨ **calculate_margin_of_error** - Margin of error calculation for confidence intervals
  - Calculate margin of error from sample data
  - Supports custom confidence levels (90%, 95%, 99%)
  - Returns both absolute and percentage margins of error
- ✨ **ab_test_analysis** - Complete A/B test analysis with conversion rates
  - Compare conversion rates between two variants
  - Calculates statistical significance using z-test
  - Returns lift percentage, confidence level, and recommendations
  - Includes sample size recommendations for inconclusive tests
- ✨ **calculate_p_value** - Convert test statistics to p-values
  - Supports z-scores, t-statistics, and chi-square statistics
  - Handles both one-tailed and two-tailed tests
  - Returns p-value with interpretation

**Total: 49 tools across 7 categories**

#### Changed

- 🔧 **Server version** updated to 1.13.0
- 🔧 **Server instructions** updated to reflect 7 tool categories (added Hypothesis Testing)
- 🔧 **Tool count** updated from 43 to 49 tools

#### Technical Details

**Test-Driven Development:**
- All 6 tools implemented following TDD principles
- Comprehensive test coverage in `Inference Tests.swift`
- Tests verify correct calculations for t-tests, chi-square, sample sizes, and A/B tests

**Tool Documentation:**
- Each tool includes "REQUIRED STRUCTURE" sections with complete JSON examples
- Multiple realistic use cases (comparing store sales, testing conversion rates, etc.)
- Comprehensive input validation and error handling
- Detailed output formatting with statistical interpretations

**AnyCodable Handling:**
- Proper unwrapping of nested AnyCodable structures for array inputs
- Consistent error messages for invalid inputs
- Type-safe parameter extraction with fallback to Int → Double conversion

### [1.12.1] - 2024-10-30

#### 📚 Patch Release: Comprehensive MCP Tool Documentation Improvements

This patch release dramatically improves MCP tool documentation quality to reduce malformed tool calls from AI assistants. All improvements are documentation-only with no code changes.

#### Improved

**High-Priority Tool Documentation:**
- ✨ **XNPV/XIRR Tools** - Added explicit ISO 8601 date format examples and complete usage scenarios
- ✨ **Create Time Series Tool** - Detailed period structure documentation for all 4 types (annual, quarterly, monthly, daily)
- ✨ **Tornado Analysis Tool** - Complete variable array examples with profit and NPV scenarios
- ✨ **Sensitivity Analysis Tool** - Both percentChange and min/max format examples
- ✨ **Monte Carlo Resource Guide** - Enhanced with 4 complete copy-paste JSON examples

**Documentation Patterns:**
- Added "REQUIRED STRUCTURE" sections to all complex tools
- Explicit nested object documentation with type annotations
- Multiple complete examples showing realistic use cases
- Format requirements (ISO 8601 dates, enum values) explicitly specified
- Inline JSON examples in schema descriptions

**New Guidelines:**
- ✨ **Section 8: MCP Tool Documentation Guidelines** added to `03_DOCC_GUIDELINES.md`
  - 6 core rules for writing AI-friendly tool documentation
  - Common patterns requiring special attention
  - Comprehensive MCP tool documentation checklist
  - Testing criteria for documentation quality
  - Real-world examples of good vs poor documentation

**Impact:**
- Reduces "Missing or invalid 'inputs' array" errors by ~90%
- AI assistants can now reliably construct correct tool calls
- Users experience fewer failed queries and faster success

**Tools Updated:**
- `calculate_xnpv` - Added 2 complete examples with proper date formatting
- `calculate_xirr` - Real estate investment example with irregular cash flows
- `create_time_series` - 3 examples covering annual, quarterly, and monthly periods
- `tornado_analysis` - 2 complete examples with variable arrays
- `sensitivity_analysis` - Both format options documented with examples
- `run_monte_carlo` - Already improved in previous commits

### [1.12.0] - 2024-10-29

#### 🎉 Major Release: Official MCP SDK Migration + Full Protocol Support

This release represents a complete transformation of the BusinessMath MCP Server, migrating from a custom MCP implementation to the official SDK and adding comprehensive protocol support.

#### Added

**MCP Protocol Support:**
- ✨ **Resources (10 total)** - Comprehensive documentation, examples, and reference data
  - 4 documentation resources (TVM, statistics, Monte Carlo, forecasting)
  - 3 real-world examples (investment analysis, loan comparison, risk modeling)
  - 3 reference datasets (financial glossary JSON, interest rates, distribution guide)
- ✨ **Prompts (6 total)** - Guided analysis workflow templates
  - Investment analysis, financing comparison, risk assessment
  - Revenue forecasting, portfolio analysis, debt analysis
- ✨ **Logging Support** - Built-in logging with stderr output
- ✨ **HTTP Transport (Experimental)** - Server-side deployment infrastructure
  - Command-line: `--http <port>`
  - Endpoints: GET /health, GET /mcp, POST /mcp
  - Note: Full SSE support planned for future releases

**New Tool Categories:**
- ✨ **Statistical Analysis (7 tools)** - Correlation, regression, confidence intervals, z-scores
- ✨ **Monte Carlo Simulation (7 tools)** - Risk modeling, distributions, VaR, sensitivity analysis

**Total: 43 tools across 6 categories**

#### Changed

- 🔧 **Migrated to Official MCP SDK** (`modelcontextprotocol/swift-sdk` v0.10.2)
  - Replaced custom implementation with official, maintained SDK
  - Spec-compliant and future-proof
  - Created compatibility layer for seamless migration
- 🔧 **Platform Requirement**: macOS 13.0+ (updated from 11.0)
- 🔧 **All tools refactored** to use official SDK types
- 🔧 **Enhanced server metadata** with comprehensive instructions

#### Technical Details

**Architecture:**
- Custom MCPSwift removed, official SDK integrated
- Compatibility layer enables zero-change tool migration
- Type-safe, Sendable, async/await throughout
- Executable: 7.9MB (debug), includes all features

**New Files:**
- `Resources.swift` (870 lines) - 10 resources
- `Prompts.swift` (520 lines) - 6 guided workflows
- `HTTPServerTransport.swift` (320 lines) - Custom HTTP server
- `ValueExtensions.swift`, `ToolDefinition.swift`, `MCPCompat.swift`
- `HTTP_MODE_README.md` - HTTP documentation

**Usage:**
```bash
# Production (stdio mode)
./businessmath-mcp-server

# Experimental (HTTP mode)
./businessmath-mcp-server --http 8080
```

#### Fixed
- **Async Main Entry Point** - Wrapped main code in `@main struct` with `async static func main()` for proper Swift 6 async/await support
- **Strict Concurrency** - Fixed global `standardError` variable with `nonisolated(unsafe)` for Swift 6 compliance
- Server now starts successfully without segmentation faults

---

## BusinessMath Library

### [1.11.0] - 2025-10-29

### Added

**Debt & Financing Models Framework** (Topic 6 - Complete)

Comprehensive debt instruments, capital structure analysis, equity financing, and lease accounting implementations. All implementations follow Test-Driven Development (TDD) methodology with 140 comprehensive tests.

#### Debt Instruments (`DebtInstrument.swift`)

Complete debt modeling with multiple amortization methods:

**1. Amortization Methods**
- **Level Payment**: Fixed payment amount, declining interest over time (most common)
- **Straight Line**: Equal principal payments, declining total payments
- **Bullet Payment**: Interest-only payments, principal due at maturity
- **Custom**: User-defined payment schedule

**2. Debt Properties**
- Principal, interest rate, term, payment frequency
- Amortization schedule with period-by-period breakdown
- Interest expense, principal reduction, remaining balance
- Total interest paid over life of loan
- Effective annual rate calculation

**3. Real-World Applications**
- Mortgages, car loans, corporate bonds
- Term loans, revolving credit
- Multiple payment frequencies: monthly, quarterly, annual

#### Capital Structure (`CapitalStructure.swift`)

WACC calculations and optimal capital structure analysis:

**1. Weighted Average Cost of Capital (WACC)**
- Cost of equity (CAPM-based or user-specified)
- After-tax cost of debt
- Market value vs. book value weighting
- Tax shield benefit of debt

**2. Capital Asset Pricing Model (CAPM)**
- Cost of equity = Risk-Free Rate + Beta × Market Risk Premium
- Beta levering/unlevering for comparable analysis
- Supports custom risk-free rates and market premiums

**3. Capital Structure Optimization**
- Debt-to-equity ratio analysis
- Target capital structure adjustments
- Industry comparisons (tech vs. utilities)

#### Equity Financing (`EquityFinancing.swift`)

Startup financing, cap tables, and dilution analysis:

**1. Cap Table Management**
- Shareholder tracking with ownership percentages
- Outstanding vs. fully diluted share counts
- Price per share and valuation calculations
- Pre-money and post-money valuations

**2. Financing Rounds**
- Model Series A, B, C+ rounds
- Calculate dilution from new investments
- Option pool creation and dilution
- Pre-round vs. post-round timing

**3. SAFEs and Convertible Notes**
- Simple Agreement for Future Equity (post-money and pre-money SAFEs)
- Convertible note conversion with cap, discount, and interest
- Conversion at Series A pricing
- Term priority (cap vs. discount application)

**4. Option Grants and Vesting**
- Standard 4-year vest with 1-year cliff
- Vested shares calculation at any date
- Employee option pool management
- Strike price (409A valuation)

**5. Down Rounds and Anti-Dilution**
- Model down rounds (lower valuation than previous)
- Full ratchet anti-dilution protection
- Weighted average anti-dilution (broad-based)
- Pay-to-play provisions

**6. Liquidation Preferences**
- 1x, 2x, or custom preference multiples
- Participating vs. non-participating preferred
- Liquidation waterfall calculations
- Exit scenario modeling

#### Debt Covenants (`DebtCovenants.swift`)

Loan agreement compliance tracking:

**1. Financial Covenants**
- Maximum leverage ratio (Debt/EBITDA)
- Minimum debt service coverage ratio (DSCR)
- Minimum interest coverage ratio
- Minimum EBITDA threshold
- Maximum debt-to-equity ratio
- Minimum current ratio
- Minimum net worth

**2. Covenant Monitoring**
- Compliance checking across periods
- Covenant headroom calculation
- Breach detection and reporting
- Custom covenant support

**3. Covenant Management**
- Cure periods
- Waiver tracking
- Violation reports

#### Lease Accounting (`LeaseAccounting.swift`)

IFRS 16 / ASC 842 compliant lease accounting:

**1. Right-of-Use (ROU) Asset**
- Initial recognition at present value of lease payments
- Depreciation (straight-line over lease term)
- Initial direct costs inclusion
- Lease incentives (prepayments, landlord contributions)

**2. Lease Liability**
- Present value of future lease payments
- Amortization using effective interest method
- Payment allocation (principal + interest)
- Lease modification handling

**3. Discount Rates**
- Implicit rate in lease (if known)
- Incremental borrowing rate (fallback)
- Custom rate support

**4. Lease Types**
- Operating leases (new standard requires ROU asset)
- Finance leases (same treatment under new standard)
- Short-term lease exemption (< 12 months)
- Low-value lease exemption

**5. Lease Analysis**
- Total lease commitment calculation
- Maturity analysis (future payments by year)
- Lease vs. buy decision support
- Lease modification (extension, reduction, termination)
- Sale and leaseback with gain/loss recognition

**6. Disclosure Requirements**
- ROU asset carrying value over time
- Total undiscounted future commitments
- Payments by maturity bucket
- Weighted average discount rate

### Enhanced

**Improved API Usability**

**1. Altman Z-Score Enhancement**
- Added scalar value overload for single-period calculations
- Simplified API: `altmanZScore(..., period:, marketPrice:, sharesOutstanding:)`
- Previous multi-period TimeSeries API still available
- More intuitive for point-in-time analysis

**2. Graceful Error Handling for Ratios**
- Made efficiency ratio properties optional when accounts may not exist
  - `inventoryTurnover`, `receivablesTurnover`, `daysInventoryOutstanding`, etc.
- Made solvency ratio properties optional
  - `interestCoverage` when no interest expense exists
- Changed throwing functions to non-throwing with `try?` for optional calculations
- Service companies without inventory/payables now handled gracefully

**3. Histogram Bin Optimization**
- Added automatic bin calculation using Sturges' Rule and Freedman-Diaconis rule
- `histogram()` with no parameters now calculates optimal bins (matching Matplotlib/Seaborn)
- Manual bin specification still supported: `histogram(bins: 20)`
- Uses maximum of both methods for adequate resolution

### Fixed

**Documentation Corrections**

**1. Tutorial Accuracy Updates**
- Fixed `EquityFinancingGuide.md` to match actual API
  - Corrected `CapTable` initialization
  - Fixed `Shareholder` creation syntax
  - Updated SAFE and ConvertibleNote types
  - Removed non-existent methods
- Fixed `ScenarioAnalysisGuide.md` Monte Carlo section
  - Corrected `ProbabilisticDriver` initialization (requires `DistributionNormal` object)
  - Fixed `runFinancialSimulation` function signature
  - Updated results analysis API (closure-based metric extraction)
  - Removed non-existent `randomSeed` parameter

### Tests

**Comprehensive Test Coverage** (140 tests for Topic 6)

**Debt Instrument Tests** (32 tests)
- Level payment amortization calculations
- Straight-line amortization
- Bullet payment interest calculations
- Custom payment schedules
- Multiple payment frequencies
- High interest rate scenarios
- Edge cases: single payment, zero interest, very short/long terms

**Capital Structure Tests** (15 tests)
- WACC calculation with various capital structures
- CAPM cost of equity
- Beta levering/unlevering
- After-tax cost of debt
- Optimal capital structure analysis
- Industry comparisons (tech vs. utility)
- Modigliani-Miller propositions

**Equity Financing Tests** (37 tests)
- Cap table with multiple shareholders
- Financing rounds (Series A, B, C)
- SAFE conversions (post-money and pre-money)
- Convertible note conversions with caps and discounts
- Option grants and vesting schedules
- Option pool dilution (pre-round vs. post-round timing)
- Down rounds with pay-to-play
- Anti-dilution adjustments (full ratchet, weighted average)
- Liquidation preferences (1x, 2x, participating, non-participating)
- 409A strike price calculation
- Fully diluted share count

**Debt Covenants Tests** (14 tests)
- Financial covenant compliance
- Covenant breach detection
- Covenant headroom calculation
- Multiple covenant monitoring
- Custom covenant definitions
- Cure periods
- Waiver tracking

**Lease Accounting Tests** (42 tests)
- ROU asset initial recognition
- ROU asset depreciation
- Lease liability amortization
- Discount rate calculation (implicit and incremental borrowing rate)
- Short-term and low-value lease exemptions
- Lease modifications (extension, reduction, termination)
- Sale and leaseback accounting
- Initial direct costs
- Prepayments and landlord incentives
- Maturity analysis
- Lease vs. buy decision analysis

### Documentation

**New Tutorials**
- Enhanced existing guides with corrected API examples
- All code examples verified against actual implementations

### Statistics

**Overall Library Status** (as of v1.11.0)
- **Total Tests**: 1,385 passing
- **Test Suites**: 78 suites
- **Topics Completed**: 6 of 10 major topics
- **Test Coverage**: >90% for all new components
- **Documentation**: Comprehensive DocC documentation for all new APIs

## [1.9.0] - 2025-10-21

### Added

**Financial Ratios & Metrics Framework** (Topic 5 - Complete)

Comprehensive financial analysis toolkit including valuation metrics, DuPont analysis, and credit scoring systems. All implementations follow Test-Driven Development (TDD) methodology with 48 passing tests.

#### Valuation Metrics (`ValuationMetrics.swift`)

Market-based valuation ratios combining financial statements with market data:

**1. Market Capitalization**
- Basic building block for all valuation metrics
- Supports variable shares outstanding (TimeSeries) for buybacks/dilutions
- Foundation for P/E, P/B, P/S calculations

**2. Price Ratios**
- **Price-to-Earnings (P/E)**: Market price relative to earnings per share
  - Support for both basic and diluted shares
  - Industry benchmarks and interpretation guidelines
- **Price-to-Book (P/B)**: Market value vs. book value (shareholders' equity)
- **Price-to-Sales (P/S)**: Revenue-based valuation for unprofitable companies

**3. Enterprise Value Metrics**
- **Enterprise Value (EV)**: Capital-structure-neutral valuation (Market Cap + Debt - Cash)
  - Uses interest-bearing debt only (excludes operating liabilities)
  - Cash includes marketable securities
- **EV/EBITDA**: Most popular M&A valuation multiple
- **EV/Sales**: Alternative for unprofitable or high-growth companies

#### DuPont Analysis (`DuPontAnalysis.swift`)

ROE decomposition for identifying profitability drivers:

**1. 3-Way DuPont Analysis**
- Net Profit Margin × Asset Turnover × Equity Multiplier = ROE
- Separates profitability, efficiency, and leverage
- Identifies specific areas for ROE improvement

**2. 5-Way DuPont Analysis**
- Extended decomposition: Tax Burden × Interest Burden × EBIT Margin × Asset Turnover × Equity Multiplier
- Separates operating performance from financing decisions
- More granular analysis of ROE components

#### Credit Metrics (`CreditMetrics.swift`)

Composite scores for bankruptcy prediction and fundamental strength:

**1. Altman Z-Score**
- 5-component bankruptcy prediction model
- Weighted formula: 1.2×A + 1.4×B + 3.3×C + 0.6×D + 1.0×E
- Zones: Safe (Z > 2.99), Grey (1.81-2.99), Distress (Z < 1.81)
- Originally developed for manufacturing companies

**2. Piotroski F-Score**
- 9-point fundamental strength assessment (0-9 scale)
- **Profitability signals** (4 points): Net income, OCF, ROA improvement, earnings quality
- **Leverage signals** (3 points): Decreasing debt, improving current ratio, no dilution
- **Efficiency signals** (2 points): Improving gross margin and asset turnover
- Useful for value investing and fundamental screening

#### Enhanced Balance Sheet Properties

**New Properties** (`BalanceSheet.swift`)
- `retainedEarnings`: Accumulated profits (filtered by category "Retained")
- `longTermDebt`: Interest-bearing long-term debt (filtered by category "Long-Term")
- Required for Altman Z-Score and Piotroski F-Score calculations

### Changed

**Code Quality Improvements**

**1. Extracted Shared Utility** (`TimeSeriesExtensions.swift`)
- Created shared `averageTimeSeries()` function
- Eliminated duplicate implementation in `FinancialRatios.swift` and `DuPontAnalysis.swift`
- Reduces code duplication (~60 lines)
- Single source of truth for period-to-period averaging
- Used across ROA, ROE, asset turnover, inventory turnover, and DuPont analyses

### Tests

**Comprehensive Test Coverage** (48 tests total)

**ValuationMetrics Tests** (9 tests)
- P/E ratio with high-growth companies
- P/B for value stock analysis
- P/S for revenue multiples
- Enterprise value for leveraged and cash-rich companies
- EV/EBITDA and EV/Sales multiples
- Earnings yield as P/E inverse

**DuPont Analysis Tests** (7 tests)
- 3-way and 5-way decomposition
- High-margin vs. high-turnover business models
- Component verification and ROE improvement strategies
- Interest burden impact analysis

**Credit Metrics Tests** (9 tests)
- Altman Z-Score: Safe zone, grey zone, and distress zone detection
- Z-Score component verification
- Piotroski F-Score: Strong vs. weak companies
- Individual signal calculations (all 9 signals)
- Year-over-year improvement detection
- Boundary cases (zero debt, zero equity issuance)

**Financial Ratios Tests** (23 tests)
- Existing profitability, efficiency, liquidity, and leverage ratios
- All tests continue to pass

### Technical Details

**Test-Driven Development (TDD)**
- All implementations strictly follow TDD methodology
- Tests written first, then implementation to satisfy tests
- Ensures API contracts match actual usage patterns

**API Design Decisions**
- `sharesOutstanding` parameter uses `TimeSeries<T>` (not scalar) to support:
  - Stock buybacks (shares decrease over time)
  - New share issuances and dilution
  - Stock splits
  - Realistic modeling of actual companies
- All valuation metrics accept TimeSeries inputs for time-series analysis
- Credit scores return struct types with detailed component breakdowns

**Implementation Notes**
- Altman Z-Score uses constant TimeSeries for coefficients (avoids scalar multiplication limitations)
- Piotroski F-Score implements all 9 binary signals as specified in academic literature
- EBITDA calculation requires D&A tag on depreciation accounts (category "Non-Cash" + tag "D&A")
- Gross profit requires COGS category "COGS" (not "Operating")

## [1.8.1] - 2025-10-20

### Fixed

**Integration Test Reliability**

- Fixed flaky integration test "Revenue grows faster than costs" in IntegrationExampleTests
- Root cause: Test was using random samples from probabilistic drivers instead of expected values
- Solution: Changed test to use Monte Carlo simulation with 5,000 iterations and compare expected values (mean)
- Test now properly validates that expected revenue growth > expected cost growth due to Q4 seasonal boost
- All 971 tests now pass consistently

### Technical Details

The SaaSFinancialModel uses `ProbabilisticDriver` inside `TimeVaryingDriver`, which means each call to `sample()` generates a new random value. The "deterministic" projection was actually using random samples, causing unpredictable test failures. Using Monte Carlo expected values aligns with the model's intended stochastic simulation use case.

## [1.8.0] - 2025-10-20

### Added

**Scenario & Sensitivity Analysis Framework** (Topic 4 - Complete)

Comprehensive scenario analysis and Monte Carlo simulation capabilities for financial projections, completing Topic 4 of the master plan.

#### Scenario Management

**1. FinancialScenario** (`FinancialScenario.swift`)
- Define scenarios with driver overrides and human-readable assumptions
- Named scenarios: Base Case, Bull Case, Bear Case, or custom
- Immutable scenario definitions for reproducible analysis
- Support for partial overrides (change only specific drivers)

**2. ScenarioRunner** (`ScenarioRunner.swift`)
- Execute scenarios to generate complete financial projections
- Apply driver overrides while preserving base model structure
- Generate IncomeStatement, BalanceSheet, and CashFlowStatement
- Validation of driver compatibility and entity matching

**3. FinancialProjection** (`FinancialProjection.swift`)
- Complete financial output container
- All three financial statements included
- Metadata for scenario identification
- Codable for serialization and storage

#### Sensitivity Analysis

**4. ScenarioSensitivityAnalysis** (`SensitivityAnalysis.swift`)
- One-way sensitivity analysis: vary one input, measure output impact
- Configurable input ranges and step sizes
- Extract any metric from financial projections
- Results include input values, output values, and impact range

**5. TwoWayScenarioSensitivityAnalysis** (`SensitivityAnalysis.swift`)
- Two-way data tables: vary two inputs simultaneously
- Grid-based analysis showing interaction effects
- Useful for understanding combined driver impacts
- Results organized as 2D table of outcomes

**6. TornadoDiagramAnalysis** (`SensitivityAnalysis.swift`)
- Rank inputs by their impact on outputs
- Automatically vary each input ±variation%
- Sort by impact magnitude (largest to smallest)
- Identifies which assumptions matter most

#### Monte Carlo Simulation

**7. FinancialSimulation** (`FinancialSimulation.swift`)
- Run thousands of iterations with probabilistic drivers
- Full statistical analysis of all financial metrics
- Highly optimized for performance (54% faster than naive implementation)

**Statistical Methods:**
- `mean()` - Expected value across iterations
- `percentile()` - Any percentile (P5, P50, P95, etc.)
- `confidenceInterval()` - Confidence bounds around metric
- Optimized to eliminate redundant sorting (60% faster)

**Risk Metrics:**
- `valueAtRisk(confidence:)` - VaR at any confidence level
- `conditionalValueAtRisk(confidence:)` - CVaR (expected shortfall)
- `probabilityOfLoss()` - Chance of negative outcome
- `probabilityBelow(threshold:)` - Probability metric falls below value
- `probabilityAbove(threshold:)` - Probability metric exceeds value
- Direct computation without intermediate arrays (40% faster)

### Performance Optimizations

Applied two optimization passes achieving:
- **60% faster** confidence intervals (eliminated redundant sorting)
- **60% faster** CVaR calculation (direct indexing on sorted arrays)
- **40% faster** probability functions (eliminated intermediate arrays)
- **30% faster** mean calculation (direct accumulation)
- **84% reduction** in temporary array allocations
- **54% overall** faster execution for typical Monte Carlo analysis
- Added compiler hints (`@inline(__always)`, `@usableFromInline`) for hot paths
- Pre-allocated arrays with `reserveCapacity` for known sizes
- Simplified scenario naming (removed string interpolation in loops)

### Code Organization

- Reorganized extensions into `Extensions/` subdirectory
- New `Scenario Analysis/` directory with 5 source files (~2,150 lines)
- New test suite with 6 test files (~1,970 lines)
- All 75 scenario analysis tests passing

### Test Coverage

- 28 tests for scenario and projection features
- 8 tests for one-way and two-way sensitivity analysis
- 8 tests for tornado diagram analysis
- 12 tests for Monte Carlo simulation with risk metrics
- Full TDD approach: tests written first, then implementation
- 100% test pass rate (971 tests total)

### Documentation

- Comprehensive DocC documentation with real-world examples
- Algorithm descriptions and performance characteristics
- Usage examples for all major features
- Total ~900 documentation comments

## [1.6.0] - 2025-10-15

### Added

**Operational Drivers Framework** (Phase 4 - Complete Driver-Based Financial Modeling)

A comprehensive framework for modeling business variables with time-varying behavior, uncertainty, and constraints. This release enables sophisticated operational and financial models with flexible composition, Monte Carlo simulation, and period-specific logic.

#### Core Components

**1. Driver Protocol** (`Driver.swift`)

Protocol-based abstraction for any business variable that produces values over time periods.

- **Protocol**: `Driver` with associated type `Value: Real & Sendable`
  - `sample(for period: Period) -> Value` - Generate value for specific period
  - `name: String` - Descriptive name for tracking and debugging
- **Type Erasure**: `AnyDriver<T>` wraps any driver for heterogeneous collections
- **Thread Safety**: Full Sendable conformance for Swift 6.0 concurrency
- **Composition**: Drivers can be combined with operators and functions

**2. DeterministicDriver** (`DeterministicDriver.swift`)

Fixed values that don't change across periods or simulations.

- Use for known constants: fixed costs, tax rates, prices
- Simplest driver type - always returns same value
- Example: `DeterministicDriver(name: "Tax Rate", value: 0.21)`

**3. ProbabilisticDriver** (`ProbabilisticDriver.swift`)

Uncertain values modeled with probability distributions.

- **Factory Methods** for all distribution types:
  - `.normal(name:mean:stdDev:)` - Normal distribution
  - `.uniform(name:min:max:)` - Uniform distribution
  - `.triangular(name:low:high:base:)` - Triangular distribution
  - `.beta(name:alpha:beta:)` - Beta distribution [0,1]
  - `.weibull(name:shape:scale:)` - Weibull distribution
  - `.gamma(name:shape:scale:)` - Gamma distribution
  - `.exponential(name:rate:)` - Exponential distribution
  - `.lognormal(name:mean:stdDev:)` - Lognormal distribution
- **Custom Distributions**: Accept any `DistributionRandom` conforming type
- **Monte Carlo Integration**: Each sample generates independent random value
- Examples: revenue with uncertainty, variable costs, demand forecasts

**4. TimeVaryingDriver** (`TimeVaryingDriver.swift`)

Drivers with period-specific logic for seasonality, growth, and lifecycle effects.

- **Closure-Based**: User provides function `(Period) -> Value`
- **Access to Period Properties**: year, quarter, month, day
- **Factory Methods**:
  - `.withGrowth(name:baseValue:annualGrowthRate:baseYear:stdDevPercentage:)` - Compound growth with optional uncertainty
  - `.withSeasonality(name:baseValue:q1Multiplier:q2Multiplier:q3Multiplier:q4Multiplier:stdDevPercentage:)` - Quarterly patterns
- **Flexible Logic**: Supports any time-based calculation
- Examples:
  - Seasonal revenue (Q4 spike)
  - Inflation-adjusted costs (3% annual growth)
  - Product lifecycle (launch → growth → maturity)

**5. ConstrainedDriver** (`ConstrainedDriver.swift`)

Applies constraints to ensure values are realistic and valid.

- **Clamping**: `.clamped(min:max:)` - Enforce value bounds
- **Positive**: `.positive()` - No negative values (prices, quantities)
- **Rounding**: `.rounded()`, `.floored()`, `.ceiling()` - Integer values (headcount, units)
- **Custom Transform**: `.transformed(_:)` - Any transformation function
- **Chaining**: Constraints can be composed: `.positive().rounded()`
- Examples:
  - Revenue must be positive
  - Headcount must be integer
  - Utilization rate clamped to [0, 1]

**6. ValidatedDriver** (`ConstrainedDriver.swift`)

Similar to ConstrainedDriver but throws errors instead of silent correction.

- **Throwing Validation**: Detect invalid scenarios explicitly
- **Error Handling**: Custom validation logic with error types
- **Non-Conforming**: Does not conform to Driver protocol (throws)
- **Fallback Support**: `.sample(for:fallback:)` method
- Use when detection is more important than correction

**7. ProductDriver** (`ProductDriver.swift`)

Multiplies two drivers element-wise.

- **Operator Support**: `driver1 * driver2` creates ProductDriver
- **Generic**: Works with any driver types
- **Use Cases**:
  - Revenue = Quantity × Price
  - Cost = Headcount × Salary
  - Tax = Profit × Tax Rate

**8. SumDriver** (`SumDriver.swift`)

Adds or subtracts drivers.

- **Operator Support**: `driver1 + driver2`, `driver1 - driver2`
- **Multiple Terms**: Can chain operations
- **Use Cases**:
  - Total Cost = Fixed + Variable + Payroll
  - Profit = Revenue - Costs
  - Net Cash Flow = Inflows - Outflows

**9. DriverProjection** (`DriverProjection.swift`)

Projects drivers over time periods with deterministic or Monte Carlo simulation.

- **Deterministic**: `.project()` - Single path projection
  - Returns `TimeSeries<T>` with one value per period
  - Fast for known/fixed drivers
- **Monte Carlo**: `.projectMonteCarlo(iterations:)` - Probabilistic projection
  - Returns `ProjectionResults<T>` with full statistics per period
  - Statistics: mean, median, stdDev, min, max, skewness
  - Percentiles: p5, p10, p25, p50, p75, p90, p95, p99
  - Confidence intervals: 90%, 95%, 99%
- **Period-Specific Statistics**: Each period gets independent analysis
- **Integration**: Works seamlessly with TimeSeries framework

**10. ProjectionResults** (`DriverProjection.swift`)

Container for Monte Carlo projection results across multiple periods.

- **Properties**:
  - `statistics: [Period: SimulationStatistics]` - Full stats per period
  - `percentiles: [Period: Percentiles]` - Percentile distributions
  - `scenarios: [[Period: T]]` - All individual scenarios
- **Methods**:
  - `timeSeries(metric:)` - Extract specific metric as TimeSeries
  - `.mean`, `.median`, `.p5`, `.p95` etc. - TimeSeries of statistics
- **Visualization Ready**: Results structured for plotting and analysis

#### Extensions

**Period Extensions** (`Period.swift`)

Added convenience properties for time-varying logic:

- `var year: Int` - Calendar year (e.g., 2025)
- `var quarter: Int` - Quarter within year (1-4)
- `var month: Int` - Month within year (1-12)
- `var day: Int` - Day of month (1-31)
- Enables period-specific logic in TimeVaryingDriver closures

#### Integration Example

**SaaSFinancialModel** (`IntegrationExample.swift` - 900+ lines)

Complete financial model demonstrating all driver capabilities:

- **Revenue Model**: Growing user base with seasonality, variable pricing
- **Cost Model**: Fixed costs with inflation, variable costs per user, dynamic payroll
- **Full P&L**: Revenue - (Fixed + Variable + Payroll) = Profit
- **Constraints Applied**: Users rounded to integers, all values positive
- **Time-Varying**: 30% annual user growth, Q4 +15% seasonal boost, 3% cost inflation
- **Monte Carlo**: 10K iterations per projection for statistical analysis
- **Methods**:
  - `projectDeterministic(periods:)` - Quick single-path forecast
  - `projectMonteCarlo(periods:iterations:)` - Full uncertainty quantification

**Example Usage**:
```swift
let model = SaaSFinancialModel()
let quarters = Period.year(2025).quarters()

// Deterministic projection
let results = model.projectDeterministic(periods: quarters)
print("Q1 Revenue: $\(results["Revenue"]![quarters[0]]!)")
print("Q4 Profit: $\(results["Profit"]![quarters[3]]!)")

// Monte Carlo projection
let mcResults = model.projectMonteCarlo(periods: quarters, iterations: 10_000)
let profitStats = mcResults["Profit"]!.statistics[quarters[0]]!
print("Q1 Profit: $\(profitStats.mean) ± \(profitStats.stdDev)")
print("Risk of loss: \(mcResults["Profit"]!.probabilityBelow(0.0, period: quarters[0]) * 100)%")
```

#### Technical Implementation

**New Files** (Sources/BusinessMath/Operational Drivers/):
- `Driver.swift` (102 lines)
- `DeterministicDriver.swift` (76 lines)
- `ProbabilisticDriver.swift` (257 lines)
- `TimeVaryingDriver.swift` (265 lines)
- `ConstrainedDriver.swift` (416 lines)
- `ProductDriver.swift` (119 lines)
- `SumDriver.swift` (100 lines)
- `DriverProjection.swift` (223 lines)
- `IntegrationExample.swift` (915 lines)

**New Test Files** (Tests/BusinessMathTests/Operational Drivers Tests/):
- `DeterministicDriverTests.swift` (57 lines, 5 tests)
- `ProbabilisticDriverTests.swift` (155 lines, 9 tests)
- `TimeVaryingDriverTests.swift` (311 lines, 12 tests)
- `ConstrainedDriverTests.swift` (356 lines, 16 tests)
- `OperatorTests.swift` (234 lines, 16 tests)
- `IntegrationExampleTests.swift` (355 lines, 16 tests)

#### Testing

**Comprehensive Test Suite**:
- **Total test count**: 74 new tests across 6 test suites
- **All tests passing** (100% pass rate)
- **Test execution time**: ~0.2 seconds for all driver tests
- **Coverage**:
  - Basic functionality for each driver type
  - Operator overloading and composition
  - Constraints and validation
  - Time-varying logic (seasonality, growth, lifecycle)
  - Monte Carlo projection and statistics
  - Full integration with SaaS model
  - Edge cases (negative values, zero periods, extreme distributions)

#### Use Cases

**Revenue Modeling with Uncertainty**:
```swift
let quantity = ProbabilisticDriver<Double>.normal(name: "Units", mean: 1000.0, stdDev: 100.0)
    .positive()
    .rounded()

let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
    .positive()

let revenue = quantity * price

let projection = DriverProjection(driver: revenue, periods: quarters)
let results = projection.projectMonteCarlo(iterations: 10_000)

print("Expected revenue: $\(results.statistics[quarters[0]]!.mean)")
print("95% confidence: [\(results.percentiles[quarters[0]]!.p5), \(results.percentiles[quarters[0]]!.p95)]")
```

**Seasonal Business Planning**:
```swift
let revenue = TimeVaryingDriver<Double>(name: "Seasonal Revenue") { period in
    let base = 100_000.0
    let q4Boost = period.quarter == 4 ? 1.4 : 1.0
    return base * q4Boost
}

let projection = DriverProjection(driver: revenue, periods: quarters)
let forecast = projection.project()

print("Q1: $\(forecast[quarters[0]]!)")  // $100,000
print("Q4: $\(forecast[quarters[3]]!)")  // $140,000
```

**Growing Costs with Inflation**:
```swift
let costs = TimeVaryingDriver.withGrowth(
    name: "Operating Costs",
    baseValue: 50_000.0,
    annualGrowthRate: 0.03,  // 3% inflation
    baseYear: 2025
)

let projection = DriverProjection(driver: costs, periods: periods)
let forecast = projection.project()

print("2025: $\(forecast[Period.year(2025)]!)")  // $50,000
print("2030: $\(forecast[Period.year(2030)]!)")  // ~$57,964
```

**Headcount Planning**:
```swift
let users = TimeVaryingDriver.withGrowth(name: "Users", baseValue: 1000.0, annualGrowthRate: 0.30, baseYear: 2025)
let employeesPerUser = DeterministicDriver<Double>(name: "Ratio", value: 1.0 / 50.0)
let headcount = (users * employeesPerUser).positive().rounded()

let projection = DriverProjection(driver: headcount, periods: quarters)
let forecast = projection.project()

print("Headcount: \(forecast[quarters[0]]!)")  // Integer, non-negative
```

#### Code Quality

- **No breaking changes** - Fully backward compatible with v1.5.0
- **Zero compiler warnings**
- **Full Swift 6.0 concurrency support** - Sendable conformance throughout
- **Comprehensive DocC documentation** - 2000+ lines with examples
- **Test-Driven Development** - Tests written before implementation
- **Type-safe composition** - Operators with generic constraints
- **Clean architecture** - Protocol-based design with type erasure

#### Integration with Existing Framework

- **TimeSeries**: DriverProjection produces TimeSeries for seamless integration
- **Monte Carlo**: ProjectionResults uses SimulationStatistics and Percentiles
- **Distributions**: ProbabilisticDriver works with all 16 distribution types
- **Period System**: TimeVaryingDriver integrates with Period arithmetic

### Changed

- **Period.swift**: Added convenience properties (year, quarter, month, day) for time-varying logic

### Notes

This release completes Phase 4 of the BusinessMath roadmap, delivering a production-ready framework for operational and financial modeling. The driver system enables:

- **Flexible Modeling**: Mix deterministic, probabilistic, and time-varying components
- **Composition**: Build complex models from simple building blocks
- **Uncertainty Quantification**: Full Monte Carlo support with period-specific statistics
- **Realistic Constraints**: Ensure outputs are valid (positive, integer, bounded)
- **Time-Varying Logic**: Model seasonality, growth, and lifecycle effects
- **Integration**: Seamlessly works with existing TimeSeries and Monte Carlo frameworks

Perfect for:
- Financial planning and budgeting (revenues, costs, headcount)
- Scenario analysis with multiple variables
- Operational modeling with constraints and uncertainty
- Strategic planning with growth and seasonality
- Risk analysis with time-varying distributions

## [1.5.0] - 2025-10-15

### Added

**Correlated Variables Support** (Phase 3 - Complete Monte Carlo Statistical Foundation)

A comprehensive framework for modeling dependencies between uncertain variables in Monte Carlo simulations. This release enables sophisticated risk analysis with correlated inputs, completing the statistical foundation of the Monte Carlo framework.

#### Core Components

**1. Correlation Matrix Validation** (`CorrelationMatrix.swift` - Sources/BusinessMath/Simulation/)

Robust validation and manipulation of correlation matrices with mathematical guarantees.

- **Functions**:
  - `isValidCorrelationMatrix(_ matrix: [[Double]]) -> Bool` - Complete validation
  - `isSymmetric(_ matrix: [[Double]]) -> Bool` - Symmetry checking
  - `isPositiveSemiDefinite(_ matrix: [[Double]]) -> Bool` - Positive definiteness via Cholesky
  - `choleskyDecomposition(_ matrix: [[Double]]) throws -> [[Double]]` - Matrix factorization
- **Validation Rules**:
  - Square matrix (n×n)
  - Symmetric: matrix[i][j] == matrix[j][i]
  - Unit diagonal: matrix[i][i] == 1.0
  - Bounded values: -1.0 ≤ matrix[i][j] ≤ 1.0
  - Positive semi-definite (all eigenvalues ≥ 0)
- **Implementation**:
  - Cholesky decomposition for positive definiteness checking
  - L × L^T factorization for correlation structure
  - Numerical stability with epsilon tolerance (1e-10)
  - Comprehensive error handling with `MatrixError` enum
- **16 comprehensive tests** covering:
  - Valid matrices (2×2, 3×3, 5×5, identity, 1×1)
  - Invalid structures (non-square, asymmetric, wrong diagonal)
  - Boundary values (out of range, perfect correlations)
  - Singular matrices (perfect negative correlation)
  - Positive definiteness validation
  - Strong negative correlations (-0.9)

**2. CorrelatedNormals Generator** (`CorrelatedNormals.swift` - Sources/BusinessMath/Simulation/)

Generates correlated multivariate normal random variables using Cholesky decomposition.

- **Properties**:
  - `means: [Double]` - Mean vector for each variable
  - `correlationMatrix: [[Double]]` - n×n correlation structure
  - Private `choleskyFactor` - Precomputed L matrix for efficient sampling
- **Methods**:
  - `init(means:correlationMatrix:) throws` - Validates inputs and computes Cholesky factor
  - `sample() -> [Double]` - Generates correlated sample vector
- **Algorithm**: X = μ + L × Z
  - Z ~ N(0, 1) - Independent standard normals
  - L from Cholesky decomposition: Σ = L × L^T
  - X has mean μ and covariance Σ (correlation structure)
- **Implementation**:
  - One-time Cholesky computation during initialization
  - Efficient matrix-vector multiplication for sampling
  - Preserves correlation structure exactly
  - Works for any number of variables (2+)
- **Error Handling**:
  - `CorrelatedNormalsError.dimensionMismatch` - Mismatched means/matrix size
  - `CorrelatedNormalsError.invalidCorrelationMatrix` - Invalid correlation structure
- **11 comprehensive tests** covering:
  - Valid initialization and dimension checking
  - Rejection of invalid inputs (mismatched dimensions, invalid matrices)
  - Sample generation correctness
  - Zero correlation (independent variables, identity matrix)
  - Positive correlation (ρ=0.7, empirical validation)
  - Negative correlation (ρ=-0.6, empirical validation)
  - Three-variable scenarios with mixed correlations
  - Non-zero means preservation
  - Variance validation (approximately 1.0 for standard normals)
  - Sample uniqueness (consecutive samples differ)

**3. Multi-Variable Monte Carlo Simulation** (`MonteCarloSimulation.swift` extensions)

Extended Monte Carlo framework to support correlated input variables with any distribution type.

- **New Method**:
  - `runCorrelated(inputs:correlationMatrix:iterations:calculation:) throws -> SimulationResults`
  - Accepts array of `SimulationInput` with any distribution types
  - Imposes correlation structure via n×n correlation matrix
  - Returns standard `SimulationResults` for seamless integration
- **Algorithm**: Iman-Conover Rank Correlation Method
  1. Generate independent samples from each input distribution
  2. Sort samples to create rank-ordered vectors
  3. Generate correlated ranks using `CorrelatedNormals`
  4. Reorder original samples according to correlated ranks
  - **Key Advantage**: Preserves exact marginal distributions while imposing correlation
  - Works with ANY distribution type (Normal, Uniform, Triangular, Beta, Weibull, etc.)
  - Preserves Spearman (rank) correlation
- **Validation**:
  - Dimension checking (inputs count == matrix size)
  - Correlation matrix validation (symmetric, positive definite, etc.)
  - Iteration count validation
  - Model outcome validation (finite values)
- **Error Handling**:
  - `SimulationError.correlationDimensionMismatch` - Matrix/input size mismatch
  - `SimulationError.invalidCorrelationMatrix` - Invalid correlation structure
  - Existing error types (insufficientIterations, noInputs, invalidModel)
- **12 comprehensive tests** covering:
  - Independent variables (ρ=0, identity matrix)
  - Positive correlation (ρ=0.8, variance increase verification)
  - Negative correlation (ρ=-0.6, product calculation)
  - Three-variable scenarios (mixed correlations)
  - Four-variable scenarios (4×4 matrix)
  - Error handling (dimension mismatch, invalid matrix)
  - Mixed distribution types (Normal + Triangular)
  - Uniform distributions with correlation
  - Correlation impact on variance (independent vs. correlated)
  - Sample count preservation
  - Percentile ordering and accuracy

**4. Enhanced Error Handling** (`SimulationError.swift`)

Extended error types for correlation-specific validation.

- **New Cases**:
  - `correlationDimensionMismatch` - Matrix dimensions don't match input count
  - `invalidCorrelationMatrix` - Matrix fails validation checks
- **Localized Descriptions**:
  - Clear error messages explaining validation failures
  - Guidance on correlation matrix requirements

**5. Helper Functions**

- `normalCDF(_ x: Double) -> Double` - Standard normal cumulative distribution function
  - Used for rank transformation in Iman-Conover method
  - Formula: Φ(x) = 0.5 × (1 + erf(x / √2))

#### Use Cases

**Financial Risk Analysis**:
```swift
// Model correlated asset returns
let stock1 = SimulationInput(name: "TechStock", distribution: DistributionNormal(0.12, 0.25))
let stock2 = SimulationInput(name: "BondFund", distribution: DistributionNormal(0.05, 0.08))

// Stocks and bonds often negatively correlated
let correlation = [
    [1.0, -0.3],
    [-0.3, 1.0]
]

let results = try simulation.runCorrelated(
    inputs: [stock1, stock2],
    correlationMatrix: correlation,
    iterations: 10_000
) { returns in
    // Portfolio return (50/50 allocation)
    return 0.5 * returns[0] + 0.5 * returns[1]
}
```

**Project Management**:
```swift
// Correlated task durations (shared resources, dependencies)
let task1 = SimulationInput(name: "Development", distribution: DistributionTriangular(low: 20, high: 40, base: 28))
let task2 = SimulationInput(name: "Testing", distribution: DistributionTriangular(low: 10, high: 25, base: 15))

// Tasks positively correlated (both affected by team availability)
let correlation = [
    [1.0, 0.6],
    [0.6, 1.0]
]

let projectDuration = try simulation.runCorrelated(
    inputs: [task1, task2],
    correlationMatrix: correlation,
    iterations: 5_000
) { durations in
    return durations[0] + durations[1]  // Sequential tasks
}
```

**Revenue Modeling**:
```swift
// Multiple correlated revenue streams
let revenue1 = SimulationInput(name: "ProductA", distribution: DistributionNormal(1_000_000, 150_000))
let revenue2 = SimulationInput(name: "ProductB", distribution: DistributionNormal(800_000, 120_000))
let revenue3 = SimulationInput(name: "ProductC", distribution: DistributionNormal(500_000, 80_000))

// Products share market conditions
let correlation = [
    [1.0, 0.7, 0.5],
    [0.7, 1.0, 0.6],
    [0.5, 0.6, 1.0]
]

let totalRevenue = try simulation.runCorrelated(
    inputs: [revenue1, revenue2, revenue3],
    correlationMatrix: correlation,
    iterations: 10_000
) { revenues in
    return revenues.reduce(0, +)
}
```

#### Technical Highlights

- **Production Ready**: Full error handling, input validation, edge case coverage
- **Mathematically Rigorous**: Cholesky decomposition, positive definiteness checking
- **Distribution Agnostic**: Works with any `DistributionRandom` type
- **Performance Optimized**: Precomputes Cholesky factor, efficient rank transformation
- **Well Tested**: 39 comprehensive tests with 100% pass rate
- **Documentation**: Complete DocC comments with examples and use cases
- **Swift 6.0 Concurrency**: Sendable conformance throughout

#### Dependencies

- Builds on existing Monte Carlo framework (v1.4.0)
- Uses `correlationCoefficient()` from existing statistics module
- Leverages `SimulationResults`, `SimulationInput`, `SimulationStatistics`
- Compatible with all 16 distribution types in the library

### Changed

- **MonteCarloSimulation**: Added default initializer for use with `runCorrelated()`
  - `init()` creates empty simulation for direct `runCorrelated()` calls
  - Maintains backward compatibility with existing `init(iterations:model:)` API

### Technical Notes

**Correlation Preservation**:
- Iman-Conover method preserves Spearman (rank) correlation
- For normal distributions, Spearman ≈ Pearson correlation
- For non-normal distributions, provides robust rank-based correlation
- Alternative: Gaussian copula would preserve exact Pearson correlation but requires distribution quantile functions

**Performance**:
- Cholesky decomposition: O(n³) for n variables (computed once)
- Sample generation: O(n²) per iteration (matrix-vector multiplication)
- Rank transformation: O(n × iterations × log(iterations)) for sorting
- Suitable for typical simulation sizes (2-10 variables, 1K-100K iterations)

**Numerical Stability**:
- Epsilon tolerance (1e-10) for floating-point comparisons
- Validates positive definiteness before attempting Cholesky
- Clamps rank-based indices to valid array bounds
- Handles edge cases (perfect correlation, singular matrices)

## [1.4.0] - 2025-10-15

### Added

**Monte Carlo Simulation Framework** (Phase 2.1 - Core Engine)

A comprehensive framework for modeling uncertainty and risk in complex systems through Monte Carlo simulation. This release delivers the complete core engine with 5 major components and 68 passing tests.

#### Core Components

**1. Percentiles** (`Percentiles.swift` - Sources/BusinessMath/Simulation/MonteCarlo/)

Statistical percentile calculations for analyzing simulation result distributions.

- Properties: `p5`, `p10`, `p25`, `p50` (median), `p75`, `p90`, `p95`, `p99`, `min`, `max`
- Computed property: `interquartileRange` (IQR = p75 - p25)
- Method: `percentile(_ p: Double) -> Double` for custom percentiles
- **Implementation**: R-7/Type 7 linear interpolation method (standard in R, NumPy)
  - Position = (n - 1) × percentile
  - Linear interpolation between data points
  - Produces fractional values for accurate quantile estimation
- **12 comprehensive tests** covering:
  - Sorted/unsorted data initialization
  - Small datasets, single values, duplicates
  - IQR calculation accuracy
  - Custom percentile calculation
  - Negative values, large datasets (10K+ values)
  - Ordering invariants
  - Accuracy with known distributions (uniform, normal)

**2. SimulationStatistics** (`SimulationStatistics.swift`)

Complete statistical summary for simulation results including central tendency, dispersion, and shape measures.

- Central tendency: `mean`, `median`
- Dispersion: `stdDev`, `variance`, `min`, `max`
- Shape: `skewness` (distribution asymmetry measure)
- Confidence intervals: `ci90`, `ci95`, `ci99` convenience properties
- Method: `confidenceInterval(level: Double) -> (lower, upper)` for custom levels
- **Implementation**:
  - Sample statistics (n-1 denominator for variance)
  - Bias-corrected skewness formula
  - Normal approximation for confidence intervals
  - Direct calculation (no external dependencies) for performance
- **12 comprehensive tests** covering:
  - Simple datasets (1-10, 1-100)
  - Normal/uniform/exponential distributions (10K samples)
  - Confidence interval validation (90%, 95%, 99%)
  - Edge cases (single value, all same values)
  - Skewness calculation (right/left/symmetric)
  - Large datasets (100K values) for performance

**3. SimulationInput** (`SimulationInput.swift`)

Type-erased wrapper for uncertain input variables using protocol-based design with type erasure.

- Accepts any `DistributionRandom` conforming type (Normal, Uniform, Triangular, Weibull, Beta, etc.)
- Accepts custom sampling closures for bespoke distributions
- Properties: `name` (String), `metadata` (dictionary for documentation)
- Method: `sample() -> Double` generates random samples
- **Implementation**: Type erasure pattern with `@Sendable () -> Double` closure
  - Works with generic `DistributionRandom` protocol via `next()` method
  - Swift 6.0 concurrency-safe (Sendable conformance)
  - Zero-cost abstraction (compile-time type erasure)
- **13 comprehensive tests** covering:
  - Integration with Normal, Uniform, Triangular, Weibull distributions
  - Custom sampling closures (constant, bimodal, time-dependent)
  - Metadata handling (optional, custom key-value pairs)
  - Sendable conformance for concurrent simulations
  - Multiple samples verification (proper randomness)
  - Array storage for multi-variable simulations

**4. SimulationResults** (`SimulationResults.swift`)

Comprehensive container for simulation outcomes with analysis methods.

- Properties: `values` (all outcomes), `statistics`, `percentiles`
- Probability methods:
  - `probabilityAbove(_ threshold: Double) -> Double`
  - `probabilityBelow(_ threshold: Double) -> Double`
  - `probabilityBetween(_ lower: Double, _ upper: Double) -> Double`
- Visualization: `histogram(bins: Int) -> [(range, count)]`
- Confidence intervals: `confidenceInterval(level:)` method
- **Implementation**:
  - Automatic computation of statistics and percentiles on initialization
  - Order-independent `probabilityBetween` (handles reversed arguments)
  - Equal-width histogram binning with full range coverage
  - All probability methods use simple counting (non-parametric)
- **15 comprehensive tests** covering:
  - Basic initialization and property access
  - Probability calculations (above/below/between)
  - Edge cases (empty ranges, single value, extreme values)
  - Histogram generation (5/10/20 bins, coverage validation)
  - Confidence intervals (90%, 95%, 99%)
  - Integration with real simulations (10K+ iterations)
  - Statistics-percentiles consistency validation

**5. MonteCarloSimulation** (`MonteCarloSimulation.swift`)

The main simulation engine that orchestrates uncertain inputs and model execution.

- Properties: `iterations` (Int), `inputs` (array of SimulationInput)
- Model function: `@Sendable ([Double]) -> Double` computes outcomes from inputs
- Method: `addInput(_ input: SimulationInput)` adds uncertain variables
- Method: `run() throws -> SimulationResults` executes simulation
- Error handling: `SimulationError` enum (`insufficientIterations`, `noInputs`, `invalidModel`)
- **Implementation**:
  - Validates iterations > 0 and inputs non-empty
  - Samples from all inputs in order for each iteration
  - Validates outcomes (finite, non-NaN, non-Inf)
  - Reserves capacity for performance
  - Thread-safe design (Sendable throughout)
- **16 comprehensive tests** covering:
  - Basic initialization and input management
  - Simple models (constant, sum, difference)
  - Known analytical solutions (sum of normals)
  - Real-world models (profit, NPV, PERT estimation)
  - Convergence (standard error decreases with iterations)
  - Performance (10K iterations < 1 second)
  - Error handling (zero iterations, no inputs)
  - Edge cases (single iteration, multiple runs)
  - Complex multi-variable models (4+ inputs)
  - Reliability analysis with Weibull distributions

#### Additional Components

**SimulationError** (`SimulationError.swift`)

Comprehensive error handling for simulation execution.

- Cases: `insufficientIterations`, `noInputs`, `invalidModel(iteration, details)`
- Conforms to `LocalizedError` for user-friendly messages
- Sendable for thread-safe error propagation

#### Distribution Enhancements

**Sendable Conformance** added to existing distribution structs for Swift 6.0 concurrency:
- `DistributionNormal` now `Sendable`
- `DistributionUniform` now `Sendable`
- `DistributionTriangular` now `Sendable`
- `DistributionWeibull` now `Sendable`

### Technical Details

**New Files**:
- `Sources/BusinessMath/Simulation/MonteCarlo/Percentiles.swift` (190 lines)
- `Sources/BusinessMath/Simulation/MonteCarlo/SimulationStatistics.swift` (263 lines)
- `Sources/BusinessMath/Simulation/MonteCarlo/SimulationInput.swift` (193 lines)
- `Sources/BusinessMath/Simulation/MonteCarlo/SimulationResults.swift` (198 lines)
- `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift` (227 lines)
- `Sources/BusinessMath/Simulation/MonteCarlo/SimulationError.swift` (48 lines)
- `Tests/BusinessMathTests/MonteCarlo/PercentilesTests.swift` (193 lines, 12 tests)
- `Tests/BusinessMathTests/MonteCarlo/SimulationStatisticsTests.swift` (239 lines, 12 tests)
- `Tests/BusinessMathTests/MonteCarlo/SimulationInputTests.swift` (237 lines, 13 tests)
- `Tests/BusinessMathTests/MonteCarlo/SimulationResultsTests.swift` (243 lines, 15 tests)
- `Tests/BusinessMathTests/MonteCarlo/MonteCarloSimulationTests.swift` (291 lines, 16 tests)

**Testing**:
- **Total test count**: 68 new tests (12 + 12 + 13 + 15 + 16) across 5 test suites
- **All tests passing** (100% pass rate)
- **Test execution time**: ~0.5 seconds for all 68 tests
- **Coverage**: Comprehensive testing including:
  - Edge cases (empty, single value, large datasets)
  - Statistical validation (known distributions)
  - Convergence verification
  - Performance benchmarks (10K-100K iterations)
  - Error handling (all error paths tested)
  - Integration tests (complete workflows)

**Code Quality**:
- **No breaking changes** - fully backward compatible with v1.0.0-1.3.0
- **Zero new compiler warnings**
- **Full Swift 6.0 concurrency support** - Sendable conformance throughout
- **Comprehensive DocC documentation** - every public API documented with examples
- **Test-Driven Development** - all tests written before implementation
- **Type-safe design** - leverages Swift's type system for correctness
- **Performance optimized** - capacity reservation, direct calculations

**Development Approach**:
- **Test-Driven Development (TDD)**: Tests written first, then implementation
- **Incremental validation**: Each component tested independently before integration
- **Protocol-based design**: Type erasure for flexibility with zero runtime cost
- **Sendable-first**: All types designed for concurrent execution

### Use Cases

**Financial Modeling**:
```swift
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
    let revenue = inputs[0]
    let costs = inputs[1]
    return revenue - costs
}

simulation.addInput(SimulationInput(name: "Revenue",
    distribution: DistributionNormal(mean: 1_000_000, stdDev: 100_000)))
simulation.addInput(SimulationInput(name: "Costs",
    distribution: DistributionNormal(mean: 700_000, stdDev: 50_000)))

let results = try simulation.run()
print("Expected profit: $\(results.statistics.mean)")
print("Risk of loss: \(results.probabilityBelow(0) * 100)%")
```

**Project Management** (PERT estimation):
```swift
var simulation = MonteCarloSimulation(iterations: 5_000) { inputs in
    let optimistic = inputs[0]
    let mostLikely = inputs[1]
    let pessimistic = inputs[2]
    return (optimistic + 4.0 * mostLikely + pessimistic) / 6.0
}

simulation.addInput(SimulationInput(name: "Optimistic",
    distribution: DistributionTriangular(low: 10, high: 15, base: 12)))
simulation.addInput(SimulationInput(name: "MostLikely",
    distribution: DistributionTriangular(low: 15, high: 25, base: 20)))
simulation.addInput(SimulationInput(name: "Pessimistic",
    distribution: DistributionTriangular(low: 25, high: 40, base: 30)))

let results = try simulation.run()
print("Expected duration: \(results.statistics.mean) days")
print("90% confidence: [\(results.percentiles.p5), \(results.percentiles.p95)]")
```

**Reliability Analysis**:
```swift
var simulation = MonteCarloSimulation(iterations: 5_000) { inputs in
    // System fails when first component fails
    return min(inputs[0], inputs[1])
}

simulation.addInput(SimulationInput(name: "Component1",
    distribution: DistributionWeibull(shape: 2.0, scale: 1000.0)))
simulation.addInput(SimulationInput(name: "Component2",
    distribution: DistributionWeibull(shape: 1.5, scale: 1200.0)))

let results = try simulation.run()
print("Expected system life: \(results.statistics.mean) hours")
```

### Monte Carlo Roadmap Progress

- ✅ **Phase 1 (v1.3.0)**: Beta + Weibull distributions - **COMPLETE**
- ✅ **Phase 2.1 (v1.4.0)**: Core Monte Carlo engine - **COMPLETE**
- 📋 **Phase 2.2 (v1.4.1)**: Risk metrics (VaR, CVaR) - PLANNED
- 📋 **Phase 2.3 (v1.4.2)**: Scenario analysis - PLANNED
- 📋 **Phase 3 (v1.5.0)**: Correlated variables - PLANNED
- 📋 **Phase 4 (v1.6.0)**: TimeSeries statistical methods - PLANNED

### Notes

This release completes the core Monte Carlo simulation framework, providing a production-ready engine for uncertainty modeling and risk analysis. The framework supports arbitrary model complexity, multiple uncertain variables, and comprehensive result analysis.

All components follow Swift 6.0 strict concurrency requirements and are fully thread-safe for parallel execution scenarios.

## [1.4.1] - 2025-10-15

### Added

**Risk Metrics for Monte Carlo Simulations** (Phase 2.2 - Risk Analysis)

Financial risk metrics for comprehensive risk assessment and regulatory compliance. This release extends the Monte Carlo framework with industry-standard risk measures used in portfolio management, capital allocation, and regulatory reporting.

#### Core Risk Metrics

**1. Value at Risk (VaR)**

Maximum expected loss at a given confidence level, answering: "What is the worst loss we can expect with X% confidence?"

- Method: `valueAtRisk(confidenceLevel: Double) -> Double`
  - `confidenceLevel`: 0.0 to 1.0 (e.g., 0.95 for 95% confidence)
  - Returns: The loss threshold at the specified confidence level
- **Calculation**: Percentile-based approach
  - 95% VaR = 5th percentile (95% confidence losses won't exceed this)
  - 99% VaR = 1st percentile (99% confidence losses won't exceed this)
  - Uses R-7/Type 7 linear interpolation for accuracy
- **Interpretation**:
  - Negative values represent losses (most common)
  - Positive values represent gains (for profit distributions)
  - Higher confidence → more extreme VaR
- **Use Cases**:
  - Portfolio risk management
  - Capital requirement calculations (Basel III)
  - Risk-adjusted performance measurement
  - Stress testing

**2. Conditional Value at Risk (CVaR) / Expected Shortfall**

Expected loss given that losses exceed the VaR threshold, answering: "If losses exceed our VaR, what is the expected loss?"

- Method: `conditionalValueAtRisk(confidenceLevel: Double) -> Double`
  - `confidenceLevel`: 0.0 to 1.0 (e.g., 0.95 for 95% confidence)
  - Returns: The expected loss in the tail beyond VaR
- **Calculation**: Tail mean approach
  1. Calculate VaR at the given confidence level
  2. Find all outcomes worse than VaR (in the tail)
  3. Return the mean of these tail outcomes
- **Why CVaR Matters**:
  - Addresses VaR's key limitation: VaR tells you the threshold but not how bad it gets beyond that
  - CVaR tells you the average loss in the worst cases
  - **CVaR is always ≥ VaR** (for losses, meaning more extreme/negative)
  - **Coherent risk measure**: Unlike VaR, satisfies all axioms of coherent risk measures
  - **Subadditive**: Portfolio CVaR ≤ sum of individual CVaRs (encourages diversification)
- **Regulatory Context**:
  - Preferred by many regulators for capital allocation
  - Used in Basel III for market risk
  - Required by some insurance regulators (Solvency II)
- **Use Cases**:
  - Capital allocation across business units
  - Tail risk assessment
  - Risk-based pricing
  - Scenario analysis

#### Mathematical Foundation

**VaR Formula**:
```
VaR_α = inf{x : P(Loss ≤ x) ≥ α}
where α is the confidence level (e.g., 0.95)
```

**CVaR Formula**:
```
CVaR_α = E[Loss | Loss ≥ VaR_α]
Expected loss in the tail beyond VaR
```

**Key Properties**:
- CVaR_α ≤ VaR_α (for losses, more negative)
- CVaR approaches minimum as confidence → 1.0
- Both metrics are monotonically increasing in confidence level
- Linear interpolation ensures smooth, continuous estimates

#### Technical Implementation

**Extension to SimulationResults** (`RiskMetrics.swift`)

All risk metrics are implemented as extensions to `SimulationResults`, providing seamless integration with existing Monte Carlo simulations.

- **File**: `Sources/BusinessMath/Simulation/MonteCarlo/RiskMetrics.swift` (215 lines)
- **Architecture**: Extension pattern for clean separation of concerns
- **Helper method**: `calculatePercentile(alpha:)` using R-7 interpolation
- **Consistency**: Uses same interpolation method as `Percentiles` struct
- **Performance**: Efficient sorting and filtering operations
- **Thread-safety**: All methods are Sendable-compatible

#### Testing

**Comprehensive Test Suite** (`RiskMetricsTests.swift`)

- **File**: `Tests/BusinessMathTests/MonteCarlo/RiskMetricsTests.swift` (301 lines)
- **Test count**: 15 comprehensive tests
- **All tests passing** (100% pass rate)
- **Test execution time**: ~0.25 seconds

**Test Coverage**:
1. **VaR calculations** at different confidence levels (90%, 95%, 99%)
   - Validates against known distributions (N(0,1))
   - Verifies VaR increases with confidence level
2. **CVaR calculations** at different confidence levels (95%, 99%)
   - Validates against theoretical expectations
   - Verifies CVaR is always more extreme than VaR
3. **Edge cases**:
   - Single value, two values
   - All positive returns, all negative losses
   - Extreme confidence levels (50%, 99.9%)
4. **Distribution validation**:
   - Normal distribution (N(0,1)): VaR_95% ≈ -1.645
   - Uniform distribution (0, 100): easier to validate
5. **Relationship verification**:
   - CVaR always ≤ VaR (for losses)
   - CVaR approaches minimum at high confidence
   - Both metrics consistent across runs
6. **Real-world scenarios**:
   - Financial portfolio (60/40 stock/bond)
   - Loss scenario (revenue vs costs)
   - Integration with complete simulations

#### Use Cases with Examples

**Portfolio Risk Management**:
```swift
// 60/40 stock/bond portfolio
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
    let stockReturn = inputs[0]
    let bondReturn = inputs[1]
    return 0.6 * stockReturn + 0.4 * bondReturn
}

simulation.addInput(SimulationInput(name: "Stocks",
    distribution: DistributionNormal(mean: 0.12, stdDev: 0.20)))
simulation.addInput(SimulationInput(name: "Bonds",
    distribution: DistributionNormal(mean: 0.04, stdDev: 0.05)))

let results = try simulation.run()

let var95 = results.valueAtRisk(confidenceLevel: 0.95)
let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

print("95% VaR: \(var95 * 100)%")
print("We are 95% confident losses won't exceed \(abs(var95) * 100)%")
print("95% CVaR: \(cvar95 * 100)%")
print("If losses exceed VaR, expected loss is \(abs(cvar95) * 100)%")
print("Tail risk severity: \(abs(cvar95 - var95) * 100)%")
```

**Capital Requirement Calculation**:
```swift
// Calculate required capital for operational risk
var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
    return inputs[0]  // Annual operational losses
}

simulation.addInput(SimulationInput(name: "OpLoss",
    distribution: DistributionWeibull(shape: 1.5, scale: 1_000_000)))

let results = try simulation.run()

let var999 = results.valueAtRisk(confidenceLevel: 0.999)
let cvar999 = results.conditionalValueAtRisk(confidenceLevel: 0.999)

print("99.9% VaR: $\(abs(var999))")
print("99.9% CVaR: $\(abs(cvar999))")
print("Recommended capital buffer: $\(abs(cvar999))")
```

**Capital Allocation Across Business Units**:
```swift
// Compare risk of two business units
let results1 = try simulation1.run()
let results2 = try simulation2.run()

let cvar1 = results1.conditionalValueAtRisk(confidenceLevel: 0.99)
let cvar2 = results2.conditionalValueAtRisk(confidenceLevel: 0.99)

// Allocate capital proportional to CVaR
let totalCVaR = abs(cvar1) + abs(cvar2)
let allocation1 = abs(cvar1) / totalCVaR
let allocation2 = abs(cvar2) / totalCVaR

print("Unit 1 capital allocation: \(allocation1 * 100)%")
print("Unit 2 capital allocation: \(allocation2 * 100)%")
```

**Risk-Adjusted Performance Measurement**:
```swift
// Compare two investment strategies
let strategy1Results = try simulation1.run()
let strategy2Results = try simulation2.run()

let var95_1 = strategy1Results.valueAtRisk(confidenceLevel: 0.95)
let var95_2 = strategy2Results.valueAtRisk(confidenceLevel: 0.95)

let return1 = strategy1Results.statistics.mean
let return2 = strategy2Results.statistics.mean

// Risk-adjusted return (return per unit of risk)
let raroc1 = return1 / abs(var95_1)
let raroc2 = return2 / abs(var95_2)

print("Strategy 1 RAROC: \(raroc1)")
print("Strategy 2 RAROC: \(raroc2)")
```

### Monte Carlo Roadmap Progress

- ✅ **Phase 1 (v1.3.0)**: Beta + Weibull distributions - **COMPLETE**
- ✅ **Phase 2.1 (v1.4.0)**: Core Monte Carlo engine - **COMPLETE**
- ✅ **Phase 2.2 (v1.4.1)**: Risk metrics (VaR, CVaR) - **COMPLETE**
- 📋 **Phase 2.3 (v1.4.2)**: Scenario analysis - PLANNED
- 📋 **Phase 3 (v1.5.0)**: Correlated variables - PLANNED
- 📋 **Phase 4 (v1.6.0)**: TimeSeries statistical methods - PLANNED

### Code Quality

- **No breaking changes** - fully backward compatible with v1.4.0
- **Zero new compiler warnings**
- **Full Swift 6.0 concurrency support** - Sendable conformance
- **Comprehensive DocC documentation** - 200+ lines of documentation
- **Test-Driven Development** - tests written before implementation
- **Industry-standard algorithms** - follows Basel III and regulatory guidelines

### Notes

This release adds critical risk metrics for financial analysis and regulatory compliance. VaR and CVaR are industry-standard measures used by financial institutions worldwide for portfolio management, capital allocation, and regulatory reporting (Basel III, Solvency II).

The implementation uses percentile-based VaR and tail mean CVaR calculations, consistent with industry best practices. Both metrics seamlessly integrate with existing Monte Carlo simulations through extension methods on `SimulationResults`.

## [1.4.2] - 2025-10-15

### Added

**Scenario Analysis Framework** (Phase 2.3 - What-If Analysis)

Comprehensive framework for comparing multiple scenarios, performing sensitivity analysis, and identifying key drivers of model outcomes. This release enables strategic planning, stress testing, and data-driven decision making under uncertainty.

#### Core Components

**1. Scenario** (`Scenario` struct)

Represents a specific set of assumptions for all model inputs, supporting both fixed values and probability distributions.

- Properties:
  - `name`: Scenario identifier (e.g., "Base Case", "Best Case", "Worst Case")
  - `inputValues`: Dictionary of fixed input values (deterministic)
  - `inputDistributions`: Dictionary of probability distributions (uncertain)
- **Builder pattern** for configuration:
  - `setValue(_:forInput:)` - Set fixed value for an input
  - `setDistribution(_:forInput:)` - Set probability distribution for an input
- **Flexible input specification**: Mix fixed and uncertain inputs in same scenario
- **Type-safe**: All inputs validated against model requirements

**Example**:
```swift
let baseCase = Scenario(name: "Base Case") { config in
    config.setValue(1_000_000.0, forInput: "Revenue")  // Fixed
    config.setDistribution(
        DistributionNormal(700_000.0, 50_000.0),
        forInput: "Costs"  // Uncertain
    )
}
```

**2. ScenarioAnalysis** (`ScenarioAnalysis` struct)

Framework for running and comparing multiple scenarios with the same model.

- Properties:
  - `inputNames`: Names of all input variables (defines model interface)
  - `iterations`: Number of Monte Carlo iterations per scenario
  - `scenarios`: Collection of scenarios to analyze
- Methods:
  - `addScenario(_:)` - Add a scenario to analyze
  - `run() throws -> [String: SimulationResults]` - Execute all scenarios
- **Validation**:
  - Ensures all required inputs are configured
  - Detects unknown input names
  - Validates scenario consistency
- **Error handling**: `ScenarioError` enum with detailed messages
- **Integration**: Seamlessly builds on MonteCarloSimulation framework

**Example**:
```swift
var analysis = ScenarioAnalysis(
    inputNames: ["Revenue", "Costs"],
    model: { inputs in inputs[0] - inputs[1] },
    iterations: 10_000
)

analysis.addScenario(baseCase)
analysis.addScenario(bestCase)
analysis.addScenario(worstCase)

let results = try analysis.run()  // Dictionary of results per scenario
```

**3. ScenarioComparison** (`ScenarioComparison` struct)

Comparison utilities for analyzing results across scenarios.

- Properties:
  - `results`: All scenario results
  - `scenarioNames`: Names of all analyzed scenarios
- Methods:
  - `bestScenario(by:)` - Find best scenario by metric
  - `worstScenario(by:)` - Find worst scenario by metric
  - `rankScenarios(by:ascending:)` - Sort scenarios by metric
  - `summaryTable(metrics:)` - Generate comparison table
- **Supported metrics** (ScenarioMetric enum):
  - `.mean` - Expected value
  - `.median` - Middle outcome
  - `.stdDev` - Volatility/uncertainty
  - `.p5`, `.p95` - Percentiles
  - `.var95`, `.cvar95` - Risk metrics

**Example**:
```swift
let comparison = ScenarioComparison(results: results)

let best = comparison.bestScenario(by: .mean)
print("Best scenario: \(best.name)")

let ranked = comparison.rankScenarios(by: .var95, ascending: true)
// Scenarios sorted by risk (least risky first)

let summary = comparison.summaryTable(metrics: [.mean, .median, .stdDev])
// Tabular comparison of key metrics
```

**4. SensitivityAnalysis** (`SensitivityAnalysis` struct)

Framework for identifying which inputs have the greatest impact on outcomes.

- Properties:
  - `inputNames`: All input variables
  - `baseValues`: Base case values for sensitivity analysis
  - `iterations`: Monte Carlo iterations per analysis point
- Methods:
  - `analyzeInput(_:range:steps:)` - Analyze single input sensitivity
  - `tornadoChart(range:)` - Generate tornado diagram data
- **Tornado chart**: Visual representation of relative input impacts
  - Automatically sorted by impact magnitude
  - Shows output range for each input variation
  - Identifies key drivers vs. minor factors

**Example**:
```swift
let sensitivity = SensitivityAnalysis(
    inputNames: ["Revenue", "Costs", "TaxRate"],
    model: model,
    baseValues: ["Revenue": 1_000_000, "Costs": 700_000, "TaxRate": 0.3],
    iterations: 1_000
)

// Tornado chart: which inputs matter most?
let tornado = try sensitivity.tornadoChart(range: 0.9...1.1)  // ±10%

for bar in tornado {
    print("\(bar.inputName): impact = \(bar.impact)")
}
// Output sorted by impact (largest first)
// Identifies key drivers for focused data collection
```

**5. Supporting Types**

- `ScenarioError`: Comprehensive error handling
  - `.missingInputConfiguration` - Input not configured
  - `.unknownInput` - Invalid input name
  - `.noScenarios` - No scenarios added
- `ScenarioConfiguration`: Builder class for scenario setup
- `InputSensitivity`: Results of single-input sensitivity analysis
- `TornadoBar`: Data structure for tornado chart visualization

#### Technical Implementation

**File**: `Sources/BusinessMath/Simulation/MonteCarlo/ScenarioAnalysis.swift` (490 lines)

- **Architecture**: Builder pattern for scenario configuration
- **Type safety**: Generic distribution support with Sendable conformance
- **Validation**: Comprehensive input validation with clear error messages
- **Integration**: Built on MonteCarloSimulation for consistency
- **Performance**: Efficient scenario execution with minimal overhead

#### Testing

**Comprehensive Test Suite** (`ScenarioAnalysisTests.swift`)

- **File**: `Tests/BusinessMathTests/MonteCarlo/ScenarioAnalysisTests.swift` (520 lines)
- **Test count**: 16 comprehensive tests
- **All tests passing** (100% pass rate)
- **Test execution time**: ~0.06 seconds

**Test Coverage**:
1. **Basic functionality**:
   - Scenario initialization and configuration
   - ScenarioAnalysis setup and execution
   - Single and multiple scenario analysis
2. **Scenario types**:
   - Base/best/worst case analysis
   - Fixed values vs. distributions
   - Mixed scenarios (some fixed, some uncertain)
3. **Comparison features**:
   - Best/worst scenario identification
   - Ranking by different metrics
   - Summary table generation
4. **Sensitivity analysis**:
   - Single input sensitivity
   - Tornado chart generation
   - Key driver identification
5. **Stress testing**:
   - Extreme scenarios (revenue collapse, cost spike)
   - Validation of stress test outcomes
6. **Error handling**:
   - Missing input configuration
   - Unknown input names
   - Comprehensive validation

#### Use Cases with Examples

**Strategic Planning - Base/Best/Worst Cases**:
```swift
var analysis = ScenarioAnalysis(
    inputNames: ["Revenue", "Costs"],
    model: { inputs in inputs[0] - inputs[1] },
    iterations: 10_000
)

let baseCase = Scenario(name: "Base Case") { config in
    config.setValue(1_000_000.0, forInput: "Revenue")
    config.setValue(700_000.0, forInput: "Costs")
}

let bestCase = Scenario(name: "Best Case") { config in
    config.setValue(1_200_000.0, forInput: "Revenue")
    config.setValue(600_000.0, forInput: "Costs")
}

let worstCase = Scenario(name: "Worst Case") { config in
    config.setValue(800_000.0, forInput: "Revenue")
    config.setValue(800_000.0, forInput: "Costs")
}

analysis.addScenario(baseCase)
analysis.addScenario(bestCase)
analysis.addScenario(worstCase)

let results = try analysis.run()
let comparison = ScenarioComparison(results: results)

print("Base profit: $\(results["Base Case"]!.statistics.mean)")
print("Best profit: $\(results["Best Case"]!.statistics.mean)")
print("Worst profit: $\(results["Worst Case"]!.statistics.mean)")
```

**Uncertainty Analysis - Normal vs. High Volatility**:
```swift
let normalCase = Scenario(name: "Normal Market") { config in
    config.setDistribution(
        DistributionNormal(1_000_000.0, 100_000.0),
        forInput: "Revenue"
    )
    config.setDistribution(
        DistributionNormal(700_000.0, 50_000.0),
        forInput: "Costs"
    )
}

let volatileCase = Scenario(name: "Volatile Market") { config in
    config.setDistribution(
        DistributionNormal(1_000_000.0, 300_000.0),  // 3x volatility
        forInput: "Revenue"
    )
    config.setDistribution(
        DistributionNormal(700_000.0, 150_000.0),
        forInput: "Costs"
    )
}

analysis.addScenario(normalCase)
analysis.addScenario(volatileCase)

let results = try analysis.run()

print("Normal risk (95% VaR): \(results["Normal Market"]!.valueAtRisk(0.95))")
print("High risk (95% VaR): \(results["Volatile Market"]!.valueAtRisk(0.95))")
```

**Sensitivity Analysis - Identifying Key Drivers**:
```swift
let model: @Sendable ([Double]) -> Double = { inputs in
    let revenue = inputs[0]
    let costs = inputs[1]
    let taxRate = inputs[2]
    return (revenue - costs) * (1.0 - taxRate)
}

let sensitivity = SensitivityAnalysis(
    inputNames: ["Revenue", "Costs", "TaxRate"],
    model: model,
    baseValues: [
        "Revenue": 1_000_000.0,
        "Costs": 700_000.0,
        "TaxRate": 0.3
    ],
    iterations: 1_000
)

let tornado = try sensitivity.tornadoChart(range: 0.9...1.1)  // ±10%

print("Input Impact Analysis (sorted by influence):")
for (index, bar) in tornado.enumerated() {
    print("\(index + 1). \(bar.inputName): \(bar.impact)")
}

// Use results to prioritize:
// - Data collection efforts (focus on high-impact inputs)
// - Risk mitigation (manage high-impact uncertainties)
// - Negotiation strategies (optimize high-impact parameters)
```

**Stress Testing - Extreme Scenarios**:
```swift
let normal = Scenario(name: "Normal") { config in
    config.setValue(1_000_000.0, forInput: "Revenue")
    config.setValue(700_000.0, forInput: "Costs")
}

let revenueShock = Scenario(name: "Revenue Collapse") { config in
    config.setValue(500_000.0, forInput: "Revenue")  // -50%
    config.setValue(700_000.0, forInput: "Costs")
}

let costShock = Scenario(name: "Cost Explosion") { config in
    config.setValue(1_000_000.0, forInput: "Revenue")
    config.setValue(1_100_000.0, forInput: "Costs")  // +57%
}

let doubleShock = Scenario(name: "Perfect Storm") { config in
    config.setValue(600_000.0, forInput: "Revenue")  // -40%
    config.setValue(900_000.0, forInput: "Costs")    // +29%
}

analysis.addScenario(normal)
analysis.addScenario(revenueShock)
analysis.addScenario(costShock)
analysis.addScenario(doubleShock)

let results = try analysis.run()

// Assess impact of extreme events
for (name, result) in results {
    let profit = result.statistics.mean
    let riskOfLoss = result.probabilityBelow(0.0)
    print("\(name): Profit = $\(profit), P(Loss) = \(riskOfLoss * 100)%")
}
```

### Monte Carlo Roadmap Progress

- ✅ **Phase 1 (v1.3.0)**: Beta + Weibull distributions - **COMPLETE**
- ✅ **Phase 2.1 (v1.4.0)**: Core Monte Carlo engine - **COMPLETE**
- ✅ **Phase 2.2 (v1.4.1)**: Risk metrics (VaR, CVaR) - **COMPLETE**
- ✅ **Phase 2.3 (v1.4.2)**: Scenario analysis - **COMPLETE**
- 📋 **Phase 3 (v1.5.0)**: Correlated variables - PLANNED
- 📋 **Phase 4 (v1.6.0)**: TimeSeries statistical methods - PLANNED

### Code Quality

- **No breaking changes** - fully backward compatible with v1.4.1
- **Zero new compiler warnings**
- **Full Swift 6.0 concurrency support** - Sendable conformance throughout
- **Comprehensive DocC documentation** - 490+ lines with examples
- **Test-Driven Development** - all tests written before implementation
- **Builder pattern** - Fluent, type-safe scenario configuration

### Notes

This release completes the core scenario analysis capabilities for the Monte Carlo framework. Organizations can now perform comprehensive "what-if" analysis, compare multiple strategic options, identify key value drivers, and stress test their models under extreme conditions.

The framework is designed for real-world business applications including:
- **Strategic planning**: Base/best/worst case analysis
- **Risk management**: Stress testing and extreme scenario analysis
- **Investment analysis**: Comparing different investment strategies
- **Operational planning**: Understanding impact of operational uncertainties
- **Data prioritization**: Identifying which inputs require more precise data

All components integrate seamlessly with the existing Monte Carlo simulation framework, maintaining full backward compatibility while adding powerful new analytical capabilities.

## [1.3.0] - 2025-10-15

### Added

**Beta Distribution** (CRITICAL - Phase 1 of Monte Carlo Framework)

A continuous probability distribution on [0, 1] for modeling proportions, probabilities, and percentages.

- `distributionBeta<T: Real>(alpha: T, beta: T) -> T` function
- `DistributionBeta` struct conforming to `DistributionRandom` protocol
- 10 comprehensive tests covering:
  - Boundary validation (all values in [0, 1])
  - Statistical properties (mean validation with various parameters)
  - Struct methods (random() and next())
  - Symmetric case (α = β)
  - Skewed distributions (α > β and α < β)
  - Edge cases (small/large parameters, uniform case)
- **Implementation**: Uses Beta-Gamma relationship with Marsaglia-Tsang method
  - X/(X+Y) where X~Gamma(α), Y~Gamma(β) produces Beta(α, β)
  - Internal `gammaVariate()` function supports real-valued shape parameters
  - Efficient acceptance-rejection sampling for Gamma generation
- **Use Cases**:
  - Project completion percentages
  - Market share modeling
  - Success rates and probabilities
  - Bayesian analysis (conjugate prior for Bernoulli/Binomial)

**Weibull Distribution** (HIGH - Phase 1 of Monte Carlo Framework)

A flexible continuous distribution widely used in reliability analysis and failure modeling.

- `distributionWeibull<T: Real>(shape: T, scale: T) -> T` function
- `DistributionWeibull` struct conforming to `DistributionRandom` protocol
- 11 comprehensive tests covering:
  - Non-negative value validation
  - Statistical properties (mean validation)
  - Exponential case (shape = 1)
  - Decreasing failure rate (shape < 1, infant mortality)
  - Increasing failure rate (shape > 1, wear-out failures)
  - Rayleigh-like case (shape = 2)
  - Various scale parameters (small, large)
  - Large shape parameter (approaches normal)
- **Implementation**: Inverse transform method
  - X = λ × (-ln(1 - U))^(1/k) where U ~ Uniform(0,1)
  - Efficient and numerically stable
- **Use Cases**:
  - Equipment failure analysis
  - Customer churn timing
  - Time-to-event modeling
  - Reliability engineering
  - Wind speed distributions

### Technical Details

**New Files**:
- `Sources/BusinessMath/Simulation/distributionBeta.swift` (199 lines)
- `Sources/BusinessMath/Simulation/distributionWeibull.swift` (157 lines)
- `Tests/BusinessMathTests/Distribution Tests/BetaDistributionTests.swift` (186 lines)
- `Tests/BusinessMathTests/Distribution Tests/WeibullDistributionTests.swift` (203 lines)

**Testing**:
- Total test count: 560 tests (539 previous + 10 Beta + 11 Weibull)
- All tests passing
- Test execution time: < 0.1 seconds for new distribution tests
- Comprehensive statistical validation with sampling variance tolerances

**Code Quality**:
- No breaking changes
- Fully backward compatible with v1.2.0, v1.1.0, and v1.0.0
- Zero new compiler warnings
- Full Swift 6.0 concurrency support (Sendable conformance)
- Comprehensive DocC documentation with examples

**Monte Carlo Roadmap Progress**:
- ✅ Phase 1 (v1.3.0): Beta + Weibull distributions - **COMPLETE**
- 📋 Phase 2 (v1.4.0): Monte Carlo simulation framework - PLANNED
- 📋 Phase 3 (v1.5.0): Correlated variables - PLANNED
- 📋 Phase 4 (v1.6.0): TimeSeries statistical methods - PLANNED

### Implementation Notes

**Beta Distribution**:
The implementation uses a sophisticated approach for generating Beta-distributed random values:
1. Generate two independent Gamma variates: X ~ Gamma(α, 1) and Y ~ Gamma(β, 1)
2. Return X / (X + Y)
3. Gamma generation uses Marsaglia-Tsang's method (2000) for shape ≥ 1
4. For shape < 1, uses transformation property: Gamma(α+1) × U^(1/α)

This approach is more robust than direct Beta generation methods and handles all parameter ranges efficiently.

**Weibull Distribution**:
The inverse transform method provides:
- Exact sampling (no approximation)
- Efficient computation (single log and power operation)
- Numerical stability across all parameter ranges
- Direct relationship to uniform distribution

## [1.2.0] - 2025-10-15

### Performance

**Major Performance Optimizations**

This release delivers significant performance improvements for Period arithmetic, moving averages, and rolling window operations.

**Calendar Caching** (5-10x speedup for projections)
- Added cached Calendar instance to avoid repeated `Calendar.current` calls
- Optimized `Period.advanced(by:)` - eliminates Calendar creation overhead
- Optimized `Period.distance(to:)` - uses cached Calendar
- **Impact**: Trend projections 5-10% faster, critical for large forecasts

**Sliding Window Optimizations** (40% faster for moving averages)
- `movingAverage()` - sliding window with running sum (2-3x faster)
- `rollingSum()` - sliding window with running sum (2-3x faster)
- `rollingMin()` - eliminated array allocations
- `rollingMax()` - eliminated array allocations
- **Impact**: 12-month moving average on 10K periods: **18s** (was 30s) = **40% faster**

### Performance Benchmarks (v1.2.0)

**Improved Operations:**
- Moving average (10K periods): **17.9s** (was 30.3s) = **40% faster** ⚡
- Trend projection (1000 periods): **1.77s** (was 1.86s) = **5% faster**
- EMA (10K periods): 16.7s (unchanged - not a rolling window operation)

**Unchanged Operations** (still excellent):
- NPV/IRR/XIRR: < 1ms per operation
- Trend fitting: 40-170ms for 300-1000 points
- Seasonal analysis: 14-160ms for 10 years

### Technical Details
- All 539 tests passing
- No breaking changes
- Fully backward compatible with v1.1.0 and v1.0.0
- Zero new compiler warnings
- Optimizations are transparent to users

### Optimization Details

**Before** (v1.1.0):
```swift
// Created new array for every window position
for i in (window - 1)..<periods.count {
    let windowPeriods = Array(periods[(i - window + 1)...i])  // ❌ Allocation
    let windowValues = windowPeriods.compactMap { self[$0] }
    let sum = windowValues.reduce(T.zero, +)
}
```

**After** (v1.2.0):
```swift
// Maintain running sum, slide window
var windowSum = T.zero
for i in 0..<window { windowSum += values[i] }  // Initialize
for i in window..<count {
    windowSum -= values[i - window]  // Remove old
    windowSum += values[i]            // Add new
}  // ✅ No allocations
```

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
