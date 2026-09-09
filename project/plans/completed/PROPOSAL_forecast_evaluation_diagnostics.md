# Design Proposal: Forecast Evaluation & Diagnostics Tier

**Status:** APPROVED (2026-07-26) — moved to UPCOMING, implementation started
**Author:** Session 2026-07-26
**Supersedes:** None
**Related:** Time Series module, Forecasting module, Streaming module

**Locked decisions (open questions resolved at approval):**
- #2 Async backtest → **synchronous v1**; async TaskGroup variant deferred.
- #3 `projectWithConfidence` → **kept**, DocC amended to mark bands in-sample and point
  to `empiricalIntervals`.
- #5 MCP scope → **ship `backtest_forecast`, `assess_forecastability`,
  `test_stationarity` first**; remaining tools after API stabilizes.
- #6 Entropy threshold → **default `strict` = 0.9**; verdict buckets calibrated against
  benchmark datasets during Green.
- #7 R1 scope → **ADF + KPSS tests only**; auto-differencing (`ndiffs`) deferred.

**Revision v2 (2026-07-26)** — incorporates review feedback aligning the proposal
more tightly with the article and the Fail-Silent principle:
- **R1. Stationarity testing (ADF + KPSS)** added to Component 4 — tells users whether
  to difference before fitting a trend model.
- **R2. Refusal logic** — a `strict` mode on backtest/forecast entry points that
  **throws** `.unforecastableSeries` when the forecastability verdict is `.noise`,
  rather than returning a plausible-but-wrong line.
- **R3. Exogenous-ready `Forecaster`** — the protocol now carries an optional
  `ForecastRegressors` parameter from day one (nil in v1), so adding ARIMAX-style
  exogenous forecasting later is **not** a breaking change. Exogenous *modeling* stays
  a formal Phase 2.
- **R4. Auto seasonality detection** — a `dominantSeasonLength()` helper (built on the
  new ACF) suggests the season length, so MASE / seasonal-naive no longer *require*
  manual configuration.

---

## 0. Motivation (Why now)

This proposal is a direct response to Suzy Ahyah's *"The Unreasonable Difficulty of
Time Series Forecasting"* (2026-06-27) and an audit of BusinessMath's current
time-series surface.

The audit found that BusinessMath has a **strong point-forecasting tier**
(`LinearTrend`/`ExponentialTrend`/`LogisticTrend`, `HoltWintersModel`,
`MovingAverageModel`, decomposition, seasonal indices) but an **entirely absent
evaluation-and-diagnostics tier**. Concretely, the following are missing:

| Capability | Present today? |
|---|---|
| Out-of-sample / rolling-origin backtesting | ❌ Absent — only in-sample `fitMAE`/`fitRMSE`/`fitMAPE` |
| Naive / seasonal-naive baseline forecasters | ❌ Absent — simplest baseline is a moving average |
| Scaled error (MASE) | ❌ Absent |
| Forecastability measure (spectral entropy, skill-vs-naive) | ❌ Absent (an `FFTBackend` exists but is not exposed for this) |
| Residual diagnostics (ACF / PACF / Ljung-Box) | ❌ Absent — residuals stored, only summarized as MAE/RMSE |
| Empirical (backtest-derived) prediction intervals | ❌ Absent — current bands are parametric in-sample residual × z |

### The core problem: overconfident intervals violate our own Fail-Silent rule

`TrendModel.projectWithConfidence` derives its confidence bands from the **in-sample
residual MSE**, widened by a parametric horizon factor
`sqrt(1 + 1/n + h²/(12n))` (`TrendModel.swift:483-489`). On an event-driven business
series — a revenue line about to hit a regime change, an FX rate, a credit spread —
those bands are **confidently narrow and wrong**, because in-sample residuals from a
calm period say nothing about the shock that defines the forecast horizon.

A 95% interval that systematically understates risk is *precisely* a
"plausible-but-wrong result" — a violation of the project's stated **Fail-Silent
principle**. The article's "forecasting is extrapolation, not interpolation → test
data is guaranteed to be out-of-distribution" is the theoretical reason our
parametric bands are structurally optimistic.

The article's prescription reorders the workflow: the **first** deliverable to a user
should not be a point forecast, it should be a *forecastability verdict* — which may
say "this series is indistinguishable from noise; do not trust any point forecast."
This proposal builds the tier that lets BusinessMath say that.

**Master Plan Reference:** Time Series & Forecasting maturity — adds the evaluation
layer that makes every existing forecaster *honest* and *comparable*.

---

## 1. Objective

Add a **Forecast Evaluation & Diagnostics tier** consisting of five cooperating
components:

1. **Rolling-origin backtesting harness** — out-of-sample, walk-forward evaluation
   that works with *any* forecaster via a uniform closure.
2. **Naive / seasonal-naive / drift baselines** — the benchmarks every forecast is
   measured against, and the denominator for scaled error.
3. **Forecastability score** — spectral entropy (0–1) plus skill-vs-naive ratio, so a
   user knows whether to model at all.
4. **Series & residual diagnostics** — ACF, PACF, the Ljung-Box test, **and formal
   stationarity/unit-root tests (ADF + KPSS)** to check whether a model extracted the
   autocorrelation structure and whether the raw series even needs differencing first.
5. **Empirical prediction intervals** — bands derived from backtest residual quantiles
   per horizon, replacing/supplementing the parametric bands.

Two cross-cutting behaviours run through these components:

- **Refusal (Fail-Silent enforcement):** a `strict` mode that throws
  `.unforecastableSeries` instead of returning a confident-looking forecast on a series
  the forecastability score classes as noise.
- **Exogenous-readiness:** the `Forecaster` protocol accepts an optional
  `ForecastRegressors` argument now (unused in v1), so the eventual **Phase 2** —
  exogenous/driver-based forecasting, which the article argues is the real source of
  lift for event-driven series — lands without a breaking API change.

Design principle throughout: **the harness is model-agnostic.** Components 2–5 all
build on Component 1's backtest output, so item 1 is the foundation and ships first.

---

## 2. Proposed Architecture

### New Files

```
Sources/BusinessMath/Forecasting/Evaluation/
├── Forecaster.swift              # Unifying protocol + closure adapter + ForecastRegressors (R3)
├── RollingOriginBacktest.swift   # The walk-forward harness (Component 1) + strict mode (R2)
├── BacktestReport.swift          # Per-fold + aggregate result type
├── Baselines.swift               # Naive, SeasonalNaive, Drift (Component 2)
├── ScaledError.swift             # MASE + scaled-error helpers (Component 2)
├── Forecastability.swift         # Spectral entropy + skill score + refusal (Component 3, R2)
└── EmpiricalIntervals.swift      # Backtest-quantile bands (Component 5)

Sources/BusinessMath/Time Series/Diagnostics/
├── Autocorrelation.swift         # acf() / pacf() + dominantSeasonLength() (Component 4, R4)
├── LjungBox.swift                # Ljung-Box whiteness test (Component 4)
└── Stationarity.swift            # ADF + KPSS unit-root tests (Component 4, R1)
```

### Modified Files

```
Sources/BusinessMath/Time Series/Growth/TrendModel.swift
    # Conform LinearTrend/ExponentialTrend/LogisticTrend/CustomTrend to Forecaster
    # (retroactive extension only — no change to existing signatures)

Sources/BusinessMath/Forecasting/HoltWintersModel.swift
Sources/BusinessMath/Forecasting/MovingAverageModel.swift
    # Conform to Forecaster via extension (additive; existing API untouched)
```

### Module Placement Rationale

- **`Forecasting/Evaluation/`** (new subdirectory) — everything that *judges* a
  forecast. Keeps evaluation separate from the models it evaluates, so the dependency
  arrow points one way (evaluation → models, never the reverse).
- **`Time Series/Diagnostics/`** (new subdirectory) — ACF/PACF/Ljung-Box are
  properties of a *series* (or residual series), not of a forecaster, so they live
  next to `TimeSeriesAnalytics`, not in `Evaluation/`. `detect_anomalies` /
  `decomposeTimeSeries` set the precedent for series-level analytics here.

---

## 3. API Surface

### 3.1 Unifying `Forecaster` protocol (the keystone)

The single abstraction that lets one harness drive every model. A forecaster is
anything that, given a training series and a horizon, produces a forecast series.

```swift
/// Optional exogenous regressors accompanying a forecast (R3 — exogenous-readiness).
///
/// In v1 this is ALWAYS nil; no shipped forecaster reads it. It exists so that adding
/// exogenous/driver-based forecasting in Phase 2 requires no change to the `Forecaster`
/// protocol or to any call site. A future ARIMAX-style model reads `historical`
/// (aligned to the training window) and `future` (known-ahead drivers spanning the
/// forecast horizon, e.g. calendar, planned promotions, published rates).
public struct ForecastRegressors<Value: Real & Sendable & Codable>: Sendable {
    /// Driver series aligned to the training history.
    public let historical: [TimeSeries<Value>]
    /// Driver series covering the forecast horizon (must be known ahead of time).
    public let future: [TimeSeries<Value>]
    public init(historical: [TimeSeries<Value>], future: [TimeSeries<Value>])
}

/// Anything that can be trained on history and produce an h-step-ahead forecast.
///
/// This is the adapter that lets the backtester drive trend models, Holt-Winters,
/// moving averages, and naive baselines through one uniform call. Each fold calls
/// `trainedForecast` on a *fresh* training window, so implementations must not carry
/// state between calls.
public protocol Forecaster<Value>: Sendable {
    associatedtype Value: Real & Sendable & Codable

    /// Train on `history` (optionally with exogenous drivers) and forecast `horizon`
    /// periods. Univariate forecasters ignore `exogenous`; in v1 it is always nil.
    /// - Returns: a forecast series of length `horizon` immediately following history.
    /// - Throws: `ForecastError` on insufficient/invalid data.
    func trainedForecast(
        from history: TimeSeries<Value>,
        exogenous: ForecastRegressors<Value>?,
        horizon: Int
    ) throws -> TimeSeries<Value>
}

public extension Forecaster {
    /// Convenience for the common univariate call site — forwards `exogenous: nil`.
    /// This is the method the backtester and every v1 caller use.
    func trainedForecast(from history: TimeSeries<Value>, horizon: Int) throws -> TimeSeries<Value> {
        try trainedForecast(from: history, exogenous: nil, horizon: horizon)
    }
}

/// Closure adapter — wrap any (train, exogenous, horizon) -> forecast function.
/// A univariate convenience initializer is provided that ignores exogenous input.
public struct AnyForecaster<Value: Real & Sendable & Codable>: Forecaster {
    public init(_ body: @escaping @Sendable (TimeSeries<Value>, ForecastRegressors<Value>?, Int) throws -> TimeSeries<Value>)
    public init(univariate body: @escaping @Sendable (TimeSeries<Value>, Int) throws -> TimeSeries<Value>)
    public func trainedForecast(from history: TimeSeries<Value>, exogenous: ForecastRegressors<Value>?, horizon: Int) throws -> TimeSeries<Value>
}
```

> **Why bake `exogenous` in now (R3)?** Adding a parameter to a protocol requirement
> later is a source-breaking change for every conformer and call site. Introducing it
> as an optional from day one — with a univariate convenience overload so v1 code never
> mentions it — means Phase 2 is purely *additive*. This is the ADR-worthy decision in
> §9.

Existing models get retroactive conformance (no public signature changes; they
implement the 3-arg requirement and ignore `exogenous`):

```swift
extension LinearTrend: Forecaster { /* fit(to:) then project(periods:) */ }
extension ExponentialTrend: Forecaster { … }
extension LogisticTrend: Forecaster { … }
extension HoltWintersModel: Forecaster { … }
extension MovingAverageModel: Forecaster { … }
```

> Note: `TrendModel.fit(to:)` is `mutating`, so the conformance copies `self` into a
> local `var`, fits, and projects — leaving the caller's model untouched and keeping
> `trainedForecast` non-mutating and `Sendable`-safe.

### 3.2 Component 1 — Rolling-origin backtest

```swift
/// How the training window grows across folds.
public enum BacktestWindow: Sendable {
    case expanding              // train grows: [0..<origin]
    case sliding(length: Int)   // train is a fixed-length trailing window
}

/// Configuration for walk-forward evaluation.
public struct BacktestConfig: Sendable {
    public var initialTrainSize: Int   // periods before the first forecast origin
    public var horizon: Int            // steps forecast at each origin (h)
    public var step: Int               // origins advance by this many periods (default 1)
    public var window: BacktestWindow  // .expanding (default) or .sliding

    /// R2 — Fail-Silent refusal. When `.strict(maxSpectralEntropy:)`, the backtest
    /// first measures forecastability on the full series and THROWS
    /// `BacktestError.unforecastableSeries` if spectral entropy exceeds the threshold,
    /// rather than producing metrics for a series that is indistinguishable from noise.
    /// Default `.lenient` preserves today's "always compute" behaviour.
    public var refusal: RefusalPolicy

    public init(initialTrainSize: Int, horizon: Int, step: Int = 1,
                window: BacktestWindow = .expanding,
                refusal: RefusalPolicy = .lenient)
}

/// R2 — how aggressively to refuse low-signal series.
public enum RefusalPolicy: Sendable {
    case lenient                                  // never refuse (default; back-compatible)
    case strict(maxSpectralEntropy: Double)       // throw if entropy > threshold (e.g. 0.9)
}

public enum BacktestError: Error {
    case seriesTooShort(required: Int, got: Int)
    case invalidConfig(String)
    /// R2 — thrown under `.strict` refusal when the series is classed as noise.
    /// Carries the measured score so callers can log/surface it.
    case unforecastableSeries(spectralEntropy: Double, threshold: Double)
}

extension TimeSeries where T: BinaryFloatingPoint {
    /// Walk-forward evaluate a forecaster against held-out actuals.
    ///
    /// At each origin the forecaster is trained on data up to the origin and asked to
    /// forecast `horizon` steps; the forecast is scored against the true future values.
    /// No future data ever enters training — this is the anti-leakage guarantee.
    public func backtest<F: Forecaster>(
        _ forecaster: F,
        config: BacktestConfig
    ) throws -> BacktestReport<T> where F.Value == T
}
```

```swift
/// Result of a rolling-origin backtest.
public struct BacktestReport<T: BinaryFloatingPoint & Sendable>: Sendable {
    /// One entry per forecast origin.
    public let folds: [BacktestFold<T>]

    /// Out-of-sample aggregate errors pooled across all folds & horizons.
    public let rmse: T
    public let mae: T
    public let mape: T
    public let mase: T?          // nil if no seasonal period / degenerate scale

    /// Per-horizon-step residuals: index h-1 holds all errors made h steps ahead.
    /// This is the raw material for empirical prediction intervals (Component 5).
    public let residualsByHorizon: [[T]]

    public let foldCount: Int
    public let horizon: Int
}

public struct BacktestFold<T: BinaryFloatingPoint & Sendable>: Sendable {
    public let originIndex: Int
    public let actual: TimeSeries<T>
    public let forecast: TimeSeries<T>
    public let errors: ForecastErrorMetrics<T>   // reuses existing type
}
```

### 3.3 Component 2 — Baselines + MASE

```swift
/// Repeat the last observed value for every horizon step.
public struct NaiveForecaster<Value: Real & Sendable & Codable>: Forecaster {
    public init()
}

/// Repeat the value from one full season ago (period m). The canonical benchmark
/// for seasonal data and the MASE scaling denominator for seasonal series.
public struct SeasonalNaiveForecaster<Value: Real & Sendable & Codable>: Forecaster {
    public init(seasonLength: Int)
}

/// Naive + average historical drift (last value + h · mean first difference).
public struct DriftForecaster<Value: Real & Sendable & Codable>: Forecaster {
    public init()
}
```

```swift
extension TimeSeries where T: BinaryFloatingPoint {
    /// Mean Absolute Scaled Error (Hyndman & Koehler 2006).
    /// Scale = in-sample MAE of the naive (m=1) or seasonal-naive (m=seasonLength)
    /// one-step forecast on `training`. MASE < 1 ⇒ beats the naive benchmark.
    /// - Parameter seasonLength: pass `training.dominantSeasonLength(maxLag:) ?? 1`
    ///   (R4) to let ACF suggest the period instead of hardcoding it.
    /// - Returns: nil if the scaling denominator is zero (constant training series).
    public func mase(
        against forecast: TimeSeries<T>,
        training: TimeSeries<T>,
        seasonLength: Int = 1
    ) -> T?
}
```

### 3.4 Component 3 — Forecastability

```swift
/// A verdict on how much exploitable structure a series contains.
public struct ForecastabilityReport<T: BinaryFloatingPoint & Sendable>: Sendable {
    /// Spectral entropy normalized to [0, 1]. 1 = white noise (unforecastable),
    /// near 0 = highly concentrated spectrum (very forecastable). Goerg (2013).
    public let spectralEntropy: T

    /// 1 − (entropy). Convenience: higher = more forecastable.
    public let forecastability: T

    /// Skill score vs seasonal-naive from a backtest: 1 − (model MASE). Optional
    /// because it requires a fitted model; the spectral measure is model-free.
    public let skillVsNaive: T?

    /// Human-readable bucket: .noise, .weak, .moderate, .strong.
    public let verdict: ForecastabilityVerdict
}

public enum ForecastabilityVerdict: String, Sendable, Codable {
    case noise, weak, moderate, strong
}

extension TimeSeries where T: BinaryFloatingPoint {
    /// Model-free forecastability from the normalized spectral entropy of the series.
    /// If `seasonLength` is nil, uses `dominantSeasonLength` (R4) to inform the report.
    public func forecastability(seasonLength: Int? = nil) throws -> ForecastabilityReport<T>

    /// R2 — Fail-Silent gate. Throws `BacktestError.unforecastableSeries` when the
    /// series' spectral entropy exceeds `maxSpectralEntropy`. This is the single
    /// enforcement point that `BacktestConfig.refusal == .strict(...)` calls, and it
    /// is also exposed directly so a caller can refuse before any forecast at all.
    @discardableResult
    public func requireForecastable(maxSpectralEntropy: Double) throws -> ForecastabilityReport<T>
}
```

### 3.5 Component 4 — Series & residual diagnostics

**Autocorrelation + auto season detection (R4):**

```swift
extension TimeSeries where T: BinaryFloatingPoint {
    /// Sample autocorrelation function for lags 1...maxLag (index 0 = lag 1).
    public func autocorrelation(maxLag: Int) -> [T]

    /// Partial autocorrelation via Durbin–Levinson recursion, lags 1...maxLag.
    public func partialAutocorrelation(maxLag: Int) -> [T]

    /// R4 — Suggest the dominant seasonal period by finding the lag (≥ 2) with the
    /// strongest ACF peak that also exceeds the ~95% white-noise band (±1.96/√n).
    /// Returns nil when no lag clears the band (no detectable seasonality) — callers
    /// then fall back to `seasonLength: 1` (non-seasonal). Purely advisory: it
    /// *suggests*, it does not silently override an explicit season length.
    /// - Parameter maxLag: largest candidate period to consider (e.g. 2·expected season).
    public func dominantSeasonLength(maxLag: Int) -> Int?
}
```

**Stationarity / unit-root tests (R1):**

```swift
/// Outcome of a unit-root / stationarity test.
public struct StationarityTestResult<T: BinaryFloatingPoint & Sendable>: Sendable {
    public let statistic: T
    public let pValue: T
    public let usedLag: Int
    /// Interpreted verdict for THIS test's null hypothesis (see per-test docs).
    public let isStationary: Bool
    /// Plain-language recommendation, e.g. "difference once (d=1) before fitting".
    public let recommendation: String
}

extension TimeSeries where T: BinaryFloatingPoint {
    /// Augmented Dickey–Fuller test. H0: a unit root is present (NON-stationary).
    /// Low p ⇒ reject H0 ⇒ `isStationary = true`. Lag selected by rule
    /// `⌊12·(n/100)^{1/4}⌋` (Schwert) unless overridden.
    public func augmentedDickeyFuller(lag: Int? = nil) throws -> StationarityTestResult<T>

    /// KPSS test. H0: the series IS (trend-)stationary — the complement of ADF.
    /// Low p ⇒ reject H0 ⇒ `isStationary = false`. Running both disambiguates the
    /// inconclusive cases where a single test is ambiguous.
    public func kpss(regression: KPSSRegression = .level, lag: Int? = nil) throws -> StationarityTestResult<T>
}

public enum KPSSRegression: Sendable { case level, trend }
```

> **Why both ADF and KPSS (R1)?** They have opposite null hypotheses, so their
> agreement/disagreement is itself the signal: ADF-reject + KPSS-fail-to-reject ⇒
> confidently stationary; the reverse ⇒ confidently needs differencing; disagreement ⇒
> flag as ambiguous rather than pretend certainty (Fail-Silent). This is why the tests
> live in Component 4 *before* modeling: they tell the user to `diff(lag:)` (an existing
> operator) before ever fitting a `TrendModel`.

**Ljung–Box whiteness (residual structure):**

```swift
/// Result of the Ljung–Box portmanteau test for residual autocorrelation.
public struct LjungBoxResult<T: BinaryFloatingPoint & Sendable>: Sendable {
    public let statistic: T     // Q
    public let degreesOfFreedom: Int
    public let pValue: T
    public let lags: Int
    /// True ⇒ reject "residuals are white noise" at the given alpha (structure remains).
    public func rejectsWhiteNoise(alpha: T) -> Bool
}

extension TimeSeries where T: BinaryFloatingPoint {
    /// Ljung–Box test (Ljung & Box 1978) on this series (typically model residuals).
    /// - Parameter fittedParameters: subtracted from dof (e.g. p+q for ARIMA).
    public func ljungBox(lags: Int, fittedParameters: Int = 0) throws -> LjungBoxResult<T>
}
```

### 3.6 Component 5 — Empirical prediction intervals

```swift
extension BacktestReport where T: BinaryFloatingPoint {
    /// Build prediction intervals from the empirical distribution of out-of-sample
    /// residuals at each horizon step, centered on a supplied point forecast.
    ///
    /// Unlike the parametric bands in `projectWithConfidence`, these widen with
    /// horizon *as the data actually did out-of-sample* — capturing the regime-shift
    /// risk that in-sample residuals hide.
    public func empiricalIntervals(
        around pointForecast: TimeSeries<T>,
        confidenceLevel: T
    ) -> ForecastWithConfidence<T>     // reuses existing type
}
```

---

## 4. Error Handling Strategy

Follows the Fail-Silent principle: degradation is **thrown or annotated**, never
silently plausible.

| Condition | Behavior |
|---|---|
| Series shorter than `initialTrainSize + horizon` | `throw BacktestError.seriesTooShort` |
| `horizon < 1`, `step < 1`, `initialTrainSize < 1` | `throw BacktestError.invalidConfig` |
| MASE scale denominator is 0 (constant training) | **return `nil`** (documented) — not a fake number |
| Forecaster throws inside a fold | propagate `ForecastError`; the whole backtest fails loudly rather than dropping a fold silently |
| Ljung-Box with `lags ≤ fittedParameters` (dof ≤ 0) | `throw ForecastError.invalidParameter` |
| ACF/PACF `maxLag ≥ n` | clamp to `n-1` and document; empty series ⇒ `[]` |
| Spectral entropy of a constant/degenerate series | entropy = 1 (treated as unforecastable), `verdict = .noise` |
| MAPE where any actual = 0 | inherit existing `forecastError` behavior (skips those periods) |
| **R2** `.strict` refusal + entropy over threshold | `throw BacktestError.unforecastableSeries(spectralEntropy:threshold:)` — never a fake metric |
| **R1** ADF/KPSS on series too short for the chosen lag | `throw ForecastError.insufficientData` (lag needs `n > lag + 2`) |
| **R1** ADF/KPSS disagree (both reject) | Report both; `recommendation` = "ambiguous — inspect/difference and re-test" (no false certainty) |
| **R4** `dominantSeasonLength` finds no lag above the band | **return `nil`** → caller falls back to `seasonLength: 1` (documented) |

No `!`, no `try!`, no `as!`. All division guarded (`mase`, ACF normalization, entropy
normalization each guard their denominator before dividing).

---

## 5. Constraints & Compliance

```
Concurrency:  All new types are immutable value types → Sendable. Forecaster: Sendable.
              Backtest is pure/synchronous in v1 (an async TaskGroup variant is a
              follow-up, mirroring AsyncDEASolver — see Open Questions).
Generics:     Gated on `T: BinaryFloatingPoint` to match existing ForecastErrorMetrics
              and forecastError(against:). Forecaster.Value: Real & Sendable & Codable
              to match ForecastWithConfidence.
Safety:       No force unwraps/casts; every divisor guarded; bounded loops (lags,
              folds, horizons all finite from config).
Determinism:  Fully deterministic — no RNG. Same series + config → identical report.
              (Empirical intervals are quantiles of observed residuals, not sampled.)
Expr. complexity: Compound generic arithmetic (Ljung-Box Q, spectral entropy,
              Durbin–Levinson) broken into intermediate `let ... : T` bindings,
              ≤ 3 operators per expression, per the CI 6.0.3 rule.
MCP Ready:    JSON schemas defined below for the four user-facing entry points.
```

---

## 6. Backend Abstraction

Spectral entropy needs a periodogram (FFT). An `FFTBackend.swift` already exists
(used by streaming anomaly detection) — Component 3 **reuses it**, no new backend.

```
Compute profile:   All components are O(n · maxLag) or O(n log n) (FFT). Not GPU-tier
                   for typical business series (n ≤ few thousand). CPU-only.
FFT:               Reuse existing FFTBackend; CPU fallback already present for Linux.
No new Metal/Accelerate code.  Backtest is embarrassingly parallel across folds — a
                   future async backend is noted in Open Questions, not v1.
```

---

## 7. Dependencies

```
Internal:
- Time Series/TimeSeries.swift              (container)
- Time Series/TimeSeriesAnalytics.swift     (ForecastErrorMetrics, diff, mean helpers)
- Statistics/Descriptors/Error Metrics/{mae,mape,rmse}.swift  (reused in folds)
- Forecasting/ForecastTypes.swift           (ForecastWithConfidence, ForecastError)
- Streaming/FFTBackend.swift                (periodogram for spectral entropy)
- Statistics/Probability Distribution/chiSquaredCDF.swift — `chiSquaredCDF(x:df:)`
  for Ljung-Box p-values. CONFIRMED PRESENT (used by kendallW.swift and
  LMEApplications.swift as `pValue = 1 - chiSquaredCDF(...)`). Do NOT use the
  deprecated `chi2cdf` (documented incorrect: CDF ≠ 1 − PDF).

External: None (swift-numerics only).
```

---

## 8. Test Strategy

**Reference truth** (independently verifiable — no hallucinated expected values):

- **Rolling origin & MASE:** Hyndman & Athanasopoulos, *Forecasting: Principles and
  Practice* (FPP3), §5.10 (time-series cross-validation) and Hyndman & Koehler (2006)
  for MASE. Cross-check numeric values against R `forecast::tsCV` and
  `Metrics::mase` / `forecast::accuracy`.
- **Seasonal-naive & drift:** FPP3 §5.2 benchmark definitions.
- **ACF/PACF:** cross-validate against Python `statsmodels.tsa.stattools.acf`/`pacf`
  and R `stats::acf`/`pacf` on a fixed AR(1) fixture.
- **Ljung-Box:** Ljung & Box (1978); cross-check Q and p-value against
  `statsmodels.stats.diagnostic.acorr_ljungbox`.
- **Spectral entropy:** Goerg (2013) "Forecastable Component Analysis"; cross-check
  against R `forecast::spectral_entropy` / `tsfeatures`.
- **ADF (R1):** Dickey & Fuller (1979); cross-check statistic against
  `statsmodels.tsa.stattools.adfuller` on a fixed random-walk vs. stationary-AR(1)
  fixture (random walk ⇒ fail to reject; AR(1) φ=0.5 ⇒ reject).
- **KPSS (R1):** Kwiatkowski et al. (1992); cross-check against
  `statsmodels.tsa.stattools.kpss` (opposite verdict to ADF on the same fixtures).
- **Auto season (R4):** on a fixture with injected period-12 seasonality,
  `dominantSeasonLength` must return 12; cross-check the ACF peak against `statsmodels`.

**Test categories (per `test_driven_development.md`):**

| Category | Examples |
|---|---|
| Golden path | AR(1) series → PACF spike at lag 1, decaying ACF; pure sine → low spectral entropy; white noise → entropy ≈ 1, `.noise` verdict |
| Baseline correctness | NaiveForecaster on `[10,11,12]` h=3 → `[12,12,12]`; SeasonalNaive m=4 repeats last season exactly; drift slope = mean first-difference |
| MASE | Hand-computed fixture: forecast == naive ⇒ MASE == 1.0; constant training ⇒ nil |
| Backtest leakage guard | **Fault-injection:** a forecaster that peeks at index > origin must be impossible — assert each fold's training series `.max(period) < forecast.min(period)` |
| Backtest mechanics | expanding vs sliding fold counts; `step > 1` origin spacing; `foldCount` matches `(n - initialTrainSize - horizon)/step + 1` |
| Empirical intervals | Symmetric residuals ⇒ symmetric band; 95% band contains ~95% of held-out actuals on a stationary fixture; band widens with horizon |
| Ljung-Box | White-noise residuals ⇒ high p (fail to reject); AR(1) residuals ⇒ low p (reject) |
| **Stationarity (R1)** | random walk ⇒ ADF fails to reject + KPSS rejects (non-stationary); AR(1) φ=0.5 ⇒ ADF rejects + KPSS fails to reject (stationary) |
| **Refusal (R2)** | white-noise series under `.strict(0.9)` ⇒ `backtest` throws `.unforecastableSeries`; strongly-seasonal series under same policy ⇒ completes normally |
| **Auto season (R4)** | injected period-12 series ⇒ `dominantSeasonLength` == 12; flat/noise series ⇒ nil |
| **Exogenous plumbing (R3)** | `AnyForecaster(univariate:)` ignores a supplied `ForecastRegressors`; the 2-arg convenience overload forwards `exogenous: nil` — confirms adding drivers later needs no call-site change |
| Edge cases | series too short (throws), horizon=0 (throws), maxLag ≥ n (clamped), constant series (entropy=1) |
| Determinism | same series + config → byte-identical report across runs |

**Validation trace (becomes a Golden Path assertion):**

> `NaiveForecaster().trainedForecast(from: TimeSeries([10,11,12,13]), horizon: 3)`
> **must equal** `[13, 13, 13]`.
>
> For `y = [1,2,3,4,5]`, one-step naive in-sample MAE = mean(|Δ|) = 1.0. A forecast
> equal to the naive forecast therefore has **MASE = 1.0** exactly. This exact value
> is the pinned assertion.
>
> `ljungBox(lags: 10)` on i.i.d. N(0,1) residuals (fixed seed fixture) → p-value > 0.05
> and cross-matches `statsmodels` to 1e-6.

---

## 9. Architecture Decision Review

```
ADR Check:
- [x] Reviewed architecture_decisions.md for related decisions
- [ ] Supersedes an existing ADR? No
- [ ] Amends an existing ADR? No
- [x] New ADR required? Yes → draft below
```

**New ADR Draft (1 of 2):**
- **Title:** Model-agnostic forecast evaluation via a `Forecaster` closure abstraction
- **Category:** api / testing
- **Key decision:** All forecast evaluation (backtest, baselines, intervals,
  forecastability) is driven through one `Forecaster` protocol / `AnyForecaster`
  closure, so evaluation never depends on any concrete model type and every current
  and future forecaster is evaluable for free. Existing parametric
  `projectWithConfidence` bands are **retained but documented as in-sample**, with
  backtest-derived `empiricalIntervals` as the recommended path for event-driven
  series.

**New ADR Draft (2 of 2) — R3:**
- **Title:** `Forecaster` is exogenous-ready from v1 (optional `ForecastRegressors`)
- **Category:** api / architecture
- **Key decision:** The `Forecaster` requirement carries an optional
  `exogenous: ForecastRegressors<Value>?` parameter from the first release, always nil
  in v1, with a univariate convenience overload so no v1 call site references it. This
  makes **Phase 2** (exogenous/driver-based forecasting — the article's identified
  source of lift for event-driven series) a purely additive change rather than a
  source-breaking protocol revision. Exogenous *modeling* itself is explicitly out of
  scope for this proposal and tracked as Phase 2.

---

## 10. Open Questions

1. ~~**χ² CDF availability**~~ — **RESOLVED.** `chiSquaredCDF(x:df:) throws -> T`
   already exists (`Statistics/Probability Distribution/chiSquaredCDF.swift`) and is
   the exact pattern used by `kendallW`/`LMEApplications` for p-values. No prerequisite
   work; Component 4 is unblocked. (Reminder: avoid the deprecated `chi2cdf`.)
2. **Async backtest in v1 or follow-up?** Folds are embarrassingly parallel. Proposal
   ships synchronous first (simpler to verify, deterministic); an `async` bounded-
   TaskGroup variant mirroring `AsyncDEASolver` is a natural follow-up. Ship sync now?
3. **Should `projectWithConfidence` be deprecated or kept?** Recommendation: **keep**
   but amend its DocC to state the bands are in-sample and point to `empiricalIntervals`
   for out-of-sample honesty. Avoids a breaking change.
4. ~~**MASE seasonality default**~~ — **RESOLVED by R4.** Ships an auto-detect helper
   (`dominantSeasonLength`) that *suggests* the period; MASE/seasonal-naive still accept
   an explicit `seasonLength` (default 1) so nothing is silently overridden. Best of
   both: no hidden magic, no mandatory manual config.
5. **MCP surface scope** — expose all entry points as MCP tools, or start with the
   highest-value (`backtest_forecast`, `assess_forecastability`, plus new
   `test_stationarity`) and add the rest after the Swift API stabilizes? Proposal leans
   to the latter.
6. **R2 default threshold** — what spectral-entropy cutoff maps to the `.noise` verdict
   and the default `strict` threshold? Literature clusters near 0.9–0.95 (normalized).
   Proposal: default `strict` to 0.9, calibrate the verdict buckets against the
   benchmark datasets (m4_hourly = forecastable, exchange/bitcoin = noise) during Green.
7. **R1 scope** — ship ADF + KPSS only, or also add an automatic
   "difference-until-stationary" convenience (`ndiffs`)? Proposal: tests-only in this
   tier; leave the auto-differencing transform to the modeling layer.

---

## 11. Documentation Strategy

```
Documentation Type: Narrative Article Required

Complexity Threshold Check:
- Combines 3+ APIs? Yes (backtest + baselines + intervals + diagnostics compose)
- Explanation needs 50+ lines? Yes
- Needs theory/background? Yes (extrapolation vs interpolation, MASE interpretation,
  reading an ACF plot, what spectral entropy means)

Article Name: ForecastEvaluationGuide.md
  (does NOT collide with any Swift symbol — no `ForecastEvaluationGuide` type)

Article outline:
  1. Why point forecasts lie (the article's thesis, our overconfident-interval bug)
  2. "Should I even model this?" — reading a forecastability report
  3. Backtesting: rolling origin, expanding vs sliding
  4. Beating the naive baseline — interpreting MASE
  5. Did the model extract the signal? — ACF/PACF & Ljung-Box
  6. Honest uncertainty — empirical vs parametric intervals
  7. Worked example: a drifting revenue series end-to-end
```

---

## 12. MCP Schema (user-facing entry points)

### 12.1 `backtest_forecast`

**Tool Description:** Walk-forward (rolling-origin) out-of-sample evaluation of a
forecasting model, returning honest error metrics including MASE vs a naive baseline.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "series": {"periods": ["2024-01", "2024-02"], "values": [100.0, 105.0]},
  "model": "holtWinters",
  "initialTrainSize": 24,
  "horizon": 3,
  "step": 1,
  "window": "expanding",
  "seasonLength": 12
}
```
- `series` (object): periods (ISO-8601 strings) + values (numbers).
- `model` (string enum): `"naive" | "seasonalNaive" | "drift" | "linearTrend" | "exponentialTrend" | "logisticTrend" | "holtWinters" | "movingAverage"`.
- `initialTrainSize` (integer > 0), `horizon` (integer ≥ 1), `step` (integer ≥ 1, default 1).
- `window` (string enum): `"expanding" | "sliding"`; if `"sliding"`, add `slidingLength` (integer > 0).
- `seasonLength` (integer, optional): season period for MASE/seasonal-naive. Omit ⇒ auto-detect via ACF (R4), falling back to 1.
- `strict` (boolean, default false) + `maxSpectralEntropy` (number 0–1, default 0.9): R2 refusal — if true and the series' spectral entropy exceeds the threshold, the tool returns an `unforecastableSeries` error instead of metrics.

### 12.2 `assess_forecastability`

**Tool Description:** Measure how much exploitable structure a series contains
(spectral entropy 0–1, skill-vs-naive), returning a verdict of noise/weak/moderate/strong.

```json
{ "series": {"periods": ["..."], "values": [1.0]}, "seasonLength": 12 }
```

### 12.3 `residual_diagnostics`

**Tool Description:** ACF, PACF, and Ljung-Box whiteness test on a series or model
residuals — checks whether autocorrelation structure remains unexploited.

```json
{ "series": {"periods": ["..."], "values": [1.0]}, "maxLag": 20, "fittedParameters": 0 }
```

### 12.3b `test_stationarity` (R1)

**Tool Description:** Run ADF and KPSS unit-root tests and report whether the series is
stationary or needs differencing before fitting a trend model.

```json
{ "series": {"periods": ["..."], "values": [1.0]}, "kpssRegression": "level", "lag": null }
```
- `kpssRegression` (string enum): `"level" | "trend"`.
- `lag` (integer or null): override the automatic Schwert lag selection.

### 12.4 `empirical_forecast_interval`

**Tool Description:** Prediction intervals derived from out-of-sample backtest residual
quantiles, honest about horizon-growing uncertainty.

```json
{
  "series": {"periods": ["..."], "values": [1.0]},
  "model": "holtWinters",
  "initialTrainSize": 24,
  "horizon": 6,
  "confidenceLevel": 0.95,
  "seasonLength": 12
}
```

---

## 13. Implementation Sequencing (for the checklist phase)

Because Components 2–5 consume Component 1's output, build in dependency order:

1. **`Forecaster` protocol (exogenous-ready, R3) + `AnyForecaster` + retroactive
   conformances** (unblocks all). The optional `ForecastRegressors` lands here so the
   protocol is never revised later.
2. **Baselines** (`Naive`, `SeasonalNaive`, `Drift`) — trivial forecasters, needed as
   both benchmarks and the MASE denominator; good first Red/Green cycle.
3. **Diagnostics I — ACF/PACF + `dominantSeasonLength` (R4)** — ships early because
   auto season detection feeds MASE/seasonal-naive and forecastability downstream.
4. **Rolling-origin backtest + `BacktestReport`** — the harness; MASE lands here
   (using #3's suggested season length).
5. **Forecastability + refusal (R2)** (spectral entropy via existing FFTBackend +
   `requireForecastable`; wire `RefusalPolicy.strict` into the backtest from #4).
6. **Diagnostics II — Ljung-Box + stationarity ADF/KPSS (R1)** (after confirming the
   χ² CDF dependency; independent of the forecasting path so can parallelize with #4–5).
7. **Empirical intervals** (quantiles of `residualsByHorizon` from #4).
8. **DocC article + MCP tools** last, once the Swift API has stabilized.

Each numbered item is an independent Red→Green→Refactor→Document→Verify cycle with its
own commit at green, per the TDD contract.

---

## Proposal Review Checklist

### Architecture
- [x] Module placement follows existing structure (`Forecasting/`, `Time Series/`)
- [x] API naming follows conventions (verb-first funcs, `Report`/`Result` suffixes)
- [x] Concurrency Swift-6 compliant (immutable Sendable value types)
- [x] Generic constraints appropriate (`BinaryFloatingPoint` to match existing metrics)
- [x] No forbidden patterns (no `!`, `try!`, `as!`; guarded division)
- [ ] Usage examples reviewed against `usage_examples.md` — **TODO before Green**

### MCP Readiness
- [x] JSON schemas with REQUIRED STRUCTURE for all five entry points (added `test_stationarity`, R1)
- [x] Parameter types mapped to JSON Schema types
- [x] Enum values listed exhaustively (`model`, `window`, `verdict`, `kpssRegression`)
- [x] Refusal params documented (`strict`, `maxSpectralEntropy`, R2)
- [x] Date formats specified as ISO-8601
- [n/a] Stochastic seed — none (fully deterministic)

### Testing & Dependencies
- [x] Test strategy covers golden/edge/invalid/determinism + leakage fault-injection
- [x] Reference truth identified (FPP3, Hyndman & Koehler 2006, statsmodels, R forecast; +Dickey-Fuller 1979, Kwiatkowski 1992 for R1)
- [x] Dependencies acceptable (swift-numerics only; χ² CDF confirmed present)
- [ ] Open questions resolved — **χ² CDF (#1) and MASE season default (#4) RESOLVED;
      remaining #2 async, #3 projectWithConfidence, #5 MCP scope, #6 entropy threshold,
      #7 R1 scope need a quick user call before Green**

### Review-feedback traceability (v2)
- [x] R1 stationarity (ADF/KPSS) → §3.5, §4, §8, MCP 12.3b
- [x] R2 refusal / `.unforecastableSeries` → §3.2 (RefusalPolicy), §3.4 (requireForecastable), §4, MCP 12.1
- [x] R3 exogenous-ready `Forecaster` → §3.1 (ForecastRegressors), ADR 2/2, §13 step 1
- [x] R4 auto seasonality (`dominantSeasonLength`) → §3.5, §3.3 (MASE), resolves Open Q #4
