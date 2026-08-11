# Plan: what "trustworthy" requires, and the order to get there

**Written:** 2026-08-10. Supersedes §6 of `proposals/IntendedSurface.md`, which predates a day of
remediation.

The goal is not zero findings. The gate was green while a MILP validator accepted nonlinear
objectives one run in a thousand, while a GPU RNG correlated adjacent Monte Carlo iterations at
ρ ≈ 0.26, and while an entire test suite passed by never compiling. Zero was achievable by all of
those.

For a numerical library, trust decomposes into three claims, in descending order of how badly a
breach damages it:

1. **The library does not lie about what it does.**
2. **Where a number cannot be exact, the library says so.**
3. **The published numbers are the numbers the code produces.**

---

## Phase 1 — stop the lying (the trust breach)

Nothing else matters as much. A wrong number is a bug; a confident wrong *answer* is a betrayal,
because the user has no reason to check it.

### 1.1 Circular-dependency detection — decide, then act

Two public functions claim to detect cycles and cannot:

| symbol | reality |
|---|---|
| `Diagnostics/ModelDebugger.swift:652` `detectCircularDependencies(in:)` | `return []`, unconditionally |
| `Developer Tools/ModelInspector.swift:183` `detectCircularReferences()` | placeholder over a graph that hardcodes `graph[revenue.name] = []`; can only return `false` |

`1.6-DebuggingGuide` teaches both and prints a sample detected cycle.
`BusinessMathError.circularDependency.recoverySuggestion` tells the user to resolve it "using an
iterative solver"; `IterativeSolver` has **zero references** in the repository, and two tests
(`BusinessMathErrorTests.swift:195`, `:488`) assert on that string. `CHANGELOG.md:1467` advertises
the capability.

The condition is not currently representable: `FormulaEvaluator` maps account names to
*already-computed* `TimeSeries`, not to formulas, so mutual reference cannot be constructed.
`FinancialModel` holds `RevenueComponent`/`CostComponent`, neither carrying a formula.

**Recommended: retract now, build later.** Delete both functions, the `CircularDependency` type's
producer path, the `recoverySuggestion` sentence, the two tests pinning it, the CHANGELOG claim,
and the `1.6` sections. A public break, and more honest than shipping a detector that reports
"clean" about a model that isn't.

Building it properly is a *feature*: formula-holding accounts, a graph walk over
`FormulaEvaluator.accountNames(in:)` (which already reports a formula's dependencies without
evaluating, and has zero production call sites), and the fixed-point evaluator the
`recoverySuggestion` promises. Worth doing; not worth blocking the retraction on.

### 1.2 The unwired error vocabulary

Seven `BusinessMathError` cases have zero throw sites and `git log -S` confirms none ever existed.

| case | verdict | first move |
|---|---|---|
| `numericalInstability` E004 | wire — detected ~11 times, mislabelled every time | `IRR.swift:136` already says "numerical instability detected" in its reason string and throws `calculationFailed`. Zero-risk relabel. |
| `invalidDriver` E200 | wire — and one site is a live bug | `SensitivityAnalysis.swift:805` does `guard let … else { continue }`, so a typo'd driver name **silently drops a tornado bar** |
| `inconsistentData` E202 | wire | `BalanceSheet.swift:915` `validate(tolerance:)` already throws a one-off local error with no code and no recovery |
| `circularDependency` E201 | blocked on 1.1 | — |
| `negativeValue` E301 | refactor, low urgency | ~91 of 138 `.invalidInput` throws are sign rejections; value is the typed payload, lost at ~8 sites today |
| `outOfRange` E302 | refactor, low urgency | ~28 are two-sided bounds; 87 sites already pass the range as a *string* |
| `resourceExhausted` E400 | decide | undocumented as well as unwired |

E301/E302 belong with a consolidation of the **four** parallel validation vocabularies
(`BusinessMathError`, `Validation/ValidationTypes`, `StandardValidation`'s unused `NonNegative`/
`Range` rules, and the macro-generated one in `BusinessMathMacrosImpl`). Not standalone work.

### 1.3 Documented API that does not exist

Catalogued in `proposals/IntendedSurface.md` §2. Largest single item is `3.15`'s ingestion
subsystem, already resolved by rewriting the article around the boundary that exists. Remaining:
`Period.custom` (shipped), `FinancialModel`'s balance-sheet surface, `DataTable`'s fluent chain,
structured logging. Each is "build it or retract it" — the same test as 1.1.

---

## Phase 2 — say when a number is inexact

### ~~2.1 `normalCDF` in the lower tail~~ — done

~~Computes `(1 + erf(x/√2))/2`, which cancels catastrophically for negative `x`: fed an exact
quantile it returns **2.2e-5 relative error at p = 1e-12**. `erfc(-x/√2)/2` gives ~1e-15.~~

~~Nothing fails today, which is the problem — every tail-risk figure inherits it. Deferred once
already because it moves expectations across the suite; that is a reason to schedule it, not to
skip it.~~

Fixed. `normalCDF` is `erfc(-x/√2)/2`; measured **2.2e-5 → 5.3e-15** relative at p = 1e-12, and
the function now reaches x = -37 instead of flushing to zero below x = -8.3. The upper half does
not regress — it is bit-exact against `1 - erfc(x/√2)/2` at all 80,001 sampled points, where the
sum form differed by 1 ulp at 9,065 of them.

Three things it turned up that the plan did not predict:

- **`percentile(zScore:)` was a second copy** of the same wrong formula, one line of it, in a
  different directory. The recurring shape: a correct implementation ships while a caller keeps a
  private worse one. It now delegates.
- **The Black-Scholes negative prices resolved as a consequence**, and the diagnosis recorded in
  `BlackScholesReferenceTests` was wrong. The deep-OTM cancellation is only 48×, not catastrophic;
  the terms were noise because Φ was noise. The proposed clamp at zero would have produced the
  right sign from the wrong number. No Black-Scholes code was changed. 311 negative prices across
  four parameter sets, now zero, and the prices agree with a 100-digit reference to ~1e-13.
- **One reference value in the new differential suite was itself wrong** — Φ at the exact `Double`
  quantile of 1e-12 is 9.9999999999999878e-13, not 1e-12, a 1.2e-14 relative offset that only
  became visible once the error under test dropped below it. §2.2's own warning about reading a
  reference at the wrong argument, one test away from where it was written.

`zScore(percentile:)` was the same defect in the inverse direction — `√2·erfInv(2p-1)`, refining
against an `erf` that saturates in the tail — and now delegates to `inverseNormalCDF`:
**2.1e-6 → 0.0** absolute at p = 1e-12. `normSInv` and `erfInv` are public, so neither was deleted;
`erfInv` routes through the canonical quantile from the smaller side, `5.3e-13 → 2.3e-15`.

### 2.2 Differential testing against published references

The class where a wrong implementation is only visible beside a right one. `inverseNormalCDF` was
discontinuous — jumping 0.30 → 1.372 at u = 0.6, an entire interval of outputs unreachable — and
survived because nobody compared it to a known-good answer. Three copies existed; comparing any
two would have exposed it.

Targets: `normalCDF`, the distribution family, `irr`/`npv`/`xirr`, Black-Scholes and the greeks,
the quantile functions. Compare against published reference values with stated tolerances, and
record the measured accuracy in each doc comment as `inverseNormalCDF` now does.

---

## Phase 3 — the published numbers must be real

`doc-code` typechecks the articles; it does not run them. So the class it cannot see:

- `4.1` documented **"Total Growth over 2 years: 62.3%"** where the code yields **113.9%** — it
  read the wrong variable, and the published figure was wrong long enough to look authoritative.
- `4.1`'s confidence intervals printed **90%, 95% and 99% identically**, because arbitrary
  percentiles were unavailable and the example hand-rolled an interpolation.
- `2.2` would have taught that a healthy manufacturer collects receivables in **219 days**, had
  the worked example used discrete quarters against a 365-day divisor.

The fix is the verification ladder in `DocCodeAuditor.md` §6: execute the assembled article and
compare its output against the `// prints:` claims. Expensive, and the only thing that closes this.

Related and cheaper: `doc-comment-code`. The `///` corpus holds **1,394** fenced blocks against the
catalogue's 1,291, is entirely unchecked, and is *upstream* — `RiskMetrics.swift:63` documents
`DistributionNormal(mean:stdDev:)`, an initialiser that does not exist, and `4.3` had the identical
error because it was copied from Quick Help.

---

## Order

1. **1.1 retraction** — the only item where the library currently misinforms a user who is doing
   everything right.
2. **1.2 first three rows** — `IRR.swift:136` relabel, `SensitivityAnalysis.swift:805` bug fix,
   `BalanceSheet` → E202. Small, independent, each closes a real gap.
3. **2.2 differential tests** — highest ratio of defects-found to effort, and it is the safety net
   for everything in Phase 2.
4. ~~**2.1 `normalCDF`** — schedule deliberately; it moves expectations.~~ Done. It moved five
   expectations, all of them recorded from this library's own output rather than from a source,
   and it closed five of the suite's nine known issues — the three it was scheduled for and two
   Black-Scholes ones nobody had connected to it.
5. **`doc-comment-code`** — larger corpus, upstream of the catalogue.
6. **Phase 3 run-and-compare** — the expensive one, last.

Deferred and tracked, not forgotten: `Period.<` orders by granularity before start date, so a
`TimeSeries` mixing annual and quarterly points is stored out of chronological order (pinned in a
test). `TestQualityAuditor` has no warning-only state, so the gate exits 1 at zero errors if any
test-quality warning exists.
