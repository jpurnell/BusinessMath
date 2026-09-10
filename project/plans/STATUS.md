# Plans — what is complete, what is open, what is in progress

**Last reconciled:** 2026-09-10, at `v3.0.0-alpha.3`.

Every "complete" line below was checked against `Sources/` rather than taken from the plan's
own status line, because several status lines were months stale. Where a claim rests on
inference rather than a file, it says so.

---

## In progress

Nothing. No branch carries unmerged work.

~~**Stage 6 of the marketing leg** — parked on `feature/stage-6-template-delegation`
(`6c3e1bd6`), waiting for 3.0.0 to merge.~~ **Merged at `2f1e92ed` and shipped in
`v3.0.0-alpha.1`.** This section said "what remains is a merge" for a day after the merge
happened, while the table below recorded it correctly — worth noting because the two halves
of one file disagreed and only the summary was wrong. A reader who stopped at the top would
have gone looking for a branch that was already gone.

### Open, and new since this file was last reconciled

**Distribution test suite review** — `proposals/REVIEW_distribution_tests.md`, September
2026, covering 40 distribution/statistics test files and the 7 TestSupport files under them.
It names 11 library defects, a TestSupport consolidation, and a per-file disposition for all
40. Its own order of work is: library defects, then TestSupport, then the tests that are
wrong, then rebuilding the statistical generation on the shared helpers. Not started.

**Test-integrity sweep** — landed in `v3.0.0-alpha.3`: 41 tests that reported passed without
asserting anything, and 8 of 18 disabled tests. **Ten disabled tests remain**, three of them
blocked on product defects in `Sources/`:

| Test | Blocked on |
|---|---|
| `AdditionalModelTests` ×2 — "Enable after adding validation" | Rate and capacity validation is absent |
| `MonteCarloGPUIntegrationTests:723` | GPU device returns wrong results on initial runs; production path via `MonteCarloSimulation` is correct |

---

## Open, and genuinely so

### ~~The items that force 3.0.0~~ — all shipped

| Item | Shipped in |
|---|---|
| `optimizeDetailed` → `throws` on DE and PSO | `v3.0.0-alpha.1` |
| `CLVDefinition.perpetuityDue` + parametric CLV | `v3.0.0-alpha.1` |
| `SaaSModel`/`SubscriptionBox` LTV delegation | `v3.0.0-alpha.1` |
| Delete `sampleSize` | `v3.0.0-alpha.2` |

**3.0.0 final is this code with the pre-release suffix dropped**, once the alpha has been
exercised. Both feature branches are fully merged into `main` (0 commits ahead) and can be
deleted.

### Optimization — six algorithms, audited and real

`proposals/PROPOSAL_advanced_optimization_gap.md`, verified 2026-09-07. SQP, Interior Point,
GRG, Network Flow, Convexity Detection, ADMM. Per-algorithm plans in `upcoming/optimizations/`,
whose `Status: Not Started` lines are **unreliable** — MINLP is substantially done and Interior
Point was written and deliberately removed, both recorded in §2.2 and §3.1 of the proposal
rather than in the plan files.

§10.5 records the constraint penalty weight, **now closed** as of 2.17.0 for the
"parameterise it" branch. Adapting the weight across restarts is still open.

### Excel coverage — see the dedicated section below

### Statistics proposals, drafted and not scheduled

`PROPOSAL_advanced_reliability`, `PROPOSAL_agreement_statistics`,
`PROPOSAL_repeated_measures_agreement`, `PROPOSAL_weighted_agreement`. Each is `Status: Draft`
and none has an implementation in `Sources/`. Krippendorff's alpha and Cohen's kappa are
absent; Weibull reliability is absent as a reliability model, though `distributionBurr.swift`
mentions the name.

### Platform and business

`ShopifyAnalyticsPlatform.md` (ACTIVE, June 2026 MVP), `v3.0-DualLicensing.md`,
`OperationsModule.md` (approved, in progress — `Operations/EOQModel.swift` exists so this is
partially built), `IntendedSurface.md` (triage), `TypedModelAuthoring.md` (phases 1–2d scoped
as 2.8.0; `PeriodDriver` exists, so partially built).

### Deferred by decision

`upcoming/gpuBufferCachingPlan.md` — explicitly "correctness fixes first".
`upcoming/v2.1.5_DocsAndPlaygroundsCleanup.md` — draft, held.
`upcoming/PSD_NORMALIZATION_PLAN.md` — claims a live branch `feature/psd-normalization`. The
branch exists on the remote and is **empty**: zero commits ahead of `main`, 488 behind, last
touched 2026-04-07. No PSD normalisation is in `Sources/`. So the plan is not started, the
branch is a dead stub, and "feature branch active" has been wrong for five months. **Worth
deleting the branch** so the next reader is not misled the way this reconciliation was — I
checked local branches first, found nothing, and nearly recorded "no such branch" as the
finding.

---

## Complete — moved to `completed/` in this reconciliation

| Plan | Evidence |
|---|---|
| `MarketingLeg.md` | Stages 0–6. Stage 5 shipped in 2.17.0; stage 6 is on its branch |
| `NetworkAnalysis.md` | `Network/Graph.swift` and the traversal, centrality, community and Markov suites, shipped 2.16.0 |
| `PROPOSAL_distribution_contract_and_sampling.md` | `Simulation/ContinuousDistribution.swift`, `Sampling/LatinHypercubeSampler.swift`, `HaltonSequence.swift`, `SobolSequence.swift` |
| `PROPOSAL_psi_completeness.md` + `psi_upstream_gaps.*` | 57 rows: **52 landed, 5 excluded**. Complete at 2.15.0 |
| `PROPOSAL_forecast_evaluation_diagnostics.md` | `Forecasting/Evaluation/BacktestReport.swift` and the backtest tier, shipped 2.5.0 |
| `SWIFT_6_CONCURRENCY_MIGRATION.md` | Its own status line: completed February 2026 |
| `MultipleLinearRegression.md` | `Statistics/Regression/MultipleLinearRegression.swift` |
| `INTERPOLATION_PLAN.md` | `Interpolation/BarycentricLagrange.swift` and siblings |
| `onlineAnomalyDetectionPlan.md` | `Streaming/StreamingAnomalyDetection.swift` |
| `CircularDependencyDetection.md` | `Model Definition/DependencyReport.swift`, and the SCC lift into `Network/` |
| `IterativeSolver.md` | `Model Definition/IterativeCycleSolver.swift` |
| `RobustScenarioGeneration.md` | `AdvancedOptimization/RobustOptimizer.swift` |
| `DSLExpressiveness.md` | Superseded same-day by `TypedModelAuthoring.md`; kept as a record |

---

## Excel coverage, which had no single account until now

Three files tracked three different things and none of them said so.

### What is complete

**The Psi distribution surface.** `completed/excel-coverage/psi_upstream_gaps.tsv` — 57 rows,
**52 landed, 5 excluded**. The five are excluded because they are not mathematics: `PsiSip`,
`PsiSlurp`, `PsiTSSip`, `PsiCertified` and `PsiVary` resolve stored data or declare a solver
role, which is a spreadsheet host's job. Closed at **2.15.0**.

**The distributions and samplers in the original 49-row work list.** Checked by Swift type
name, not by substring: `DistributionCauchy`, `Laplace`, `Levy`, `Erlang`, `Frechet`,
`JohnsonSB`, `Kumaraswamy`, `Metalog`, `Myerson`, `Burr12`, `Dagum`, `HypSecant`, `Pearson5`,
`MVLogNormal` and the rest are all present, as are `LatinHypercubeSampler`, `HaltonSequence`
and `SobolSequence`.

### What is open

| Item | Count | Note |
|---|---|---|
| ~~Excel financial functions~~ | 0 | **All eight are implemented.** Checked one by one, 2026-09-09 — see the table below |
| `ImportanceSampling` | 1 | Genuinely absent. The only row of 49 that is |
| Compatibility and lookup bucket | — | `proposals/excel-coverage/PROPOSAL_compatibility_and_lookup.md`, planned 2026-09-08, not started. `XLOOKUP` absent |
| ETS fitting | — | `proposals/excel-coverage/PROPOSAL_ets_fitting.md`, reviewed. Real gap is a parameter search and SMAPE; **five of Excel's eight `STAT` types are already answerable** |
| Complex notation | — | `proposals/PROPOSAL_complex_notation.md`. Nothing in the corpus calls it |
| ~~`thirty360_february`~~ | — | **Both halves done, moved to `completed/`.** The defect: `DayCountConvention.swift:34` builds a gregorian calendar at GMT rather than reading `Calendar.current`, with the reasoning in a doc comment above it. The gap: `thirty360` (Excel's answer), `siaThirty360` (the standard) and `thirty360European` all ship, recorded in CHANGELOG |

### The eight Excel financial functions all exist, under Swift names

| Excel | BusinessMath | Location |
|---|---|---|
| `RATE` | `periodicRate` | `Time Series/TVM/SolvingTheAnnuity.swift` |
| `NPER` | `numberOfPeriods` | `SolvingTheAnnuity.swift:86` |
| `PDURATION` | `periodsToGrow(rate:presentValue:futureValue:)` | `SolvingTheAnnuity.swift:262` |
| `NOMINAL` | `nominalRate(effectiveRate:periodsPerYear:)` | `SolvingTheAnnuity.swift:306` |
| `SLN` | `straightLineDepreciation(cost:salvage:life:)` | `Time Series/TVM/Depreciation.swift:40` |
| `SYD` | `sumOfYearsDigitsDepreciation(cost:salvage:life:period:)` | `Depreciation.swift:72` |
| `DDB` | `decliningBalanceDepreciation` | `Depreciation.swift:127` |
| `VDB` | `variableDecliningBalanceDepreciation` | `Depreciation.swift:205` |
| `ACCRINT` | `accruedInterest` | `Valuation/AccruedInterest.swift:58` |

**Nothing needed implementing.** The work list said `absent` because it was generated by
matching *Excel's* names against the tree, and this library names functions for what they
compute rather than for Excel's abbreviation. A name-matched audit reports a complete library
as missing. Statuses corrected in place, each row naming its function and file.

### `businessmath_work.tsv` was stale, and is now reconciled

It was last updated **2026-09-04** and marked 45 of its 49 rows `absent`. Reconciled
2026-09-09 by checking each row against `Sources/` by Swift type name: **45 present, 3
maths-no-sampler, 1 genuinely absent** (`ImportanceSampling`). Every re-statused row now names
the function and file that satisfies it.

It shares **zero rows** with `psi_upstream_gaps.tsv` — two different scopes, not two versions
of one list, and nothing said so until now.

Regenerating it from the corpus is still a documented one-liner, and would refresh the demand
columns rather than the statuses:

```
BUSINESSMATHEXCEL_CORPUS="<roots>" swift test --filter testWhichFunctionsTheCorpusCalls
```

### And a warning about its demand column

See `proposals/excel-coverage/README.md`. The column labelled `books` counts **sheets**, the
sweep covered **79 workbooks**, and a `0 / 0` row means "absent from every formula on every
sheet of those 79" — one sample, not a ranking signal across 726 rows.
