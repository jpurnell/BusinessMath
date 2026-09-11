# Plans — what is complete, what is open, what is in progress

**Last reconciled:** 2026-09-11 (later), after the Bessel family landed.

**Previously:** 2026-09-11, at `70d29b1e` (post `v3.0.0-alpha.3`).

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

**Distribution test suite review** — `proposals/REVIEW_distribution_tests.md`, September 2026,
covering 40 distribution/statistics test files and the 7 TestSupport files under them. It names
11 library defects, a TestSupport consolidation, and a per-file disposition for all 40.

**Its §2 library defects: 10 of 11 fixed**, in `a38f1c18`, `0ab3be8f`, `8933e6a5`, `c3134e5c`,
`e2fc963c` and `70d29b1e`. Two of its findings did not survive contact and the record should say
so: **#1** (the erfc `normalCDF`) was already fixed at `91ca7f03`, a month before the review —
only the test-side workaround was real; and **#9**'s conditional (combinatorics computed from
factorials) is false, since `maxFactorialInt` is 20 and both functions switch to the
multiplicative form above it.

| Still open | Status |
|---|---|
| **#11 Metalog feasibility** | Probed and confirmed: rejects ε = 1e-3 and 1e-6, **accepts ε = 1e-9 and 1e-12**. Any finite grid loses to a small enough ε; needs the analytic tail-slope check. The only research-shaped item left. |
| **§3.2 helper promotion** | Not started. Everything in phases 4–5 sits on it. |
| **§5 per-file dispositions / §6 phases 4–5** | Not started. A rewrite of ~20 test files onto the shared helpers — the bulk of the remaining work. |
| ~~§3.4 TestSupport module split~~ | **Deferred deliberately.** Speculative generality: the stated payoff is serving BioFeedbackKit and YahooFinanceKit, neither of which consumes it, and real sharing needs a published package rather than a target split. Revisit when a second consumer exists. |
| §4.9 checker changes | **Not ours.** The SwiftExcelFunctions session is doing these in `quality-gate` directly. It has already shipped `unasserted-optional-unwrap` and `skipped-test-inventory`. |

**Test-integrity sweep** — **63 guard sites** that reported passed while asserting nothing, in two
passes. The first found 41 by grepping `else { return }`; the second found 22 more via the new
AST-based checker, because they were written across three lines. A grep encodes an assumption
about formatting; a parser does not.

**Ten disabled tests remain**, three blocked on product defects in `Sources/`:

| Test | Blocked on |
|---|---|
| `AdditionalModelTests` ×2 — "Enable after adding validation" | Rate and capacity validation is absent |
| `MonteCarloGPUIntegrationTests:723` | GPU device returns wrong results on initial runs; the production path via `MonteCarloSimulation` is correct |

~~**Bessel — the next body of work, and unblocked.**~~ **COMPLETE 2026-09-11.** Steps 1–5 of
`proposals/excel-coverage/PROPOSAL_bessel_functions.md` §7 are on `main`; step 6, the
SwiftExcelFunctions binding, belongs to that session. Excel's engineering block now contains no
mathematics this package lacks. Still **3.1.0, not 3.0.0** (§8) — purely additive, blocks nothing.

§3.1's negative-`X` convention was settled 2026-09-11: parity, not absolute value, decided by
sign rather than tolerance.

Three things from the implementation that the plan did not anticipate, all recorded in the
proposal's new §11:

- **§5.3's recommended method has a hole.** Ascending series and Hankel asymptotic carry `ε·e^x`
  and `e^(−2x)`, which move in opposite directions; the best a single crossover achieves is
  ~1e-11 for Y, against §6.4's 1e-12, and for K there is no workable crossover at all. Y and K
  use Temme's series and Steed's continued fraction, which converge. §5.3's *principle* — no
  coefficient tables, thresholds from `T.ulpOfOne` — is what shipped.
- **SciPy cannot be the oracle for this family**, and every other fixture here comes from SciPy.
  Its own error reaches 3.6e-12 at large argument, so a SciPy fixture asserted at 1e-12 fails a
  correct implementation. The fixture is generated from mpmath — the only one that is.
- **Two entries in the proposal's own §10 reference table were wrong** (Y₂ and K₂ at x = 1.5),
  and §1 contradicted §10 on Y₂. Corrected in place; the three-term recurrence is what exposed it.

Validated at better than 1.8e-13 across 59,928 argument-order pairs, with a negative control on
every regression test.

**3.0.0 final** — docs-only, no technical blocker, whenever wanted.

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
