# Handoff — 2026-08-11

**The gate is clean bar one warning, the suite is green twice running, and the release
documentation now says what the code does. 2.6.0 is ready to cut.**

Nothing is pushed. Forty-five commits on `fix/simplex-scale-relative-feasibility`, all verified by
direct runs rather than agent reports. The working tree is clean except for this file and the three
release documents.

---

## State

| | |
|---|---|
| tests | 6,494 in 565 suites, 0 known issues — two consecutive clean runs |
| build | 0 warnings, library and test target |
| DocC articles | 73/73 compiling as one program |
| documentation coverage | 100% — 6,447 of 6,447 public APIs |
| quality gate | **0 errors, 1 warning** — a `weak-assertion` consistency cluster, 137 occurrences |

The previous handoff left the gate at 54 errors / 10 warnings, all of them the `fp-equality` class
the redeployed gate had just made visible. Those are closed: 92 floating-point comparisons in the
suite and 3 more in `TestSupport` now name the claim each one is making — bitwise, ulp, absolute or
relative — rather than asserting `==` on two computed `Double`s and reporting `NaN != NaN` as a pass.

It also flagged uncommitted simplex work and predicted 6,488 in 565 suites once it landed. That work
is committed — `753f79b` for the equilibration, `175db71` for the dual sign that came out of writing
its tests — and the measured figure is 6,494 in 565.

---

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

---

## Open, and each is a decision rather than effort

- **Push, and tag.** Forty-five commits, none of them on `origin`. This is the first item because
  everything else is easier to reason about once the branch is not the only copy.
- **The CHANGELOG does not cover the whole branch.** Roughly half the 45 commits have an entry. The
  numerically significant ones do, and five were written today to close that gap, but the seeding
  work, the clock injection, the GPU RNG, the period stubs and the export fixes have no entry. Decide
  whether 2.6.0 ships with a partial history or someone writes the rest.
- **`weak-assertion`, 137 occurrences** — the one gate warning. Treat it as a defect class, not
  hygiene: it is the same shape as the ordering-only assertions that let a 37% percentile error
  through, and as the tests that survived `chi2cdf` being one minus a PDF.
- **34 unseeded `MonteCarloSimulation` constructions** in the suite, unaudited. An assertion over an
  unseeded run either fails intermittently or asserts nothing; two of this class were caught by
  accident. An audit is running.
- **`IntendedSurface.md`** (`project/plans/proposals/`) — API the documentation promises that does
  not exist. Reduced since the last handoff: `3.15`'s ingestion subsystem is rewritten,
  `Period.custom` shipped, and the `circularDependency` recovery suggestion no longer names a solver
  that was never built. Remaining: `FinancialModel`'s balance-sheet surface, `DataTable`'s fluent
  chain, structured logging.
- **Three `BusinessMathError` cases still have no producer** — `negativeValue` (E301), `outOfRange`
  (E302), `resourceExhausted` (E400). The first two belong with a consolidation of the four parallel
  validation vocabularies, not with a relabel.
- **`Period.<` compares granularity before start date**, so a `TimeSeries` mixing annual and
  quarterly points is stored out of chronological order. Pinned in a test, not fixed.
- **`TestQualityAuditor` has no warning-only state**, so the gate exits 1 at zero errors if any
  test-quality warning exists. One line, in quality-gate-swift — and it is what the 137 above will
  run into.
- **README quoted the wrong platform minimums, in the direction that hurts.** It claimed iOS 14 /
  macOS 13 / tvOS 14 / watchOS 7 while `Package.swift` declares iOS 17 / macOS 14 / tvOS 17 /
  watchOS 10 / visionOS 1 — so a reader on iOS 15 was told they were supported and would have hit
  a resolution failure. Corrected to the declared floors. Worth noting the manifest was right the
  whole time and only the prose was wrong, which is the failure mode a doc auditor cannot see.

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
git -C . log --oneline -5          # expect da932ec at or near HEAD
/usr/local/custom/bin/quality-gate # expect 0 errors, 1 warning (weak-assertion ×137)
quality-gate --check doc-code      # expect 73/73
swift test                         # expect 6,494 in 565 suites
```

Then push, decide whether the CHANGELOG ships partial, and tag `v2.6.0`.
