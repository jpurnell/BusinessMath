# Mutation check of the registry layer

84 hand-written mutants (`mutate.py`) in an outside-the-repo lab (`make_lab.sh`, `/private/tmp/claude-501/mut3`),
run against the registry-layer suites plus the existing envelope, value and stored-record suites (122 tests in the lab,
baseline green). Raw output: `mutation_output.txt`. **83 killed, 1 survived (equivalent), 0 invalid.**

| Group | Mutants | Killed | Notes |
|---|---|---|---|
| Versions (V, 12) and identifiers (I, 12) of every standard metric | 24 | 24 | killed by the descriptor-listing golden, the version test and the record goldens |
| Descriptor text (D) | 3 | 3 | the listing golden pins every word |
| Eigenvector metric (E01-E10): defaults, reported ceiling/tolerance/iterations/converged/residual, parameters passed through, scores | 10 | 10 | EigenvectorDiagnosticsTests, the golden settings and the record goldens |
| Wiring (W01-W13): each metric routed to another measure, other normalisation, resolution, passes | 13 | 13 | the record goldens (bit patterns) and `registryAgreesWithFunctions` |
| Registry (R01-R12) | 12 | 11 | R09 survived: equivalent |
| Standard membership (M01-M11): each metric dropped in turn | 11 | 11 | |
| AnyGraphMetric (A) and MetricRecord (Q) | 6 | 6 | |
| Cross-layer (G01-G06): measure changes underneath | 6 | 6 | the golden records notice a changed measure |

## Survivor

- **R09** `record` takes `metric: identifier` instead of `metric.descriptor.identifier`. Equivalent: the registry keys
  every metric by its descriptor's identifier, so the two strings are always equal. No test can tell them apart.

No survivor needed a new test, so no test was added in response to the check. Every pattern in the script matched exactly once (no PATTERN MISMATCH lines). Orphaned test processes: none remained after the run.
