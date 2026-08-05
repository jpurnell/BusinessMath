# Market Data Input Modules Roadmap

**Purpose:** Transform portfolio optimization from manual parameter guessing to empirical market data estimation
**Status:** Planning Phase
**Last Updated:** 2026-01-16
**Target Version:** v2.1.0+

---

## Executive Summary

Currently, our `PortfolioOptimizer` requires users to manually provide expected returns and covariance matrices:

```swift
let optimizer = PortfolioOptimizer(
    assetNames: ["AAPL", "GOOGL", "MSFT"],
    expectedReturns: [0.12, 0.15, 0.10],  // ❌ Guessed!
    covariance: covarianceMatrix              // ❌ Guessed!
)
```

This roadmap addresses the fundamental question: **"How do we actually get these parameters from real market data?"**

### Solution Architecture

This roadmap implements a comprehensive market data input system with **seven integrated modules**:

1. **Market Data Provider** - Abstract data source layer (Yahoo Finance, Bloomberg, CSV)
2. **Historical Estimators** - Sample statistics with shrinkage correction (Ledoit-Wolf)
3. **Factor Models** - CAPM, Fama-French 3/5-factor models for expected returns
4. **Black-Litterman** - Bayesian approach mixing market equilibrium with investor views
5. **GARCH/EWMA** - Time-varying volatility and covariance estimation
6. **Robust Optimization** - Uncertainty sets for parameter ambiguity
7. **Resampling Methods** - Bootstrap and Monte Carlo for stability analysis

### Key Benefits

- **Empirical Foundation**: Replace guesses with statistical estimation from real data
- **Multiple Methodologies**: Choose approach based on use case (factor models for expected returns, shrinkage for covariance)
- **Practitioner-Friendly**: Black-Litterman allows mixing market data with subjective views
- **Risk Management**: Robust optimization handles parameter uncertainty explicitly
- **Production-Ready**: Plugin architecture supports multiple data sources (Yahoo Finance, Bloomberg, CSV)

---

## Design Principles

Following `development-guidelines/rules/ergonomicsAndPresentation.md`:

### 1. Data-Driven Model Definitions

```swift
// JSON-based configuration for data sources and estimation methods
let config = """
{
  "dataSources": [
    {"provider": "yahooFinance", "tickers": ["AAPL", "GOOGL", "MSFT"]},
    {"provider": "csv", "path": "historical_prices.csv"}
  ],
  "estimation": {
    "expectedReturns": {
      "method": "famaFrench5Factor",
      "riskFreeRate": 0.04,
      "lookbackPeriod": 252
    },
    "covariance": {
      "method": "ledoitWolf",
      "shrinkageTarget": "constantCorrelation",
      "lookbackPeriod": 252
    }
  },
  "robustness": {
    "uncertaintySet": "ellipsoidal",
    "confidenceLevel": 0.95
    }
}
"""
```

### 2. Plugin Architecture for Data Sources

```swift
// Protocol-based abstraction for data providers
protocol MarketDataProvider {
    func fetchPrices(tickers: [String], startDate: Date, endDate: Date) async throws -> TimeSeries
    func fetchFactorData(factors: [String], startDate: Date, endDate: Date) async throws -> [String: TimeSeries]
}

// Implementations
class YahooFinanceProvider: MarketDataProvider { ... }
class BloombergProvider: MarketDataProvider { ... }
class CSVProvider: MarketDataProvider { ... }
```

### 3. Declarative API for Estimation

```swift
// Fluent API for estimation pipeline
let estimator = MarketDataEstimator()
    .withDataSource(.yahooFinance(tickers: ["AAPL", "GOOGL", "MSFT"]))
    .withLookbackPeriod(252)  // 1 year of daily data
    .withExpectedReturns(.famaFrench5Factor(riskFreeRate: 0.04))
    .withCovariance(.ledoitWolf(target: .constantCorrelation))
    .withRobustness(.ellipsoidalUncertainty(confidence: 0.95))

let parameters = try await estimator.estimate()

// Seamless integration with existing PortfolioOptimizer
let optimizer = PortfolioOptimizer(
    assetNames: parameters.assetNames,
    expectedReturns: parameters.expectedReturns,
    covariance: parameters.covariance
)
```

---

## Phase Breakdown

### Phase 1: Market Data Provider Infrastructure (Foundation)

**Duration:** 2-3 sessions
**Priority:** Critical (enables all other phases)

#### 1.1 Core Abstractions

**File:** `Sources/BusinessMath/MarketData/MarketDataProvider.swift`

**Protocol Definition:**
```swift
/// Abstract interface for fetching market data from various sources.
///
/// Implementations provide:
/// - Price history for portfolio assets
/// - Factor returns (market, size, value, etc.)
/// - Risk-free rate data
/// - Benchmark returns
///
/// ## Topics
/// ### Data Fetching
/// - ``fetchPrices(tickers:startDate:endDate:)``
/// - ``fetchFactorData(factors:startDate:endDate:)``
/// - ``fetchRiskFreeRate(startDate:endDate:)``
/// - ``fetchBenchmarkReturns(benchmark:startDate:endDate:)``
public protocol MarketDataProvider: Sendable {
    /// Fetch historical prices for given tickers.
    func fetchPrices(tickers: [String], startDate: Date, endDate: Date) async throws -> [String: TimeSeries<Double>]

    /// Fetch factor returns (e.g., Fama-French factors).
    func fetchFactorData(factors: [String], startDate: Date, endDate: Date) async throws -> [String: TimeSeries<Double>]

    /// Fetch risk-free rate (e.g., 3-month T-bill).
    func fetchRiskFreeRate(startDate: Date, endDate: Date) async throws -> TimeSeries<Double>

    /// Fetch benchmark returns (e.g., S&P 500).
    func fetchBenchmarkReturns(benchmark: String, startDate: Date, endDate: Date) async throws -> TimeSeries<Double>
}
```

**Error Handling:**
```swift
/// Errors that can occur during market data fetching.
public enum MarketDataError: Error, Sendable {
    case networkError(String)
    case invalidTicker(String)
    case dataUnavailable(String)
    case dateRangeInvalid(String)
    case parseError(String)
    case rateLimitExceeded
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/MarketDataProviderTests.swift`
- [ ] Test protocol conformance with mock provider
- [ ] Test error handling (invalid ticker, date range, network)
- [ ] Test concurrent requests (multiple tickers)
- [ ] Test data validation (no missing dates, correct order)
- [ ] Test rate limiting behavior

**Expected:** 15-20 tests

---

#### 1.2 Yahoo Finance Provider

**File:** `Sources/BusinessMath/MarketData/Providers/YahooFinanceProvider.swift`

**Implementation:**
```swift
/// Yahoo Finance data provider implementation.
///
/// Uses Yahoo Finance API v8 for historical price data.
/// Free for personal use, rate-limited for production.
///
/// ## Usage Example
/// ```swift
/// let provider = YahooFinanceProvider()
/// let prices = try await provider.fetchPrices(
///     tickers: ["AAPL", "GOOGL"],
///     startDate: Date().addingTimeInterval(-365*24*3600),
///     endDate: Date()
/// )
/// ```
///
/// ## Rate Limits
/// - 2,000 requests per hour
/// - 48,000 requests per day
/// - Implement exponential backoff for 429 responses
///
/// ## Topics
/// ### Configuration
/// - ``init(apiKey:)``
/// - ``init(session:)``
///
/// - SeeAlso: ``MarketDataProvider``
public actor YahooFinanceProvider: MarketDataProvider {
    private let session: URLSession
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance"

    // Rate limiting state
    private var requestCount: Int = 0
    private var windowStart: Date = Date()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchPrices(tickers: [String], startDate: Date, endDate: Date) async throws -> [String: TimeSeries<Double>] {
        // Implementation with rate limiting, error handling, retry logic
    }
}
```

**Features:**
- Async/await for network requests
- Rate limiting with actor isolation
- Exponential backoff retry logic
- Price adjustment for splits/dividends
- CSV response parsing
- Concurrent fetching with TaskGroup

**Tests:** `Tests/BusinessMathTests/MarketData/YahooFinanceProviderTests.swift`
- [ ] Test successful price fetching (live or mocked)
- [ ] Test invalid ticker handling
- [ ] Test date range validation
- [ ] Test rate limiting behavior
- [ ] Test retry logic on transient failures
- [ ] Test split/dividend adjustment
- [ ] Test concurrent fetching (10+ tickers)
- [ ] Test response parsing (valid/invalid CSV)

**Expected:** 20-25 tests

**Performance Target:** < 2s for 5 tickers, 1 year daily data

---

#### 1.3 CSV Provider

**File:** `Sources/BusinessMath/MarketData/Providers/CSVProvider.swift`

**Implementation:**
```swift
/// CSV file data provider for historical price data.
///
/// Supports standard formats:
/// - Yahoo Finance export format
/// - Google Finance export format
/// - Custom CSV with column mapping
///
/// ## CSV Format
/// ```csv
/// Date,Open,High,Low,Close,Adj Close,Volume
/// 2024-01-01,180.00,185.00,179.00,184.50,184.50,1000000
/// 2024-01-02,184.50,186.00,183.00,185.50,185.50,950000
/// ```
///
/// ## Usage Example
/// ```swift
/// let provider = CSVProvider(path: "historical_prices.csv")
/// let prices = try await provider.fetchPrices(
///     tickers: ["AAPL"],
///     startDate: Date(),
///     endDate: Date()
/// )
/// ```
///
/// ## Column Mapping
/// Specify custom column names:
/// ```swift
/// let provider = CSVProvider(
///     path: "data.csv",
///     mapping: CSVColumnMapping(
///         dateColumn: "timestamp",
///         priceColumn: "adjusted_close",
///         tickerColumn: "symbol"
///     )
/// )
/// ```
public final class CSVProvider: MarketDataProvider, @unchecked Sendable {
    private let path: String
    private let mapping: CSVColumnMapping

    public init(path: String, mapping: CSVColumnMapping = .default) {
        self.path = path
        self.mapping = mapping
    }

    public func fetchPrices(tickers: [String], startDate: Date, endDate: Date) async throws -> [String: TimeSeries<Double>] {
        // Implementation with CSV parsing, date filtering, validation
    }
}
```

**Features:**
- Standard format detection (Yahoo, Google)
- Custom column mapping
- Date filtering by range
- Multi-ticker support (ticker column or separate files)
- Validation (monotonic dates, no gaps)
- Memory-efficient streaming for large files

**Tests:** `Tests/BusinessMathTests/MarketData/CSVProviderTests.swift`
- [ ] Test Yahoo Finance format parsing
- [ ] Test Google Finance format parsing
- [ ] Test custom column mapping
- [ ] Test date filtering
- [ ] Test multi-ticker CSV
- [ ] Test separate files per ticker
- [ ] Test validation (missing dates, invalid format)
- [ ] Test large file performance (10K+ rows)

**Expected:** 15-20 tests

**Performance Target:** < 100ms for 1,000 rows

---

#### 1.4 Factor Data Provider

**File:** `Sources/BusinessMath/MarketData/Providers/FamaFrenchDataProvider.swift`

**Implementation:**
```swift
/// Fama-French factor data provider.
///
/// Fetches factor returns from Kenneth French's data library:
/// - Market excess return (Mkt-RF)
/// - Size (SMB - Small Minus Big)
/// - Value (HML - High Minus Low)
/// - Profitability (RMW - Robust Minus Weak)
/// - Investment (CMA - Conservative Minus Aggressive)
///
/// ## Data Source
/// Source: https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html
///
/// ## Usage Example
/// ```swift
/// let provider = FamaFrenchDataProvider()
/// let factors = try await provider.fetchFactorData(
///     factors: ["Mkt-RF", "SMB", "HML"],
///     startDate: Date().addingTimeInterval(-365*24*3600),
///     endDate: Date()
/// )
/// ```
///
/// ## Available Factors
/// ### 3-Factor Model
/// - Mkt-RF: Market excess return
/// - SMB: Size factor
/// - HML: Value factor
///
/// ### 5-Factor Model (adds)
/// - RMW: Profitability factor
/// - CMA: Investment factor
///
/// ### Risk-Free Rate
/// - RF: Risk-free rate (3-month T-bill)
public actor FamaFrenchDataProvider: MarketDataProvider {
    private let baseURL = "https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp"
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchFactorData(factors: [String], startDate: Date, endDate: Date) async throws -> [String: TimeSeries<Double>] {
        // Implementation with CSV download, parsing, date filtering
    }
}
```

**Features:**
- CSV download and caching
- Daily, weekly, monthly frequency support
- Automatic date range filtering
- Factor validation (available factors)
- Unit conversion (percentage to decimal)

**Tests:** `Tests/BusinessMathTests/MarketData/FamaFrenchDataProviderTests.swift`
- [ ] Test 3-factor data fetching
- [ ] Test 5-factor data fetching
- [ ] Test risk-free rate fetching
- [ ] Test date filtering
- [ ] Test invalid factor handling
- [ ] Test frequency conversion (daily/monthly)
- [ ] Test caching behavior
- [ ] Test unit conversion

**Expected:** 15-20 tests

**Phase 1 Documentation:**
- [ ] Add `MarketDataGuide.md` to `.docc` catalog
- [ ] Document provider selection criteria
- [ ] Add data source comparison table
- [ ] Include rate limit guidelines
- [ ] Provide CSV format examples
- [ ] Add troubleshooting guide

**Phase 1 Total:** 65-80 tests, ~8-10 files, ~2,000 lines

---

### Phase 2: Historical Estimation with Shrinkage

**Duration:** 2-3 sessions
**Priority:** High (foundational for covariance estimation)

#### 2.1 Sample Statistics Estimators

**File:** `Sources/BusinessMath/MarketData/Estimation/SampleEstimators.swift`

**Implementation:**
```swift
/// Sample mean and covariance estimators from historical returns.
///
/// Implements classical moment estimators:
/// - Sample mean: μ̂ = (1/T) Σ rₜ
/// - Sample covariance: Σ̂ = (1/(T-1)) Σ (rₜ - μ̂)(rₜ - μ̂)ᵀ
///
/// ## Limitations
/// Sample covariance is **ill-conditioned** for:
/// - Short time series (T < N)
/// - Many assets (large N)
/// - Noisy data
///
/// **Solution:** Use shrinkage estimators (``LedoitWolfEstimator``)
///
/// ## Usage Example
/// ```swift
/// let returns = // [N × T matrix of returns]
/// let estimator = SampleEstimators()
/// let meanReturn = estimator.estimateMean(returns)
/// let covariance = estimator.estimateCovariance(returns)
/// ```
///
/// ## Topics
/// ### Estimation Methods
/// - ``estimateMean(_:)``
/// - ``estimateCovariance(_:)``
/// - ``estimateCorrelation(_:)``
///
/// - SeeAlso: ``LedoitWolfEstimator``
public struct SampleEstimators<T: Real>: Sendable {

    /// Estimate mean return from historical data.
    ///
    /// - Parameter returns: Matrix of returns [N assets × T periods]
    /// - Returns: Vector of mean returns [N × 1]
    public func estimateMean(_ returns: [[T]]) -> [T] {
        // Mean across time dimension for each asset
    }

    /// Estimate sample covariance matrix.
    ///
    /// Uses unbiased estimator with (T-1) denominator.
    ///
    /// - Parameter returns: Matrix of returns [N assets × T periods]
    /// - Returns: Covariance matrix [N × N]
    ///
    /// - Warning: Ill-conditioned for T < N. Use shrinkage estimators instead.
    public func estimateCovariance(_ returns: [[T]]) -> [[T]] {
        // Sample covariance with Bessel's correction
    }

    /// Estimate correlation matrix from covariance.
    ///
    /// - Parameter covariance: Covariance matrix [N × N]
    /// - Returns: Correlation matrix [N × N]
    public func estimateCorrelation(from covariance: [[T]]) -> [[T]] {
        // Normalize by standard deviations
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/SampleEstimatorsTests.swift`
- [ ] Test mean estimation (known data)
- [ ] Test covariance estimation (2×2, 3×3 matrices)
- [ ] Test correlation calculation
- [ ] Test symmetry of covariance matrix
- [ ] Test positive semi-definite property
- [ ] Test with single period (T=1)
- [ ] Test with many periods (T=252)
- [ ] Test numerical stability (near-zero variance)
- [ ] Test with real market data

**Expected:** 15-20 tests

---

#### 2.2 Ledoit-Wolf Shrinkage Estimator

**File:** `Sources/BusinessMath/MarketData/Estimation/LedoitWolfEstimator.swift`

**Implementation:**
```swift
/// Ledoit-Wolf shrinkage estimator for covariance matrices.
///
/// Shrinks sample covariance toward structured target to reduce estimation error:
/// ```
/// Σ̂ₛₕᵣᵤₙₖ = δ·F + (1-δ)·S
/// ```
/// where:
/// - S = sample covariance
/// - F = shrinkage target
/// - δ = optimal shrinkage intensity (data-driven)
///
/// ## Shrinkage Targets
///
/// ### Constant Correlation
/// All correlations equal, variances preserved:
/// ```
/// F = diag(σ) · ρ̄ · diag(σ)
/// ```
/// **Best for:** Diversified portfolios, many assets
///
/// ### Identity Matrix
/// All correlations = 0, equal variances:
/// ```
/// F = σ̄² · I
/// ```
/// **Best for:** Maximum shrinkage, extreme noise
///
/// ### Single-Factor
/// Market factor structure:
/// ```
/// F = β·β'·σ²ₘ + diag(σ²ₑ)
/// ```
/// **Best for:** Factor-based models
///
/// ## Usage Example
/// ```swift
/// let returns = // [N × T matrix]
/// let estimator = LedoitWolfEstimator<Double>(target: .constantCorrelation)
/// let (covariance, shrinkageIntensity) = estimator.estimate(returns)
/// print("Shrinkage: \(shrinkageIntensity)")  // e.g., 0.35 = 35% toward target
/// ```
///
/// ## Mathematical Background
///
/// Ledoit & Wolf (2004) derive optimal shrinkage intensity by minimizing expected loss:
/// ```
/// δ* = argmin E[||Σ̂(δ) - Σ||²]
/// ```
///
/// Closed-form solution:
/// ```
/// δ* = max(0, min(1, (κ - π) / γ))
/// ```
/// where κ, π, γ are sample statistics estimating the loss function.
///
/// ## Topics
/// ### Shrinkage Estimation
/// - ``estimate(_:)``
/// - ``estimateWithDiagnostics(_:)``
///
/// ### Shrinkage Targets
/// - ``ShrinkageTarget``
///
/// ## See Also
/// - ``SampleEstimators``
/// - [Ledoit & Wolf (2004)](https://www.ledoit.net/honey.pdf)
public struct LedoitWolfEstimator<T: Real>: Sendable {

    /// Shrinkage target structure.
    public enum ShrinkageTarget: Sendable {
        /// Constant correlation target (best for diversified portfolios)
        case constantCorrelation

        /// Identity matrix target (maximum shrinkage)
        case identity

        /// Single-factor target (market beta structure)
        case singleFactor

        /// Custom target matrix
        case custom([[T]])
    }

    public let target: ShrinkageTarget

    public init(target: ShrinkageTarget) {
        self.target = target
    }

    /// Estimate shrunk covariance matrix.
    ///
    /// - Parameter returns: Matrix of returns [N assets × T periods]
    /// - Returns: Tuple of (shrunk covariance matrix, optimal shrinkage intensity)
    ///
    /// - Note: Returns shrinkage intensity δ ∈ [0, 1] indicating proportion toward target
    public func estimate(_ returns: [[T]]) -> (covariance: [[T]], shrinkageIntensity: T) {
        // 1. Compute sample covariance S
        // 2. Compute shrinkage target F
        // 3. Estimate optimal δ from data
        // 4. Return δ·F + (1-δ)·S
    }

    /// Estimate with detailed diagnostics.
    ///
    /// - Returns: Diagnostics including estimation error, condition number, etc.
    public func estimateWithDiagnostics(_ returns: [[T]]) -> LedoitWolfDiagnostics<T> {
        // Extended diagnostics for validation
    }
}

/// Diagnostics from Ledoit-Wolf estimation.
public struct LedoitWolfDiagnostics<T: Real>: Sendable {
    public let covariance: [[T]]
    public let shrinkageIntensity: T
    public let sampleCovariance: [[T]]
    public let target: [[T]]
    public let conditionNumber: T
    public let estimatedError: T
}
```

**Key Features:**
- Data-driven shrinkage intensity (no tuning)
- Multiple target structures (constant correlation, identity, single-factor)
- Guaranteed positive-definite output
- Numerical stability for ill-conditioned problems
- Diagnostic output for validation

**Tests:** `Tests/BusinessMathTests/MarketData/LedoitWolfEstimatorTests.swift`
- [ ] Test constant correlation target
- [ ] Test identity target
- [ ] Test single-factor target
- [ ] Test custom target
- [ ] Test shrinkage intensity bounds (0 ≤ δ ≤ 1)
- [ ] Test positive-definiteness of result
- [ ] Test with well-conditioned data (δ → 0)
- [ ] Test with ill-conditioned data (δ → 1)
- [ ] Test with T < N (more assets than periods)
- [ ] Test with T >> N (many periods)
- [ ] Test numerical stability
- [ ] Compare with known results (replicate Ledoit & Wolf 2004 examples)
- [ ] Test with real market data

**Expected:** 20-25 tests

**Performance Target:** < 50ms for 50 assets, 250 periods

---

#### 2.3 Integration with Portfolio Optimizer

**File:** `Sources/BusinessMath/MarketData/PortfolioParameterEstimator.swift`

**Implementation:**
```swift
/// Estimate portfolio parameters from market data.
///
/// Integrates data fetching, return calculation, and covariance estimation
/// into a single workflow for portfolio optimization.
///
/// ## Usage Example
/// ```swift
/// let estimator = PortfolioParameterEstimator()
///     .withDataProvider(.yahooFinance())
///     .withLookbackPeriod(252)  // 1 year daily
///     .withCovarianceEstimator(.ledoitWolf(target: .constantCorrelation))
///
/// let params = try await estimator.estimate(
///     tickers: ["AAPL", "GOOGL", "MSFT", "AMZN"]
/// )
///
/// // Use with PortfolioOptimizer
/// let optimizer = PortfolioOptimizer(
///     assetNames: params.assetNames,
///     expectedReturns: params.expectedReturns,
///     covariance: params.covariance
/// )
/// ```
///
/// ## Return Calculation Methods
/// - ``ReturnMethod/arithmetic`` - Simple returns: (P₁ - P₀) / P₀
/// - ``ReturnMethod/logarithmic`` - Log returns: ln(P₁ / P₀)
/// - ``ReturnMethod/annualized`` - Annualized returns with compounding
public struct PortfolioParameterEstimator<T: Real>: Sendable {

    public enum ReturnMethod: Sendable {
        case arithmetic
        case logarithmic
        case annualized(periodsPerYear: Int)
    }

    public enum CovarianceMethod: Sendable {
        case sample
        case ledoitWolf(target: LedoitWolfEstimator<T>.ShrinkageTarget)
    }

    private var dataProvider: MarketDataProvider?
    private var lookbackPeriod: Int = 252
    private var returnMethod: ReturnMethod = .logarithmic
    private var covarianceMethod: CovarianceMethod = .ledoitWolf(target: .constantCorrelation)

    public func withDataProvider(_ provider: MarketDataProvider) -> Self {
        var copy = self
        copy.dataProvider = provider
        return copy
    }

    public func estimate(tickers: [String]) async throws -> PortfolioParameters<T> {
        // 1. Fetch price data
        // 2. Calculate returns
        // 3. Estimate mean returns (historical average)
        // 4. Estimate covariance (with shrinkage)
        // 5. Return parameters ready for optimization
    }
}

/// Portfolio parameters ready for optimization.
public struct PortfolioParameters<T: Real>: Sendable {
    public let assetNames: [String]
    public let expectedReturns: [T]
    public let covariance: [[T]]
    public let shrinkageIntensity: T?  // If Ledoit-Wolf used
    public let dataStartDate: Date
    public let dataEndDate: Date
    public let numberOfObservations: Int
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/PortfolioParameterEstimatorTests.swift`
- [ ] Test end-to-end estimation with mock provider
- [ ] Test arithmetic vs logarithmic returns
- [ ] Test annualized returns calculation
- [ ] Test sample covariance method
- [ ] Test Ledoit-Wolf covariance method
- [ ] Test with different lookback periods
- [ ] Test error handling (missing data, invalid tickers)
- [ ] Test integration with PortfolioOptimizer
- [ ] Test with real Yahoo Finance data (integration test)

**Expected:** 15-20 tests

**Phase 2 Documentation:**
- [ ] Add `CovarianceEstimation.md` to `.docc` catalog
- [ ] Explain sample covariance limitations
- [ ] Document shrinkage targets comparison
- [ ] Include numerical examples
- [ ] Add decision guide (when to use which target)
- [ ] Reference academic papers

**Phase 2 Total:** 50-65 tests, ~6-8 files, ~1,500 lines

---

### Phase 3: Factor Models (CAPM, Fama-French)

**Duration:** 3-4 sessions
**Priority:** High (industry-standard approach)

#### 3.1 Factor Model Infrastructure

**File:** `Sources/BusinessMath/MarketData/FactorModels/FactorModel.swift`

**Protocol Definition:**
```swift
/// Protocol for factor-based expected return models.
///
/// Factor models decompose asset returns into:
/// - Common factors (market, size, value, etc.)
/// - Idiosyncratic (asset-specific) component
///
/// ```
/// rᵢ = αᵢ + Σⱼ βᵢⱼ·fⱼ + εᵢ
/// ```
/// where:
/// - rᵢ = asset i return
/// - fⱼ = factor j return
/// - βᵢⱼ = loading of asset i on factor j
/// - αᵢ = alpha (excess return)
/// - εᵢ = idiosyncratic return
///
/// ## Expected Return Calculation
/// ```
/// E[rᵢ] = rₓ + Σⱼ βᵢⱼ·λⱼ
/// ```
/// where:
/// - rₓ = risk-free rate
/// - λⱼ = risk premium for factor j
///
/// ## Topics
/// ### Model Estimation
/// - ``estimateFactorLoadings(returns:factors:)``
/// - ``calculateExpectedReturns(loadings:premiums:riskFreeRate:)``
///
/// ### Diagnostics
/// - ``rsquared(returns:factors:loadings:)``
/// - ``residualVolatility(returns:factors:loadings:)``
///
/// - SeeAlso: ``CAPMModel``, ``FamaFrenchModel``
public protocol FactorModel: Sendable {
    associatedtype T: Real

    /// Estimate factor loadings (betas) via time-series regression.
    ///
    /// - Parameters:
    ///   - returns: Asset returns [N assets × T periods]
    ///   - factors: Factor returns [K factors × T periods]
    /// - Returns: Factor loadings [N × K] and alphas [N]
    func estimateFactorLoadings(
        returns: [[T]],
        factors: [[T]]
    ) -> (loadings: [[T]], alphas: [T])

    /// Calculate expected returns from factor loadings.
    ///
    /// - Parameters:
    ///   - loadings: Factor loadings [N × K]
    ///   - premiums: Factor risk premiums [K]
    ///   - riskFreeRate: Risk-free rate
    /// - Returns: Expected returns [N]
    func calculateExpectedReturns(
        loadings: [[T]],
        premiums: [T],
        riskFreeRate: T
    ) -> [T]
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/FactorModelTests.swift`
- [ ] Test protocol conformance with mock model
- [ ] Test factor loading estimation
- [ ] Test expected return calculation
- [ ] Test R² calculation
- [ ] Test residual volatility
- [ ] Test with known synthetic data

**Expected:** 10-15 tests

---

#### 3.2 CAPM Model

**File:** `Sources/BusinessMath/MarketData/FactorModels/CAPMModel.swift`

**Implementation:**
```swift
/// Capital Asset Pricing Model (CAPM) for expected returns.
///
/// CAPM is a single-factor model using the market portfolio:
/// ```
/// E[rᵢ] = rₓ + βᵢ·(E[rₘ] - rₓ)
/// ```
/// where:
/// - rₓ = risk-free rate
/// - βᵢ = asset beta (sensitivity to market)
/// - E[rₘ] = expected market return
///
/// ## Beta Estimation
/// Beta is estimated via time-series regression:
/// ```
/// rᵢₜ - rₓₜ = αᵢ + βᵢ·(rₘₜ - rₓₜ) + εᵢₜ
/// ```
///
/// ## Usage Example
/// ```swift
/// let capm = CAPMModel<Double>()
///
/// // Estimate betas
/// let assetReturns = // [3 assets × 252 periods]
/// let marketReturns = // [252 periods]
/// let (betas, alphas) = capm.estimateBetas(
///     assetReturns: assetReturns,
///     marketReturns: marketReturns,
///     riskFreeRate: 0.04 / 252  // Daily rate
/// )
///
/// // Calculate expected returns (annualized)
/// let expectedReturns = capm.expectedReturns(
///     betas: betas,
///     marketPremium: 0.08,  // 8% equity premium
///     riskFreeRate: 0.04     // 4% risk-free rate
/// )
/// ```
///
/// ## Interpretation
/// - β < 1: Defensive asset (less volatile than market)
/// - β = 1: Market-like volatility
/// - β > 1: Aggressive asset (more volatile than market)
///
/// ## Limitations
/// CAPM assumes:
/// - Single risk factor (market)
/// - All investors hold market portfolio
/// - No transaction costs, taxes
///
/// For better empirical fit, consider ``FamaFrenchModel``.
///
/// ## Topics
/// ### Estimation
/// - ``estimateBetas(assetReturns:marketReturns:riskFreeRate:)``
/// - ``expectedReturns(betas:marketPremium:riskFreeRate:)``
///
/// ### Diagnostics
/// - ``treynorRatio(excessReturn:beta:)``
/// - ``jensenAlpha(actualReturn:expectedReturn:)``
///
/// ## See Also
/// - ``FamaFrenchModel``
/// - [Sharpe (1964)](https://doi.org/10.1111/j.1540-6261.1964.tb02865.x)
public struct CAPMModel<T: Real>: FactorModel, Sendable {

    public init() {}

    /// Estimate asset betas via time-series regression.
    ///
    /// Regresses excess asset returns on excess market returns:
    /// ```
    /// rᵢ - rₓ = α + β·(rₘ - rₓ) + ε
    /// ```
    ///
    /// - Parameters:
    ///   - assetReturns: Asset returns [N assets × T periods]
    ///   - marketReturns: Market returns [T periods]
    ///   - riskFreeRate: Risk-free rate (same frequency as returns)
    /// - Returns: Betas [N] and alphas [N]
    public func estimateBetas(
        assetReturns: [[T]],
        marketReturns: [T],
        riskFreeRate: T
    ) -> (betas: [T], alphas: [T]) {
        // Time-series regression for each asset
        // Use existing linear regression infrastructure
    }

    /// Calculate expected returns using CAPM.
    ///
    /// - Parameters:
    ///   - betas: Asset betas [N]
    ///   - marketPremium: Expected market excess return (E[rₘ] - rₓ)
    ///   - riskFreeRate: Risk-free rate
    /// - Returns: Expected returns [N]
    public func expectedReturns(
        betas: [T],
        marketPremium: T,
        riskFreeRate: T
    ) -> [T] {
        // E[rᵢ] = rₓ + βᵢ·(E[rₘ] - rₓ)
    }

    /// Calculate Treynor ratio (risk-adjusted performance).
    ///
    /// ```
    /// Treynor = (rₚ - rₓ) / βₚ
    /// ```
    public func treynorRatio(excessReturn: T, beta: T) -> T {
        // Return per unit of systematic risk
    }

    /// Calculate Jensen's alpha (abnormal return).
    ///
    /// ```
    /// α = rₐctual - E[r]
    /// ```
    public func jensenAlpha(actualReturn: T, expectedReturn: T) -> T {
        // Excess return beyond CAPM prediction
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/CAPMModelTests.swift`
- [ ] Test beta estimation with synthetic data
- [ ] Test expected return calculation
- [ ] Test with β < 1 (defensive asset)
- [ ] Test with β = 1 (market-like asset)
- [ ] Test with β > 1 (aggressive asset)
- [ ] Test Treynor ratio calculation
- [ ] Test Jensen alpha calculation
- [ ] Test with real market data (S&P 500 + assets)
- [ ] Compare with Excel/Python CAPM implementation
- [ ] Test edge cases (zero beta, negative beta)

**Expected:** 20-25 tests

---

#### 3.3 Fama-French 3-Factor Model

**File:** `Sources/BusinessMath/MarketData/FactorModels/FamaFrench3FactorModel.swift`

**Implementation:**
```swift
/// Fama-French 3-factor model for expected returns.
///
/// Extends CAPM with size (SMB) and value (HML) factors:
/// ```
/// E[rᵢ] = rₓ + βᵢᴹ·λᴹ + βᵢˢ·λˢ + βᵢᴴ·λᴴ
/// ```
/// where:
/// - λᴹ = market risk premium (Mkt-RF)
/// - λˢ = size premium (SMB = Small Minus Big)
/// - λᴴ = value premium (HML = High Minus Low)
///
/// ## Factor Definitions
///
/// ### Market Factor (Mkt-RF)
/// Excess return of market portfolio over risk-free rate.
///
/// ### Size Factor (SMB)
/// Small-cap stocks outperform large-cap stocks historically.
/// SMB = return of small stocks - return of big stocks.
///
/// ### Value Factor (HML)
/// Value stocks (high book-to-market) outperform growth stocks.
/// HML = return of high B/M stocks - return of low B/M stocks.
///
/// ## Usage Example
/// ```swift
/// let ff3 = FamaFrench3FactorModel<Double>()
///
/// // Fetch factor data
/// let provider = FamaFrenchDataProvider()
/// let factors = try await provider.fetchFactorData(
///     factors: ["Mkt-RF", "SMB", "HML"],
///     startDate: startDate,
///     endDate: endDate
/// )
///
/// // Estimate factor loadings
/// let assetReturns = // [3 assets × 252 periods]
/// let (loadings, alphas) = ff3.estimateFactorLoadings(
///     returns: assetReturns,
///     factors: [factors["Mkt-RF"]!, factors["SMB"]!, factors["HML"]!]
/// )
///
/// // Calculate expected returns
/// let expectedReturns = ff3.calculateExpectedReturns(
///     loadings: loadings,
///     premiums: [0.08, 0.03, 0.05],  // Market, size, value premiums
///     riskFreeRate: 0.04
/// )
/// ```
///
/// ## Factor Premiums (Historical Averages)
/// - Market: ~8% per year
/// - Size (SMB): ~3% per year
/// - Value (HML): ~5% per year
///
/// **Note:** Historical premiums may not predict future returns.
///
/// ## Topics
/// ### Estimation
/// - ``estimateFactorLoadings(returns:factors:)``
/// - ``calculateExpectedReturns(loadings:premiums:riskFreeRate:)``
///
/// ### Diagnostics
/// - ``rsquared(returns:factors:loadings:)``
/// - ``adjustedRsquared(returns:factors:loadings:)``
///
/// ## See Also
/// - ``FamaFrench5FactorModel``
/// - ``CAPMModel``
/// - [Fama & French (1993)](https://doi.org/10.1016/0304-405X(93)90023-5)
public struct FamaFrench3FactorModel<T: Real>: FactorModel, Sendable {

    public init() {}

    public func estimateFactorLoadings(
        returns: [[T]],
        factors: [[T]]  // [Mkt-RF, SMB, HML] each [T periods]
    ) -> (loadings: [[T]], alphas: [T]) {
        // Multi-variate regression for each asset
        // rᵢ = α + βᴹ·Mkt + βˢ·SMB + βᴴ·HML + ε
    }

    public func calculateExpectedReturns(
        loadings: [[T]],  // [N assets × 3 factors]
        premiums: [T],     // [Market, SMB, HML]
        riskFreeRate: T
    ) -> [T] {
        // E[rᵢ] = rₓ + Σⱼ βᵢⱼ·λⱼ
    }

    /// Calculate R² (model fit quality).
    public func rsquared(
        returns: [[T]],
        factors: [[T]],
        loadings: [[T]]
    ) -> [T] {
        // R² for each asset
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/FamaFrench3FactorModelTests.swift`
- [ ] Test factor loading estimation
- [ ] Test expected return calculation
- [ ] Test with synthetic data (known betas)
- [ ] Test R² calculation
- [ ] Test with real Fama-French factor data
- [ ] Compare 3-factor vs CAPM R² (should improve)
- [ ] Test with growth stock (negative HML beta)
- [ ] Test with value stock (positive HML beta)
- [ ] Test with small-cap stock (positive SMB beta)
- [ ] Test with large-cap stock (negative SMB beta)

**Expected:** 20-25 tests

---

#### 3.4 Fama-French 5-Factor Model

**File:** `Sources/BusinessMath/MarketData/FactorModels/FamaFrench5FactorModel.swift`

**Implementation:**
```swift
/// Fama-French 5-factor model for expected returns.
///
/// Extends 3-factor model with profitability (RMW) and investment (CMA) factors:
/// ```
/// E[rᵢ] = rₓ + βᴹ·λᴹ + βˢ·λˢ + βᴴ·λᴴ + βᴿ·λᴿ + βᶜ·λᶜ
/// ```
///
/// ## Additional Factors
///
/// ### Profitability Factor (RMW = Robust Minus Weak)
/// Profitable firms outperform unprofitable firms.
/// RMW = return of high operating profitability - return of low profitability.
///
/// ### Investment Factor (CMA = Conservative Minus Aggressive)
/// Conservative investment firms outperform aggressive investment firms.
/// CMA = return of low investment - return of high investment.
///
/// ## Factor Premiums (Historical Averages)
/// - Market: ~8% per year
/// - Size (SMB): ~3% per year
/// - Value (HML): ~5% per year
/// - Profitability (RMW): ~3% per year
/// - Investment (CMA): ~4% per year
///
/// ## Model Comparison
///
/// | Model | R² | Complexity | Best For |
/// |-------|-----|------------|----------|
/// | CAPM | ~30% | Low | Quick estimates |
/// | FF3 | ~90% | Medium | General portfolios |
/// | FF5 | ~95% | High | Precise estimates |
///
/// ## Topics
/// ### Estimation
/// - ``estimateFactorLoadings(returns:factors:)``
/// - ``calculateExpectedReturns(loadings:premiums:riskFreeRate:)``
///
/// ## See Also
/// - ``FamaFrench3FactorModel``
/// - [Fama & French (2015)](https://doi.org/10.1016/j.jfineco.2014.10.010)
public struct FamaFrench5FactorModel<T: Real>: FactorModel, Sendable {

    public init() {}

    public func estimateFactorLoadings(
        returns: [[T]],
        factors: [[T]]  // [Mkt-RF, SMB, HML, RMW, CMA] each [T periods]
    ) -> (loadings: [[T]], alphas: [T]) {
        // Multi-variate regression with 5 factors
    }

    // ... (similar to 3-factor model)
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/FamaFrench5FactorModelTests.swift`
- [ ] Test factor loading estimation
- [ ] Test expected return calculation
- [ ] Test with real Fama-French 5-factor data
- [ ] Compare 5-factor vs 3-factor R² (should improve)
- [ ] Test with profitable company (positive RMW beta)
- [ ] Test with conservative investor (positive CMA beta)
- [ ] Test full model diagnostics

**Expected:** 15-20 tests

**Phase 3 Documentation:**
- [ ] Add `FactorModelsGuide.md` to `.docc` catalog
- [ ] Explain CAPM assumptions and limitations
- [ ] Document factor definitions and interpretations
- [ ] Include model comparison table
- [ ] Add practical examples with real tickers
- [ ] Reference academic papers
- [ ] Include expected vs realized returns discussion

**Phase 3 Total:** 65-85 tests, ~8-10 files, ~2,500 lines

---

### Phase 4: Black-Litterman Model

**Duration:** 3-4 sessions
**Priority:** Medium-High (practitioner favorite)

#### 4.1 Black-Litterman Infrastructure

**File:** `Sources/BusinessMath/MarketData/BlackLitterman/BlackLittermanModel.swift`

**Implementation:**
```swift
/// Black-Litterman model for combining market equilibrium with investor views.
///
/// Black-Litterman starts with market-implied returns (equilibrium) and adjusts
/// them based on investor views using Bayesian updating:
///
/// ```
/// E[R] = [(τΣ)⁻¹ + P'Ω⁻¹P]⁻¹ [(τΣ)⁻¹Π + P'Ω⁻¹Q]
/// ```
///
/// where:
/// - Π = market-implied equilibrium returns (reverse optimization)
/// - Σ = covariance matrix
/// - P = view matrix (picks) linking views to assets
/// - Q = view returns
/// - Ω = uncertainty in views
/// - τ = scaling factor for prior uncertainty (typically 0.025 - 0.05)
///
/// ## Key Advantages
///
/// 1. **Stability**: Market equilibrium provides stable baseline
/// 2. **Intuitive**: Express views on specific assets or combinations
/// 3. **Bayesian**: Uncertainty quantification built-in
/// 4. **Practitioner-Friendly**: Widely used in institutional asset management
///
/// ## Usage Example
///
/// ```swift
/// let bl = BlackLittermanModel<Double>(
///     marketCapitalization: [100e9, 80e9, 60e9],  // AAPL, GOOGL, MSFT
///     covariance: covarianceMatrix,
///     riskAversion: 2.5,
///     tau: 0.025
/// )
///
/// // Add investor views
/// bl.addAbsoluteView(asset: 0, expectedReturn: 0.15, confidence: 0.02)  // AAPL will return 15%
/// bl.addRelativeView(asset1: 1, asset2: 2, outperformance: 0.03, confidence: 0.05)  // GOOGL outperforms MSFT by 3%
///
/// // Compute posterior expected returns
/// let posteriorReturns = bl.computePosteriorReturns()
///
/// // Use with portfolio optimizer
/// let optimizer = PortfolioOptimizer(
///     assetNames: ["AAPL", "GOOGL", "MSFT"],
///     expectedReturns: posteriorReturns,
///     covariance: covarianceMatrix
/// )
/// ```
///
/// ## View Types
///
/// ### Absolute Views
/// "Asset i will return Q%"
/// - P: single row with 1 in position i
/// - Q: expected return
///
/// ### Relative Views
/// "Asset i will outperform asset j by Q%"
/// - P: single row with +1 in position i, -1 in position j
/// - Q: expected outperformance
///
/// ### Portfolio Views
/// "Portfolio [w₁, w₂, ...] will return Q%"
/// - P: single row with portfolio weights
/// - Q: expected portfolio return
///
/// ## Confidence Specification
///
/// View confidence (Ω) can be specified as:
/// - **Proportional to variance**: Ω = (1/c)·P·Σ·P' (recommended)
/// - **Fixed scalar**: Ω = c·I (simpler but less theoretically grounded)
///
/// Higher confidence → tighter Ω → more influence on posterior.
///
/// ## Mathematical Background
///
/// ### Reverse Optimization (Equilibrium Returns)
///
/// Given market weights wₘ, compute implied returns:
/// ```
/// Π = λ·Σ·wₘ
/// ```
/// where λ = risk aversion parameter.
///
/// ### Bayesian Update
///
/// Posterior returns combine prior (Π) with views (Q) weighted by precision:
/// ```
/// Posterior = Prior + UpdateTerm
/// ```
///
/// ## Topics
/// ### Model Creation
/// - ``init(marketCapitalization:covariance:riskAversion:tau:)``
/// - ``init(marketWeights:covariance:riskAversion:tau:)``
///
/// ### Adding Views
/// - ``addAbsoluteView(asset:expectedReturn:confidence:)``
/// - ``addRelativeView(asset1:asset2:outperformance:confidence:)``
/// - ``addPortfolioView(weights:expectedReturn:confidence:)``
///
/// ### Computation
/// - ``computePosteriorReturns()``
/// - ``computePosteriorCovariance()``
///
/// ### Diagnostics
/// - ``equilibriumReturns()``
/// - ``viewImpact()``
///
/// ## See Also
/// - [Black & Litterman (1992)](https://doi.org/10.2469/faj.v48.n5.28)
/// - [Idzorek (2007)](https://faculty.fuqua.duke.edu/~charvey/Teaching/BA453_2006/Idzorek_onBL.pdf)
public final class BlackLittermanModel<T: Real>: @unchecked Sendable {

    private let covariance: [[T]]
    private let riskAversion: T
    private let tau: T
    private let equilibriumReturns: [T]

    private var viewMatrix: [[T]] = []     // P matrix
    private var viewReturns: [T] = []      // Q vector
    private var viewUncertainty: [[T]] = [] // Ω matrix

    /// Initialize with market capitalization.
    ///
    /// - Parameters:
    ///   - marketCapitalization: Market cap for each asset (computes weights)
    ///   - covariance: Covariance matrix
    ///   - riskAversion: Risk aversion parameter λ (typically 2-4)
    ///   - tau: Prior uncertainty scaling (typically 0.025 - 0.05)
    public init(
        marketCapitalization: [T],
        covariance: [[T]],
        riskAversion: T,
        tau: T = T(0.025)
    ) {
        // Compute market weights from market cap
        // Compute equilibrium returns via reverse optimization: Π = λ·Σ·w
    }

    /// Add absolute view: "Asset i will return Q%"
    ///
    /// - Parameters:
    ///   - asset: Asset index
    ///   - expectedReturn: Expected return
    ///   - confidence: View confidence (higher = more certain, typically 0.01 - 0.10)
    public func addAbsoluteView(asset: Int, expectedReturn: T, confidence: T) {
        // P: row with 1 at asset index
        // Q: expected return
        // Ω: proportional to asset variance
    }

    /// Add relative view: "Asset i will outperform asset j by Q%"
    public func addRelativeView(asset1: Int, asset2: Int, outperformance: T, confidence: T) {
        // P: row with +1 at asset1, -1 at asset2
        // Q: outperformance
    }

    /// Compute posterior expected returns incorporating views.
    ///
    /// - Returns: Adjusted expected returns blending equilibrium and views
    public func computePosteriorReturns() -> [T] {
        // Bayesian update formula
        // E[R] = [(τΣ)⁻¹ + P'Ω⁻¹P]⁻¹ [(τΣ)⁻¹Π + P'Ω⁻¹Q]
    }

    /// Compute posterior covariance incorporating views.
    public func computePosteriorCovariance() -> [[T]] {
        // Σ_posterior = Σ + [(τΣ)⁻¹ + P'Ω⁻¹P]⁻¹
    }

    /// Get equilibrium returns (market-implied).
    public func equilibriumReturns() -> [T] {
        return self.equilibriumReturns
    }

    /// Analyze impact of each view on posterior returns.
    public func viewImpact() -> [ViewImpact<T>] {
        // Decompose posterior change by view
    }
}

/// Impact of a single view on posterior returns.
public struct ViewImpact<T: Real>: Sendable {
    public let viewIndex: Int
    public let returnShift: [T]  // Change in each asset's expected return
    public let confidence: T
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/BlackLittermanModelTests.swift`
- [ ] Test equilibrium return calculation (reverse optimization)
- [ ] Test absolute view (single asset)
- [ ] Test relative view (two assets)
- [ ] Test portfolio view
- [ ] Test posterior return calculation
- [ ] Test posterior covariance calculation
- [ ] Test view impact decomposition
- [ ] Test with high confidence view (large shift)
- [ ] Test with low confidence view (small shift)
- [ ] Test multiple views
- [ ] Test conflicting views (averaging behavior)
- [ ] Test with zero views (should return equilibrium)
- [ ] Compare with known Black-Litterman examples
- [ ] Test numerical stability

**Expected:** 25-30 tests

**Performance Target:** < 100ms for 50 assets, 5 views

---

#### 4.2 View Builder DSL

**File:** `Sources/BusinessMath/MarketData/BlackLitterman/ViewBuilder.swift`

**Implementation:**
```swift
/// Result builder for declarative Black-Litterman view specification.
///
/// Provides fluent DSL for expressing investor views:
///
/// ```swift
/// let views = BlackLittermanViews {
///     AbsoluteView(asset: "AAPL", return: 0.15, confidence: .high)
///     RelativeView(asset: "GOOGL", outperforms: "MSFT", by: 0.03, confidence: .medium)
///     PortfolioView(weights: ["AAPL": 0.5, "GOOGL": 0.5], return: 0.12, confidence: .low)
/// }
///
/// let bl = BlackLittermanModel(...)
/// bl.addViews(views)
/// ```
///
/// ## Confidence Levels
/// - `.veryHigh`: ~99% confidence (Ω = 0.01·P·Σ·P')
/// - `.high`: ~95% confidence (Ω = 0.05·P·Σ·P')
/// - `.medium`: ~80% confidence (Ω = 0.20·P·Σ·P')
/// - `.low`: ~50% confidence (Ω = 0.50·P·Σ·P')
@resultBuilder
public struct ViewBuilder {
    public static func buildBlock(_ components: BlackLittermanView...) -> [BlackLittermanView] {
        components
    }
}

/// Protocol for Black-Litterman views.
public protocol BlackLittermanView: Sendable {
    associatedtype T: Real

    func toMatrixForm(assetNames: [String]) -> (P: [T], Q: T, omega: T)
}

/// Absolute view on single asset return.
public struct AbsoluteView<T: Real>: BlackLittermanView {
    public let asset: String
    public let expectedReturn: T
    public let confidence: ViewConfidence

    public init(asset: String, return: T, confidence: ViewConfidence) {
        self.asset = asset
        self.expectedReturn = return
        self.confidence = confidence
    }
}

/// Relative view between two assets.
public struct RelativeView<T: Real>: BlackLittermanView {
    public let asset1: String
    public let asset2: String
    public let outperformance: T
    public let confidence: ViewConfidence
}

/// Portfolio-level view.
public struct PortfolioView<T: Real>: BlackLittermanView {
    public let weights: [String: T]
    public let expectedReturn: T
    public let confidence: ViewConfidence
}

/// View confidence level.
public enum ViewConfidence: Sendable {
    case veryHigh
    case high
    case medium
    case low
    case custom(Double)

    var scalar: Double {
        switch self {
        case .veryHigh: return 0.01
        case .high: return 0.05
        case .medium: return 0.20
        case .low: return 0.50
        case .custom(let value): return value
        }
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/ViewBuilderTests.swift`
- [ ] Test absolute view creation
- [ ] Test relative view creation
- [ ] Test portfolio view creation
- [ ] Test view builder syntax
- [ ] Test confidence level conversion
- [ ] Test matrix form generation
- [ ] Test integration with BlackLittermanModel

**Expected:** 10-15 tests

---

#### 4.3 Integration Example

**File:** `Sources/BusinessMath/MarketData/BlackLitterman/BlackLittermanIntegration.swift`

**Complete workflow:**
```swift
/// End-to-end Black-Litterman portfolio optimization.
///
/// This example demonstrates complete workflow:
/// 1. Fetch market data
/// 2. Estimate covariance with shrinkage
/// 3. Set up Black-Litterman model
/// 4. Add investor views
/// 5. Optimize portfolio
public struct BlackLittermanPortfolioOptimizer<T: Real>: Sendable {

    public static func optimize(
        tickers: [String],
        marketCapitalization: [T],
        views: [BlackLittermanView],
        dataProvider: MarketDataProvider,
        lookbackPeriod: Int = 252
    ) async throws -> PortfolioOptimizationResult<T> {

        // 1. Fetch price data
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -lookbackPeriod, to: endDate)!
        let prices = try await dataProvider.fetchPrices(tickers: tickers, startDate: startDate, endDate: endDate)

        // 2. Calculate returns
        let returns = calculateReturns(prices: prices)

        // 3. Estimate covariance with Ledoit-Wolf shrinkage
        let estimator = LedoitWolfEstimator<T>(target: .constantCorrelation)
        let (covariance, shrinkage) = estimator.estimate(returns)

        // 4. Set up Black-Litterman model
        let bl = BlackLittermanModel(
            marketCapitalization: marketCapitalization,
            covariance: covariance,
            riskAversion: T(2.5),
            tau: T(0.025)
        )

        // 5. Add views
        for view in views {
            bl.addView(view)
        }

        // 6. Compute posterior returns
        let posteriorReturns = bl.computePosteriorReturns()

        // 7. Optimize portfolio
        let optimizer = PortfolioOptimizer(
            assetNames: tickers,
            expectedReturns: posteriorReturns,
            covariance: covariance
        )

        let weights = try optimizer.optimizePortfolio(
            objective: .maximizeSharpe(riskFreeRate: T(0.04))
        )

        return PortfolioOptimizationResult(
            weights: weights,
            expectedReturn: dotProduct(weights, posteriorReturns),
            volatility: calculatePortfolioVolatility(weights, covariance),
            equilibriumReturns: bl.equilibriumReturns(),
            posteriorReturns: posteriorReturns,
            shrinkageIntensity: shrinkage
        )
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/BlackLittermanIntegrationTests.swift`
- [ ] Test complete workflow with mock data
- [ ] Test with real market data (integration test)
- [ ] Test with zero views (equilibrium portfolio)
- [ ] Test with single view
- [ ] Test with multiple views
- [ ] Test view impact on weights
- [ ] Compare optimized weights with naive equal-weight

**Expected:** 10-15 tests

**Phase 4 Documentation:**
- [ ] Add `BlackLittermanGuide.md` to `.docc` catalog
- [ ] Explain reverse optimization concept
- [ ] Document view types with examples
- [ ] Include confidence level guidelines
- [ ] Add complete worked example
- [ ] Reference original paper and Idzorek tutorial
- [ ] Include comparison with mean-variance optimization

**Phase 4 Total:** 45-60 tests, ~6-8 files, ~2,000 lines

---

### Phase 5: GARCH and EWMA for Time-Varying Covariance

**Duration:** 2-3 sessions
**Priority:** Medium (advanced feature)

#### 5.1 EWMA Covariance Estimator

**File:** `Sources/BusinessMath/MarketData/Estimation/EWMACovariance.swift`

**Implementation:**
```swift
/// Exponentially Weighted Moving Average (EWMA) covariance estimator.
///
/// EWMA gives more weight to recent observations, capturing time-varying volatility:
/// ```
/// σₜ² = λ·σₜ₋₁² + (1-λ)·rₜ²
/// ```
///
/// where:
/// - λ = decay factor (typically 0.94 - 0.97)
/// - rₜ = return at time t
///
/// For multivariate case:
/// ```
/// Σₜ = λ·Σₜ₋₁ + (1-λ)·rₜ·rₜ'
/// ```
///
/// ## Advantages
/// - Simple and fast
/// - Adapts to changing volatility
/// - No parameter estimation needed (λ is user-specified)
///
/// ## RiskMetrics™ Standard
/// J.P. Morgan RiskMetrics uses λ = 0.94 for daily data, 0.97 for monthly data.
///
/// ## Usage Example
/// ```swift
/// let ewma = EWMACovariance<Double>(decayFactor: 0.94)
/// let returns = // [N assets × T periods]
///
/// // Estimate current covariance
/// let currentCovariance = ewma.estimate(returns: returns)
///
/// // Forecast 1-period ahead
/// let forecastCovariance = ewma.forecast(returns: returns, horizon: 1)
/// ```
///
/// ## Decay Factor Selection
/// - **λ = 0.94**: Fast adaptation, high variance (daily data)
/// - **λ = 0.97**: Slower adaptation, low variance (monthly data)
/// - **λ → 1**: Approaches equal-weighted sample covariance
/// - **λ → 0**: Only most recent observation matters
///
/// ## Topics
/// ### Estimation
/// - ``estimate(returns:)``
/// - ``forecast(returns:horizon:)``
///
/// ### Configuration
/// - ``init(decayFactor:)``
///
/// ## See Also
/// - ``GARCHModel``
/// - [RiskMetrics Technical Document](https://www.msci.com/documents/10199/5915b101-4206-4ba0-aee2-3449d5c7e95a)
public struct EWMACovariance<T: Real>: Sendable {

    public let decayFactor: T  // λ ∈ (0, 1)

    public init(decayFactor: T) {
        precondition(decayFactor > T(0) && decayFactor < T(1), "Decay factor must be in (0, 1)")
        self.decayFactor = decayFactor
    }

    /// Estimate EWMA covariance matrix.
    ///
    /// - Parameter returns: Matrix of returns [N assets × T periods]
    /// - Returns: EWMA covariance matrix [N × N]
    public func estimate(returns: [[T]]) -> [[T]] {
        // Iterative update: Σₜ = λ·Σₜ₋₁ + (1-λ)·rₜ·rₜ'
        // Initialize Σ₀ with unconditional covariance
    }

    /// Forecast covariance h periods ahead.
    ///
    /// EWMA forecast is constant:
    /// ```
    /// Σₜ₊ₕ|ₜ = Σₜ  ∀h ≥ 1
    /// ```
    ///
    /// - Parameters:
    ///   - returns: Historical returns
    ///   - horizon: Forecast horizon
    /// - Returns: Forecasted covariance matrix
    public func forecast(returns: [[T]], horizon: Int) -> [[T]] {
        // EWMA forecasts are flat (constant variance)
        return estimate(returns: returns)
    }

    /// Estimate EWMA variances (diagonal elements only).
    ///
    /// Faster when only volatilities are needed, not correlations.
    public func estimateVariances(returns: [[T]]) -> [T] {
        // Update σᵢₜ² = λ·σᵢₜ₋₁² + (1-λ)·rᵢₜ² for each asset i
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/EWMACovarianceTests.swift`
- [ ] Test variance estimation for single asset
- [ ] Test covariance estimation for two assets
- [ ] Test with known synthetic data
- [ ] Test decay factor sensitivity (λ = 0.90, 0.94, 0.97)
- [ ] Test initialization with unconditional covariance
- [ ] Test forecast (should be constant)
- [ ] Test positive-definiteness
- [ ] Compare with sample covariance (λ → 1 limit)
- [ ] Test with real market data
- [ ] Test computational performance

**Expected:** 15-20 tests

**Performance Target:** < 20ms for 50 assets, 250 periods

---

#### 5.2 GARCH(1,1) Model (Optional - Advanced)

**File:** `Sources/BusinessMath/MarketData/Estimation/GARCHModel.swift`

**Brief specification (detailed implementation optional):**
```swift
/// GARCH(1,1) volatility model.
///
/// GARCH models conditional volatility with mean reversion:
/// ```
/// σₜ² = ω + α·rₜ₋₁² + β·σₜ₋₁²
/// ```
///
/// where:
/// - ω = long-run variance component
/// - α = ARCH coefficient (short-run shock persistence)
/// - β = GARCH coefficient (long-run persistence)
/// - Constraint: α + β < 1 (stationarity)
///
/// ## Advantages over EWMA
/// - Mean reversion to long-run variance
/// - Multi-step forecasting with decay
/// - Better theoretical properties
///
/// ## Disadvantages
/// - Requires maximum likelihood estimation (complex)
/// - Slower computation
/// - Risk of convergence issues
///
/// **Recommendation:** Start with EWMA (simpler), add GARCH if needed.
public struct GARCHModel<T: Real>: Sendable {
    public let omega: T
    public let alpha: T
    public let beta: T

    public func estimate(returns: [T]) -> [T] {
        // Maximum likelihood estimation (complex)
    }

    public func forecast(returns: [T], horizon: Int) -> [T] {
        // Forecast with mean reversion
    }
}
```

**Note:** GARCH implementation is **optional** for initial release. EWMA is simpler and often sufficient.

**Phase 5 Documentation:**
- [ ] Add `TimeVaryingCovarianceGuide.md` to `.docc` catalog
- [ ] Explain EWMA vs GARCH tradeoffs
- [ ] Document decay factor selection
- [ ] Include volatility clustering examples
- [ ] Add RiskMetrics methodology reference

**Phase 5 Total:** 15-20 tests (EWMA only), ~2-3 files, ~800 lines

---

### Phase 6: Robust Optimization with Uncertainty Sets

**Duration:** 2-3 sessions
**Priority:** Medium (advanced feature)

#### 6.1 Uncertainty Set Infrastructure

**File:** `Sources/BusinessMath/MarketData/RobustOptimization/UncertaintySet.swift`

**Implementation:**
```swift
/// Uncertainty set for robust portfolio optimization.
///
/// Robust optimization acknowledges parameter uncertainty explicitly:
/// ```
/// maximize  min_{μ ∈ U} w'μ
/// subject to w'Σw ≤ σ²_target
///            Σw = 1
/// ```
///
/// Instead of optimizing with point estimates, optimize for **worst-case**
/// within an uncertainty set.
///
/// ## Uncertainty Set Types
///
/// ### Box Uncertainty
/// ```
/// U = {μ : |μᵢ - μ̂ᵢ| ≤ δᵢ}
/// ```
/// Independent bounds on each asset return.
///
/// ### Ellipsoidal Uncertainty
/// ```
/// U = {μ : (μ - μ̂)'Σ⁻¹(μ - μ̂) ≤ ρ²}
/// ```
/// Correlated uncertainty (better theoretical properties).
///
/// ### Polyhedral Uncertainty
/// ```
/// U = {μ : Aμ ≤ b}
/// ```
/// General linear constraints on returns.
///
/// ## Usage Example
/// ```swift
/// // Create ellipsoidal uncertainty set
/// let uncertaintySet = UncertaintySet<Double>.ellipsoidal(
///     center: expectedReturns,
///     covariance: covariance,
///     radius: 1.96  // 95% confidence
/// )
///
/// // Optimize robust portfolio
/// let robustOptimizer = RobustPortfolioOptimizer(
///     assetNames: tickers,
///     uncertaintySet: uncertaintySet,
///     covariance: covariance
/// )
///
/// let weights = try robustOptimizer.optimize()
/// ```
///
/// ## Confidence Level to Radius
/// - 68% confidence: ρ = 1.0
/// - 95% confidence: ρ = 1.96
/// - 99% confidence: ρ = 2.58
///
/// ## Topics
/// ### Uncertainty Sets
/// - ``box(center:halfwidths:)``
/// - ``ellipsoidal(center:covariance:radius:)``
/// - ``polyhedral(center:constraints:)``
///
/// ### Worst-Case Computation
/// - ``worstCase(direction:)``
///
/// ## See Also
/// - ``RobustPortfolioOptimizer``
/// - [Ben-Tal & Nemirovski (1998)](https://www2.isye.gatech.edu/~nemirovs/robustbook.pdf)
public enum UncertaintySet<T: Real>: Sendable {

    /// Box uncertainty: independent bounds per asset.
    case box(center: [T], halfwidths: [T])

    /// Ellipsoidal uncertainty: correlated multivariate normal.
    case ellipsoidal(center: [T], covariance: [[T]], radius: T)

    /// Polyhedral uncertainty: general linear constraints.
    case polyhedral(center: [T], constraints: LinearConstraints<T>)

    /// Compute worst-case return in given direction.
    ///
    /// For portfolio weights w, find:
    /// ```
    /// min_{μ ∈ U} w'μ
    /// ```
    ///
    /// - Parameter direction: Portfolio weights
    /// - Returns: Worst-case return
    public func worstCase(direction: [T]) -> T {
        switch self {
        case .box(let center, let halfwidths):
            // Worst case: take lower bound when wᵢ > 0, upper bound when wᵢ < 0
            return zip(direction, zip(center, halfwidths)).map { w, (μ, δ) in
                w * (w > 0 ? μ - δ : μ + δ)
            }.reduce(T(0), +)

        case .ellipsoidal(let center, let cov, let radius):
            // Worst case: μ - ρ·√(w'Σw)
            let portfolioStdDev = sqrt(quadraticForm(weights: direction, covariance: cov))
            let centerReturn = dotProduct(direction, center)
            return centerReturn - radius * portfolioStdDev

        case .polyhedral(let center, let constraints):
            // Solve LP: min w'μ subject to constraints
            // (More complex - requires LP solver)
            fatalError("Polyhedral worst-case not yet implemented")
        }
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/UncertaintySetTests.swift`
- [ ] Test box uncertainty worst-case
- [ ] Test ellipsoidal uncertainty worst-case
- [ ] Test with all-positive weights
- [ ] Test with mixed-sign weights
- [ ] Test worst-case bounds
- [ ] Test with zero uncertainty (should equal center)
- [ ] Test with high uncertainty (large deviation)

**Expected:** 15-20 tests

---

#### 6.2 Robust Portfolio Optimizer

**File:** `Sources/BusinessMath/MarketData/RobustOptimization/RobustPortfolioOptimizer.swift`

**Implementation:**
```swift
/// Robust portfolio optimizer with uncertainty sets.
///
/// Maximizes **worst-case** return instead of expected return:
/// ```
/// maximize  min_{μ ∈ U} w'μ
/// subject to w'Σw ≤ σ²_target
///            Σw = 1, w ≥ 0
/// ```
///
/// ## Reformulation for Ellipsoidal Uncertainty
///
/// The robust problem with ellipsoidal uncertainty can be reformulated as:
/// ```
/// maximize  w'μ̂ - ρ·√(w'Σw)
/// subject to Σw = 1, w ≥ 0
/// ```
///
/// This is a **second-order cone program (SOCP)**.
///
/// ## Comparison with Standard Optimization
///
/// | Approach | Objective | Pros | Cons |
/// |----------|-----------|------|------|
/// | Standard | E[w'r] | Higher expected return | Sensitive to estimation error |
/// | Robust | min E[w'r] | Stable, conservative | Lower expected return |
///
/// ## Usage Example
/// ```swift
/// let robust = RobustPortfolioOptimizer(
///     assetNames: ["AAPL", "GOOGL", "MSFT"],
///     uncertaintySet: .ellipsoidal(
///         center: [0.10, 0.12, 0.08],
///         covariance: covarianceMatrix,
///         radius: 1.96
///     ),
///     covariance: covarianceMatrix
/// )
///
/// let weights = try robust.maximize()
///
/// // Compare with standard optimizer
/// let standard = PortfolioOptimizer(
///     assetNames: ["AAPL", "GOOGL", "MSFT"],
///     expectedReturns: [0.10, 0.12, 0.08],
///     covariance: covarianceMatrix
/// )
/// let standardWeights = try standard.optimizePortfolio(objective: .maximizeSharpe(riskFreeRate: 0.04))
///
/// print("Robust weights:", weights)
/// print("Standard weights:", standardWeights)
/// ```
public struct RobustPortfolioOptimizer<T: Real>: Sendable {

    public let assetNames: [String]
    public let uncertaintySet: UncertaintySet<T>
    public let covariance: [[T]]

    public init(
        assetNames: [String],
        uncertaintySet: UncertaintySet<T>,
        covariance: [[T]]
    ) {
        self.assetNames = assetNames
        self.uncertaintySet = uncertaintySet
        self.covariance = covariance
    }

    /// Maximize worst-case return.
    ///
    /// - Returns: Optimal robust portfolio weights
    public func maximize() throws -> [T] {
        // Solve robust optimization problem
        // For ellipsoidal uncertainty, use SOCP reformulation
        // For box uncertainty, use LP reformulation
    }

    /// Maximize worst-case Sharpe ratio.
    public func maximizeWorstCaseSharpe(riskFreeRate: T) throws -> [T] {
        // Robust Sharpe ratio optimization
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/RobustPortfolioOptimizerTests.swift`
- [ ] Test robust optimization with box uncertainty
- [ ] Test robust optimization with ellipsoidal uncertainty
- [ ] Test with zero uncertainty (should match standard optimizer)
- [ ] Test with high uncertainty (conservative weights)
- [ ] Compare robust vs standard weights
- [ ] Test worst-case return computation
- [ ] Test with real market data

**Expected:** 15-20 tests

**Phase 6 Documentation:**
- [ ] Add `RobustOptimizationGuide.md` to `.docc` catalog
- [ ] Explain robust optimization philosophy
- [ ] Document uncertainty set types
- [ ] Include comparison with standard optimization
- [ ] Add practical guidelines (when to use robust)
- [ ] Reference academic papers

**Phase 6 Total:** 30-40 tests, ~4-5 files, ~1,200 lines

---

### Phase 7: Resampling and Bootstrap Methods

**Duration:** 2 sessions
**Priority:** Low-Medium (portfolio stability analysis)

#### 7.1 Bootstrap Resampling

**File:** `Sources/BusinessMath/MarketData/Resampling/BootstrapResampler.swift`

**Implementation:**
```swift
/// Bootstrap resampling for portfolio optimization.
///
/// Addresses parameter uncertainty by:
/// 1. Resample returns (with replacement)
/// 2. Re-estimate parameters
/// 3. Optimize portfolio
/// 4. Repeat many times
/// 5. Average resulting weights
///
/// This produces more **stable** portfolios than single-sample optimization.
///
/// ## Resampled Efficient Frontier (Michaud)
///
/// Michaud's resampled efficient frontier:
/// 1. For each risk level, generate B bootstrap samples
/// 2. Optimize on each sample
/// 3. Average weights across samples
///
/// Result: Smoother, more diversified portfolios.
///
/// ## Usage Example
/// ```swift
/// let resampler = BootstrapResampler<Double>(
///     numBootstraps: 1000,
///     seed: 42
/// )
///
/// let returns = // [N × T matrix]
///
/// // Generate resampled portfolios
/// let resampledWeights = try resampler.resamplePortfolio(
///     returns: returns,
///     objective: .maximizeSharpe(riskFreeRate: 0.04)
/// )
///
/// print("Mean weights:", resampledWeights.mean)
/// print("Std weights:", resampledWeights.std)
/// print("Weight range:", resampledWeights.range)
/// ```
///
/// ## Bootstrap Sample Size
/// - **B = 100**: Quick estimate
/// - **B = 500**: Standard
/// - **B = 1,000**: High precision
/// - **B = 10,000**: Publication quality
///
/// ## Topics
/// ### Resampling
/// - ``resamplePortfolio(returns:objective:)``
/// - ``resampleEfficientFrontier(returns:riskLevels:)``
///
/// ### Diagnostics
/// - ``stabilityMetrics(weights:)``
/// - ``diversificationBenefit(original:resampled:)``
///
/// ## See Also
/// - [Michaud & Michaud (1998)](https://doi.org/10.3905/jpm.1998.409643)
public struct BootstrapResampler<T: Real>: Sendable {

    public let numBootstraps: Int
    public let seed: UInt64?

    public init(numBootstraps: Int, seed: UInt64? = nil) {
        self.numBootstraps = numBootstraps
        self.seed = seed
    }

    /// Resample portfolio optimization.
    ///
    /// - Parameters:
    ///   - returns: Historical returns [N × T]
    ///   - objective: Portfolio objective
    /// - Returns: Distribution of optimized weights
    public func resamplePortfolio(
        returns: [[T]],
        objective: PortfolioObjective<T>
    ) throws -> ResampledWeights<T> {
        var allWeights: [[T]] = []

        for _ in 0..<numBootstraps {
            // 1. Bootstrap sample returns (with replacement)
            let sampleReturns = bootstrapSample(returns)

            // 2. Estimate parameters
            let sampleMean = estimateMean(sampleReturns)
            let sampleCov = estimateCovariance(sampleReturns)

            // 3. Optimize
            let optimizer = PortfolioOptimizer(
                assetNames: (0..<returns.count).map { "Asset\($0)" },
                expectedReturns: sampleMean,
                covariance: sampleCov
            )
            let weights = try optimizer.optimizePortfolio(objective: objective)
            allWeights.append(weights)
        }

        // 4. Aggregate results
        return ResampledWeights(samples: allWeights)
    }

    private func bootstrapSample(_ returns: [[T]]) -> [[T]] {
        // Sample T periods with replacement
    }
}

/// Distribution of resampled portfolio weights.
public struct ResampledWeights<T: Real>: Sendable {
    public let samples: [[T]]

    public var mean: [T] {
        // Average weights across samples
    }

    public var std: [T] {
        // Standard deviation of weights
    }

    public var percentile: (Double) -> [T] {
        // Quantile function
    }

    public var range: ([T], [T]) {
        // (Min weights, Max weights)
    }
}
```

**Tests:** `Tests/BusinessMathTests/MarketData/BootstrapResamplerTests.swift`
- [ ] Test bootstrap sampling (verify with-replacement)
- [ ] Test resampled portfolio with known data
- [ ] Test weight averaging
- [ ] Test weight standard deviation
- [ ] Test percentile calculation
- [ ] Test with deterministic seed (reproducibility)
- [ ] Test with B=10, 100, 1000 (convergence)
- [ ] Compare resampled vs single-sample weights
- [ ] Test stability improvement

**Expected:** 15-20 tests

**Performance Target:** < 10s for 1,000 bootstraps, 50 assets

**Phase 7 Documentation:**
- [ ] Add `ResamplingMethodsGuide.md` to `.docc` catalog
- [ ] Explain bootstrap methodology
- [ ] Document stability benefits
- [ ] Include comparison with single-sample optimization
- [ ] Reference Michaud papers

**Phase 7 Total:** 15-20 tests, ~2-3 files, ~800 lines

---

## Integration and Testing Strategy

### Integration Tests

**File:** `Tests/BusinessMathTests/MarketData/EndToEndIntegrationTests.swift`

Complete workflows testing all components together:

```swift
@Test("Complete portfolio optimization workflow")
func testCompleteWorkflow() async throws {
    // 1. Fetch data
    let provider = YahooFinanceProvider()
    let tickers = ["AAPL", "GOOGL", "MSFT", "AMZN"]

    // 2. Estimate parameters with Ledoit-Wolf
    let estimator = PortfolioParameterEstimator<Double>()
        .withDataProvider(provider)
        .withLookbackPeriod(252)
        .withCovarianceEstimator(.ledoitWolf(target: .constantCorrelation))

    let params = try await estimator.estimate(tickers: tickers)

    // 3. Optimize with standard mean-variance
    let optimizer = PortfolioOptimizer(
        assetNames: params.assetNames,
        expectedReturns: params.expectedReturns,
        covariance: params.covariance
    )
    let standardWeights = try optimizer.optimizePortfolio(objective: .maximizeSharpe(riskFreeRate: 0.04))

    // 4. Optimize with Black-Litterman
    let bl = BlackLittermanModel(
        marketCapitalization: [2.5e12, 1.8e12, 2.0e12, 1.6e12],
        covariance: params.covariance,
        riskAversion: 2.5
    )
    bl.addAbsoluteView(asset: 0, expectedReturn: 0.15, confidence: 0.05)
    let blWeights = try optimizer.optimizePortfolio(objective: .maximizeSharpe(riskFreeRate: 0.04))

    // 5. Optimize with robust optimization
    let robust = RobustPortfolioOptimizer(
        assetNames: tickers,
        uncertaintySet: .ellipsoidal(
            center: params.expectedReturns,
            covariance: params.covariance,
            radius: 1.96
        ),
        covariance: params.covariance
    )
    let robustWeights = try robust.maximize()

    // 6. Bootstrap resampling
    let resampler = BootstrapResampler<Double>(numBootstraps: 100)
    let resampledWeights = try resampler.resamplePortfolio(
        returns: /* ... */,
        objective: .maximizeSharpe(riskFreeRate: 0.04)
    )

    // Assertions
    #expect(standardWeights.count == 4)
    #expect(blWeights.count == 4)
    #expect(robustWeights.count == 4)
    #expect(abs(standardWeights.reduce(0, +) - 1.0) < 0.001)  // Budget constraint
}
```

**Expected Integration Tests:** 10-15 comprehensive workflows

---

## Documentation Strategy

### Comprehensive Guides

Following `docc_guidelines.md`, create narrative DocC articles:

1. **MarketDataGuide.md** (Phase 1)
   - Overview of data providers
   - Comparison table (Yahoo Finance, Bloomberg, CSV)
   - Rate limit guidelines
   - Troubleshooting

2. **CovarianceEstimation.md** (Phase 2)
   - Sample covariance limitations
   - Shrinkage estimators explained
   - Ledoit-Wolf targets comparison
   - Decision guide

3. **FactorModelsGuide.md** (Phase 3)
   - CAPM foundations
   - Fama-French factors explained
   - Model comparison (CAPM vs FF3 vs FF5)
   - Practical examples

4. **BlackLittermanGuide.md** (Phase 4)
   - Reverse optimization concept
   - View specification examples
   - Confidence level guidelines
   - Complete worked example

5. **TimeVaryingCovarianceGuide.md** (Phase 5)
   - EWMA methodology
   - Decay factor selection
   - Volatility clustering examples

6. **RobustOptimizationGuide.md** (Phase 6)
   - Uncertainty sets explained
   - Robust vs standard optimization
   - When to use robust approach

7. **ResamplingMethodsGuide.md** (Phase 7)
   - Bootstrap methodology
   - Stability analysis
   - Michaud resampled efficient frontier

### Landing Page Integration

Add to `BusinessMath.md`:

```markdown
### Market Data & Parameter Estimation

- <doc:MarketDataGuide>
- <doc:CovarianceEstimation>
- <doc:FactorModelsGuide>
- <doc:BlackLittermanGuide>
```

### MCP Tool Documentation

Following Section 8 of `docc_guidelines.md`, create MCP tools with explicit JSON examples:

```swift
@MCPTool(
    name: "estimate_portfolio_parameters",
    description: """
    Estimate expected returns and covariance from market data.

    REQUIRED STRUCTURE:
    {
      "tickers": ["AAPL", "GOOGL", "MSFT"],
      "lookbackPeriod": 252,
      "returnMethod": "logarithmic",
      "covarianceMethod": {
        "type": "ledoitWolf",
        "target": "constantCorrelation"
      }
    }

    Example: Tech portfolio with 1-year lookback
    {
      "tickers": ["AAPL", "GOOGL", "MSFT", "AMZN"],
      "lookbackPeriod": 252,
      "returnMethod": "logarithmic",
      "covarianceMethod": {
        "type": "ledoitWolf",
        "target": "constantCorrelation"
      }
    }
    """
)
func estimatePortfolioParameters(tickers: [String], ...) async throws -> PortfolioParameters<Double> {
    // Implementation
}
```

---

## Testing Strategy (TDD Approach)

Following `test_driven_development.md`:

### 1. Write Tests First

For each module:
1. Write comprehensive test suite before implementation
2. Include edge cases and error conditions
3. Use `@Test` attributes (Swift Testing framework)
4. Deterministic seeded tests for stochastic functions

### 2. Test Structure

```swift
@Suite("Market Data Provider Tests")
struct MarketDataProviderTests {

    @Test("Fetch prices for valid tickers")
    func testFetchPricesSuccess() async throws {
        let provider = YahooFinanceProvider()
        let prices = try await provider.fetchPrices(
            tickers: ["AAPL"],
            startDate: Date().addingTimeInterval(-365*24*3600),
            endDate: Date()
        )

        #expect(prices.count == 1)
        #expect(prices["AAPL"]?.count ?? 0 > 200)  // ~252 trading days
    }

    @Test("Fetch prices with invalid ticker", .tags(.errorHandling))
    func testFetchPricesInvalidTicker() async {
        let provider = YahooFinanceProvider()

        await #expect(throws: MarketDataError.invalidTicker) {
            try await provider.fetchPrices(
                tickers: ["INVALID_TICKER_XYZ"],
                startDate: Date().addingTimeInterval(-365*24*3600),
                endDate: Date()
            )
        }
    }
}
```

### 3. Tolerance-Based Assertions

For numerical comparisons:
```swift
// Tolerance = 2 × standard error (from TDD rules)
let tolerance = 2 * standardError(samples)
#expect(abs(actual - expected) < tolerance)
```

### 4. Deterministic Tests

For stochastic methods (bootstrap, Monte Carlo):
```swift
@Test("Bootstrap resampling with seed")
func testBootstrapDeterministic() throws {
    let resampler1 = BootstrapResampler<Double>(numBootstraps: 100, seed: 42)
    let resampler2 = BootstrapResampler<Double>(numBootstraps: 100, seed: 42)

    let result1 = try resampler1.resamplePortfolio(...)
    let result2 = try resampler2.resamplePortfolio(...)

    #expect(result1.mean == result2.mean)  // Identical with same seed
}
```

---

## Performance Targets

Following `PERFORMANCE.md`:

### Phase-by-Phase Targets

| Phase | Operation | Target | Notes |
|-------|-----------|--------|-------|
| 1 | Yahoo Finance fetch (5 tickers, 1 year) | < 2s | Network dependent |
| 1 | CSV parsing (1,000 rows) | < 100ms | Local I/O |
| 2 | Sample covariance (50 assets, 250 periods) | < 50ms | O(N²T) complexity |
| 2 | Ledoit-Wolf shrinkage (50 assets, 250 periods) | < 100ms | Additional matrix inversion |
| 3 | CAPM beta estimation (10 assets, 250 periods) | < 20ms | 10 regressions |
| 3 | FF3 loading estimation (10 assets, 250 periods) | < 50ms | Multivariate regression |
| 4 | Black-Litterman posterior (50 assets, 5 views) | < 100ms | Matrix operations |
| 5 | EWMA covariance (50 assets, 250 periods) | < 50ms | Iterative updates |
| 6 | Robust optimization (50 assets) | < 200ms | SOCP solving |
| 7 | Bootstrap resampling (1,000 samples, 50 assets) | < 10s | Parallelizable |

### Optimization Opportunities

From `PERFORMANCE.md` findings:

1. **Matrix Operations**: Use BLAS/LAPACK where available
2. **Parallel Execution**: TaskGroup for concurrent ticker fetching
3. **Caching**: Cache factor data, covariance matrices
4. **Sparse Matrices**: For large portfolios (100+ assets)

---

## Migration Path for Existing Code

### Current PortfolioOptimizer Usage

```swift
// Today: Manual parameter specification
let optimizer = PortfolioOptimizer(
    assetNames: ["AAPL", "GOOGL", "MSFT"],
    expectedReturns: [0.12, 0.15, 0.10],  // ❌ Guessed
    covariance: covarianceMatrix              // ❌ Guessed
)
```

### After Phase 2: Empirical Estimation

```swift
// After Phase 2: Historical estimation
let estimator = PortfolioParameterEstimator()
    .withDataProvider(.yahooFinance())
    .withLookbackPeriod(252)
    .withCovarianceEstimator(.ledoitWolf(target: .constantCorrelation))

let params = try await estimator.estimate(tickers: ["AAPL", "GOOGL", "MSFT"])

let optimizer = PortfolioOptimizer(
    assetNames: params.assetNames,
    expectedReturns: params.expectedReturns,  // ✅ Empirical
    covariance: params.covariance              // ✅ Shrinkage-corrected
)
```

### After Phase 3: Factor Models

```swift
// After Phase 3: Factor-based expected returns
let ff3 = FamaFrench3FactorModel<Double>()
let factors = try await provider.fetchFactorData(factors: ["Mkt-RF", "SMB", "HML"], ...)
let (loadings, _) = ff3.estimateFactorLoadings(returns: assetReturns, factors: factors)
let expectedReturns = ff3.calculateExpectedReturns(
    loadings: loadings,
    premiums: [0.08, 0.03, 0.05],  // Market, size, value premiums
    riskFreeRate: 0.04
)

let optimizer = PortfolioOptimizer(
    assetNames: tickers,
    expectedReturns: expectedReturns,  // ✅ Factor-based
    covariance: params.covariance
)
```

### After Phase 4: Black-Litterman

```swift
// After Phase 4: Equilibrium + views
let bl = BlackLittermanModel(...)
bl.addAbsoluteView(asset: "AAPL", expectedReturn: 0.15, confidence: .high)
let posteriorReturns = bl.computePosteriorReturns()

let optimizer = PortfolioOptimizer(
    assetNames: tickers,
    expectedReturns: posteriorReturns,  // ✅ Equilibrium + views
    covariance: params.covariance
)
```

**Backward Compatibility:** Existing manual parameter specification continues to work. New modules are additive.

---

## Implementation Checklist

### Phase 1: Market Data Provider Infrastructure ⬜

- [ ] `MarketDataProvider.swift` protocol (15-20 tests)
- [ ] `YahooFinanceProvider.swift` implementation (20-25 tests)
- [ ] `CSVProvider.swift` implementation (15-20 tests)
- [ ] `FamaFrenchDataProvider.swift` implementation (15-20 tests)
- [ ] `MarketDataGuide.md` documentation
- [ ] Integration with existing `TimeSeries` types
- [ ] MCP tool for data fetching
- [ ] **Total:** 65-80 tests, ~8-10 files, ~2,000 lines

### Phase 2: Historical Estimation with Shrinkage ⬜

- [ ] `SampleEstimators.swift` implementation (15-20 tests)
- [ ] `LedoitWolfEstimator.swift` implementation (20-25 tests)
- [ ] `PortfolioParameterEstimator.swift` integration (15-20 tests)
- [ ] `CovarianceEstimation.md` documentation
- [ ] MCP tool for parameter estimation
- [ ] **Total:** 50-65 tests, ~6-8 files, ~1,500 lines

### Phase 3: Factor Models (CAPM, Fama-French) ⬜

- [ ] `FactorModel.swift` protocol (10-15 tests)
- [ ] `CAPMModel.swift` implementation (20-25 tests)
- [ ] `FamaFrench3FactorModel.swift` implementation (20-25 tests)
- [ ] `FamaFrench5FactorModel.swift` implementation (15-20 tests)
- [ ] `FactorModelsGuide.md` documentation
- [ ] MCP tools for factor estimation
- [ ] **Total:** 65-85 tests, ~8-10 files, ~2,500 lines

### Phase 4: Black-Litterman Model ⬜

- [ ] `BlackLittermanModel.swift` implementation (25-30 tests)
- [ ] `ViewBuilder.swift` DSL (10-15 tests)
- [ ] `BlackLittermanIntegration.swift` workflow (10-15 tests)
- [ ] `BlackLittermanGuide.md` documentation
- [ ] MCP tools for BL optimization
- [ ] **Total:** 45-60 tests, ~6-8 files, ~2,000 lines

### Phase 5: GARCH and EWMA ⬜

- [ ] `EWMACovariance.swift` implementation (15-20 tests)
- [ ] `GARCHModel.swift` implementation (optional)
- [ ] `TimeVaryingCovarianceGuide.md` documentation
- [ ] **Total:** 15-20 tests, ~2-3 files, ~800 lines

### Phase 6: Robust Optimization ⬜

- [ ] `UncertaintySet.swift` infrastructure (15-20 tests)
- [ ] `RobustPortfolioOptimizer.swift` implementation (15-20 tests)
- [ ] `RobustOptimizationGuide.md` documentation
- [ ] **Total:** 30-40 tests, ~4-5 files, ~1,200 lines

### Phase 7: Resampling Methods ⬜

- [ ] `BootstrapResampler.swift` implementation (15-20 tests)
- [ ] `ResamplingMethodsGuide.md` documentation
- [ ] **Total:** 15-20 tests, ~2-3 files, ~800 lines

### Integration & Documentation ⬜

- [ ] End-to-end integration tests (10-15 tests)
- [ ] Performance benchmarking
- [ ] Update `BusinessMath.md` landing page
- [ ] Create tutorial examples
- [ ] Update README.md
- [ ] Create CHANGELOG entry

---

## Success Criteria

### Functionality

- [ ] All seven modules implemented and tested
- [ ] 285-365 tests passing (across all phases)
- [ ] < 5 compiler warnings
- [ ] Integration with existing `PortfolioOptimizer`
- [ ] Backward compatibility maintained

### Documentation

- [ ] 7+ DocC guide articles
- [ ] All public APIs documented
- [ ] Practical examples for each module
- [ ] MCP tools with explicit JSON examples
- [ ] Updated landing page

### Performance

- [ ] All performance targets met
- [ ] < 2s for data fetching (network dependent)
- [ ] < 100ms for covariance estimation (50 assets)
- [ ] < 10s for bootstrap resampling (1,000 samples)

### Code Quality

- [ ] TDD approach followed throughout
- [ ] Consistent with existing coding standards
- [ ] Swift 6 concurrency compliance (@Sendable, actor isolation)
- [ ] Comprehensive error handling

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1 | 2-3 sessions | 2-3 sessions |
| Phase 2 | 2-3 sessions | 4-6 sessions |
| Phase 3 | 3-4 sessions | 7-10 sessions |
| Phase 4 | 3-4 sessions | 10-14 sessions |
| Phase 5 | 2-3 sessions | 12-17 sessions |
| Phase 6 | 2-3 sessions | 14-20 sessions |
| Phase 7 | 2 sessions | 16-22 sessions |
| Integration & Docs | 2-3 sessions | **18-25 sessions** |

**Estimated Total:** 18-25 working sessions (assuming 2-4 hours per session)

---

## References

### Academic Papers

1. **Ledoit & Wolf (2004)** - "Honey, I Shrunk the Sample Covariance Matrix"
   - https://www.ledoit.net/honey.pdf

2. **Fama & French (1993)** - "Common Risk Factors in the Returns on Stocks and Bonds"
   - https://doi.org/10.1016/0304-405X(93)90023-5

3. **Fama & French (2015)** - "A Five-Factor Asset Pricing Model"
   - https://doi.org/10.1016/j.jfineco.2014.10.010

4. **Black & Litterman (1992)** - "Global Portfolio Optimization"
   - https://doi.org/10.2469/faj.v48.n5.28

5. **Idzorek (2007)** - "A Step-by-Step Guide to the Black-Litterman Model"
   - https://faculty.fuqua.duke.edu/~charvey/Teaching/BA453_2006/Idzorek_onBL.pdf

6. **Michaud & Michaud (1998)** - "Efficient Asset Management"
   - https://doi.org/10.3905/jpm.1998.409643

7. **Ben-Tal & Nemirovski (1998)** - "Robust Optimization"
   - https://www2.isye.gatech.edu/~nemirovs/robustbook.pdf

### Industry Standards

1. **RiskMetrics™ Technical Document** (J.P. Morgan, 1996)
   - https://www.msci.com/documents/10199/5915b101-4206-4ba0-aee2-3449d5c7e95a

2. **Kenneth French Data Library**
   - https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html

---

## Notes

### Design Decisions

1. **Plugin Architecture**: Chose protocol-based data providers for flexibility (Yahoo Finance, Bloomberg, CSV, future providers)

2. **Ledoit-Wolf over Other Shrinkage**: Most widely used, analytically tractable, no parameter tuning

3. **EWMA before GARCH**: EWMA is simpler and often sufficient; GARCH is optional advanced feature

4. **Factor Models Priority**: Industry standard (CAPM, Fama-French) before exotic alternatives

5. **Black-Litterman over Pure Equilibrium**: Practitioners need to incorporate views, not just use market weights

6. **Ellipsoidal Uncertainty Sets**: Better theoretical properties than box constraints, computationally tractable

### Future Enhancements (Post-v2.1)

- [ ] Conditional Value-at-Risk (CVaR) optimization
- [ ] Transaction cost modeling
- [ ] Multi-period portfolio optimization
- [ ] Alternative data sources (Quandl, FRED)
- [ ] Real-time data streaming
- [ ] Machine learning return forecasts (neural networks, random forests)
- [ ] Alternative risk measures (downside deviation, semivariance)
- [ ] Regime-switching models (Hidden Markov Models)

---

## Appendix: Code Size Estimates

### Total Project Addition

| Component | Files | Lines | Tests |
|-----------|-------|-------|-------|
| Phase 1: Market Data | 8-10 | 2,000 | 65-80 |
| Phase 2: Shrinkage | 6-8 | 1,500 | 50-65 |
| Phase 3: Factor Models | 8-10 | 2,500 | 65-85 |
| Phase 4: Black-Litterman | 6-8 | 2,000 | 45-60 |
| Phase 5: GARCH/EWMA | 2-3 | 800 | 15-20 |
| Phase 6: Robust | 4-5 | 1,200 | 30-40 |
| Phase 7: Resampling | 2-3 | 800 | 15-20 |
| Integration & Docs | 5-7 | 1,500 | 10-15 |
| **Total** | **41-54** | **~12,300** | **295-385** |

---

## Contact & Collaboration

For questions, suggestions, or contributions related to this roadmap:

- **GitHub Issues**: [BusinessMath Issues](https://github.com/username/BusinessMath/issues)
- **Email**: [Contact](mailto:your-email@example.com)
- **Discussions**: [GitHub Discussions](https://github.com/username/BusinessMath/discussions)

---

**Document Status:** Draft
**Last Updated:** 2026-01-16
**Next Review:** After Phase 1 completion
