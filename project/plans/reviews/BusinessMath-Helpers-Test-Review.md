# BusinessMath helper tests: templates, diagnostics, performance, documentation, developer tools

*September 2026. Covers 14 files: TemplateRegistryTests, StandardTemplatesTests, ModelDebuggerTests, ModelProfilerTests, CalculationTraceTests, LoggerTests, DataExportTests, DocumentationExamplesTests, PerformanceOptimizationTests, PerformanceBenchmarkTests, SparsePerformanceBenchmark, SparseMatrixTests, ParallelOptimizerTests, AdaptiveOptimizerTests. Companion to the fifteen preceding domain reviews.*

*All reference values recomputed in Python.*

## 1. Summary

These are the library's supporting tools, and the domain divides sharply by whether the file found a way to make its subject deterministic.

**`ModelProfilerTests` is the model, and it is the answer to a problem that recurs across the whole corpus.** A profiler's output is wall-clock time, which is the least testable quantity there is. The file injects a `ManualElapsedTimeSource` instead, so `time.advance(by: .milliseconds(1))` makes the elapsed time an exact input. Its comments document the transition:

> "Was: sleep 1ms and assert 'at least 1ms', which a slow machine could only overshoot. The same lower bound holds, and now an upper one does too."

> "The value they all agree on is now known, not merely self-consistent."

That second line is the sharpest short statement of the corpus's central weakness. `singleMeasurementStatistics` previously asserted `minTime == maxTime == averageTime == medianTime` — four mutually-consistent claims about an unknown number. Now it asserts they all equal 0.001 at 1e-12, and `multipleMeasurementStatistics` pins min 0.001, max 0.005, mean 0.003, median 0.003, total 0.015 for the 1–5 ms sequence, which I confirmed.

**Against that, `PerformanceOptimizationTests` has about 17 wall-clock assertions and is not `.benchmarkOnly`** (§2 item 1). It is the file the injected-clock technique should be applied to next, and the project's own notes list wall-clock timing in CI as a recurring problem.

**`LoggerTests` has 13 `#expect(true)` markers** — the largest single concentration in the corpus (§2 item 2). Every logging test is a did-not-crash check.

The other files are mostly sound, with the recurring pattern being string-content assertions where a structured claim is available.

### Templates to copy

| Kind of test | Copy from |
|---|---|
| Anything whose output is a duration | ModelProfilerTests (`ManualElapsedTimeSource`) |
| Benchmarks that must assert, not just report | SparsePerformanceBenchmark (speedup and memory floors) |
| Executable documentation | DocumentationExamplesTests |
| Dispatch logic | AdaptiveOptimizerTests (`algorithmUsed`, not the reason string) |

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`PerformanceOptimizationTests` asserts wall-clock time in the regular suite** | About 17 assertions of the form `#expect(elapsed < 0.5, "Should complete in < 500ms")`, with bounds from 0.05 s to 25 s. Only one test in the file (`Benchmark_TimeSeriesCreationThroughput`, line 284) carries `.benchmarkOnly`; the suite declaration does not. So the rest run on every CI pass, on shared runners, under whatever load. The tightest is `elapsed < 0.05` for a validation call. | Two separable changes. The *timing* assertions belong behind `.benchmarkOnly` alongside the other benchmark suites. The *correctness* assertions in the same tests (`profit == 13_000`, `totalProfit == 2_475_000`, `csv.count > 1000`) should stay in the regular suite — so the tests want splitting rather than moving wholesale. Where the point is an algorithmic bound rather than a wall-clock one, the `ManualElapsedTimeSource` approach from `ModelProfilerTests` removes the machine dependence entirely. |
| 2 | **`LoggerTests` is 13 `#expect(true)` markers** | Every logging test — calculation started/completed/failed, validation warning/error, performance, signposts, workflow, concurrent safety — ends in `#expect(true) // TEST-QUALITY: validates no-throw execution`. The three tests with real assertions are the Linux-fallback ones (`logger.subsystem`, `logger.category`) and `loggers.count == 5`. | A logger is testable: inject a recording sink and assert what was logged — the category, the level, the message fields, and for `logPerformance` the duration that was passed. That turns 13 vacuous tests into 13 real ones. If the OS logging backend genuinely cannot be observed, the honest form is a comment stating that the absence of a throw is the assertion, with the marker deleted — the test is already `throws`. `concurrentLoggingSafety` deserves better either way: it is the one test in the file whose subject (a data race) a did-not-crash check might actually detect, but only under TSan. |
| 3 | **Two tautologies in `CalculationTraceTests`** | `#expect(step.category == step.category, "Step should have category")` — true for any enum. `#expect(profit == profit)` — true for any non-NaN `Double`, so it is a NaN check written as a self-comparison, the same shape as `sharpe >= 0.0 \|\| sharpe < 0.0` in the portfolio review. | The category test should assert the expected category per step. The profit one should assert the value: the model in `HandlesComplexModels` has a computable profit. |
| 4 | **`PerformanceBenchmarkTests.executionTimeMeasurement` computes a coefficient of variation from two samples** | With n = 2 the sample standard deviation is just \|t₁ − t₂\|/√2, so CV < 0.5 means the two times differ by less than about 1.4× their mean — and it is wall-clock, so a scheduling hiccup on either run trips it. The test also asserts `executionTime < 1.0` for a 2-D sphere minimisation. | The suite is correctly `.benchmarkOnly`, so this is not a CI-stability risk. But a two-sample CV is not a consistency measurement. Either raise the run count to something where the statistic means something, or drop to asserting both runs completed and let the benchmark report carry the timings. |
| 5 | **`DataExportTests` uses disjunctions that accept either behaviour** | `#expect(csvOutput.contains("Component") \|\| csvOutput.contains("empty"), "Should have header or empty message")` for an empty model, and the same shape for an empty time series. Also `contains("periods") \|\| contains("data")`, and `contains("15000") \|\| contains("15,000")`. | The empty-input contract is a decision: header-only, or an explicit empty marker. Pick one and assert it — this is the contract-free disjunction pattern, here applied to an API surface users will depend on. The number-formatting disjunction is a reasonable locale hedge, but pinning the format once is stronger. |
| 6 | **The checksum test recomputes the checksum the same way** | `expectedChecksum = TemplatePackage.calculateChecksum(package.templateJSON)` compared against `package.checksum` — self-recomputation, so a wrong checksum function passes. | Mitigated by `Cannot import package with invalid checksum`, which is the discriminating test and exists. Worth adding a pinned checksum literal for one fixed template, so a change to the hashing algorithm is visible rather than silently consistent. |
| 7 | **`AdaptiveOptimizerTests` asserts on a diagnostic string** | Each dispatch test asserts both `result.algorithmUsed == expected` and `result.selectionReason.contains("inequality")` / `"Large problem"` / `"Small problem"`. | The first assertion is the contract; the second pins the wording of a human-readable explanation. Keep one string test that pins a full reason for one case, and drop the substring checks from the rest — otherwise a clearer rewording of the diagnostics breaks four tests that were not about wording. |

## 3. Patterns

### 3.1 String content as the primary assertion

This is the dominant pattern across five files in the batch:

| File | Shape |
|---|---|
| DataExportTests | ~30 `csvOutput.contains(...)` / `jsonOutput.contains(...)` |
| DocumentationExamplesTests | ~15 `summary.contains(...)`, `csv.contains(...)`, `formattedTrace.contains(...)` |
| CalculationTraceTests | ~12 `description.contains(...)`, including `contains("30,000")` and `contains("22,500")` — number formatting as a correctness property |
| PerformanceBenchmarkTests | 11 across `summaryReport` and `detailedReport` |
| ModelDebuggerTests | Several on formatted output |

The error-handling review makes the general argument, and it applies verbatim here: substring matching is fragile against rewording, and it passes when the substring appears in an unrelated position. The specific improvements for this batch:

- **CSV and JSON have structure.** Parse the CSV and assert the header row, the row count and a named cell; parse the JSON and assert the decoded shape. `DocumentationExamplesTests` already does the second — `#expect(parsed is [String: Any] || parsed is [Any])` — though that disjunction is weaker than asserting which one it is.
- **Formatted-report tests want one golden string each.** Pinning the whole rendered output for one fixed input catches spacing regressions, doubled headers and missing sections in a single assertion, and it is no more brittle than eleven substring checks.
- **Number formatting in a trace is a real property**, but it belongs in one test of the formatter, not spread across the trace tests.

### 3.2 Assertions that restate the construction

Roughly 25 across the batch: `report.operations[0].operation == "Simple"`, `result.allResults.count == 7`, `sparse.rows == 4`, `registry.count == 1`, `package.metadata.name == "Exportable Template"`. These are cheap contract checks on returned shape and not worth removing, but they are the bulk of `TemplateRegistryTests` and `SparseMatrixTests` by volume.

`TemplateRegistryTests`' better tests are the ones that exercise behaviour: duplicate registration throwing, category and tag filtering with distinct counts (2 SaaS, 1 retail, 2 enterprise, 1 B2B), the export/import round trip, and the invalid-checksum rejection. Two gaps: registration is tested for `BusinessMathError` by type only (twice), and nothing tests concurrent registration despite the registry being an actor.

### 3.3 Benchmarks that do assert

`SparsePerformanceBenchmark` is the counter-example to the GPU benchmarks criticised in the simulation review. It is `.serialized` and `.benchmarkOnly`, and every test asserts a floor:

- `speedup > 2.0` for sparse versus dense at 500×500
- `avgTime < 0.2` at 5,000×5,000
- `residual < 1e-6` for the CG solver and `< 1e-4` for BiCG — correctness alongside timing
- `memorySavings > 0.95` at 1,000×1,000

I verified the memory claim: a 1,000×1,000 tri-diagonal matrix in CSR is about 39,980 bytes against 8,000,000 dense, a 99.5% saving, so the 95% floor holds with margin. The two solver residual assertions are the most valuable things in the file, because they check the sparse path produces a *correct* answer rather than merely a fast one.

Two notes: the file carries its own private `SplitMix64`, which is the Nth copy in the corpus (the optimization and TestSupport reviews track the others), and the `0.1% density` in the test names is wrong — the comment inside computes 0.6%, and both names say 0.1%.

### 3.4 Documentation examples

`DocumentationExamplesTests` is a good idea well executed in principle: if a documented example breaks, the test fails. The values are exact and correct — I confirmed revenue 99,000 (99 × 1000), costs 64,850 (50,000 + 15% of 99,000), profit 34,150 — and asserted at `< 1.0`, which for integer-valued money is loose but harmless.

Its weakness is that about half the assertions are existence checks: `npv > 0`, `irr.isFinite`, `payback.isFinite`, `!csvOutput.isEmpty`, `validation.isValid`. For an executable-documentation suite the stronger claim is that the example produces *the value the documentation shows*. If the docs say "NPV: $12,345", the test should assert 12,345 — otherwise the documentation can drift from the code while the test still passes.

The `QuickStart_InvestmentAnalysis` test is the clearest case: it asserts `npv > 0`, `irr.isFinite` and `payback.isFinite` where all three have closed forms for the fixture's cash flows.

## 4. Coverage gaps

**Templates.** Concurrent registration and export on the actor; a template whose required parameters are not supplied; version-conflict handling on import; `StandardTemplatesTests` overlaps `TemplateDelegationTests` from the fluent-API review and should adopt its delegation property.

**Diagnostics.** `ModelDebuggerTests` and `CalculationTraceTests` both trace the same models; worth checking they agree. Nothing tests a trace of a model that throws mid-calculation — whether partial steps survive. `CalculationTrace_CanClearTrace` is good; a test that clearing during an active calculation is safe would complete it.

**Export.** Round-trip: export to CSV or JSON and re-import, asserting the recovered model equals the original. Currently every export test checks the output string and nothing reads it back. Escaping: a component name containing a comma, a quote or a newline is the classic CSV defect and is untested.

**Sparse matrices.** A matrix with an explicitly stored zero (a numerical zero in the triplet list); duplicate triplets for the same (i, j); out-of-bounds triplet indices; the CG solver on a non-SPD matrix, where it should fail rather than silently converge to nothing.

**Parallel optimizer.** `ParallelOptimizerTests` mostly duplicates `MultiStartOptimizerTests` from the optimization review. Its distinctive subject is parallelism, and the untested properties are exactly the parallel ones: that the result is independent of thread scheduling (run twice, assert `identical`), and that per-start seeds are derived deterministically rather than from shared mutable state. `ScenarioGeneratorDeterminismTests` in the optimization batch is the model — it checks concurrent seeded runs against their serial baselines.

`elapsed < 30.0` at line 482 is another unguarded wall-clock assertion, in a file with no `.benchmarkOnly` trait.

## 5. Recommended order of work

1. **Split `PerformanceOptimizationTests`** (§2 item 1): correctness assertions stay, timing assertions move behind `.benchmarkOnly` or onto an injected clock. This is the CI-stability item.
2. **Give `LoggerTests` a recording sink** (§2 item 2). Thirteen vacuous tests become thirteen real ones, and it is the largest single concentration of the pattern in the corpus.
3. **Apply `ManualElapsedTimeSource` more widely** — `ParallelOptimizerTests` line 482, and anywhere else a duration is asserted for an algorithmic reason rather than a benchmarking one.
4. **Fix the two tautologies** in `CalculationTraceTests` (§2 item 3).
5. **Decide the empty-export contract** and replace the disjunctions (§2 item 5).
6. **Add export round-trip and CSV escaping tests** (§4).
7. **Assert documented values, not existence**, in `DocumentationExamplesTests` (§3.4).
8. **Add a golden-string test per formatted report** and thin the substring assertions (§3.1).
9. **Add the parallel-determinism tests** (§4) and pin one checksum literal (§2 item 6).

## 6. Gate rules

One new rule, and it is a useful one because it is precise.

**Wall-clock assertion outside `.benchmarkOnly` (blocking).** Flag an `#expect` whose operand derives from a clock read (`Date()`, `ContinuousClock`, `DispatchTime`, or a library `executionTime` / `elapsed` property) in a test whose enclosing suite and test declaration lack `.benchmarkOnly`. About 18 sites here across two files. The existing proposal was "flag clock reads that no assertion consumes"; this is the complement — clock reads that an assertion *does* consume, in a suite that does not permit it. The corpus already has the trait and the convention; this rule enforces it.

Existing rules that apply:

- **Vacuous assertions.** 13 `#expect(true)` in `LoggerTests`, plus the two self-comparisons in `CalculationTraceTests`. The self-comparison shape (`x == x`) is worth naming explicitly in that rule alongside `#expect(true)`.
- **Contract-free disjunctions.** `DataExportTests`' empty-input cases (§2 item 5).
- **String-content dominance (advisory).** Five files in this batch would trip the proposed threshold; `DataExportTests` and `PerformanceBenchmarkTests`' report tests most heavily.
- **Self-recomputation.** The checksum test (§2 item 6).
- **Field-storage tests (advisory).** ~25 sites.
- **Test names quoting numbers the body does not produce.** The two `0.1% density` names in `SparsePerformanceBenchmark` whose own comments compute 0.6%.

## Appendix. Verified values

### A.1 Profiler (with the injected clock)

| Quantity | Value |
|---|---|
| Single 1 ms measurement: min = max = mean = median | 0.001 exactly |
| 1–5 ms sequence: min / max / mean / median / total | 0.001 / 0.005 / 0.003 / 0.003 / 0.015 |
| Async 1 ms measurement | 0.001, asserted in [0.001, 0.002) |

### A.2 Documentation examples

| Quantity | Value |
|---|---|
| Revenue, 99 × 1000 | 99,000 exactly |
| Costs, 50,000 + 15% of 99,000 | 64,850 exactly |
| Profit | 34,150 exactly |
| `PerformanceOptimizationTests` single-model profit | 13,000 exactly |
| `PerformanceOptimizationTests` aggregate profit | 2,475,000 exactly |
| Sum 1…1000 (profiler fixture) | 500,500 exactly |

### A.3 Sparse matrices

| Quantity | Value |
|---|---|
| 4×4 with 6 non-zeros: sparsity | 0.625 exactly (test asserts > 0.6) |
| 1,000×1,000 tri-diagonal: non-zeros | 2,998 |
| Dense storage | 8,000,000 bytes |
| CSR storage (values + column indices + row pointers) | ≈ 39,980 bytes |
| Memory saving | ≈ 99.50% (test asserts > 95%) |
| Tri-diagonal density at n = 500 | 0.60% (test names say 0.1%) |
