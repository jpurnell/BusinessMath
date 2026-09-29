# Handoff — 2026-09-29 (Phases 1, 2 and 3 CLOSED; Phase 4 in flight)

**8,694 tests / 808 suites. Gate verified 46/46 by hand — 43 PASSED, 3 SKIPPED.**

A long campaign against one defect class: **a guard that is correct while the value it returns
is wrong** — plus its cousin, `Int(x)` trapping the process. 25 commits. Phases 1, 2 and 3 are closed.

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

**Phase 3 — Streaming and Time Series, by probe.** 21 probes measured, everything fixed in
`ef4c0538` and `7b1c69cd`. Three detectors were *silent about something real*:
`detectBreakpoints` returned `[]` where the control returned `[20]` at cost 16000;
`detectSeasonalAnomalies` let one NaN poison a season baseline permanently, so a genuine 50x
spike 24 observations later reported `isAnomaly = false`; `ewma` never tripped again. Four more
operators never recovered, and `rollingStatistics` on the same input did — **the recovering
sibling decided the contract**. The gap findings contain *no NaN at all*: `.sum`/`.max` treat a
missing month exactly as a zero month, and `movingAverage(window: 3)` across a hole averaged
Feb+Apr+May and labelled it May.

**Phase 2 — the `?? 0` period-lookup class.** Closed in `2bf3129f`. 34 sites read: 9 real
defects, 3 latent-but-guarded, **18 legitimate and pinned**. Two invariants decided most of it,
both read out of the code: `validatePeriodConsistency` makes statement-layer lookups
unreachable, and `TimeSeries.periods` is its own key set. The test that falls out — **where does
the period come from?** own domain → dead, caller-supplied → live.

The worst of it was invisible to the census: `DebtCovenants` declared `toDouble(_ value: T?)`
**twice**, applied to nine `series[period]` reads, so the `??` sat one level below every call
site and a `?? 0` grep returned nothing for the file. Its fix then needed three more guards,
because `abs(nan) > 0.001` is false and a `.nan` would have reached an `.infinity` exit —
boundless coverage, the *passing* end of every minimum covenant.

## OPEN

### 1. Phase 3 leftovers — what survived `7b1c69cd`

Most of the Phase 3 leftover list was closed by the warm-up/partial-evidence commit
(`dispersionScaledScore`, the IQR/MAD NaN sorts, SES/TES, `exponentialMovingAverage`,
`growthRate(lag:)`'s length invariant, `rollingThresholdExceedanceRate`, `seasonalIndices`'
zero-crossing trend, label preservation, `AggregationMethod: Sendable`, and the
`PeriodSequence.aggregate` twin). What is still open:

- **`decomposeTimeSeries(.additive)` does not compute an additive index at all.** It takes the
  *multiplicative* indices and re-centres them, then subtracts that **dimensionless** quantity
  from values carrying units. Fixing it properly would change every additive result the
  function has ever returned — an API decision, not a guard.
- **`growthRate(lag:)` and `diff(lag:)` across a period gap** label a 2-month span as 1-period
  growth. A third shape — neither "never recovers" nor "silently drops" — and every available
  fix conflicts with the length invariant just restored there. Related: `averageTimeSeries`
  averages against `periods[i-1]`, the adjacent *sorted-list* element, not the calendar-prior
  period.
- **`FinancialPeriodSummary`'s margin/EBITDA trends still return `[T]` that can hold `nan`** —
  correct per §3.1, but any consumer that `sorted()`s one hits the unspecified-ordering shape.
- **Triple smoothing: a legitimate `0.0` observation in the initialisation window** gives that
  slot a factor of exactly `0.0`, so `value / 0.0` is `inf`, the level goes `inf` and stays.
  Clean finite input, permanent contamination — and it sits under an
  `// fp-safety:disable — factors initialized to 1.0` suppression **whose justification is
  simply false** once a zero lands in the window.

### 2. Deferred deliberately — needs an API decision, not a guard

`piotroskiScore` and `FinancialPeriodSummary` were both closed in Phase 2 by widening six ratio
fields to `T?` and making the initializer's declared `throws` true. What remains needs the same
kind of decision, and the same window: the repository is on a pre-release line
(`v3.0.0-alpha.7`) and **SPM excludes pre-releases from `from:` ranges**, so a source-breaking
change currently reaches only callers naming an alpha exactly. That window closes at 3.0.0.

- **`DebtInstrument.swift:177`** — `.custom(schedule:)` shorter than the generated period count
  is an **index-out-of-range trap in a public API from public input**; longer silently drops the
  tail. `schedule()` is non-throwing and non-optional, so refusing needs a signature change.
- **The covenant `Bool` has no third state.** A `.nan` metric now reads as *non-compliance*
  rather than as *silence*, because `CovenantComplianceResult.isCompliant` is a `Bool`.

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

### 4. Phase 4 and Phase 5 — the remainder

**Phase 4 (shape G, `else { return T(0) }` after a valid guard) is 3.7x the plan's estimate:
350 raw matches, not ~95.** Simulation 156, Statistics 61, Fluent API 31, Optimization 19,
Valuation 17. At the campaign's measured triage rate (82% legitimate across 295 sites) that
implies roughly 60 real defects — but that rate is an average over areas that differ wildly:
Network's accumulators were ~100% legitimate, `piotroskiScore`'s 19 were 100% defects.

**Phase 5 is scoped and its precondition is met.** The plan said to run it "once the checker
from `AFallbackIsAnAnswer.md` exists, and let the checker do the enumeration instead of grep" —
that checker landed in `0ecc7848` with a baseline of 61 sites (38 `int-conversion-unguarded`,
14 `classification-omits-nan`, 9 `clamp-absorbs-nan`). Measured scope:

| shape | count | where |
|---|---|---|
| H — `.min()`/`.max()` on floats | 43 | Optimization 9, Simulation 6, Streaming 7, Scenario Analysis 6 |
| I — `firstIndex(of:)`/`contains` on floats | 131 raw | very noisy; mostly `String`, needs type resolution to be worth reading |

Never-probed areas by public surface: **Fluent API 314** (and 31 shape-G sites — the largest
unswept block in the repository), Streaming 147, Marketing 72, Diagnostics 55, Model Definition
52, Operational Drivers 48, Scenario Analysis 31, Developer Tools 27, Validation 26, and a tail
of ten smaller ones.

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
- **`✅ Quality Gate: PASSED` is not evidence. The line under it is.** On 2026-09-29 a new gate
  binary (v3.3.0, installed at 10:00 by the peer session that develops it) expanded
  `--check all` to **24 of its own 46 checkers** and still printed PASSED, with
  *"22 NOT REACHED — 0 findings from them means nothing"* directly beneath. Three runs were
  reported as clean before anyone read the count. **Recovery:** `--check <name>` still works;
  diff the checker names against a known-good earlier run and run the missing ones
  individually. Expect `privacy-manifest`, `mcp-readiness` and `appintents-readiness` to come
  back `○ SKIPPED` — they do not apply here, so 43 PASSED + 3 SKIPPED is a complete result.
  Check `ls -l $(which quality-gate)` when behaviour changes mid-session.
- **The standard `agree` test helper is wrong for this campaign.** `isEqual(to:)` is IEEE
  equality, so `nan.isEqual(to: .nan)` is **false** and a deliberately-marked position can never
  match. Four agent-written tests failed on it in one run. All 14 copies now carry
  `|| ($0.isNaN && $1.isNaN)`.
- **`git add -A` sweeps a peer session's untracked files into your commit.** An 849-line
  proposal of theirs landed in a commit describing this sweep, while they were still writing it.
  Stage explicit paths, and account for every line of `git status --porcelain`.
- **A justification comment's *placement* is part of the contract.** `} catch { // logging: …`
  must be single-line and inline; on the next line it is invisible to the checker even when the
  text is right. Copy the shape of an accepted instance rather than writing one from the rule.

## CI

`doc-run` is **load-sensitive** and this is now measured twice: it failed on
`5.16-GPUAccelerationTutorial.md` at load 136 and passed on the identical tree at load 12. It
blocks the *push*, not the commit. If it fails, check `uptime` before reading code.

`Release Tests` -> **Thread Sanitizer (macOS)** has failed twice, both cleared by a re-run on
identical code, log stopping mid-build with no error text and the 120-minute timeout never
approached. Hypothesis is runner memory pressure — **unproven**. Never treat a TSan-only failure
as a regression without checking the other two jobs.
