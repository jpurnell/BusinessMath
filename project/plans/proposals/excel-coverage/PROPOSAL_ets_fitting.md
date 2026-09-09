# Design Proposal — fitting the ETS parameters, and reporting the fit

**Status:** proposal, 2026-09-09. Phase 0 (Design).
**Scope:** a Holt-Winters parameter fitter and one missing error metric, for BusinessMath.
**Motivated by:** Excel's `FORECAST.ETS.STAT` and `FORECAST.ETS.SEASONALITY` — but, as §2.2
records, most of what those need is already here and I twice said otherwise.

---

## 1. Objective

**Let a Holt-Winters model choose its own smoothing parameters, and say how well it did.**

```swift
let fit = try series.fitETS(seasonality: .detect)
fit.alpha                      // searched for, not supplied
fit.errors.smape               // how well the fitted model tracks the history
try series.backtest(fit.model, config: .default)   // it is already a Forecaster
```

The first two lines have no equivalent today. The third works the moment the first does.

---

## 2. Motivation

### 2.1 What Excel asks for

Two functions in the coverage matrix are unanswerable, and one is not what it looks like.

```
FORECAST.ETS.SEASONALITY(values, timeline, [data_completion], [aggregation])
FORECAST.ETS.STAT(values, timeline, statistic_type, [seasonality], [data_completion], [aggregation])
```

`SEASONALITY` returns "the length of the repetitive pattern Excel detects for the specified
time series." `STAT` dispatches on `statistic_type`, and the published table is the
requirements list:

| Type | Returns | Present here? |
|---|---|---|
| 1 | Alpha parameter of the ETS algorithm | **no — the fitter** |
| 2 | Beta parameter | **no — the fitter** |
| 3 | Gamma parameter | **no — the fitter** |
| 4 | MASE | yes — `TimeSeries.mase(against:training:seasonLength:)` |
| 5 | SMAPE | **no — one function** |
| 6 | MAE | yes — `ForecastErrorMetrics.mae` |
| 7 | RMSE | yes — `ForecastErrorMetrics.rmse` |
| 8 | Step size detected in the timeline | not ours — see §3.5 |

Five of eight are answered by code that already exists. The gap is a fitter and a metric.

**Excel genuinely fits the parameters, and this had not been checked.** The premise under
types 1–3 is that `STAT` reports a *searched* value rather than a constant, and it was taken
from the documentation rather than observed. The §8.1 run settles it as a byproduct: alpha
came back `0.126`, which is neither this library's `0.2` default nor a boundary value. Small
enough to be worth writing down, because a whole third of the `STAT` table rests on it.

### 2.2 What is already here, including two things I said were not

Verified against the 2.15.0 tree (`be704795`), by opening the files rather than by keyword
probe — which is what went wrong the first two times:

- **`HoltWintersModel<T>`** — `train(on:)`, `predictValues(periods:)`, `predict(periods:)`,
  `predictWithConfidence(periods:confidenceLevel:)`, and a `Forecaster` conformance. Its
  `alpha`, `beta` and `gamma` are `public let`, set by `init(alpha:beta:gamma:seasonalPeriods:)`
  and defaulted to `0.2 / 0.1 / 0.1` by the `where T == Double` convenience.
- **Seasonality detection already exists and is public.** `TimeSeries.dominantSeasonLength(maxLag:)`
  in `Time Series/Diagnostics/Autocorrelation.swift` returns the lag `h ≥ 2` whose
  autocorrelation is strongest *and* exceeds the white-noise band `1.96/√n`, and `nil` when
  none clears it. **That is `FORECAST.ETS.SEASONALITY`**, in the same shape Excel describes,
  including the "no detectable pattern" answer. I previously recorded that nothing upstream
  detected seasonality. That was wrong.
- **MASE already exists.** `TimeSeries.mase(against:training:seasonLength:)`, over
  `naiveScale(_:seasonLength:)`, Hyndman & Koehler's definition, `nil` on a degenerate scale.
  `BacktestReport` carries it pooled out-of-sample alongside `rmse`, `mae` and `mape`. I
  previously recorded MASE as absent. Also wrong.
- **`NelderMead<V: VectorSpace>`** — `minimize(_:from:constraints:)` returning
  `MultivariateOptimizationResult<V>`, with `VectorN<T>` as the n-dimensional vector.
- **`RollingOriginBacktest`** — `TimeSeries.backtest(_:config:)` over any `Forecaster`.

Genuinely absent: **a search for α, β and γ**, and **SMAPE**. Nothing else.

That is a much smaller proposal than the one I said would be needed, and the correction is
recorded here rather than quietly dropped because the same mistake produced the same
overestimate twice.

### 2.3 Why the fitter belongs here rather than in the Excel layer

A parameter search over a smoothing model is mathematics with no spreadsheet content in it.
It needs an optimizer, an objective and a model — all three already in this package — and
none of Excel's vocabulary. Put it in the binding layer and it is unavailable to every other
consumer of `HoltWintersModel`, which is most of the reason it is worth writing: today a
caller must *supply* `alpha: 0.2` and has no way to know whether 0.2 is any good for their
series.

**And Excel's `FORECAST.ETS` is not the only caller, nor even the only Excel-side one.**
`psi_functions.tsv` carries **eight** `PsiForecast*` entries — `PsiForecast`,
`PsiForecastARIMA`, `PsiForecastDoubleExp`, `PsiForecastETS`, `PsiForecastExp`,
**`PsiForecastHoltWinters`**, `PsiForecastLinear` and `PsiForecastMovingAvg` — of which
`PsiForecastETS(target_date, values, timeline, seasonality, data_completion, aggregation,
simulate)` is Excel's six arguments plus a simulation flag. `PsiForecastHoltWinters` names the
model being fitted here outright. So the fitter already has callers in two function families
on the binding side, which is the argument for it living in neither.

The division is settled and is stated in §3.5: mathematics here, spreadsheet argument
semantics in SwiftExcelFunctions.

---

## 3. Proposed Architecture

### 3.1 The seasonality choice, named

Excel encodes three cases in one optional numeric argument — `0` non-seasonal, `1` (default)
auto-detect, any positive integer an explicit cycle length. That is a sum type wearing a
number, and it should arrive here as a sum type:

```swift
/// How a fit decides its seasonal cycle length.
public enum ETSSeasonality: Sendable, Equatable {
    /// Non-seasonal: level and trend only, gamma unused.
    case none
    /// Suggest a cycle from the autocorrelation, falling back to ``none`` when none clears
    /// the white-noise band.
    case detect
    /// An explicit cycle length, in periods.
    case periods(Int)
}
```

`detect` delegates to `dominantSeasonLength(maxLag:)`. It does not reimplement it.

### 3.2 The fit and what it reports

```swift
/// A Holt-Winters model whose smoothing parameters were searched for, with the accuracy
/// of that fit measured on the data it was fitted to.
public struct ETSFit<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {
    /// The fitted model, trained and ready to forecast. Already a ``Forecaster``.
    public let model: HoltWintersModel<T>
    /// Level smoothing, in `[0, 1]`.
    public let alpha: T
    /// Trend smoothing, in `[0, 1]`.
    public let beta: T
    /// Seasonal smoothing, in `[0, 1]`. Unused, and reported as zero, when non-seasonal.
    public let gamma: T
    /// The cycle length used: `1` when non-seasonal.
    public let seasonLength: Int
    /// Whether ``seasonLength`` came from detection rather than from the caller.
    public let seasonalityWasDetected: Bool
    /// In-sample accuracy of the fitted model.
    public let errors: ETSFitErrors<T>
    /// Whether the parameter search converged, and in how many objective evaluations.
    public let convergence: ETSConvergence
}

/// What the parameter search did before it stopped.
///
/// Declared here because §3.2 referenced it without defining it. `converged == false` is not
/// a failure — a run that hit its evaluation budget still returns the best feasible point it
/// found — but it is a fact the caller should be able to see rather than infer.
public struct ETSConvergence: Sendable, Equatable {
    /// Whether the simplex met its tolerance before the evaluation budget ran out.
    public let converged: Bool
    /// How many times the objective was evaluated.
    public let evaluations: Int
    /// The final objective value: the in-sample sum of squared one-step residuals.
    public let objective: Double
}

/// In-sample accuracy of a fitted model.
public struct ETSFitErrors<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable, Codable {
    public let mae: T
    public let rmse: T
    public let mape: T
    public let smape: T
    /// `nil` when the naive scale is degenerate — a constant series has no MASE.
    public let mase: T?
}
```

The entry point sits where the other series diagnostics sit:

```swift
public extension TimeSeries where T: BinaryFloatingPoint & Codable {
    /// Searches for the smoothing parameters that best fit this series.
    ///
    /// - Throws: ``ForecastError/insufficientData(required:got:)`` when the series is
    ///   shorter than two seasonal cycles, which is what training requires.
    /// - Throws: ``ForecastError/invalidParameter(_:)`` for a non-positive
    ///   ``ETSSeasonality/periods(_:)``. That case already exists and is the right one; the
    ///   enum can express a cycle length of zero and the fit cannot.
    func fitETS(
        seasonality: ETSSeasonality = .detect,
        config: ETSFitConfig = .default
    ) throws -> ETSFit<T>
}
```

### 3.3 How the search is done, and the one decision in it

**Nelder-Mead over an unbounded reparameterisation.** The parameters are boxed in `[0, 1]³`,
and there are two ways to hold a simplex method to a box: penalise infeasible points, or
remove the infeasibility. `minimize(_:from:constraints:)` supports the first via
`MultivariateConstraint`. This proposes the second — optimise over `ℝ³` and map each
coordinate through the logistic `1/(1 + e^{-x})`.

The reason is not elegance, and it is stronger than "the weight has to be tuned". **The weight
cannot be tuned: it is hardcoded.** `NelderMead.minimizeWithPenalty` sets
`let penaltyWeight: V.Scalar = 100` (`Optimization/Heuristic/NelderMead.swift:507`) and
exposes no way to change it. **The same literal is hardcoded in all five constrained
heuristics** — NelderMead 507, DifferentialEvolution 739, IslandModel 315, SimulatedAnnealing
415, ParticleSwarmOptimization 768 — so this is not a NelderMead quirk to route around but an
unparameterised package-wide convention. That belongs to the optimizer tier rather than to
this proposal, and is recorded as §10.5 of `proposals/PROPOSAL_advanced_optimization_gap.md`. So the penalty route does not offer a weight to choose badly —
it offers a constant chosen for other problems, and `alpha = 1.4` is admitted or the boundary
distorted according to how 100 happens to compare with this objective's curvature. Under the
transform an infeasible point cannot be *proposed*, so there is no weight and no tuning, and
the boundary behaviour is a property of the parameterisation rather than of a constant
someone chose. The cost is that the optimum can only be approached asymptotically as
`x → ±∞`; §8.2 records that, and it is why `config` carries bounds of `[0.0001, 0.9999]`
rather than `[0, 1]`.

**The objective is the sum of squared one-step-ahead in-sample residuals.** Excel does not
publish its objective, so this is chosen on the standard for ETS (Hyndman) rather than to
match. §5 is built entirely on that fact: nothing here asserts a number Excel would produce.

**Non-seasonal fits search two parameters, not three.** With `seasonality: .none`, gamma has
nothing to smooth; searching it would wander over a flat dimension and report a meaningless
value. The search is over `(α, β)` and gamma is reported as zero.

### 3.4 SMAPE

```swift
/// Symmetric Mean Absolute Percentage Error — forecast error against the average magnitude
/// of the actual and the forecast, rather than against the actual alone.
///
/// `mean(|actual − forecast| / ((|actual| + |forecast|) / 2))`. Unlike ``mape(_:_:)`` it is
/// finite when an actual is zero, and it is symmetric in its arguments — swapping them
/// leaves the result unchanged, which is the property that names it.
public func smape<T: Real>(_ actual: [T], _ forecast: [T]) -> T
```

Placed in `Statistics/Descriptors/Error Metrics/` beside `mae.swift`, `mape.swift` and
`rmse.swift`, and matching their shape: a free function, a ratio rather than a percentage,
`T.nan` for empty or mismatched input.

Two details that are decisions rather than transcription:

- **When both `actual[i]` and `forecast[i]` are zero**, the term is `0/0`. It contributes
  **zero**, not `NaN`: a forecast that predicted zero and got zero was not wrong. The divisor
  is bound and guarded rather than tested through its operands — `guard denominator > 0`, not
  `guard actual[i] != 0` — because the fp-safety checker tracks the divisor symbol.
- **The denominator is halved**, giving a `[0, 2]` range (Makridakis). The unhalved form gives
  `[0, 1]` and is equally common. §8.1 records why this cannot be settled from the
  specification, and it is the one place this proposal may not match Excel's number.

### 3.5 What stays in SwiftExcelFunctions

The lane, stated so the binding is not written twice:

| Concern | Where | Why |
|---|---|---|
| Parameter search, SMAPE, seasonality detection | BusinessMath | mathematics, no spreadsheet content |
| `data_completion` — zeros vs. interpolated neighbours | SwiftExcelFunctions | an argument convention |
| `aggregation` — AVERAGE/SUM/COUNT/… over duplicate timestamps | SwiftExcelFunctions | an argument convention |
| Timeline step detection, and `statistic_type` 8 | SwiftExcelFunctions | reads the timeline, never reaches a model |
| `statistic_type` dispatch, 1–7 | SwiftExcelFunctions | selects a field of ``ETSFit`` |
| `#NUM!` / `#VALUE!` / `#N/A` mapping | SwiftExcelFunctions | Excel's error vocabulary |

Excel's error conditions are all timeline conditions — non-constant step is `#NUM!`,
duplicate timestamps `#VALUE!`, mismatched lengths `#N/A` — and every one of them is detected
before a `TimeSeries` can be built. None of them needs an error case here.

---

## 4. Constraints & Compliance

- No force unwraps, no `try!`. `fitETS` throws `ForecastError`; `smape` returns `T.nan`;
  `mase` stays optional.
- No new dependency. `NelderMead`, `HoltWintersModel`, `dominantSeasonLength` and the three
  error metrics are all in this package already.
- Every divisor is bound to a named value and guarded on that binding — SMAPE's denominator,
  and the mean in the objective.
- `Sendable` throughout; `ETSFit` and `ETSFitErrors` are value types over `Sendable` scalars.
- The search is deterministic: same series, same config, same parameters. Nelder-Mead from a
  fixed initial simplex has no randomness in it, and the fit is reproducible by construction
  rather than by seeding.

---

## 5. Test Strategy

**Nothing here asserts a number Excel would produce, and nothing asserts a remembered
constant.** Excel's ETS uses its own initialisation and its own optimizer; matching its
digits is not achievable and pretending otherwise would produce tests that fail correct code.
Every assertion below is a property or a relationship.

**The fitter is tested against a coarse grid, not against the defaults.** An earlier draft
asserted that the fitted in-sample SSE must be **no worse than** the library defaults
`0.2 / 0.1 / 0.1`, and called that the one assertion no stub could satisfy. It is not. `≤` is
satisfied by equality, so a fitter that starts at the defaults and returns them unchanged
passes it — and the initial guess was never specified, so that no-op is a plausible
implementation rather than a contrived one. A fitter returning any hardcoded triple that
happens to beat `0.2 / 0.1 / 0.1` on most series passes it too, and that is a lookup table
rather than a search.

The assertion that survives: **the fitted SSE must be no worse than the best point of a
0.1-resolution grid over the feasible box.** Eleven values per parameter is 1,331 trainings
for a seasonal fit and 121 for a non-seasonal one — affordable once, in a test, on a short
series. No fixed-point stub passes it, because the grid contains the stub's answer by
construction and will beat it on some series. It also states the property that actually
matters: the search is at least as good as brute force at the resolution brute force could
afford.

Keep the defaults comparison as well, as a **strict** inequality on a series built so the
defaults are known to be poor. It is cheap and it fails loudly.

**Recovery on synthetic data.** Generate a seasonal series from a known cycle length `m` with
additive noise; assert `dominantSeasonLength` recovers `m`, that `fitETS(seasonality: .detect)`
reports `seasonLength == m` and `seasonalityWasDetected == true`, and that the fitted model
beats seasonal-naive out of sample — `backtest(fit.model, config:).mase < 1`. That last one
ties the fitter to the evaluation tier that already exists.

**SMAPE is tested by its defining property.** `smape(a, f) == smape(f, a)`, exactly, for a
spread of inputs including zeros on each side and on both. Symmetry is what distinguishes it
from MAPE and is the assertion a wrong implementation cannot pass. Plus the bounds
`0 ≤ smape ≤ 2`, the both-zero case contributing zero, and `T.nan` for empty and mismatched.

**Parameter feasibility.** Every fitted `alpha`, `beta`, `gamma` lies within the configured
bounds, on every series in the test corpus — including short ones, constant ones, and a pure
white-noise series where there is nothing to fit and the optimizer must still return
something feasible.

**Refusals get named tests.** A series shorter than `2 × seasonLength` throws
`insufficientData`; a constant series reports `mase == nil` rather than dividing by a zero
scale; `seasonality: .periods(0)` and negative lengths throw
``ForecastError/invalidParameter(_:)``, which already exists rather than needing a new case.

---

## 6. Alternatives Considered

**Grid search over `[0,1]³`.** No optimizer, trivially correct, and honest about what it
found. Rejected on cost: a 0.01-resolution grid is 10⁶ full trainings per fit, and the
resolution is exactly what determines whether the answer is any good. Nelder-Mead reaches a
better answer in hundreds of evaluations and is already in the package.

**Penalty-constrained Nelder-Mead**, via the `constraints:` parameter `minimize` already
takes. Rejected for §3.3's reason: it introduces a weight nobody can choose on principle. The
transform makes the box structural.

**Fit against a rolling-origin backtest rather than in-sample residuals.** Statistically the
better objective — it optimises what you actually care about — and `backtest(_:config:)` would
supply it directly. Rejected as the *default* on two grounds: it multiplies the cost of every
objective evaluation by the fold count, and Excel's `STAT` 4–7 read as diagnostics of a fit
rather than of a cross-validation. It is a good future `ETSFitConfig` option and §8.3 keeps
it open.

**Return the metrics without the parameters.** Five of the eight `STAT` types are already
answerable, so a smaller change would bind those and leave 1–3 as `#N/A`. Rejected: it ships
a function that silently answers some of its arguments and not others, and the fitter is the
part with value outside Excel entirely.

**Put the fitter in SwiftExcelFunctions.** Rejected per §2.3. It is mathematics, it needs
three things that live here and nothing that lives there, and every non-Excel caller of
`HoltWintersModel` currently has to guess its parameters.

---

## 7. Source & API Compatibility

**Purely additive.** One free function, four new types, one method on a constrained
`TimeSeries` extension. No existing signature changes; `HoltWintersModel`'s initialisers,
`alpha`/`beta`/`gamma` and defaults are untouched, so every current caller supplying its own
parameters keeps working exactly as it does.

`ETSFit.model` is a `HoltWintersModel`, which already conforms to `Forecaster`, so a fitted
model is accepted by `backtest(_:config:)`, `AnyForecaster` and everything else built on that
protocol without a new conformance.

---

## 8. Open Questions

1. ~~**Which SMAPE denominator**~~ — **settled by measurement, 2026-09-09.** Excel for Mac,
   `=FORECAST.ETS.STAT($D$21:$D$32,$C$21:$C$32,$D34,0)` over an alternating `+1, −1` series
   with seasonality forced to `0`:

   | Statistic | Type | Result |
   |---|---|---|
   | SMAPE | 5 | **1.94306435** |
   | MAE | 6 | 1.040036514 |

   **Excel uses the halved denominator**, so §3.4's formula stands as written. The reading is
   decisive rather than suggestive: the unhalved form `|a−f|/(|a|+|f|)` is bounded by **1** by
   the triangle inequality, termwise and therefore in the mean, so no series can drive it to
   1.943 by any route. The halved form is bounded by 2 and 1.943 sits just under it.

   MAE corroborates rather than merely accompanies: actuals of ±1 against an MAE of 1.04 says
   the forecasts sat near zero, which is exactly what puts each SMAPE term at `1/0.5 = 2` and
   the mean just below it. Two numbers, one story.

   The doc comment naming the convention is now *measured* rather than chosen — and it
   remains the only place a caller learns which one they got, because §5's symmetry and
   zero-case tests pass under either denominator. That was worth noting when the choice was
   arbitrary and is worth more now that it is not.

2. ~~**How close to the boundary the search may go**~~ — **settled: snap at saturation.** `[0.0001, 0.9999]`
   is a chosen pair of constants, and a series whose true optimum is `alpha = 1` reports
   `0.9999`. That is not a pathological case kept in for completeness: **`alpha = 1` is the
   optimum for a random walk**, where the best forecast of tomorrow is today's value and no
   smoothing helps. Any series close to a random walk — which is most financial series — lands
   there. So `STAT` 1 will report `0.9999` regularly rather than rarely, and a reader
   comparing it against Excel sees a number that looks like a rounding bug.
   Snapping to the boundary when the transform saturates is therefore the default, agreed by
   both sides on the argument alone.

   **This has NOT been measured, and one attempt to measure it failed twice.** The `STAT` type
   1 readings taken alongside §8.1 do not bear on it: alpha → 1 is optimal for a *random
   walk*, and both series tried were mean-reverting — an alternating `+1, −1` series is
   maximally anti-persistent (returned `0.126`) and a trend with sawtooth noise is also
   mean-reverting (returned `0.002`). Both are correct answers to a question nobody asked.
   **The two questions need opposite data**, and running them on one series cannot answer
   both.

   To measure it properly: a genuinely driftless random walk, `STAT` type 1, seasonality `0`,
   where exactly `1` means Excel snaps and `0.99…` means it does not. Note that twelve points
   may be too few regardless, since the trend component absorbs part of a walk. The default
   here does not wait on it.
3. **Should an out-of-sample objective be offered as config**, per §6? Leaning yes, after the
   in-sample path is proven, so the two can be compared on the same series.
4. **Does `fitETS` belong on `TimeSeries` or on `HoltWintersModel`?** Proposed on `TimeSeries`
   because that is where `backtest`, `forecastability` and `dominantSeasonLength` already sit
   and the series is the subject. The alternative reads as `HoltWintersModel.fitted(to:)`.

---

## 9. Sequencing

Ordered so that each step ships something answerable on its own.

| # | Deliverable | Ends when |
|---|---|---|
| 1 | `smape(_:_:)` with the symmetry property test | Symmetry holds exactly; both-zero contributes zero; bounds hold |
| 2 | `ETSSeasonality`, and a named entry point over `dominantSeasonLength` | `.detect` recovers `m` on a synthetic seasonal series and falls back to `.none` on noise |
| 3 | The parameter search — logistic transform, SSE objective, Nelder-Mead | Fitted SSE ≤ default-parameter SSE on every corpus series; parameters always feasible |
| 4 | `ETSFit` / `ETSFitErrors`, assembling parameters and metrics | A fitted model beats seasonal-naive out of sample (`mase < 1`) on the synthetic series |
| 5 | Changelog and the forecasting guide | Additive entry; `3.2-ForecastingGuide.md` gains the fitting section |

**Step 2 closes `FORECAST.ETS.SEASONALITY` on its own, and it is nearly free** — the
detection exists, is public, and matches Excel's description including the no-pattern answer.
Only `STAT` needs steps 3 and 4.

---

**Next action:** step 1. SMAPE is independent of everything else here, it is the only metric
missing from `STAT`'s table, and its symmetry test is the cheapest way to establish that this
proposal's test discipline holds before any optimizer is involved.
