# Handoff — 2026-09-28 (Phases 1 and 3 CLOSED)

**8,538 tests / 792 suites. Gate 45/45, 0 errors, 0 warnings.**

A long campaign against one defect class: **a guard that is correct while the value it returns
is wrong** — plus its cousin, `Int(x)` trapping the process. 24 commits. Phases 1 and 3 are closed.

## Read first

| document | what it is |
|---|---|
| `project/plans/CONTAMINATED_INPUT_CONTRACT.md` | the behavioural spec. §3.7 covers period-keyed lookups |
| `project/plans/PHASE3_PROBE_FINDINGS.md` | **21 probes, measured 2026-09-28.** The open work |
| `project/plans/CONTAMINATED_INPUT_SWEEP_PLAN.md` | five phases; §2 scoping corrected 2026-09-28 |
| `quality-gate-swift-project/plans/proposals/AFallbackIsAnAnswer.md` | the checker that would end this class (pushed, `85844a9`) |

The fact underneath everything: **every comparison against `nan` is false, including
`nan == nan`.** It never raises. It answers *no*, and "no" is valid everywhere in Swift.

## CLOSED

**Phase 1 — the trap class.** All 39 sites resolved across 23 commits. 4 hard crashes fixed
early (`spearmansRho`, `DiscountCurve.bootstrap`, `optimizeIntegerProjects`, 18 heuristic config
parameters); the final 21 landed in `cb829637`. Shapes B and D (two-arm sign classification,
NaN-absorbing clamp) are finished repository-wide.

Four of that last batch needed **no bad input at all** — worth remembering as the reason a
finiteness grep is not enough:

- `SimulationResults.formattedPercentiles` took the process down *while printing an already
  correct result*: `log10` of a negative number is `nan`, `Swift.max(nan, x)` returns the `nan`,
  and any loss distribution has a negative p5.
- `CreditTermStructure.cdsSpread` computed `Int(maturity) * 4`, so `numPeriods == 0` below one
  year and `for i in 1...0` crashed on clean data. Fixing it also repaired a pricing defect
  never about contamination: a 1.5-year CDS priced off a one-year premium leg.
- `JumpDiffusion` composed two *correct* functions into a crash — `normalCDF` saturates to 1.0
  above ~8.3, and `inverseNormalCDF(p: 1)` is documented as `+infinity`.
- `SimulationResults.histogram` asked for ~2.9e306 bins for a heavy tail over a tight core.

**The uncovered-period defect.** `altmanZScore` returned 0.00 — the distress zone — for a
solvent, profitable company asked about a period outside its statements. Fixed, with
`BalanceSheet.workingCapitalTurnover(revenue:)`. Contract §3.7 generalises it.

## OPEN

### 1. Phase 3 leftovers — located, unfixed

Phase 3 itself is **closed**: six agents fixed everything in `PHASE3_PROBE_FINDINGS.md`, and the
suite went 8,434 -> 8,538 with exactly **one** existing fixture needing an update
(`aggregateMonthlyToQuarterlySum`, which was asserting the fabricated answer in so many words).
What they flagged on the way and did not fix:

- **`dispersionScaledScore` returns `0.0` for a NaN deviation** — "perfectly normal" for a value
  that could not be scored. This is *the helper this campaign added* to fix six clamp sites,
  carrying the same defect for the contaminated case that its own DocC was written to remove.
  The real fix is in the composite scorer's aggregation (exclude unevaluable sub-scores, divide
  by the count that remained), which is a design decision, not a guard.
- **`detectWithIQR` / `detectWithMAD` sort a buffer that may contain NaN** — the contract's
  "`sorted()` is unspecified" row. Not silence: **valid elements come back out of order**, so
  `q1`/`q3`/median can be confidently wrong finite numbers.
- **`simpleExponentialSmoothing` and `tripleExponentialSmoothing`** have the identical
  never-recovers recursion as DES. Two lines each, mirroring `StreamingForecasting.swift:531`.
- **`exponentialMovingAverage(alpha:)`** — same shape, `TimeSeriesAnalytics.swift:428`.
- **`growthRate(lag:)`** drops a period entirely when the previous value is legitimately zero —
  the series comes back shorter with no diagnostic.
- **`rollingThresholdExceedanceRate`** counts an unusable difference as "did not exceed" and
  reports a confident fraction. It recovers, so it is not in the never-recovers class.
- **`seasonalIndices`' `ratios.isEmpty -> T(1)` fallback is still reachable** for a *clean*
  series whose trend passes through zero.
- **`adf` threw `noVariance` on the CLEAN series** in the probe fixture — unexplained. Establish
  whether the fixture is degenerate for ADF's purposes or the test is.
- **`labels` are silently dropped by every operation** in `TimeSeriesOperations.swift`.
- **`AggregationMethod` is not `Sendable`**, which is why the new tests loop instead of using
  `@Test(arguments:)`. Additive one-liner.

### 2. Deferred deliberately — needs an API decision, not a guard

`piotroskiScore` and `FinancialPeriodSummary.init` together. Neither has a representation for
"not answerable": `PiotroskiScore.totalScore` is a non-optional `Int` and its `signals` DocC
promises all nine keys are always present. `FinancialPeriodSummary.init` is declared `throws`
and contains **zero `throw` statements**, filling 20 fields with fabricated zeros.

The trap in the obvious fix: **three different meanings of `nil` share one spelling** there. Six
fields come from `BalanceSheet.ratio(_:over:)`, which deliberately omits zero-divisor periods —
so `currentRatio[period]` is legitimately `nil` at a *fully covered* period for a company with
no current liabilities, and a blanket nil-to-throw would reject exactly the debt-free company an
earlier commit in this campaign made representable. Doing it properly means changing six public
`let` properties from `T` to `T?` and adding `T?` overloads of three `KeyPath` aggregators in
`ConsolidatedStatements.swift`.

### 3. Smaller, located, unfixed

- `DistributionPoisson.quantile` is **O(λ)** — `for k in 0...ceiling` with `ceiling ≈ λ`. λ=1e12
  is constructible and hangs. This is not a regression (it never trapped below `Int.max`); the
  real repair is to start the search near the mode, not to pick a performance cutoff.
- `InventorySimulator` has **no guard on `iterations`** — `iterations: 0` reaches
  `sorted[clampedIndex]` on an empty array.
- `distributionTriangular:61` — at exactly `u == 0` the condition `u > 0 && u < fc` is false, so
  it takes the second branch and returns 2.93 instead of `low` for `[0,10]` mode 5.
- `bootstrapCreditCurve` does not screen `tenors`; a `nan` tenor makes `sorted` unspecified.
- `SimulationResults:445` — `Int(ceil(log2(n) + 1.0))` traps at `n == 0`; currently unreachable,
  one future caller away.
- `ClassifierEvaluation.calibration` returns `brierScore == +infinity` for an unbounded score.

### 4. Phase 2 — scoped, not started

~75 `?? 0` sites in Financial Statements (63), Model Definition, Diagnostics, Industry Models.
Top files `CreditMetrics.swift` (25), `FinancialPeriodSummary.swift` (20). See the plan's Phase 2,
which was **corrected on 2026-09-28**: the original "78 sites in Time Series" are
`DateComponents.year ?? 0`, a different shape, and Network's 20 are correct by construction.

## Method — these each cost something to learn

- **Probe before theorising.** Three items that looked like defects measured clean this session.
- **Keep a control that passes on both sides.** It is the only thing separating a fix from a
  blanket short-circuit, and it caught an over-generalised claim in this campaign.
- **The fix is where the new bugs come from.** The knapsack fix took three attempts, each caught
  by a different trap. `PowerAnalysis` needs strict `<` against `T(Int.max)` because that value
  rounds up to 2^63 and traps — the bug, inside the guard against it.
- **The clamp-absorbs-NaN shape reappears in remediation.** `Swift.min(span, limit)` returns the
  `nan`. Use an explicit comparison.
- **A correctly-behaving sibling decides the contract.** Used eight times now.
- **A search is not evidence — and neither is a census by syntax.** The Phase 2 grep was right
  about where `?? 0` appears and wrong about what it *meant* in each place.
- **Never `allSatisfy(\.isNaN)` inside `#expect`** — the macro expansion makes `rethrows`
  unprovable and it fails to compile. Write `allSatisfy { $0.isNaN }`. Same family as the
  type-check timeouts in `CLAUDE.md`: the macro strips the context the solver relied on.
- **Never `components(separatedBy: "\n")`** — `safety` rejects it. Use
  `split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)`.
- **A gate run from `.claude/worktrees/` examines 0 files and prints PASSED.** Agents must not
  self-certify; they author, one process executes.
- **Do not run parallel `swift build`s** — killed twice here for memory pressure. Thirteen
  agents this session ran with builds forbidden and it worked well.
- `swift test --filter` matches **type** names, not `@Suite` display names. Add `--no-parallel`
  when reading printed output, or probes interleave into nonsense.

## CI

`doc-run` is **load-sensitive** and this is now measured twice: it failed on
`5.16-GPUAccelerationTutorial.md` at load 136 and passed on the identical tree at load 12. It
blocks the *push*, not the commit. If it fails, check `uptime` before reading code.

`Release Tests` -> **Thread Sanitizer (macOS)** has failed twice, both cleared by a re-run on
identical code, log stopping mid-build with no error text and the 120-minute timeout never
approached. Hypothesis is runner memory pressure — **unproven**. Never treat a TSan-only failure
as a regression without checking the other two jobs.
