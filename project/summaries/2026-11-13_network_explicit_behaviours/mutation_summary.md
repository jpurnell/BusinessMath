# Mutation check, step 4 (ADR-009)

83 hand-written mutants (`mutate.py`) over the changed code, run in an outside-the-repo lab (`make_lab.sh`, a SwiftPM package
holding copies of the Network sources and 307 tests, deleted afterwards). Each mutant is one textual edit; a mutant is killed if
any test fails or the run hangs.

| group | mutants | what they change |
|---|---|---|
| D | 9 | damping validation: each clause of the check, the payload, the order against the empty-graph shortcut, swallowing the throw |
| P | 22 | the PageRank loop and report: teleport, dangling spread, share, stop test, flag, counters, residual, defaults, delegation |
| K | 13 | `PageRankMetric`: version, defaults, each setting passed to the loop, each field reported |
| M | 9 | modularity validation: each clause, inverted tests, dropped and unsorted names, ordering against the edgeless shortcut |
| L | 9 | the unweighted Louvain margin: raw vs scaled, none, multiplied, magnitude, comparison, best-gain update, side |
| V | 15 | eigenvector refusal: threshold, zero-weight connectivity, search, count, payload, versions, lone node, ceiling |
| G | 6 | `GraphMeasureError` equality |

**Run 1** (`mutation_output_run1.txt`): 83 mutants, 76 killed, 7 survived. Every survivor classified:

- **D01** (`isFinite` dropped from the damping check): **equivalent.** `NaN >= 0` is false and `+infinity < 1` is false, so the
  remaining two comparisons already refuse both. The clause is kept because it says the intent; it cannot be killed.
- **L06** (`>` to `>=` in the move test): **equivalent in practice.** It differs only when a gain exceeds the best by exactly the
  margin to the last bit; a gain tie (difference zero) is below the margin either way, and the tie case is tested.
- **M09** (validation after the edgeless shortcut): **a bad mutant, not a survivor.** The edit only removed a comment line. It was
  rewritten to put the shortcut ahead of the validation, and is killed (`mutation_output_run2_M09.txt`, by the golden measure test).
- **K07, K08, K09, K10** (`PageRankMetric` ignoring its ceiling or tolerance, reporting a fixed tolerance or the raw ceiling):
  **real gaps.** The defaults were tested and the settings were not. Closed by a new test,
  `PageRankMetricVersion3Tests.settingsReachTheLoop` (5-pass ceiling, tolerance 1e-3, a ceiling of 0 floored to one pass, each against
  `Centrality.pageRank` with the same settings, bit for bit). Its red is the survivors themselves, recorded in run 1; the re-run
  (`mutation_output_run2_K.txt`, `mutation_output_run3_K09.txt` after one transient CodeSign build error under load) kills all four.

**Final:** 83 mutants, 81 killed, 2 equivalent (D01, L06), 0 unclassified.

Not covered by this check, by design: Linux; the diffusion and siting code; the pre-existing mutation audits of the other measures
(`project/summaries/2026-11-12_network_weighted_measures`), which this change did not touch.
