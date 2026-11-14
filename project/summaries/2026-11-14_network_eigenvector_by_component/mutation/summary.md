# Mutation audit of the by-component eigenvector code (ADR-010)

Outside-repo scratch package (`make_lab.sh <worktree> <lab>`: the Network sources copied into a small SwiftPM target, so a mutant rebuilds in seconds; the suites are
the by-component tests, the parity tests and goldens, `MetricRegistryTests`, `MetricRecordGoldenTests`, `RegistryListingGoldenTests`). Script `mutate.py`:
81 hand-written mutants, one exact textual edit each over `EigenvectorByComponent.swift` (E01 to E60), `ComponentwiseScores.swift` (V01 to V10),
`ComponentwiseEigenvectorMetric.swift` (M01 to M08) and the registration in `MetricRegistry.swift` (R01 to R03). Output: `mutants-run1.out` (first run),
`mutants-run2.out` (after the survivors below were closed and one expression refactored), `mutants-run3-E56.out` (the last closing test), `mutants-final.out` (the final run, on the committed code, after the function was split for the gate: 74 killed by assertion, E51 and E54 killed by a crash, E31 E57 E59 E60 R03 survive; identical to run 2 plus E56 closed).
The baseline (unmutated) passes in every run. A hung or crashed run counts as detected; a build error would not count (none remained).

## Result

81 mutants: **74 killed by a failing assertion, 2 killed by a crash of the test process (E51, E54), 5 survive and are equivalent**, classified below. 0 invalid after V04 was fixed
(its first form did not compile, because it renamed a case used elsewhere; it now changes the raw value only). No timeouts.

## First run: 12 survivors, closed or classified

The first run (against the tests as first green) left 12. A survivor is a red: a behaviour the tests did not pin. Closed by a test written against the unchanged implementation:

| Survivor | What it showed was unpinned | Closing test |
|---|---|---|
| E24 shared-scale fallback `?? 1` to `?? 0` | a dead default (only read when the set it guards is non-empty) | removed by a refactor (`smallest` is now optional); the new E24 (drop the `rms > 0` guard) is killed |
| E26 scale guard accepts a zero rms | a component whose iteration returned zeros (weights of 1e200) was never tested; the mutant gives NaN scores | `hugeComponentBesidePlain`, `onlyHugeComponents` |
| E27 zero-rms component scale 1 to 0 | same: the stored scale of such a component | same |
| E37 worst-case `converged` judged by the first component | the slow component was always first in the tests | `slowComponentInTheMiddle` (E38, the last component, was already dead) |
| E46, E48 the component / whole iteration ignores the tolerance | tests passed a tolerance but only looked at the reported value | `componentTolerance`, `wholeGraphTolerance` (a looser tolerance stops earlier, exactly where `eigenvector` stops) |
| E56 the subgraph emits every tie twice | looked equivalent (doubling is exact in binary); it is not at the top of the range: the doubled total overflows and `WeightedGraph` refuses a valid graph | `acceptedGraphIsAnswered` (weight 8e307) |

## Survivors in the final run (equivalent; no test can distinguish them)

- **E31** `run.scores[$0] ?? 0` to `?? 1`: `sub.nodes` are the keys of `run.scores` by construction, so the default is never read.
- **E57** emitting each tie from the higher end instead of the lower: the same undirected graph; `WeightedGraph` merges both directions, and the edge order does not enter any sum that matters.
- **E59** `Double(max(1, values.count))` to `Double(values.count)`: a scored component has at least two nodes.
- **E60** `iterations ... ?? 0` to `?? 1`: `parts` is non-empty here (the trivial branch returned earlier), so the default is never read. The residual's `?? 0` is the same.
- **R03** registering the metric twice: the registry keeps the first of two metrics with one identifier (tested by `firstWins`), so the listing and the output are unchanged.

## A claim of ClassGraph's that does not hold

ClassGraph's mutation notes (`project/summaries/2026-11-14_businessmath_cutover/mutation/summary.md`, cw22 and cw24) call `.min() ?? 1` and `part.rms > 0` "unreachable without changing BusinessMath". They are reachable: for weights of about 1e154 and above
`eigenvectorConvergence` returns all zeros (reported converged), so a component's rms is 0 (measured with ClassGraph's own code: a path and a pair of weight 1e200 score all zeros, scale 1). The guard is the only thing keeping that from being NaN scores (E26).
See ADR-010 and the proposal, section 16.

## Not covered

Mutants over the documentation, the descriptor's prose beyond the strings pinned by the parity test, and `ComponentScoring`/`ComponentwiseScores` initialisers beyond V09 and V10.
