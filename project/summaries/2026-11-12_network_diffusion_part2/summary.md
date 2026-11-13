# Session summary 2026-11-12: diffusion and siting, part 2 (seed selection and stored-record conformances)

Branch `feature/network-diffusion-part2`, stacked on `integration/network-diffusion-values`. Source of truth:
SwiftGraphMetrics `main`, read only. Plan: `project/plans/upcoming/NetworkWeightedGraph.md`, ADR-006; part 1 record:
`../2026-11-12_network_diffusion_siting_core/`.

## Done

- `Network/Diffusion/SeedSelector.swift`: `SeedSelector` (`compute`, `computeAsync`, `sweep`), `SeedSweep`, `SweepPoint`,
  lazy greedy (CELF) only for models with `hasSubmodularTrials` (ADR-005). Ported with bodies unchanged.
- `Network/Metrics/Protocol/GraphMetric.swift`, `MetricDescriptor.swift`: **not in the base branch**, and `SeedSelector`
  conforms to the first and uses the second, so both were ported unchanged (no registry). If the weighted-measures stream
  also adds them there will be an add/add conflict on these two files; the contents are SGM's verbatim (tabs, `import
  BusinessMath` in the fences), so keeping either side is fine if it is the same text.
- `extension SiteAssignment: MetricValue` (kind `"site-assignment"`, Codable shape unchanged), `SiteProblem.init(demand: NodeScores ...)`.
- Doc links part 1 replaced with prose restored (`DiffusionModel` x3, `SiteProblem`).
- Tests (Diffusion/, Siting/): ported selector, sweep, lazy-greedy, `SeedSweep` Codable, oracle suites, benchmark (behind
  `RUN_BENCHMARKS`, the repo's trait; SGM used `SGM_BENCHMARK`), siting and weight-consumer halves; additions: golden
  seed-for-seed values, lazy soundness oracle, refresh-count (ADR-005) tests, brute-force guarantee, a reference for the
  lazy refresh work.
- Evidence: `red-green.md`, `mutation-check.md`, `mutation-output.txt`, `mutation-check.py`, golden script.

## Additions beyond the port

1. **Golden values** (`SeedSelectionGoldenTests`, `SiteAssignmentGoldenTests`, `GoldenSeedValues.swift`): computed by SGM
   main before porting, by `golden-script-main.swift.txt` (a scratch package outside both repos depending on SGM by path).
   48 selections (4 graphs x 3 models x 4 configs: picks, gain bits, total gain, spread mean and standard error of the
   chosen set, JSON, envelope), 10 sweeps (probability grid, weight-scaled and linear-threshold builders, 4 synthetic
   point sets: picks, frequencies, full Jaccard matrix, mean, `alwaysPicked`, JSON, envelope), descriptor JSON, 18
   `SiteAssignment` JSON texts (6 with envelopes), 5 `NodeScores` siting answers. All Doubles as bit patterns, JSON
   sorted keys, compared verbatim. Matched on the first green run.
2. **Lazy soundness and the gate** (`SeedSelectionGuaranteeTests`): 48 seeded graphs x 3 models x 4 budgets x 4 batches
   equal to a plain-greedy oracle exactly; an undeclared model runs exactly `trials x (n + sum (n - p))` trials; a declared
   one fewer; reference lazy rule for exact work at batches 1, 2, 3, 7.
3. **Guarantee** (`GreedyGuaranteeTests`): picks on 100 trials; greedy and the best of all k-subsets (k = 1..3, 9 nodes,
   six graphs, p 0.2 and 0.5) measured on 4,000 unseen trials; bar `greedy >= (1 - 1/e) * best - 4 * (seGreedy + seBest)`.
   The summed standard errors overstate the difference's (the means share trials), and the best of many subsets is biased
   up; both only widen the margin. A hub star at p = 1 shows the bar is not the whole story (greedy must be exact there).

## Not verified here

- Linux and Swift 6.2.1 (the CI toolchain): not run. Generic-arithmetic budget handled by inspection (typed lets, at most
  two or three operators per expression).
- Fixtures use `Double.random(in:using:)` over `SplitMix64` as in part 1; a standard-library change would move them
  (the goldens do not: their inputs are literals).
- `RUN_BENCHMARKS` benchmarks were not run.
