# Red then green: `Centrality.eigenvectorByComponent` and `eigenvector-centrality-by-component` 1

Branch `feature/network-eigenvector-by-component`, off `origin/main` ae06466f. Design: `project/plans/proposals/NetworkEigenvectorByComponent.md`.
ADR-010. Source of the moved code and tests: ClassGraph main d38b363 (read only; `ComponentwiseEigenvector.swift` md5 29974c382ead5998f3dff2a3767f566f).
Command for every run below: `swift test --skip-build --filter "EigenvectorByComponent|MetricRegistryTests|MetricRecordGoldenTests|RegistryListingGoldenTests|OldRecordDecodeTests"`
after `swift build --build-tests`. "[S]" = passed against the stub for a stated reason; "[P]" = a pin that must pass before and after.
Linux was not run (not available here). No real archive was opened; every graph is synthetic.

## Goldens (the contract with ClassGraph)

`golden/main.swift` (a scratch SwiftPM program outside both repositories, kept as `golden/main.swift` + `golden/Package.swift.txt`) compiles an unmodified copy
of ClassGraph's `ComponentwiseEigenvector.swift` against the Network sources of BusinessMath ae06466f (taken with `git archive`, so before any change here)
and runs it over `ByComponentParityCases` (25 synthetic graphs: five connected, several with components and isolates, zero-weight ties, edgeless, lone, empty,
low ceilings, a long path that misses the default ceiling). Output: `ByComponentParityGoldens.swift`, the encoded `MetricEnvelope` (sorted keys) per case, and the
descriptor strings. `golden/main2.swift` does the same through the registry for `GoldenRecordData` (whole `MetricRecord` per existing fixture, bit patterns,
listing entry, integer-node karate tokens), spliced into the existing constants without touching the eleven entries already there.

**Finding while generating (not in the brief):** the generator, run twelve times, gave different bytes for two cases (six and three runs differed from run 1). Cause:
`WeightedGraph.init(unchecked:)` sums `totalWeight` in dictionary order, so for weights that are not binary fractions the last bit of every score can move between
processes. Those cases (decimal weights) are marked `exact == false` and compared on structure exactly and on values to 1e-9; the dyadic cases are compared
byte for byte (twelve generator runs identical, twelve test processes pass). The ClassGraph parity graphs `weighted-bridge` and `weighted-lollipop`
(decimal weights) were stable in 12 runs but are marked non-exact because nothing makes them so.

## Stub

`Centrality.eigenvectorByComponent` returned every score 0, no components, `isolatedCount = nodeCount`, converged with 0 passes. The value types
(`ComponentScoring`, `ComponentwiseScores`, with Codable, `unconverged`, `diagnosed`) and `ComponentwiseEigenvectorMetric` (real descriptor, calling the stub) were real and the
metric was registered in `MetricRegistry.standard`, so every red is a failed assertion, not a compile error. Existing tests that count the registry were edited in the same step
to expect twelve (they are part of the red: `MetricRegistryTests`, the `stored.count == 11` assertion), and `GoldenRecordData` gained the new metric's entries.

## Red

First run (`red0-crashed-rows.txt`): the process **crashed** (`Fatal error: Index out of range`), the stub having no components while one test indexed `passes[0]`. That is a test bug
(an unguarded index), fixed to `Set(passes).count == 2` before the red recorded below; no assertion about behaviour changed.

Recorded red (`red-rows.txt`, `red-failed-tests.txt`, `red-passed-tests.txt`): **87 tests in 11 suites, 34 tests failed (427 issues), 53 passed.** The failures are the value tests (scales, isolates, anchors,
sizes), the one-component bit-identity cases, the convergence aggregation, every byte and bit comparison against ClassGraph's constants, and the new
registry records. The 53 passes, classified (38 are tests that existed before, 15 are new):

- **38 existing registry and record tests ([P] pins, run so that registering a twelfth metric could not break them)**, e.g. "Runs a metric by identifier", "The registry lists its metrics in identifier order, once each", the version 2/3/4
  decode tests. Seven of them are tests whose count or constants I edited for the twelfth metric and which pass at red **by registration, not behaviour [S]**, because the stub registers the real metric with the real descriptor:
  "Every added measure is in the registry, and there are exactly twelve", "Identifiers and versions are exactly the stored ones", "The descriptor listing encodes to exactly the stored text", "The stored listing decodes ...",
  "The same listing comes from a registry of integer nodes", "Each fixture stores a record for every registered metric", "A stored envelope decodes to the typed value of its kind". Mutants R01 and M01 to M03 kill them (R01: not registered).
- **15 new tests pass against the stub:**
  - **[S] the trivial branch, which the stub emulates (5):** "the empty graph is empty, trivially converged", "a lone node scores 0", "a graph with nothing to iterate still reports the tolerance and ceiling", "an edge-less graph is all zeros",
    "a graph whose only ties have weight zero has nothing to iterate". They pin the documented trivial branch; mutants E02 to E09 show they are not vacuous (the failing test for each is named in `mutation/mutants-run2.out`).
  - **[S] registration (3):** "the identifier and version are its own", "the identifier, version, title and wording are ClassGraph's, character for character", "the standard registry lists it beside every other metric".
    Mutants M01 to M03, M08 and R01 kill them.
  - **[P] over the constants and the existing readers, not the new algorithm (5):** "every case has a golden", "a record ClassGraph stored decodes here and re-encodes to the same bytes", "a stored record reads as plain scores and as diagnosed scores",
    "the stored payload has exactly the four keys", "the shapes the brief names" (this last one only checks the constants against `eigenvectorConvergence`, i.e. that the goldens carry the version 5 numbers on a connected graph).
    They exercise `ComponentwiseScores`' Codable (real in the stub); mutants V03 to V08 kill them.
  - **[P] "eigenvector still refuses the graphs this one answers"** pins that `Centrality.eigenvector` is unchanged (1).
  - **[S] "the diagnosed view is the scores and the aggregate"**: the value type is real in the stub; mutants V02 kills it (1).

## Green

`Centrality.eigenvectorByComponent` implemented (a port of ClassGraph's function; value types and metric unchanged). `green-rows.txt`: **87 tests in 11 suites passed.** No test was edited between the recorded red and this green.

## Edits after green, none changing what an assertion claims about behaviour

1. **Linux type-check budget** (Swift 6.2.1: at most three operators per `#expect`, no arithmetic inside): `allSatisfy { a && b && c }` closures became named helpers and arithmetic moved to typed `let`s. Re-run green afterwards.
2. **Settings and worst-case suite, overflow suite** (`EigenvectorByComponentSettingsTests`, `EigenvectorByComponentOverflowTests`), written against the unchanged implementation to close mutation survivors (below). They passed first time
   except one: `acceptedGraphIsAnswered` failed because my own constant was wrong (1e308: `WeightedGraph` counts each tie from both ends and refuses a sum past the largest number, so the test's own `graph()` threw). That is a **test bug**; the constant is 8e307 (accepted, and twice it is not).
3. **Refactor of one expression**: `let smallest = ...min() ?? 1` with `part.rms > 0 ? smallest / part.rms : 1` became `smallest: Double?` with an `if let` (the default `1` was dead: it is only read when the filtered set is non-empty). Behaviour identical; every parity test and mutant run 2 was done on the refactored code.

4. **First gate run** (`--no-cache`, 0 errors) reported two warnings in my tests (`residuals.max() ?? -1` inside an assertion: "falls back to -1 when the optional is nil") and a cognitive-complexity note on `eigenvectorByComponent` (16 against 15).
   The assertions now `#require` the maximum; the multi-component part of the function became a private `scoreScaledComponents`. No behaviour change (re-run: 96 tests pass; mutation re-run on the final code, `mutation/mutants-final.out`).

## Hash-seed repeat

`hash-seed-repeat.txt`: the by-component, golden record and registry suites (96 tests) run in 12 separate processes (each its own random hash seed): 12 of 12 passed (96 tests each, after the late additions). The generator's own twelve runs are the other half (see Goldens).

## Full suite and gate

Full suite before the late edits: `full-suite-run1-summary.txt` (9749 tests passed). On the final tree: `gate-final.txt` (its test checker passed in 539 s; 0 errors, 0 warnings). See `summary.md`.
