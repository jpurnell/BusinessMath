# Red then green: silent behaviours made explicit (step 4)

Branch `feature/network-explicit-behaviours`, off `origin/main` `799e4a5c` (steps 0 to 3). Plan:
`project/plans/upcoming/NetworkWeightedGraph.md`; ADR-006, ADR-007, ADR-009. Five changes, each its own
red, green and commit. No test is edited between a change's red run and its green run except where this file
says so. "Compile-stub" means the new API exists with the right signature and the old, wrong behaviour, so every
red is a failed assertion and not a compile error.

Run command for each change (the suites named in its section):
`swift test --skip-build --filter "<suites>"`. Linux was not run (not possible locally).

## Change 1: PageRank reports convergence (pagerank 2 to 3)

**Stub.** `Centrality.pageRankConvergence` returns `(0, true, 0, pageRank(...))`; `PageRankMetric` gains
`damping`/`maxIterations`/`tolerance` but returns `DiagnosedScores(scores:..., convergence: nil)` at version 2.

**Before the red run (not between red and green):** the existing assertions of the old behaviour were rewritten to the
new expectation: `MetricRegistryTests` (`pagerank` version 3), the golden listing and `identifiersAndVersions`
constants (version 3, the one deliberate edit of `GoldenRecordData.swift`, with a comment), and
`MetricRecordGoldenTests`, which now compares a pagerank record with the stored text after undoing only the
version number and the `convergence` key (`asStoredBeforeStepFour`), so every other byte must still equal what the
previous package wrote. The first red run (`red1-first-run-before-strengthening.txt`) showed three tests that passed
against the stub for the wrong reason (they asserted `iterations <= 176` and `converged`, which the stub satisfies with
zero passes). They were strengthened (`iterations >= 1`, `residual < tolerance`, a lower bound from the bound itself for
the star) **before any implementation existed**, and the red run was repeated: that is `red1-run-full.txt`.

**Red (stub): 63 tests in 8 suites, 67 issues, 21 tests failed (rows in `red1-rows.txt`), the rest passed.** Failing tests: the version/descriptor tests, the
four registry-listing goldens, `storedShape`, `scoresAndReport`, every convergence-flag/ceiling/residual/degenerate test,
damping 0.99 and 0.9, the 5,000 and 50,000 stars, `defaultConverges`, `passesMatchThePrediction`.

Passed against the stub, classified:
- [S] `oneLoopAndUnchangedNumbers`: the stub delegates to `pageRank`, so identical scores is true by construction. It is
  the invariant guard (bit-identical to a frozen copy of the old loop, across 6 seeds, 3 families, 5 dampings, 6 ceilings,
  3 tolerances); its bite is checked by the mutation run, not by this red.
- [P] `aPrioriBound`: the oracle (L1 error after k passes <= 2 * damping^k against a dense linear solve) tests the loop that
  was already there; it passes before and after, as it should. Not red-first evidence for the report.
- [P] `version2StillDecodes`, the golden record/envelope/bit-pattern tests, the old-record decode tests: decode and
  invariance tests over stored text; they must pass before and after. The pagerank rows of the golden record tests pass
  against the stub only because the stub still writes version 2 and no `convergence` key, i.e. exactly the stored form;
  `storedShape` is the test that demands version 3 and a report.

**Green.** Real loop in `pageRankConvergence`, `pageRank` delegating, `PageRankMetric` at version 3 returning the report.
Same command: 63 tests, all passed (`green1-run-full.txt`). Nothing edited between.

**Measured in this repository** (`pagerank-remeasure-in-repo.txt`, arm64, Swift 6.4, debug): star of 1,000 to 10,500 nodes
converges in 174 to 175 passes; from 11,000 nodes it stops at the ceiling with residual 1.037e-12 (1.086e-12 at 12,000,
1.337e-12 at 17,000, 4.527e-12 at 50,000) and a hub error of about 3e-13 (1.3e-12 at 50,000). This matches
`pagerank-measurement.md`. The pinned tests use 5,000 (converges) and 50,000 (does not, floor 4.5 times the tolerance)
because the 10,000/11,000 threshold sits within 4% of the tolerance and is a rounding limit cycle that x86 Linux may
place differently; the threshold is recorded here, not pinned.
