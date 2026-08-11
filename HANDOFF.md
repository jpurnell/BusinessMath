# Handoff — 2026-08-11

**2.6.0 is written, verified, and deliberately unshipped.** The gate is clean, the suite is green
across repeated runs, and the tag is being held on purpose. Read the *why* below before tagging.

Nothing is pushed. Sixty-four commits on `main` (the release branch was fast-forwarded in), all
verified by direct runs rather than agent reports.

## State

| | |
|---|---|
| branch | `main`, clean, 64 commits ahead of `origin/main` |
| tag | **none** — deliberately. See "Why the tag is held" |
| tests | 6,520 in 567 suites, 0 known issues |
| build | 0 warnings, library **and** test target |
| quality gate | **0 errors, 0 warnings**, 36 checkers |
| documentation coverage | 100% — 6,471 of 6,471 public APIs |
| DocC catalogue | 73 articles, 1,310 fences, `doc-code` green |

**Run the gate with `--no-cache`.** A cached run executes **10 of 36 checkers** and prints an
identical summary line. Every figure above came from `--no-cache`; a plain `quality-gate` is not
evidence. This was the third instance of that shape found in one session — see also the build
checker that compiled only the library, and the diagnostic parser that never matched a coloured
line, both fixed in quality-gate-swift.

---

## Why the tag is held

2.6.0's code and documentation are done. The tag waits on four DocC checkers — `doc-comment-code`,
`doc-symbol-link`, `doc-generated`, and `doc-claims` (rung 3; `doc-run` is committed) — landing
**and clearing this codebase**.

The reasoning is empirical rather than cautious. Executing five articles by hand, which nothing in
the gate does, found four real defects that all pass `doc-code`:

- `1.2-TimeSeries` published `[100, 120, 115]` for a value that is `[0.1, 0.12, 0.115]`
- `3.10-BondValuationGuide` published `$1,043.30` for a bond that prices at `$1,043.76` — and the
  stale figure was exactly the *annual*-coupon price, so it came from a calculation ignoring
  `paymentFrequency`
- `4.2-ScenarioAnalysisGuide` trapped at runtime on a driver-name mismatch — inherited from
  `ScenarioRunner`'s own `///` comments, which `doc-code` does not audit
- `5.3-CoreOptimization` segfaulted at address zero, calling a closure declared 180 lines later

And `4.1`, the article the TrustPlan is written about, published a two-year growth figure computed
off the one-year array. Shipping before the checkers exist means shipping whatever else is in that
class.

While held, the CHANGELOG heading reads `[2.6.0] — unreleased` and the README advertises
`from: "2.5.2"`, which is what resolves today. Both revert at tag time. `release-readiness` passes
on that basis; it failed, correctly, while they claimed otherwise.

## What landed since

**Simplex.** Constraint rows now reach the tableau equilibrated, so a tolerance means the same thing
in a row of 10⁴ coefficients as in a row of 1; a BCC model at 200 units that reported `.unbounded`
now solves. Duals are divided back by their row factor on the way out — and, separately,
`SimplexResult.dualValues` had been negating every shadow price since it was written. Magnitudes
were always right, which is why nothing caught it: the only other test that touched duals checked
that each was finite.

**The lower tail.** `normalCDF` computed `(1 + erf(x/√2))/2`, which cancels: below about `x = −8.3`
it returned zero. It is now `erfc(-x/√2)/2` — an algebraic identity, not a different approximation —
and holds ~1e-14 relative down to `x = −37`. Two Black-Scholes known issues resolved with no
Black-Scholes code changed: 311 negative deep-OTM prices became none. The diagnosis recorded in the
test file had been wrong, and the clamp it proposed would have produced the right sign from the wrong
number.

**Integer division, six sites.** `T(Int(106) / 100)` evaluates to `1`. `zScore(fisherR:)` was
computing the Pearson standard error and every z-score was 2.956% too large; `correctedStdErr` had
three of them and its finite-population branch has never executed in any released version, with the
guarding comparison inverted on top; `standardErrorProbabilistic` returned exactly zero above its
threshold; `VectorN.random(in: 0...1)` returned the zero vector. The remaining eighteen occurrences
were checked individually and are sound.

**Distributions.** `poissonCDF` returned `P(X ≤ k−1)` at every integer argument — the error is
exactly `P(X = k)`, so a test grid that never landed on an integer saw nothing. `distributionPareto`
returned `+infinity` for a uniform of zero, through a pole guard that was dead code. Rayleigh's
`mean:` was always the scale σ, and now says so.

**One of each.** Five private R-7 quantile implementations became one public `quantile(sorted:p:)`,
and `DriverProjection.percentile` stopped snapping to the nearest of five stored summaries — it was
37% off at p = 0.10 and returned the median for both p = 0.40 and p = 0.60. No existing test had to
change, because every assertion touching it was an ordering check.

**Retraction and replacement.** The two circular-dependency detectors are deleted; neither could
detect anything, and `1.6-DebuggingGuide` taught both. In their place `ModelDefinition` holds
formulas rather than evaluated series, so a cycle is representable at all: Tarjan finds the
components, the classification into linear and nonlinear is decidable rather than heuristic, and
linear cycles are solved exactly by `(I − A)m = c` rather than iterated.

**Deletions and small repairs.** `chi2cdf` (which was `1 − pdf`), `pValueStudent` (a density) and
`pValue` are gone, with correct replacements already shipping. Template export never serialised the
identifier, so import fabricated one from the display name — a template exported as
`com.businessmath.templates.saas` came back as "SaaS Template". A marketplace template with no
buyers reported `NaN`. Two GPU tests were failing by chance and are seeded.

**The release documents.** `CHANGELOG.md`'s `[Unreleased]` is now `[2.6.0] - 2026-08-11`, opening
with a table of every result that moved and by how much, because this release changes numbers far
more than it changes signatures. `project/master_plan.md` was a generated stub asserting that
TestSupport did not exist and that there were no known issues; it is now real. `README.md` was
announcing version 2.0 against a v2.5.2 tag.

**Determinism, finished rather than started.** `SeedableDriver` closed the last unseeded randomness
the documentation could reach — `ProbabilisticDriver.sample(for:)` had no seed at all, so `4.1`
differed in 228 of 232 output lines between runs. It is a refinement protocol mirroring
`SeedableDistribution`, with a concrete generator because drivers are erased into `AnyDriver`, and
conditional conformance only where the type system can express it. `DeterministicDriver` conforms
deliberately: a fixed value is reproducibility in its strongest form, and excluding it would have
made the library's own `SumDriver(lhs: fixedCost, rhs: variableCost)` example permanently unseedable.

**A solver that returned nothing.** `BranchAndBoundSolver`'s elapsed check was unguarded, so
`timeLimit: 0` — documented as "no limit" — expired at the first node. `BranchAndCutSolver`
*defaults* to 0, so a default-constructed solver returned `success: false` with the objective at
infinity for every problem it was ever given. No test anywhere constructed one, which is why it
shipped. Found by auditing 13 tests that gate a correctness assertion on a wall clock; ten now bind
on `maxNodes`, and the margin table is the useful artefact — the one that flipped had 35× headroom
and everything else had 1,000× or more.

**Timing made deterministic.** `ModelProfiler` and `ModelDebugger` both took an injectable
`WallClock` for timestamps while constructing their own `ContinuousClock` for durations.
`ElapsedTimeSource` closes that; thirteen sleep-based profiler tests became exact, and the suite
went from 1.119s to 0.006s. Most assertions got *stronger*: the threshold test now checks which
operation was the bottleneck rather than how many. A new `benchmarkOnly` trait replaced `.localOnly`
on the one test whose result genuinely is a wall-clock number — `.localOnly` skips where `CI` is set
and runs on the machine that actually fails it, which is protection pointed the wrong way. It now
has zero call sites.

---

## Open, and each is a decision rather than effort

Three items from the previous handoff are closed and not repeated here: the `weak-assertion`
cluster (0 in the gate), the unseeded `MonteCarloSimulation` audit (all 22 remaining constructions
verified correct — 13 pass their seed to `runCorrelated`, the rest are custom-sampler tests the
seeded path rejects by design), and the CHANGELOG gap (29 commits that had no entry now do).

- **Push.** Sixty-four commits, none on `origin`. Everything else is easier to reason about once
  the branch is not the only copy. The tag is separate and held.
- **`doc-comment-code` does not exist**, and it is the one the proposal says to build first. The
  `///` corpus is 1,394 blocks against the catalogue's 1,310, and it is *upstream*:
  `ScenarioRunner`'s doc comments taught the force-unwrap that shipped as a runtime trap in `4.2`,
  and `RiskMetrics.swift:63` documents an initialiser that does not exist. Repairing the catalogue
  while Quick Help hands out the wrong signature guarantees the drift returns.
- **`BusinessMathDSL` offers no non-trapping parameter access.** `evaluate`, `statistics`, `best`,
  `worst` and `percentile` take non-throwing `(Scenario) -> Double` closures over a bare
  `[String: Double]`. Seven doc examples use `preconditionFailure` naming the key — a workaround,
  not a fix. Either make the closures throwing, as `ScenarioRunner.StatementBuilder` already is, or
  add the accessor `MonteCarloScenario` has at `AdvancedOptimization/Scenario.swift:73`.
- **Three timed correctness tests need splitting**, not a trait: `Performance_SummaryGeneration`
  (12× margin), `ModelValidation` (16×), `ModelInspectionOnLargeModel` (17×) — all tighter than the
  37× that went red under load, and each also asserts something real, so gating them on
  `RUN_BENCHMARKS` would delete coverage. `Performance_MemoryEfficiency` is the same
  name-versus-instrument defect at ~1100×.
- **`IntendedSurface.md`** — API the documentation promises that does not exist. Remaining:
  `FinancialModel`'s balance-sheet surface, `DataTable`'s fluent chain, structured logging.
- **Three `BusinessMathError` cases still have no producer** — `negativeValue` (E301), `outOfRange`
  (E302), `resourceExhausted` (E400). The first two belong with a consolidation of the four parallel
  validation vocabularies, not with a relabel.
- **`Period.<` compares granularity before start date**, so a `TimeSeries` mixing annual and
  quarterly points is stored out of chronological order. Pinned in a test, not fixed.
- **Two bugs in quality-gate-swift, found here, unfixed there.** `TestQualityAuditor` has no
  warning-only state, so the gate exits 1 at zero errors on any test-quality warning. And
  `release-readiness` reads a version out of any heading containing a number — "…accurate to
  ~1.5e-7" was reported as a missing `v1.5` tag. Worked around by moving the figure into the body.

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

The `///` doc-comment corpus is the gap: 1,394 fenced blocks, entirely unchecked, and *upstream* of
the catalogue — `RiskMetrics.swift` documents an initialiser that does not exist and article `4.3`
had the identical error because it was copied from Quick Help. `doc-comment-code` is the next
auditor, and it is a bigger corpus than the one already covered.

Branch `docs/auditor-proposals` in quality-gate-swift carries `doc-code` plus the `fp-equality`
unification; it is at `2573c36` today. **Local `main` (`f7a4e05`) and `origin/main` (`fe14122`) are
still diverged** — verified again today — and the local line predates the newline-split remediation,
so it fails the gate with 62 pre-existing errors. Anything new should branch from `origin/main`.

---

## Lessons that cost something

- **Fix collisions first, re-run, and only then read the type errors.** 40-90% of diagnostics are
  cascade, and errors that read as API drift are usually a shadowed variable.
- **A green auditor does not mean the references landed on the right object.** Renaming re-binds
  blocks that use a name without declaring it.
- **Labels are mechanical; *meanings* are not.** `shape:scale:` → `r:λ:` compiles and is wrong by
  9× because λ is a rate. Rayleigh's `mean:` compiled for years and was wrong by 25.2%.
- **A property test only catches what its axes vary.** `E[τ] → 1/λ` passes on a simulator with six
  defects if you only test `Double` at σ=0.
- **Exercising a parameter is not testing it.** A tolerance assertion on a converging estimator
  passes whether or not the seed works.
- **An ordering assertion is not a value assertion.** p5 < p50 < p95 held while p10 was 37% wrong,
  and nothing in the suite had ever asserted a percentile's value.
- **A test that documents a defect in a comment is a test that will keep it.** The `chi2cdf` test
  said in prose that the implementation was incorrect and then asserted only that the result was
  between 0 and 1.
- **Check under the same rules the build uses.** Weaker hides defects; stricter invents them.
- **Verify a claim before relaying it.** Several characterisations across these sessions were wrong
  and got acted on. The generated master plan's "7,818 tests" is the current example — it is a count
  of test-shaped declarations, not of tests.

---

## First action on resume

```sh
git -C . log --oneline -5                      # expect d83c938 at or near HEAD
git tag -l                                     # expect NO v2.6.0 — the tag is held
/usr/local/custom/bin/quality-gate --no-cache  # expect 0 errors, 0 warnings, 36 checkers
swift test                                     # expect 6,520 in 567 suites
```

`--no-cache` is not optional: a cached run executes 10 of 36 checkers and prints the same summary.

Then **push** — sixty-four commits exist only here.

**Do not tag** until `doc-comment-code`, `doc-symbol-link`, `doc-generated` and `doc-claims` have
landed *and* this codebase is clean under all four. When that holds, tagging is three steps:
revert the CHANGELOG heading to `### [2.6.0] - <date>`, restore `from: "2.6.0"` and "Current
release" in the README, then `git tag -a v2.6.0` and push tags. Both version strings are the only
things that change.
