# Handoff — 2026-09-28 (contaminated-input sweep: 22 commits, Phase 1 half done)

**Head is `b4a3a4a7`, pushed and CI-green. 8,350 tests / 779 suites, gate 45/45 at 0 warnings.**

A long defect-hunting campaign against one class: **a guard that is correct while the value it
returns is wrong**. ~48 defects and 4 hard crashes fixed. This handoff exists because the work
is mid-phase and the remaining items are precise enough to lose.

## Read first

| document | what it is |
|---|---|
| `project/plans/CONTAMINATED_INPUT_CONTRACT.md` | the behavioural spec — **freeze before any fan-out** |
| `project/plans/CONTAMINATED_INPUT_SWEEP_PLAN.md` | the five phases, with measured yield rates |
| `quality-gate-swift-project/plans/proposals/AFallbackIsAnAnswer.md` | the checker that would end this class (pushed, `85844a9`) |

The single fact underneath everything: **every comparison against `nan` is false, including
`nan == nan`.** It never raises. It answers *no*, and "no" is valid everywhere in Swift.

## What is DONE

Twenty-two commits, `3898aafb` … `b4a3a4a7`. Four hard crashes fixed (`spearmansRho`,
`DiscountCurve.bootstrap`, `CapitalAllocationOptimizer.optimizeIntegerProjects`, and 18
trapping config parameters across the heuristics). Shapes B and D (two-arm sign classification,
NaN-absorbing clamp) are **finished repository-wide**. Shape A is finished for eleven areas.

## What is OPEN, in priority order

### 1. Phase 1 traps — 21 remaining, all verified by a read-only agent, none fixed

`Int(x)` traps for non-finite **and** for out-of-range. Fix by screening at the **entry point**,
never at the conversion: all four already-fixed traps needed the screen earlier, and one needed
it earlier than a *count* was taken or the fix turned a crash into `Index out of range`.

**Statistics (3)**
- `Statistics/Experiment/PowerAnalysis.swift:112` — `Int(rounded)`. `meanSampleSize`/
  `proportionSampleSize` deliberately `return T.infinity` as a sentinel (`:132`, `:145`). Also
  reachable with no infinity at all: `minimumDetectableEffect: 1e-10` gives `exact ≈ 1.6e21`.
  The DocC already promises `- Throws: ExperimentError when the design has no finite answer` —
  documented, never implemented. Screen before `:111`.
- `Statistics/Classification/ClassifierEvaluation.swift:185` — `Int(scaled)`. The clamp on the
  next line is **one line too late**: it clamps the `Int` after the conversion traps. Move the
  clamp into `T` before converting. Init screens `isFinite` but not magnitude; scores are
  legitimately unbounded (only ordered by `roc`/`auc`).
- `Statistics/.../DistributionPoisson.swift:85` — `Int(lambda + spread)`, `lambda: 1e19` traps.
  Screen in `init?(lambda:)` at `:53`.

**Simulation / Streaming / Operations (10)**
- `Simulation/MonteCarlo/SimulationResults.swift:506` — `Int(max(log10(p5), log10(p99))…)`.
  Reachable with **entirely legitimate finite data**: all-zero values → `log10(0) = -inf`;
  any loss distribution (negative percentiles) → `nan`. Also via `.undefined(values:)`.
- `Simulation/MonteCarlo/SimulationResults.swift:454` — `Int(ceil(range / binWidth))`,
  out-of-range for a heavy tail over a tight interquartile core.
- `Streaming/StreamingFrequencyDomain.swift:84` and `:85` — `spectrum.power(in: 0.15 ..< .infinity)`
  is the natural spelling of "all power above 0.15 Hz" and crashes. Clamp in `Double` first.
- `Operations/InventorySimulator.swift:167` and `:170` — `meanLeadTime`/`leadTimeStdDev` never
  screened. NB the same value is the trip count of `for _ in 0..<days`, so a finiteness-only
  patch converts the crash into an unbounded loop.
- `Simulation/distributionCumulativeDiscrete.swift:82` — the guard above is `allSatisfy(isFinite)`,
  which passes `1e300`. Widen it; it must stay before the `map`.
- `Simulation/distributionDiscreteCounts.swift:112` — `Int(mean + 20 * deviation)`, `p = 1e-300`.
- `Simulation/distributionGeometric.swift:161` — only `q = -.infinity` reaches it; weakest.
- `Simulation/distributionTriangular.swift:51` — `Int(uSeed * 1_000_000)`; five guards precede it
  and none touches `uSeed`, the public fourth parameter.

**Valuation and elsewhere (8)**
- `Valuation/CreditDerivatives/CreditTermStructure.swift:114` — `Int(maturity) * 4`. In-repo path:
  `bootstrapCreditCurve` → `bootstrapHazardRate` → `cdsSpread`. **Also** `for i in 1...numPeriods`
  traps for `maturity < 0.25`, so a finiteness-only fix swaps one crash for another.
- `Scenario Analysis/FinancialSimulation.swift:316` — `conditionalValueAtRisk(.nan)`, one hop.
- `Valuation/Debt/NelsonSiegel.swift:236` — `bond.maturity`; crashes a whole calibration, not one
  price. Screen in `BondMarketData.init`.
- `Operational Drivers/DriverProjection.swift:415` — `"P\(Int(p * 100))"`, a **label string** takes
  the process down. `BusinessMathDSL/ScenarioAnalysis.swift:383-393` already fixed this exact
  shape and documents it — the correctly-behaving sibling.
- `Portfolio/PortfolioUtilities.swift:295` — `sparsity: .nan`; `max(5, …)` runs after the trap.
- `Valuation/Curves/DiscountCurve.swift:377` — the **other** `Int(` in that file; the existing
  `placeable` filter screens finiteness but not magnitude. Widen that predicate, do not add a
  second guard.
- `Fluent API/Templates/StandardTemplates.swift:1186` — `loanTermYears`; `nan` already screened
  by `> 0`, `+inf` is not. Extend the guard at `:1102`.
- `Stochastic/JumpDiffusion.swift:209` — `jumpIntensity: .infinity` passes `> 0`. Weakest.

### 2. `altmanZScore` on a period the statements do not cover — VERIFIED, unfixed

Measured this session:

    period covered   -> Z = 5.92  (safe)
    period NOT covered -> Z = 0.00 (DISTRESS), totalAssets[period] == nil

A solvent company scores "high bankruptcy risk within 2 years" because the caller asked about a
quarter outside its books. This is the **third** path into the guard at
`Financial Statements/CreditMetrics.swift:244`, which already carries a nine-line comment
justifying zero for *a firm with no assets* — the comment never mentions an uncovered period.
`piotroskiScore` is worse: it takes `period` *and* `priorPeriod` and thresholds on both, so an
uncovered prior period silently awards the "increasing ROA" point.

### 3. Phase 2 — the plan's scoping was WRONG; corrected findings

`CONTAMINATED_INPUT_SWEEP_PLAN.md` §2.1 says the `?? 0` class lives in Time Series. **It does
not.** Time Series' 78 hits are `DateComponents.year/month/day ?? 0` — Foundation calendar
unwraps, a different shape entirely (a missing component silently becomes year 0). Network's 20
are `[Node: Double]` accumulators, correct by construction.

The real class is **75 sites in Financial Statements (63), Model Definition, Diagnostics and
Industry Models**, top files `CreditMetrics.swift` (25) and `FinancialPeriodSummary.swift` (20).

A design note was produced and its §3.7 clause is ready to paste into the contract. Its findings:
- `TimeSeries` **cannot** distinguish "before the series starts" from "a hole in the middle" —
  `periods` is derived from the value keys (`self.periods = valueDict.keys.sorted()`), and
  `Period: Comparable` sorts **type-first**, so `periods.first`/`.last` do not bound a span.
- Therefore the rule must be **"narrow the domain, don't fabricate the observation"**, which
  `TimeSeries.zip(with:)` already does and which needs **no API change**.
- `FinancialPeriodSummary.init` is declared `throws` and contains **zero `throw` statements**;
  it fills 20 fields with fabricated zeros for any period. Highest-value fix, and the one most
  likely to turn fixtures red — budget for fixture repair, not for the guard.
- Recommendation: land §3.7, fix `workingCapitalTurnover` and `altmanZScore` now, defer
  `FinancialPeriodSummary` and `piotroskiScore` to a deliberate pass.

### 4. Phase 3 — two probe harnesses were authored and LOST with the agent context

Re-author them; it is one agent each, ~5 minutes. Targets and the questions that matter:

**Streaming** — the point is that it is **stateful**, so the probe must test RECOVERY: feed N
clean values, then one `.nan`, then N more clean, and print every emitted element. Cover
`rollingMean` vs `rollingStatistics` (incremental `runningSum -= evicted` cannot subtract a NaN
back out; the recomputing sibling is the control), `rollingVariance` (reverse-Welford, same),
`cusum` (does `Swift.max(0, nan)` erase accumulated evidence of a real shift?), `ewma`
(`outOfControl` false forever after contamination), `detectSeasonalAnomalies` (per-season
poisoning — put a real 999 spike in the same season position later in the stream),
`compositeAnomalyScore`, `detectBreakpoints` and `detectChangePoints` (does one NaN suppress an
unmistakable 10→50 level shift?), `forecastErrors`. Exclude `detectOutliers`/`detectTrend`, fixed.

**Time Series** — two questions. (a) contamination at first/middle/last (position-dependence is
itself the finding); (b) **a genuine gap with no NaN at all** — months 1,2,4,5 with no month 3 —
against a dense control and a zero-filled control. Watch `aggregate(to:.quarterly,.average)`:
Q1 divided by "months we happen to have" rather than months in the quarter. Also `cagr`
(`startValue > T.zero` is false for NaN → returns 0, "no growth"), `forecastError` (`mape` has an
explicit `isNaN ? T.zero` → a **perfect** forecast score for unscoreable data),
`decomposeTimeSeries` (residual `T(1)` = "trend × seasonal explains this perfectly"), and
`ExponentialTrend.fit` (throws "requires all positive values" for a NaN — wrong diagnosis).

## Method — these each cost something to learn

- **Probe before theorising.** Several agent predictions were too strong and dissolved on
  measurement; two of my own hypotheses were wrong.
- **Write the test red first; keep controls that pass on both sides.** Fixing 3 of 5 clamp sites
  left two tests red, which found the remaining pair plus two inline copies grep had missed.
- **The fix is where the new bugs come from.** The knapsack fix took three attempts, each caught
  by a *different* trap.
- **Measure control values, never recall them.** Fabricated expected values were caught twice.
- **Agent findings are claims until measured.** 295 triaged sites, 82% legitimate.
- **Do not fan out before the contract is frozen** — the defect class *is* inconsistency.
- **A gate run from `.claude/worktrees/` examines 0 files and prints PASSED.** Agents must not
  self-certify; they author probes, one process executes them.
- **Do not run parallel `swift build`s** — this machine killed runs twice for memory pressure.
- `swift test --filter` matches **type** names, not `@Suite` display names.
- Never put a bare `cat > file` before a heredoc; it eats the heredoc and leaves a 0-byte file.

## Known non-defects — do not re-report

`LMEDiagnostics` ×3 (throws before the guards are reachable; variance floored at `ulpOfOne`),
`postHocTests:233` (`normalRangeCDF` unreachable — `:304` fires first), `SimplexSolver:606`
(`1.0` is a genuine no-op scale), `ManufacturingModel` zero-production unit cost (**0 is correct**
— at zero output there are no units to carry a cost; an unconstrained cost-minimisation is the
badly-posed part, and two existing tests pin it), the `RetailModel` `!=` NaN path (already
correct), the weighted CCC overload (does not exist).

## CI

`Release Tests` → **Thread Sanitizer (macOS)** has failed twice, both cleared by a re-run on
identical code. Only that job; Release Tests pass on ubuntu-24.04 and macos-26 and plain CI is
green. The log stops **mid-build** with no error text and the workflow timeout (120 min) is never
approached. Hypothesis is runner memory pressure — **unproven**; the honest next step is a
diagnostic on that job, not a guess. Do not treat a TSan-only failure as a code regression
without checking the other two jobs first.
