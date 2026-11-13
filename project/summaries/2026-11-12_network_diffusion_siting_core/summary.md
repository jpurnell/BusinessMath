# Session summary 2026-11-12: diffusion and siting core (step 3, part 1)

Branch `feature/network-diffusion-siting`, stacked on `integration/network-base` (PR #14 fixes, PR #15 `WeightedGraph`).
Plan: `project/plans/upcoming/NetworkWeightedGraph.md` (sections 3, 6, 8, 10, 11; open question 15.3), ADR-006.
Source of truth: SwiftGraphMetrics `main`, read only.

## Done

- `Network/Diffusion/`: `DiffusionError`, `DiffusionGraph`, `DiffusionModel` (protocol, `hasSubmodularTrials`, generator
  overload, `EdgeProbability`, `IndependentCascade`, `LinearThreshold`), `TrialRandomness`, `SpreadEstimate`,
  `SpreadEstimator`. Names, numerics, tie-breaking, stream derivation and every draw are unchanged;
  `SplitMix64` comes from SwiftDeterminism through the existing re-export.
- `Network/Siting/`: `SiteProblem`, `SiteError`, `SiteSelector`, `PMedian`, `SiteAssignment`.
- Tests in `Tests/BusinessMathTests/Network Tests/Diffusion/` and `.../Siting/`: the ported suites (95 tests in 17 suites,
  including the per-trial oracles, closed forms, `TrialRandomness` golden master, exhaustive and brute-force
  p-median oracles), plus two additions below.
- Evidence: `red-green.md`, `mutation-check.md`, `mutation-output.txt`, `mutation-check.py`, and the scratch script that
  produced the golden values (`golden-script-*.txt`).

## Additions beyond the port

1. **Seed-for-seed golden test** (`DiffusionGoldenTests`, `PMedianGoldenTests`, `GoldenSGMValues.swift`). Computed by
   SwiftGraphMetrics `main` before any porting, with a scratch package under `/private/tmp/claude-501/sgm-golden`
   that depends on it by path: 96 `TrialRandomness` draws, 168 per-trial outcomes (count and exact activated set; the
   set is derived from SGM counts alone, as "valid seed, or adding it as a seed changes nothing"), 63 `SpreadEstimate`s,
   18 generator-overload counts, the compressed-row form of a weighted graph, and 18 p-median answers on 3 instances
   (exact and heuristic). Every `Double` is stored as its bit pattern and compared with `bitPattern ==`. All reproduced
   exactly on the first green run.
2. **Integer-programming oracle for `PMedian`** (`PMedianIntegerProgramOracleTests`). The p-median written as a
   mixed-integer program (binary `y[j]`, continuous `x[d][j]`, 104 variables at 8 sites x 12 demands) and solved with
   `BranchAndBoundSolver` and its simplex relaxation. Four seeded instances (6x8, 7x10, 8x12, 8x9), p = 1, 2, 3.
   Asserts: the program agrees with an enumeration written in the test file (so the oracle is trusted); `PMedian`'s
   exact optimum equals the program's within a relative 1e-6 and chooses the same sites; the heuristic is never below
   the program and reaches it on all but at most one instance. Tolerance reasoning is in the test header: the solver
   recovers the objective numerically (finite differences) and stops inside a relative gap of 1e-9. All 12 solves were
   reported `.optimal`; the suite takes a few seconds. The solver's API expressed the problem without difficulty.

## Left for part 2, and why

- `SeedSelector`, `SeedSweep`, `SweepPoint` (and `computeAsync`): they return `NodeSelection`, a `MetricValue`, and
  conform to `GraphMetric`. The doc comments here mention the seed selector in words, with no symbol link, because
  the symbol does not exist yet; restore the links with it.
- `SiteProblem.init(demand: NodeScores<Demand>, ...)`: `NodeScores` is a value type owned by the other worktree.
- `SiteAssignment` is ported as a plain `Sendable, Codable, Hashable` struct, **without** its `MetricValue`
  conformance and its `kind` (`"site-assignment"`). `PMedian` and `SiteSelector` return it, so the struct could not
  wait; part 2 adds `extension SiteAssignment: MetricValue { public static var kind: String { "site-assignment" } }`.
  The synthesised `Codable` shape is the same as SwiftGraphMetrics', so stored records are unaffected.
- Tests needing those: `SeedSelectorTests`, `SeedSweepTests`, the seed-selection and sweep oracle suites,
  `SiteSelection` envelope round trips (`codable`, the `MetricEnvelope` half of `roundTrip`), the `NodeScores` demand
  tests, `selectionFinite` and the registry half of `WeightConsumerTests`, the benchmark suite. `sitingFinite` was
  ported with the weighted degree (`WeightedGraph.degree(of:)`) in place of `Centrality.degree(...).scores`.

## Not verified here

- Linux and Swift 6.2.1 (the CI toolchain): not run. Local is Swift 6.4 on macOS arm64. The generic-arithmetic
  budget was handled by inspection only (six `#expect` expressions split; local `let`s typed `Double`).
- `Double.random(in:using:)` over `SplitMix64` builds several seeded fixtures (random graphs and p-median instances,
  as in SwiftGraphMetrics). A change in the standard library's algorithm between toolchains would change those
  fixtures, and the measured bars on them (greedy-versus-optimum counts, the 80% Teitz-Bart bar) were taken on 6.4.
  The golden values do not use it: their inputs are stored as literals.
- The mutation lab uses a local SwiftDeterminism checkout (v1.3.0 + 2 commits); the package resolves a published
  `from: "1.2.0"`. The golden draws pass in both.
