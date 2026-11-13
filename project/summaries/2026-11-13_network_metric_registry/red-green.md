# Red then green: metric registry and stored-record layer (step 3)

Branch `feature/network-metric-registry`, based on `integration/network-all`. Source of truth: SwiftGraphMetrics
(commit `0aa9c80`, read only). Plan: `project/plans/upcoming/NetworkWeightedGraph.md`, ADR-006, ADR-008.

## Method

1. **Golden first, outside both repos.** `golden/main.swift` (scratch package depending on SwiftGraphMetrics by
   path, built in the session scratch directory) ran SGM's own `MetricRegistry.standard` over 20 fixtures and wrote
   `Tests/.../Metrics/GoldenRecordData.swift`: for each standard metric the full `MetricRecord` JSON
   (`.sortedKeys`, clock 1_770_000_000, a fixed context), the bare envelope JSON, and the scores as Double bit
   patterns; the descriptor listing; non-default eigenvector settings; karate on `Int` nodes. SGM's working tree was
   clean and unchanged by the run.
2. **Design.** Signatures fixed by SGM and ADR-006; no new API.
3. **Compile-stub.** `AnyGraphMetric`, `MetricRecord`, `MetricRegistry`, the eleven metric structs and
   `BurtConstraint` with the real signatures and wrong, right-sized behaviour: every metric has its right identifier
   but version 0, empty descriptor text and all-zero scores or one-community partitions; `EigenvectorMetric` returns
   `DiagnosedScores` with `convergence == nil`; `AnyGraphMetric.compute` returns a `stub` envelope; the registry's
   `run` and `record` return `nil`, `registering` returns `self`, `available` is unsorted; `MetricRecord`'s
   initialiser forces version 0 and clock 0. The stub built with no errors and no warnings from it.
4. **Tests written and run against the stub** (command below). Every failure is a failed assertion: the run completed.
5. **Real code** (SGM's, tabs, `import BusinessMath` and compiling examples in the doc fences) copied in. Same command, green.
   No test was edited between red and green. (A compile fix to the test file happened before the red run:
   a private helper named `hex` collided with the module's existing `hex`; renamed `bitHex`. One more reference to it
   was fixed afterwards, when the mutation lab, which has no `GoldenMeasureRunner`, failed to compile: a build
   error, not a behavioural change.)

Command: `swift test --skip-build --filter "MetricRegistryTests|MetricRecordTests|MetricRecordGoldenTests|RegistryListingGoldenTests|OldRecordDecodeTests|EigenvectorDiagnosticsTests|ValueTypeMutationTests|BurtConstraintMetricTests|WeightConsumerRegistryTests"`

## Red (stub): 73 tests in 9 suites, 47 failed, 26 passed, 270 issues

Full output `red-run-full.txt`, one line per test `red-rows.txt`. Failing suites: registry listing (4 issues),
registry (68), record provenance (7), golden records (142: every metric over every fixture fails on version, text
and values), eigenvector diagnostics (29), Burt metric (10), weight consumers (7), value-type audit (2),
old-record decode (1).

### Tests that PASSED against the stub, by name and reason

[S] the stub already satisfies it (right identifiers, right defaults, `nil` for an unknown or unrunnable metric);
[P] it exercises code that was already ported (envelope, value types, `ConvergenceNote`, the synthesised
`Codable` of `MetricRecord`, which does not go through the stubbed initialiser) or data alone; none is red-first
evidence for this step. The mutation check shows which of them bite.

- [S] A metric looked up by identifier carries the descriptor it was registered with (the stub's own descriptor)
- [S] An empty registry lists nothing and runs nothing
- [S] An unknown identifier records nothing (stub `record` returns nil)
- [S] Returns nil for an unknown identifier rather than throwing
- [S] Ships the metrics the design calls for; Every added measure is in the registry, and there are exactly eleven
- [S] The instance descriptor is the static one
- [S] The metric's defaults are 200 passes and a tolerance of 1e-10
- [S] The seed selector is deliberately not in the standard registry
- [S] A record for a metric this build does not know decodes and re-encodes unchanged (registry returns nil)
- [P] A null payload decodes as null and re-encodes; bottom(0) is empty...; Ranking is by score descending...;
  Groups of equal size are ordered...; Edge count and neighbour order...; (value types and graph, pre-existing)
- [P] A stored envelope decodes to the typed value of its kind (20 cases); The long path misses the default
  ceiling and says so in the stored record; The fixture set covers the cases the plan names (stored data only)
- [P] A stored version 3 envelope decodes...; A whole stored version 3 record decodes; Only a scores envelope is read
  for convergence...; The sentence says which it was...; A version 2, a version 3 and a version 4 eigenvector
  record decode (the old-record tests: decode of stored text through the already-ported envelope and the synthesised
  record decoding)
- [P] Siting on centrality-weighted demand stays finite (7 cases): uses no registry, only `Centrality.degree`

## Green (real code)

`Test run with 73 tests in 9 suites passed after 12.881 seconds.` (`green-run-full.txt`). The golden records matched
SGM's output byte for byte and bit for bit on the first run with the real code.

## Louvain golden, hash-seed check

The golden suites (registry records, listing, and the step-2 measure golden, which also pins Louvain on every fixture)
were run 20 times in separate processes (Swift randomises dictionary hashing per process): 20 of 20 runs passed,
21 tests each. See `louvain-repeat.txt`.
