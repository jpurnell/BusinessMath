# The breaking set as a pre-release, and forty-one tests that could not fail

**2026-09-09 – 2026-09-10** · shipped **3.0.0-alpha.1** at `11920cfe`, **alpha.2** at
`ddbc8a4d`, **alpha.3** at `5902b0c8` · 7,631 tests / 680 suites at alpha.3 ·
quality-gate 45/45, 0 errors, 0 warnings, 1,241 files examined

Reconstructed on 2026-10-05 from the git history (`7069e5e1..5902b0c8`) and the CHANGELOG;
it is not a contemporaneous note.

Nineteen commits from the 2.18.0 release commit, four of them merges. Two alphas carried the
four changes that force a major, and the third changed no API at all. What the three have in
common is the thing worth carrying forward: **in each, something had been reporting success
without doing the work** — a determinism test that never reached the GPU, methods returning
`0` for quantities that are not zero, tests that passed by returning early, and a bond test
that shared its code's mistake.

---

## What shipped

| Release | Content |
|---|---|
| **alpha.1** | `optimizeDetailed` now `throws` on `DifferentialEvolution` and `ParticleSwarmOptimization`; `CLVDefinition.perpetuityDue` and `CLVError.definitionNeedsHistory`; seven template methods deprecated in favour of `lifetimeValue(...)`, `acquisitionMetrics(...)` and `retentionRate`; a parametric `customerLifetimeValue(marginPerPeriod:retention:definition:discountRate:horizon:)` |
| **alpha.2** | `sampleSize(ci:proportion:n:error:)` deleted, the fourth and last breaking item |
| **alpha.3** | No API change: the coupon-grid fix, `.requiresMetalGPU`, and the test sweep |

Test counts along the way, each from a commit message: 7,628 / 679 for the merged alpha.1,
7,626 / 679 after alpha.2 removed two tests with the function they exercised, 7,631 / 680 at
alpha.3.

The alphas are pre-releases on purpose. The README tells consumers `from: "2.7.0"`, which in
SPM is up-to-next-major, so a 2.19.0 would have upgraded every existing consumer into three
source-breaking changes on their next `swift package update`. SPM excludes pre-releases from
`from:` ranges. `5905b0f9` records this in `HANDOFF.md` so that a later session does not undo
it, along with the note that `3.0.0a` is not valid semver and SPM would ignore such a tag.

---

## What is worth carrying forward

### 1. Margin over churn is an annuity due, and naming it made the migration safe

The subscription industry's LTV is margin over churn. That is not `CLVDefinition.perpetuity`:
it differs by exactly one period's margin, for any retention and any discount rate, because
the ordinary perpetuity starts a period from now and the industry's counts the margin arriving
today. At 5% churn the two differ by 5%, small enough to look like rounding.

`153ebd04` added `perpetuityDue`, `m·(1 + d)/(1 + d − r)`, and built its tests on the exact
identity that due minus ordinary equals the margin. Without the new case, delegating the
templates to the library's CLV would have moved every LTV by one period's margin with nothing
saying so. With it, six of the seven deprecated methods return an identical number through
their replacement.

### 2. Every deprecated template method returned `0` for something that is not zero

`7efd4572` lists five cases: zero churn gave a lifetime value of zero, where the perpetuity
diverges; a missing acquisition cost gave a payback of zero months, the best score on that
scale; a zero acquisition cost gave an LTV:CAC of infinity, a live division by zero confirmed
by probe; a box sold at a loss gave zero months; churn above one gave a negative retention.
The replacements throw or return `nil`.

The seventh method renumbers because it was wrong. `SaaSModel.calculateCACPayback()` divided
by revenue where `SubscriptionBoxModel` divided by margin, so the same named quantity was
computed two ways in one library. Acquisition cost is recovered out of gross profit: 5 months
where the answer is 6.25 at an 80% margin.

### 3. The seeded determinism tests had been running on the CPU

2.6.0's interim had DE and PSO decline the GPU whenever a seed was set, because a
non-throwing `optimizeDetailed` could not refuse after a mid-flight failure. The existing
determinism tests asserted on `MetalDevice.shouldUseGPU(populationSize:)`, and a guard inside
the optimizer is invisible to that assertion, so they passed while never reaching a kernel.
`1cc64a4f` made both signatures throw, adopted `RNGWrapper.attemptGPU(seeded:_:)`, and added
assertions that a seeded configuration at the threshold actually engages the GPU.

The scope document had estimated 67 call sites for this change. The measured blast radius was
22 lines; the count had included four other optimizers with their own `optimizeDetailed`.
`294d7a53` struck the estimate through in `v3.0.0_SCOPE.md` rather than deleting it.

### 4. A coupon grid that moved with the machine's time zone

`CouponPeriod` and `ACCRINT`'s quasi-coupon walk stepped through the schedule with
`Calendar.current`. On Microsoft's own COUP* example that returned the right `COUPPCD` and a
`COUPNCD` one day early; `PRICE` was out by about 0.017 per 100 of face. Fixed in `e6e7bcf8`.

**It was invisible from inside this package.** `ExcelBondFunctionTests` built its dates with
`Calendar.current` as well, so the tests and the code agreed in every zone. It surfaced only
when SwiftExcelFunctions handed in the UTC midnights an Excel date serial decodes to.
`CouponPeriodCalendarTests` now pins the grid in UTC against the published example.

The rule was already written down, on a `private` declaration in `DayCountConvention.swift`
where no other file could reach it. It is now internal and named `gregorianUTC`, deliberately
not `cachedCalendar`, which `Period` arithmetic uses for a cached `Calendar.current`.

The mechanism as stated in this range — a UTC midnight decomposing to the previous day
"anywhere west of Greenwich" — did not survive. The CHANGELOG entry was rewritten after
alpha.3, in `d1f8eecb`, to say the offset was never the problem and a change of offset was.

### 5. Forty-one tests reported passed while asserting nothing

- **Thirty GPU tests** across five suites opened with a guard whose `else { return }` meant
  "no Metal here", which Swift Testing reports as passed. `c81ab004` added
  `.requiresMetalGPU` to `ConditionTraits`, conditioned on device and runtime shader
  compiler: no `MTLDevice` should skip, while an MSL compiler rejecting our source is a
  defect and must fail. Every guard became `try #require`.
- **Eleven tests** across six suites returned early from an unmet precondition (`2ec309a1`).
  Six asserted nothing beforehand: an empty fixture passed two determinism tests without
  loading a case, and a zero mean-square deleted the check that `F_between` divides by
  `MS_subgroups`.
- **Eight of eighteen disabled tests** were re-enabled (`dbfb6357`). Two `PeriodTests` were
  disabled because precondition failures could not be caught; Swift Testing has since gained
  exit tests, and both now pass as `#expect(processExitsWith: .failure)`. What stood in for
  them was two `withKnownIssue` blocks wrapping calls that never executed, closed by an
  `#expect(true)` added to satisfy a checker. Six benchmarks moved from `.disabled()` to the
  existing `.benchmarkOnly` and pass under `RUN_BENCHMARKS=1`.

---

## Process

**A reason for dropping tests was wrong, and the next commit said so.** `7efd4572` omitted
tests of the deprecated methods on the grounds that the gate requires zero warnings.
`36466464` restored them: the gate does not inspect compiler deprecation warnings, and CI
builds without `-warnings-as-errors`. A deprecated `LegacyTemplateEconomics` type reads all
seven methods once, so the surface costs one build warning at one line. The same commit
corrects `7efd4572`'s count of six deprecated methods to seven.

**Verify by negative control, not by the green run.** With the Metal probe forced to `false`
the GPU tests report `skipped` in 0.001s, against 0.499s when they execute. A probe stuck at
`false` would also have printed green.

**Test the combination that ships.** Neither feature branch had been tested with the other
until the merge. Each was green alone; alpha.1 was built, tested and gated as a combination.

**A finding can outlive the function.** `correctedSizingExceedsTheLegacyFactor` still asserts
the 4.07× correction, with `384.145735` recorded as a constant now that `sampleSize` is gone.

**Traps recorded in the handoff** (`5905b0f9`): a gate run from inside `.claude/worktrees`
examines zero files and prints PASSED; doc-run timeouts are load artefacts; a `git mv` stages
two index entries, so a pathspec naming only the new path leaves a deletion staged.

---

## Not done

- Ten disabled tests remain. Three are blocked on product defects in `Sources/` and were
  filed, not fixed.
- Whether to drop the pre-release suffix was left as the one open decision.
- `proposals/REVIEW_distribution_tests.md`, committed with alpha.3, names 11 library defects
  and a disposition for 40 test files, and is described there as the next body of work.
- `PROPOSAL_bessel_functions.md` (`5b6b4447`) is a design only. It is blocked on measuring
  Excel's behaviour for negative X in `BESSELJ` and `BESSELI`, and argues for 3.1.0.
