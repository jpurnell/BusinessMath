# Contaminated-input sweep — remaining work

**Status:** planned
**Companion to:** `CONTAMINATED_INPUT_CONTRACT.md` (the behavioural spec) and
`quality-gate-swift-project/plans/proposals/AFallbackIsAnAnswer.md` (the checker)
**Baseline:** BusinessMath at `917127b5` — 20 commits, ~45 defects, 3 hard crashes, 8,342 tests
**Date:** 2026-09-28

---

## 1. What has actually been covered

It is worth being exact, because the campaign felt more complete than it was. The work so far
swept **four shapes across six areas**, plus ad-hoc probing in a few others:

| shape | what it is | swept in |
|---|---|---|
| **A** | `guard <computed fp> > 0 else { return <literal> }` | Simulation, Fluent API, Financial Statements, Statistics, Network, Valuation, Marketing, Stochastic, Optimization, AdvancedOptimization, Forecasting |
| **B** | `if x > 0 … else if x < 0 … else` | whole repository (only 5 sites existed) |
| **C** | `.sorted()` on a floating-point collection, then indexed | Risk, Statistics, Simulation, Forecasting |
| **D** | `Swift.max(a, Swift.min(b, x))` | whole repository (only 2 sites existed) |

Shapes B and D are genuinely finished — the greps return single digits repository-wide and
every hit was triaged. Shape A is finished for the eleven areas the four triage agents covered.

**Everything else is open.** Five further shapes were never swept anywhere, and roughly a dozen
areas were never probed at all.

## 2. What remains, measured

Counts are `grep`-level and comment-excluded. They are **upper bounds**: the triage rate
observed across 295 sites was 82% legitimate, so expect roughly one in six to survive reading,
and fewer than that to be real defects.

### 2.1 Shapes never swept

| shape | what it is | why it matters | sites |
|---|---|---|---|
| **E** | `Int(<floating-point expr>)` with no finiteness guard | **traps** — `Int(nan)` and `Int(1e300)` both crash | ~92 |
| **F** | `?? 0` on an optional numeric lookup | missing data silently becomes a real zero | ~140 |
| **G** | `else { return T(0) }` after a validity guard | the shape-A family, other spelling | ~95 |
| **H** | `.min()` / `.max()` on a floating-point collection | **skips** NaN silently, position-dependent | ~35 |
| **I** | `firstIndex(of:)` / `.contains(` on floating-point | `nan == nan` is false → element vanishes | ~100 (very noisy; most are `String`) |

Shape E is the only one that produces a **crash rather than a wrong answer**, and all three
crashes in the campaign were found by accident rather than by sweeping for it.

### 2.2 By area, shapes E–H combined

| area | E `Int(` | F `?? 0` | G `else 0` | H min/max | total |
|---|---|---|---|---|---|
| Time Series | 0 | 78 | 10 | 5 | **93** |
| Statistics | 25 | 8 | 43 | 4 | **80** |
| Optimization | 32 | 9 | 14 | 9 | **64** |
| Simulation | 23 | 6 | 3 | 6 | **38** |
| Valuation | 8 | 7 | 16 | 0 | **31** |
| Network | 0 | 20 | 2 | 0 | **22** |
| Streaming | 1 | 5 | 6 | 4 | **16** |
| BusinessOptimization | 0 | 8 | 0 | 2 | **10** |
| Scenario Analysis / Diagnostics / Fluent API | — | — | — | — | ~27 |
| Visualization / Risk / Marketing / Finance / AdvancedOpt | — | — | — | — | ~28 |

> **The F column has been read since this table was built, and two of its cells do not mean what
> the header says.** Time Series' 78 are `DateComponents.year ?? 0` — Foundation calendar
> unwraps, a different shape — and Network's 20 are accumulator reads that are correct by
> construction. The real `?? 0`-on-a-period-lookup class is ~75 sites concentrated in Financial
> Statements. See Phase 2. Every other cell in this table is still `grep`-level and unread;
> treat each as a question, not a count.

### 2.3 Areas never probed at all

Never visited by a triage agent and never probed by hand, ordered by public API surface:

Streaming (123 public funcs, only anomaly detection and trend touched) · Time Series (122, only
TVM touched) · Diagnostics (43) · Interpolation (41) · Operational Drivers (39) · Model
Definition (35) · Risk (27, only VaR/CVaR/Sharpe/Sortino/Kurtosis touched) · Portfolio (17,
only the Sharpe family) · Developer Tools (17) · Scenario Analysis (15) · Extensions (14) ·
Combination and Permutation (14) · Performance (13) · Operations (12) · Derivatives (10) ·
Audit (10) · Validation (9) · Utilities (9)

---

## 3. Phases

Ordered by expected yield per hour, not by size. The rates come from the campaign: a systematic
sweep of an untargeted area returned **3.7%** defects (Simulation, 3 of 81), hand-picked
families returned **25–35%**, and the four-agent triage returned **15%** across 295 sites.

### Phase 1 — Shape E everywhere (the trap class)

**Scope:** ~92 `Int(<expr>)` sites, concentrated in Optimization (32), Statistics (25),
Simulation (23), Valuation (8).

**Why first:** it is the only class that crashes rather than lying, it needs no judgement about
what a fallback *means*, and it is exactly the rule proposed as an **error** severity in
`AFallbackIsAnAnswer.md` §3.2 — so this phase doubles as that rule's test corpus.

**Method:** mechanical. For each site, establish whether the argument is floating-point and
whether a finiteness check dominates it. No probe needed for the verdict; a probe only to
demonstrate the trap where one is found. Fix by screening at the entry point, never by
`if x.isFinite` at the conversion — the three already fixed all needed the screen *earlier*
than the conversion, and one of them needed it earlier than a count was taken.

**Expected:** 92 sites → ~15 reachable from a public entry point → a handful of real traps.
Low defect count, high severity each.

**Exit:** every `Int(` on a floating-point expression either has a dominating finiteness guard
or a comment saying why it cannot be non-finite.

### Phase 2 — Shape F in Financial Statements (`?? 0`)

> **Corrected 2026-09-28.** This section originally scoped the class as "~78 sites in Time
> Series, ~20 in Network, ~8 in Statistics". That was wrong, and wrong in the way a grep is
> usually wrong: the pattern matched, the meaning did not. The counts below are read, not
> matched. See §5's rule — *a site is not a defect* — which applies just as forcefully to a
> site's **classification** as to its severity.

**What the original scope actually contained:**

- **Time Series' 78** are `DateComponents.year ?? 0`, `.month ?? 0`, `.day ?? 0` — Foundation
  calendar unwraps, in `Period.swift` (62), `PeriodArithmetic.swift` (10) and
  `FiscalCalendar.swift` (4). Not period lookups at all. They are a **different shape worth its
  own line**: a missing calendar component silently becomes year 0, which is a real defect
  class, just not this one. Do not fix it here; log it and scope it separately.
- **Network's 20** are `[Node: Double]` accumulator reads, where a node absent from the
  accumulator has genuinely contributed nothing. Correct by construction. Not defects.

**Actual scope:** ~75 sites — **Financial Statements (63)**, Model Definition (3), Diagnostics
(2), Industry Models (2). Top files: `CreditMetrics.swift` (25), `FinancialPeriodSummary.swift`
(20).

**Why it matters:** `statements[period] ?? 0` means **a missing period reads as a real zero**.
Measured: `altmanZScore` for a period outside the supplied statements returns **0.00 — the
distress zone** — for a solvent, profitable company, because `totalAssets[period]` is `nil`.
`piotroskiScore` is worse, taking `period` *and* `priorPeriod` and thresholding on both, so an
uncovered prior period silently **awards** the "increasing ROA" point: the score goes up
because data is missing.

**The design constraint, established before any edit:** `TimeSeries` **cannot** distinguish
"before the series starts" from "a hole in the middle". Its `periods` is derived from the value
keys (`self.periods = valueDict.keys.sorted()`), and `Period: Comparable` sorts **type-first**,
so `periods.first` / `.last` do not bound a span. The rule therefore cannot be "detect the gap".

**Method:** the rule is **"narrow the domain, don't fabricate the observation"** — a query about
a period the data does not cover is not answerable, and the API says so in whatever way its
signature already allows. `TimeSeries.zip(with:)` already does exactly this and is the
precedent. This needs **no API change**. Landed as contract §3.7.

**Sequencing.** `altmanZScore` and `BalanceSheet.workingCapitalTurnover(revenue:)` are ready
now. `piotroskiScore` and `FinancialPeriodSummary.init` are not: the latter is declared `throws`
and contains **zero `throw` statements**, filling twenty fields with fabricated zeros for any
period whatsoever. It is the highest-value fix in the file and the most likely to turn existing
fixtures red — budget it as a deliberate pass with fixture repair, not as part of a sweep.

**Expected:** a design note and two fixes in this phase; a second, larger pass for the rest.

### Phase 3 — Streaming and Time Series, by probe

**Scope:** the two largest never-probed areas, 245 public functions between them.

**Why third:** area-based rather than shape-based, because these have had no adversarial input
at all. Streaming is the higher risk of the two: it is stateful, so a contaminated value can
persist in a window or accumulator long after the reading that introduced it — a failure mode
none of the pure functions swept so far can exhibit.

**Method:** the harness pattern from the campaign. One probe file per area, a loop over
`(name, closure)` printing clean / nan-first / nan-middle / nan-last, flagging any contaminated
result that comes back finite. For stateful operators, additionally: feed a contaminated value
**then clean values**, and check whether the operator recovers or stays poisoned.

**Expected:** 3–8% on the untargeted rate, so perhaps 8–20 findings, weighted toward Streaming.

### Phase 4 — Shape G, remaining areas

**Scope:** ~95 `else { return T(0) }` sites, concentrated in Statistics (43), Valuation (16),
Optimization (14).

**Why fourth:** same family as shape A, already well understood, and the triage question is
already written. Lower yield because Statistics has been partly swept.

**Method:** the four-agent read-only triage, unchanged — it worked, returned 82% legitimate,
and correctly identified four candidates as *not* defects with mechanisms.

### Phase 5 — Shapes H and I, and the small areas

**Scope:** ~35 min/max sites, the noisy shape-I set, and the dozen small never-probed areas
(Diagnostics, Interpolation, Operational Drivers, Model Definition, Portfolio, Developer Tools,
Derivatives, Operations, Audit, Validation, Utilities).

**Why last:** lowest expected yield. Shape I is mostly `String` and will need type resolution to
be worth reading at all; the small areas are small.

**Method:** fold into a single agent pass once the checker from `AFallbackIsAnAnswer.md` exists,
and let the checker do the enumeration instead of grep.

---

## 4. Method notes that cost the most to learn

These are not optional; each was paid for once already.

- **Probe before theorising.** Two hypotheses in the campaign were wrong and the probe settled
  both in minutes. One agent prediction — "all three anomaly detectors return `[]`" — was too
  strong, and only two of five assertions failed against the unfixed source, which is what
  caught it.
- **Write the test red first, and keep controls that pass on both sides.** The controls are
  what prove the suite discriminates. In the `kendallW` batch, fixing three of five clamp sites
  left two tests red, which found the remaining pair plus two inline copies a grep had missed.
- **The fix is where the new bugs come from.** The knapsack fix took three attempts and the
  tests caught each with a *different* trap: `Int(.nan)`, then `Index out of range` because `n`
  was taken before the filter, and a patch that landed in the wrong function because two
  `guard budget > 0` blocks are textually identical.
- **Measure control values, never recall them.** Two fabricated expected values were caught by
  tests during the campaign.
- **Agent findings are claims until measured.** 295 triaged sites, 82% legitimate, and a
  meaningful share of the remainder dissolved under probing.
- **Do not fan out before the contract is frozen.** The defect class *is* inconsistency; four
  authors answering independently manufacture more of it.
- **A gate run from a `.claude/worktrees/` path examines 0 files and prints PASSED.** Agents
  must not self-certify.

## 5. When to stop

Not "when the greps are empty" — they never will be, and most hits are legitimate. Stop a phase
when either holds:

1. **Yield falls below ~5%** over a full area. Simulation returned 3 of 81 and that was the
   signal the high-value work in that area was done.
2. **The checker can enumerate the class.** Once `fallback.*` ships, hand-sweeping a shape it
   detects is redundant; the ratchet does it continuously and for every future commit.

Phase 1 is the exception and should be finished regardless of yield, because a crash is not a
yield question.

## 6. What not to do

- **Do not tidy identical guards into agreement.** `altmanZScore` and `CapitalStructure` each
  contain two textually identical guards four lines apart where one is correct and one was
  maximally wrong.
- **Do not treat a justification comment as evidence.** The most expensive defect sat behind a
  correct, carefully written comment that simply never mentioned the second condition reaching
  the same line.
- **Do not change a documented sentinel without raising it.** `ManufacturingModel`'s zero unit
  cost was queried, and the answer was that the *caller's* objective was badly posed — minimise
  unit cost unconstrained and it will always prefer making nothing, whatever the function
  returns. Two existing tests pinned that decision and were right to.
- **Do not run four `swift build`s in parallel.** This machine killed runs twice for memory
  pressure during the campaign. Agents author probes; one process executes them.
