# Red then green: diffusion and siting, part 2 (seed selection and the stored-record conformances)

## Red

Compile-stubs came first, with the real public signatures and deliberately wrong behaviour:
`SeedSelector.compute` and `computeAsync` returned the first `min(budget, n)` nodes in node order with gain 0 and
validated nothing; `sweep` returned one empty selection per probability and accepted an empty list;
`SeedSweep.init(results:)` kept the points but returned no frequencies, an all-zero `n x n` Jaccard matrix, a mean
of 0 and an empty `alwaysPicked`; its `Codable` wrote an empty container and decoded to no points; `SeedSweep.kind`
and `SiteAssignment.kind` returned `""`; `SiteProblem.init(demand: NodeScores ...)` ignored the scores (demand
`[:]`, so it threw `noDemand`); `SeedSelector.descriptor` was empty. The matrices and picks are right-sized so a
test fails on an assertion, not on an index trap (the part 1 lesson). `GraphMetric` and `MetricDescriptor` are a
protocol and a plain data struct with no behaviour, so they were ported as they are and were not stubbed.

The suites compiled (`swift build --build-tests`, no errors, no warnings) and were run with
`swift test --skip-build --filter` over the new and ported suites (`red-run-summary.txt`; per-test table in
`red-rows.txt`). Result: **100 test cases in 19 suites, 5,188 issues; of the 69 test functions in the new and
ported files, 50 failed on assertions (36 plain, 14 parameterised), 2 benchmarks were skipped (they need
`RUN_BENCHMARKS`), and 17 passed against the stub.** Every failure is a failed `#expect`; none is a compile error or
a trap.

Failures include: every golden selection, sweep, summary, descriptor, JSON and envelope comparison (706 issues);
the new lazy-greedy oracle suite (2,304); the part 1 style oracle suites for selection (1,191) and sweep (96); the
refresh-count test (undeclared models must run exactly `trials x (n + sum (n - p))` trials; the stub ran 0); the
declared-model batch bound; the `(1 - 1/e)` guarantee (the stub's picks are not the best sets); every hand-checked
Jaccard, frequency and `alwaysPicked` value; the `SiteAssignment` kind and envelope tests; the `NodeScores`
siting tests; the golden siting JSON and `NodeScores` siting (55).

### Passed against the stub, and why (vacuous against it, not weak by themselves)

The stub is constant, deterministic or empty, or the test does not touch the code that was stubbed:

- LazyGreedyTests.swift: "An undeclared model gets exact plain greedy even when asked to be as lazy as possible"
- LazyGreedyTests.swift: "Independent cascade declares it; linear threshold and an undeclared model do not"
- LazyGreedyTests.swift: "Independent cascade is submodular in every single trial: gains never grow with the seed set"
- LazyGreedyTests.swift: "Linear threshold is NOT submodular in a single trial: two half-weight neighbours can jointly activate a node neither does alone"
- SeedSelectionGuaranteeTests.swift: "The guarantee is not vacuous: on a graph with one hub, greedy keeps most of the optimum, not just 63%"
- SeedSelectionOracleTests.swift: "NodeSelection round-trips through JSON and its envelope, for seeded arbitrary picks"
- SeedSelectionOracleTests.swift: "The linear threshold selection is deterministic and no worse than the worst-connected nodes"
- SeedSelectorTests.swift: "Budget above node count returns at most node count picks, all distinct"
- SeedSelectorTests.swift: "Empty graph yields an empty selection"
- SeedSelectorTests.swift: "Frequencies are the fraction of sweep points in which a node was picked"
- SeedSelectorTests.swift: "Sweeps are deterministic"
- SeedSelectorTests.swift: "The linear threshold model also selects, deterministically, and beats a random-ish set"
- SeedSelectorTests.swift: "The parallel first pass agrees bit-for-bit with the async task-group version"
- SitingTests.swift: "Round trip: encode then decode returns the original, as JSON and as an envelope"
- SweepCodableTests.swift: "A point whose probability is NaN cannot be encoded, and says so rather than storing garbage"
- SweepCodableTests.swift: "A single point round-trips, including on String nodes"
- WeightConsumerDiffusionTests.swift: "Seed selection and a probability sweep pick real, distinct nodes"

Reasons, in groups. Do not touch the selector or sweep at all (they exercise types ported earlier or the
derived `Codable` of `SweepPoint` and `NodeSelection`): the two submodularity-in-one-trial tests, the `NodeSelection`
round trip, the single-point round trip, the `NaN` probability refusal (the encoder refuses `NaN` whatever the type).
Constant and deterministic stub: "Sweeps are deterministic", the async-versus-sync agreement, "Budget above node
count" (the stub returns `min(budget, n)` distinct nodes), "Empty graph" (the stub returns none), "Frequencies are
the fraction..." (empty frequencies agree with an empty manual count over empty selections), the linear-threshold
selection tests (the stub's first nodes happen to be well connected in the karate club), the "guarantee is not
vacuous" hub test (the stub's first node is the star centre), "An undeclared model gets exact plain greedy" (all
gains tie in that fixture, so node order is the greedy order). `selectionFinite` passed because the stub returns
`min(3, n)` distinct nodes with finite, non-negative gains and a finite Jaccard mean. The siting round trip passed
with the stub's empty kind because a kind that equals itself round-trips; `SiteAssignment.kind` is pinned by
`codable`, `SiteAssignmentGoldenTests` and the mutation check. Their strength is established by the mutation check,
not by this run.

## Green

`GraphMetric` and `MetricDescriptor` were ported unchanged (SwiftGraphMetrics `Protocol/`, re-styled to tabs and
DocC). `SeedSelector.swift` was ported from SwiftGraphMetrics `Diffusion/SeedSelector.swift` (tabs, BusinessMath
header, `import BusinessMath` in the doc fences; no body, constant, comparison, tie-break, chunking or refresh rule
touched). `SiteAssignment` conforms to `MetricValue`; `SiteProblem.init(demand: NodeScores ...)` is the original;
the three doc-comment symbol links part 1 had replaced with prose are restored (`DiffusionModel` twice,
`SeedSelector`, the `sweep` link; `SiteProblem` points at the `NodeScores` initialiser again).

First green run, the same command with the Diffusion and PMedian suites added: **191 tests in 37 suites pass, 0
issues.** No test was edited between the red run and the first green run, and no implementation line was changed
to satisfy a test. Every golden value (48 selections, 10 sweeps, the descriptor, 18 `SiteAssignment` JSON texts and
envelopes, 5 `NodeScores` siting answers) matched on the first run, bit for bit and character for character, with
both `compute` and `computeAsync`.
