# Red then green: diffusion and siting core (step 3, part 1)

## Red

Compile-stubs were written first for every ported type, with the real public signatures and deliberately wrong
or empty behaviour: `TrialRandomness` returned 0.5 for every draw; `IndependentCascade` and `LinearThreshold`
returned the seed count; `SpreadEstimator` returned a zero estimate and never threw; `DiffusionGraph` held
zero-filled offsets and no edges; `SiteProblem` validated nothing and returned cost 0; `SiteAssignment` kept
no totals or loads; `PMedian` returned the first `k` sites, and its `subsetCount`, `enumerate`, `greedy` and
`swapSearch` were constants. `DiffusionError` is a plain error enum and was ported as is.

The ported tests then compiled (`swift build --build-tests`, no errors) and were run with
`swift test --skip-build --filter` over the 15 new suites (the integer-program suite separately, below).

One false start, recorded because it is not behavioural: the first stub gave `DiffusionGraph` empty `offsets`,
and the ported tests index `flat.offsets[node + 1]`, so the test process trapped (`Index out of range`) and
reported nothing. The stub was changed to zero-filled arrays of the right length (still wrong), and the run
below is the one on record.

Result: **90 test cases in 15 suites, 5,682 issues; 75 of the 89 test functions failed, 13 passed, 1 reported
only through its issues.** Every failure is a failed `#expect` or a missing throw; none is a compile error.
Failures include: every golden draw, per-trial outcome and estimate (bits differ); both per-trial oracles
(587 + 364 issues); the strict `draw < p` test (40); the threshold tolerance window (1,152); the closed-form
star, path and threshold checks; compressed-row flattening (276); `summarise` hand values; zero-trial
rejection; probability validation; the exact p-median against brute force (172) and against the lexicographic
oracle (791); the heuristic structure, swap-optimality and greedy-pick-order checks (547 and 27); site-order
invariance (46); the subset-count binomials (32); `enumerate`, `greedy` and `swapSearch` rules; every
`SiteProblem` validation error (23); the businessMath golden path (travel hours 5.2078, cash 301.6533, the
Philadelphia winner); the p-median golden file (112).

The 13 that passed against the stub did so because the stub is constant, deterministic or empty, not because
the test is weak: "A graph of one node is simulated" and "A node whose incident weights are all zero ... never
activates" (stub returns the seed count, which is the expected answer there), "A single trial reports zero
standard error", "Identical inputs give bit-identical estimates", "Estimates are identical when run
concurrently", "The RNG-driven simulate overload is reproducible" (a constant is reproducible),
"An improvement exactly equal to the tolerance is not taken" (stub `swapSearch` returns its start),
"SpreadEstimate round-trips through JSON" and "Round trip: encode then decode ... as JSON" (data types kept real),
"Extreme legal weights never trap or hang", "Siting on degree-weighted demand stays finite", "SiteAssignment
sorts by demand ... re-sorting is a no-op" and "Scaling every weight ... changes no choice" (stub results are
equal to themselves). Their strength is established by the mutation check, not by this run.

### Integer-programming oracle (`PMedianIntegerProgramOracleTests`), against the stub

3 tests, 47 issues. The two that compare `PMedian` with the integer program failed (cost and chosen sites
differ; `isExact` wrong on the heuristic branch). The third, "The integer program agrees with enumeration, so it
is a trustworthy oracle", passed, by design: it does not touch `PMedian`, and it passing on 12 instances is the
evidence that the formulation and BusinessMath's solver are right.

## Green

The real implementations were ported from SwiftGraphMetrics `Diffusion/` and `Siting/` (re-styled to tabs,
BusinessMath DocC and `import BusinessMath` in the doc fences; nothing else changed in any body, constant,
comparison, tie-break or draw), then the same command was run.

First green run: **93 tests in 16 suites pass** (the 90 + the 3 integer-program tests), including every golden
value bit for bit. No test was edited between the red run and the first green run, and no implementation line
was changed to satisfy a test.

After the mutation check (see `mutation-check.md`) two tests were added, each written against a surviving
mutant (red against the mutant first): `DiffusionModelDeclarationTests` and `swapToleranceScalesWithCurrent`.
Final: **95 tests in 17 suites pass**; the 10 existing Network suites (114 tests) pass alongside.

Corrections to my own tests on the way, none to implementation: the gate's `stochastic-determinism` checker
read the enum case `EdgeProbability.uniform(_:)` as a call to a test-support function named `uniform` that has
a defaulted `seed:`; the oracle helper now takes a local `CascadeRule` and the two equality assertions compare
the enum's description, so no test writes `.uniform(`. Six `#expect` expressions with four or more operators
were split into explicitly typed lets for the Swift 6.2.1 type-checker budget.
