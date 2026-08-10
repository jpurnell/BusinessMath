# Handoff — 2026-08-10

**The DocC catalogue compiles, and the checker that proves it now ships in the gate.**

Nothing is pushed. Fifteen commits on `fix/simplex-scale-relative-feasibility`, all verified by
direct runs rather than agent reports.

---

## State

| | |
|---|---|
| tests | 6,278 in 553 suites |
| build | 0 warnings |
| DocC articles | 73/73, 1,219 fences checked, 86 exempt |
| quality gate | **in progress** — was 54 errors / 10 warnings after the gate redeploy |

The gate number is not a regression. Redeploying brought in a unified `fp-equality` rule that
closed a coverage hole: the old test-quality rule required a float *literal* adjacent to `==`, so
comparisons between two computed `Double`s were invisible. The 54 are that class, newly visible.
Most are seeded-reproducibility assertions where `==` is genuinely the wrong operator — it reports
`NaN != NaN`, so a NaN in the stream lets the assertion pass while broken.

---

## What landed today

**Documentation.** 73 articles from 6 passing / 2,092 errors to all green. `3.16` is now generated
from the role enums by *executing* them (`docref`), so its tables cannot drift. `3.15` went 986 →
332 lines: it documented an ingestion subsystem that does not exist, and the boundary that does is
that the model graph is already `Codable`.

**Determinism, both halves.** RNG: `integrate`'s seed was inert (erased before the second sample);
`ScenarioGenerator` used process-global `srand48`, so seeds did not survive parallel execution
(measured: 20/20 runs failed, 96.1% of assertions); `seeds: [Double]?` silently fell through to the
global generator when exhausted, removed across 9 entry points and 152 call sites; the GPU seeded
threads `baseSeed ^ tid`, correlating adjacent Monte Carlo iterations at ρ ≈ 0.26. Clock:
`WallClock` injected at 21 timestamp sites, `ContinuousClock` at 22 elapsed-time sites.

**Numerical.** One inverse normal CDF (was three, one discontinuous) at 1.8e-15. One Box-Muller
(was ten, six different pole guards). One empirical quantile (was five, two different algorithms) —
`DriverProjection.percentile(0.10)` was returning the p5 value, 37% off. Exact `erf` in
BlackScholes. `OptimizationError` gained `dimensionMismatch` and `numericalInstability`.

**Correctness bugs found and fixed.** A MILP gate that accepted nonlinear objectives one run in a
thousand (measured 23/20,000). A Cox simulator with six defects, including a generic that
substituted `0.02` for the caller's hazard rate. A JSON export that terminated the process on a
NaN. A hazard curve integrated as though every period were a year.

---

## Open, and each is a decision rather than effort

- **`IntendedSurface.md`** (`project/plans/proposals/`) — API the documentation promises that does
  not exist. The one to read first: `BusinessMathError.circularDependency.recoverySuggestion` tells
  users to resolve cycles "using an iterative solver", two tests assert on that string, and no such
  type exists. Meanwhile `ModelDebugger.detectCircularDependencies` returns `[]` and
  `ModelInspector.detectCircularReferences` can only return `false`, while `1.6-DebuggingGuide`
  teaches both.
- **Seven `BusinessMathError` cases have no producer.** Most are wireable —
  `numericalInstability` is already detected in ~11 places and mislabelled every time.
- **`normalCDF` loses precision in the lower tail** — `(1 + erf(x/√2))/2` cancels; 2.2e-5 relative
  at p=1e-12 where `erfc(-x/√2)/2` gives ~1e-15. Left alone: it moves expectations across the suite.
- **`Period.<` compares granularity before start date**, so a `TimeSeries` mixing annual and
  quarterly points is stored out of chronological order. Pinned in a test, not fixed.
- **`TestQualityAuditor` has no warning-only state**, so the gate exits 1 at zero errors if any
  test-quality warning exists. One line, in quality-gate-swift.

---

## Tooling

`doc-code` ships in quality-gate-swift (`Sources/DocCodeAuditor`, 46 tests). **Opt-in**:

```sh
quality-gate --check doc-code
```

It needs the module built (unbuilt → `.skipped` with its reason) and reads the language mode from
the manifest. ~55s for 1,305 fences. Expect a first run on any documented project to produce a
lot — quality-gate-swift's own catalogue produces 76, mostly ✅/❌ contrast pairs needing
`<!-- docs:illustrative -->`.

Branch `docs/auditor-proposals` in quality-gate-swift carries it plus the `fp-equality`
unification, merged at `bd222f6`. **Local `main` (`f7a4e05`) and `origin/main` (`fe14122`) have
diverged** — the local line predates the newline-split remediation and fails the gate with 62
pre-existing errors. Anything new should branch from `origin/main`.

---

## Lessons that cost something

- **Fix collisions first, re-run, and only then read the type errors.** 40-90% of diagnostics are
  cascade, and errors that read as API drift are usually a shadowed variable.
- **A green auditor does not mean the references landed on the right object.** Renaming re-binds
  blocks that use a name without declaring it.
- **Labels are mechanical; *meanings* are not.** `shape:scale:` → `r:λ:` compiles and is wrong by
  9× because λ is a rate.
- **A property test only catches what its axes vary.** `E[τ] → 1/λ` passes on a simulator with six
  defects if you only test `Double` at σ=0.
- **Exercising a parameter is not testing it.** A tolerance assertion on a converging estimator
  passes whether or not the seed works.
- **Check under the same rules the build uses.** Weaker hides defects; stricter invents them. I did
  both today.
- **Verify a claim before relaying it.** Several of today's characterisations were wrong and got
  acted on.

---

## First action on resume

```sh
git -C . log --oneline -5          # expect efb89d3 at or near HEAD
/usr/local/custom/bin/quality-gate # target: 0 errors, 0 warnings
quality-gate --check doc-code      # target: 73/73
swift test                         # target: 6278+
```

Then decide on pushing — fifteen commits are unpushed, and `IntendedSurface.md` is waiting on you.
