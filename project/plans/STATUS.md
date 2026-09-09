# Plans — what is complete, what is open, what is in progress

**Last reconciled:** 2026-09-09, at `v2.17.0`.

Every "complete" line below was checked against `Sources/` rather than taken from the plan's
own status line, because several status lines were months stale. Where a claim rests on
inference rather than a file, it says so.

---

## In progress

| | |
|---|---|
| **Stage 6 of the marketing leg** | Written, tested, gate-clean, parked on `feature/stage-6-template-delegation` (`6c3e1bd6`). Breaking, so it waits for 3.0.0. Development is done; what remains is a merge. |

Nothing else is mid-flight. No branch other than that one carries unmerged work.

---

## Open, and genuinely so

### The three items that force 3.0.0

| Item | Where | State |
|---|---|---|
| `optimizeDetailed` → `throws` | `proposals/GPUAttemptSeedContract.md` §4 | Decided, not built. **See the note below — the defect it fixes is already mitigated.** |
| Delete `sampleSize` | `completed/v2.7.0_SCOPE.md` | Deprecated in 2.7.0, deletion waits |
| `SaaSModel`/`SubscriptionBox` LTV delegation | `completed/marketing/MarketingLeg.md` §3.3 | **Built**, on the branch above |

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
| Excel financial functions | 8 | `RATE`, `NPER`, `PDURATION`, `NOMINAL`, `DDB`, `SYD`, `VDB`, `ACCRINT`. `Time Series/TVM/Depreciation.swift`, `SolvingTheAnnuity.swift` and `Valuation/AccruedInterest.swift` exist, so **some may already be implemented under Swift names** — this needs a per-function check, not a grep |
| `ImportanceSampling` | 1 | Absent |
| Compatibility and lookup bucket | — | `proposals/excel-coverage/PROPOSAL_compatibility_and_lookup.md`, planned 2026-09-08, not started. `XLOOKUP` absent |
| ETS fitting | — | `proposals/excel-coverage/PROPOSAL_ets_fitting.md`, reviewed. Real gap is a parameter search and SMAPE; **five of Excel's eight `STAT` types are already answerable** |
| Complex notation | — | `proposals/PROPOSAL_complex_notation.md`. Nothing in the corpus calls it |
| `thirty360_february` | — | `siaThirty360` is shipped (`Valuation/DayCountConvention.swift:122`, `AccruedInterest.swift:162`). The proposal covers two things kept deliberately apart, so **one half is done**; check the other before moving it |

### `businessmath_work.tsv` is stale and should not be read as current

Last updated **2026-09-04**, before the Psi push closed on 2026-09-08. It marks 45 of its 49
rows `absent`; most of the distribution rows are in fact implemented. It shares **zero rows**
with `psi_upstream_gaps.tsv` — they are two different scopes, not two versions of one list, and
nothing said so.

**Before it is trusted again it needs regenerating**, which is a documented one-liner:

```
BUSINESSMATHEXCEL_CORPUS="<roots>" swift test --filter testWhichFunctionsTheCorpusCalls
```

### And a warning about its demand column

See `proposals/excel-coverage/README.md`. The column labelled `books` counts **sheets**, the
sweep covered **79 workbooks**, and a `0 / 0` row means "absent from every formula on every
sheet of those 79" — one sample, not a ranking signal across 726 rows.
