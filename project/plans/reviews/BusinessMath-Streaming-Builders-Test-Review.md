# BusinessMath streaming, result builder, and utility tests

*September 2026. Covers 18 files across three areas: streaming (StreamingInfrastructureTests, StreamingStatisticsTests, StreamingCompositionTests, StreamAlignmentTests, TimeWindowedTests, TimestampedTests, StreamingSuccessiveDifferenceTests, StreamingForecastingTests, StreamingAnomalyDetectionTests, StreamingFrequencyDomainTests, PowerSpectralDensityTests, MergeLeakRepro), result builders (CashFlowBuilderTests, ValuationBuilderTests, ScenarioAnalysisBuilderTests), and formatting (FloatingPointFormatterTests, FormattedOptimizationResultTests, FormattedDomainResultsTests). Companion to the seventeen preceding domain reviews.*

*All reference values recomputed in Python with numpy.*

## 1. Summary

**`MergeLeakRepro` is the best async test in the corpus**, and it is the only one that tests a resource-lifetime property rather than a value. The subject is a producer-task leak: an infinite source, merged, consumed briefly, then abandoned. The question is whether the producer stops pulling. The test answers it by giving the source an actor-backed counter, taking five elements, breaking, then sampling the count twice with 50 and 250 `Task.yield()`s between. If the producer leaked, the second sample keeps climbing.

That shape — instrument the thing that should stop, then check it stopped — is what makes a cancellation test possible at all. Everything else in the corpus that touches structured concurrency asserts on values and would pass with a leaked task still running.

**`StreamingFrequencyDomainTests`' Parseval test documents a tightening the whole corpus needs.** The comment is explicit:

> "Tightened in v2.1.3: previously this used `0.5 < ratio < 2.0`, a 2× margin in either direction so loose it would have passed even with major numerical bugs. Parseval's theorem holds at machine precision for this discrete formulation, so the assertion is now `1e-12` relative tolerance."

I confirmed the ratio is exactly 1.0 for that signal and formulation, so 1e-12 has margin to spare. The same file also has the batch's best differential test: Accelerate versus pure-Swift FFT compared bin-for-bin, which is a genuine second implementation rather than a reference value.

**`TimeWindowedTests` avoids sleeps entirely**, building `Timestamped` values at synthetic offsets from a single `ContinuousClock.now` reference. That is the same technique `ModelProfilerTests` uses with its injected clock, arrived at independently, and it is why an 18-reference-to-milliseconds file has no timing flakiness.

**Against that, about 17 assertions across the streaming files are `results.count >= 1`** (§2 item 1) — "the stream produced something" from a stream with fully known input. And the formatting tests assert `formatted.contains("3")`, which almost any output satisfies (§2 item 3).

### Templates to copy

| Kind of test | Copy from |
|---|---|
| Task cancellation and resource lifetime | MergeLeakRepro |
| Two backends for the same computation | StreamingFrequencyDomainTests (`Accelerate FFT: matches Pure Swift bin-for-bin`) |
| A mathematical identity as an oracle | StreamingFrequencyDomainTests (Parseval at 1e-12) |
| Time-dependent behaviour without sleeps | TimeWindowedTests (synthetic timestamps) |
| Hand-derived arithmetic per component | CashFlowBuilderTests |

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`results.count >= 1` is the dominant streaming assertion** | 9 in StreamAlignmentTests, 7 in StreamingAnomalyDetectionTests, 1 in StreamingForecastingTests. In every case the input stream is a fixed array, so the output count is determined. `#expect(results.count >= 1)` passes for an operator that drops 90% of its input. | Assert the exact count. Where an async operator genuinely has a race in how many elements survive, that race is the bug — `StreamAlignmentTests` has `results.count <= primaryCount` and `resultCount <= 1000`, which suggests the counts are believed nondeterministic. If so, that belongs in a doc comment, and the test should pin the bound the operator guarantees. |
| 2 | **`#expect(hasNaN \|\| hasNonNaN)` cannot fail** | StreamAlignmentTests:222. Every value is either NaN or not, so the disjunction is exhaustive. The only way to fail is an empty collection, and `results.count >= 1` two lines up already covers that. | Decide what the operator should do with a NaN in the secondary stream — propagate, skip, or interpolate around — and assert it. This is the contract-free disjunction pattern in its purest form yet. |
| 3 | **Formatter tests assert single-digit substrings** | `#expect(result.formattedSolution.contains("3"))`, `contains("0"))`, `contains("123"))`. "3" is satisfied by "13", "0.3", "23.7" or "-1.5" alongside anything else in the string. FormattedOptimizationResultTests has about eight of these. | The *negative* assertions in the same tests are the strong ones — `!description.contains("2.9999")` and `!formatted.contains("99")` would catch the defect the file exists for. Pair each positive check with an exact expected string: `#expect(result.formattedSolution == "[3, -1.5]")` or whatever the format is. `formattedObjectiveValue == "0"` is already the right shape. |
| 4 | **`#expect(nearest != interpolation)` uses `!=` on Doubles** | StreamAlignmentTests:167, asserting that two alignment strategies differ. A one-ulp difference passes, and per FloatingPointClaims the form also passes when one side has gone NaN. | `#expect(!identical(nearest, interpolation))` states the weak claim correctly; better still, assert the specific values each strategy should produce for the fixture, since both are computable from the timestamps. |
| 5 | **A timing tolerance inside a value assertion** | StreamAlignmentTests:135: `#expect(abs(results[0].1 - 5.0) < 0.5)  // Allow tolerance for async timing`. The secondary value should be 5.0 exactly if the alignment picked the right sample; a 0.5 window means it would also pass having picked a neighbouring one. | If the timestamps are synthetic, the answer is exact and the tolerance should be 1e-10 like its sibling on line 134. If they are real, use synthetic timestamps as `TimeWindowedTests` does. |
| 6 | **FFT peak frequency asserted within 2 Hz at 1 Hz resolution** | `pureSwiftFFTSinusoid` uses n = 256 at 256 Hz for a 10 Hz sinusoid, so bin 10 is exactly 10.0 Hz and the peak lands there with zero error (verified). The assertion `abs(peakFreq - signalFreq) < 2.0` admits bins 9, 10 and 11. | `#expect(peakBin == 10)`. The frequency is exactly representable because the signal frequency is an integer multiple of the resolution, which is presumably why those parameters were chosen. |
| 7 | **`dcPower > totalNonDC` is weaker than the property** | For a constant signal, *all* power is at bin 0 and every other bin is zero to rounding. The test asserts only that DC exceeds the sum of the rest. | `#expect(totalNonDC < 1e-20 * dcPower)` or similar. A leakage bug that put 30% of the power in bin 1 would pass the current form. |
| 8 | **The integer-truncation defect family reappears** | `FormattedOptimizationResultTests` asserts `intSolution[0] == 100  // NOT 99!` and `intSolution[2] == 80  // NOT 79!`. That is the same class as `IntegerTruncatedConstantTests` from the probability batch: a `Double` at 99.9999999 truncating rather than rounding. | Good that it is pinned. Worth adding the boundary: exactly 99.5 and exactly 100.5, to fix the rounding rule (`.toNearestOrAwayFromZero` vs `.toNearestOrEven`) — the same open question the operational-driver review raises for headcount drivers. |
| 9 | **`Task.sleep` appears once, in a test helper** | StreamingCompositionTests:408, inside what appears to be a delayed-source helper. Nine sleep-adjacent references in that file resolve to one actual sleep. | Better than the corpus average. Worth confirming the delay is only used to interleave two sources rather than to establish a timing property — if a test asserts ordering that depends on the sleep landing, it is a wall-clock test. |

## 3. What the strong files establish

### 3.1 The leak test

`MergeLeakRepro` is 58 lines and worth reading in full as a template. Three details make it work:

- **The instrument is in the source, not the test.** `InfiniteCounter.next()` bumps an actor-backed counter on every element, so the count measures pulls rather than anything the consumer observed.
- **Two samples, not one.** `after` (50 yields) establishes a baseline post-teardown; `later` (250 more yields) detects continued growth. A single sample could not distinguish "stopped" from "stopped soon after".
- **The tolerance is stated as a bound on drift, not equality.** `later - after <= 2` allows a couple of in-flight elements without allowing unbounded growth. That is the honest reading — a cancelled task may have one pull already in progress.

The gap: this pattern is applied to `merge` only. `zip`, `combineLatest`, the windowing operators and the alignment operators all spawn producers and all have the same failure mode. One parameterised version over the composition operators would cover them.

### 3.2 The FFT backend comparison

`Accelerate FFT: matches Pure Swift bin-for-bin (tightened in v2.1.3)` compares two independent implementations bin by bin. That is the differential-testing pattern the optimization review recommends for the matrix backends, and the one the simulation review found missing for GPU-versus-CPU.

It is stronger than a reference fixture here for the reason `LinearProgrammingCertificateTests` gives about its vertex enumerator: the two implementations share no code, so an agreement is evidence, and a disagreement localises to one of them.

Two extensions worth adding:

- **A signal where the two backends' internal precision differs most** — a long signal with a large dynamic range, where accumulated rounding diverges. The current fixture is presumably well-conditioned.
- **`PowerSpectralDensityTests` has no equivalent.** If PSD has both a pure-Swift and an Accelerate path, the same comparison applies.

### 3.3 The builders

`CashFlowBuilderTests` is the best of the three builder files, and better than the fluent-API builders reviewed earlier, for one reason: every assertion carries its arithmetic and most values are exact.

| Assertion | Arithmetic |
|---|---|
| `year2 == 1_150_000` | 1M × 1.15 |
| `q1 == 300_000` | 250k × 1.2 |
| `year2Q1 == 360_000` | 250k × 1.2 × 1.2 |
| `expenses2M == 800_000` | 40% of 2M |
| `annualDepreciation == 100_000` | 1M / 10 |
| `taxOnIncome == 270_000` | (21% + 6%) of 1M |

Several use `==` on `Double` directly, which is correct here: these are products of exactly-representable values. `identical` would state it more precisely, and the mixed use of `==` and `abs(...) < 0.01` across the file is worth unifying.

Two gaps: the depreciation test checks years 1, 5, 10 and 11 but not year 0, and no builder test covers a composition where a percentage-of-revenue expense and a one-time expense land in the same year — the interaction case.

## 4. Coverage gaps

**Streaming.**
- **Cancellation for every composition operator** (§3.1), not just `merge`.
- **Backpressure**: a slow consumer against a fast producer. Whether the operator buffers unboundedly is a memory-leak question the leak test's technique could answer.
- **Error propagation**: a source that throws mid-stream. Does the merged stream surface the error, and are the other producers cancelled?
- **`StreamingStatisticsTests`' rolling window at boundaries**: window larger than the stream, window of 1, window of 0.
- **Rolling variance convention**: the tests assert 1.0 for a fixture whose values presumably step by 1, but whether the rolling variance is sample or population is not pinned. This is the same open question the statistics review raises for `weightedVariance`.

**Formatting.**
- **Locale.** Every expected string uses `.` as the decimal separator. If the formatter uses `NumberFormatter` anywhere, a machine set to a comma-decimal locale produces `"0,75"` and every test fails. That is the same class as the ambient-calendar finding, and the fix is the same: pin the locale.
- **Rounding half-way cases** (§2 item 8).
- **Significant figures at the boundary**: I verified 123456.789 → 3 sf = 123000 and 4 sf = 123500, both correct. Missing is what happens at 5 sf where the next digit is exactly 5 (123456.789 → 123460), and negative significant-figure counts.

**Builders.**
- Empty builder bodies for all three.
- A builder with two components of the same name.
- `ValuationBuilderTests` and `ScenarioAnalysisBuilderTests` overlap the scenario-analysis and valuation domains; worth checking the builders and the direct APIs agree, which is the delegation property `TemplateDelegationTests` established.

## 5. Recommended order of work

1. **Replace the 17 `results.count >= 1` assertions with exact counts** (§2 item 1). If any count is genuinely nondeterministic, document why and pin the guaranteed bound.
2. **Extend the leak test to every composition operator** (§3.1). This is the highest-value addition: the technique exists, the defect class is proven, and the coverage is one operator wide.
3. **Fix the tautology and the weak comparisons** (§2 items 2, 4, 5).
4. **Pin exact strings in the formatter tests** and add the locale test (§2 item 3, §4).
5. **Tighten the FFT peak and DC assertions** (§2 items 6–7) — both are exact for their fixtures.
6. **Add the rounding half-way cases** (§2 item 8) and settle the rule.
7. **Pin the rolling variance convention** (§4).
8. **Add the backpressure and error-propagation tests** (§4).

## 6. Gate rules

One new rule, precise and cheap:

**Exhaustive disjunction (blocking).** Flag an `#expect` whose operand is `A || B` where `B` is the syntactic negation of `A`, or where the pair is a known exhaustive predicate split — `isNaN || !isNaN`, `hasNaN || hasNonNaN`, `x >= 0 || x < 0`. This is narrower than the contract-free-disjunction advisory and admits no false positives. Three sites across the corpus: this batch's `hasNaN || hasNonNaN`, the portfolio review's `sharpe >= 0.0 || sharpe < 0.0`, and the binomial descriptor suite's three-way NaN-or-zero-or-negative chains.

Existing rules that apply:

- **Weak count assertions.** `results.count >= 1` is a new shape for the assertion-strength advisory, alongside range and sign checks — worth listing explicitly since it is this domain's dominant form.
- **String-content dominance (advisory).** The three formatting files would trip it; single-character substring checks are the weakest instance seen so far and arguably deserve their own blocking rule.
- **`!=` on floating point (blocking).** §2 item 4.
- **Ambient locale in a test.** Not previously proposed. The ambient-calendar rule should extend to `Locale.current` and to any `NumberFormatter` without an explicit locale, for the reason in §4.

## Appendix. Verified values

### A.1 FFT and spectral

| Quantity | Value |
|---|---|
| 10 Hz sinusoid, n = 256, sr = 256 Hz: peak bin | **10** exactly (10.0 Hz, zero error) |
| Frequency resolution at those parameters | 1.0 Hz |
| Parseval ratio for sin(2π·10t) + 0.5cos(2π·25t), n = 256 | **1.0** exactly |
| Band power 10 + 20 + 15 | 45.0 exactly |

### A.2 Significant figures

| Input | 3 sf | 4 sf |
|---|---|---|
| 123456.789 | **123000** | **123500** |
| 1.23456789 | **1.23** | **1.235** |
| 0.00123456789 | **0.00123** | **0.001235** |

All six confirmed. Note 4 sf of 123456.789 rounds up because the fifth digit is 5.

### A.3 Cash flow builder

| Quantity | Value |
|---|---|
| Revenue year 2 at 15% growth on 1M | 1,150,000 exactly |
| Q1 with 1.2 seasonality on 250k | 300,000 exactly |
| Year 2 Q1 (growth × seasonality) | 360,000 exactly |
| Variable expenses, 40% of 2M | 800,000 exactly |
| Straight-line depreciation, 1M over 10 years | 100,000 exactly |
| Combined tax, 21% federal + 6% state on 1M | 270,000 exactly |

### A.4 Streaming statistics fixtures

| Quantity | Value |
|---|---|
| Rolling mean, window 3, over [1,2,3,4,5] | 2.0, 3.0, 4.0 |
| Cumulative mean over [1,2,3,4,5] | 1.0, 1.5, 2.0, 2.5, 3.0 |
| Rolling variance, window 3, consecutive integers | 1.0 (sample convention) or 2/3 (population) — the fixture asserts 1.0, so the convention is sample |
| Rolling sum, window 3, over [1,2,3,4,5] | 6.0, 9.0, 12.0 |
