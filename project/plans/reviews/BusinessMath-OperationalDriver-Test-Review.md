# BusinessMath operational driver tests: review

*September 2026. Covers 6 files: DriverTests, ConstrainedDriverTests, TimeVaryingDriverTests, DriverProjectionTests, SeededDriverSamplingTests, ProjectionResultsPercentileTests. Companion to the distribution, simulation, statistics, time-series, Bayes, financial-ratio and scenario-analysis reviews.*

*All reference values recomputed in Python.*

## 1. Summary

This is the most consistently well-tested of the three suites in this batch, and `SeededDriverSamplingTests` is the reason. It establishes the property the rest of the driver layer depends on: that a driver given the same seed produces the same draw, and that different seeds diverge. Once that holds, the composition tests (`CompositeDriver`, `ConstrainedDriver`, `TimeVaryingDriver`) can be checked as exact identities against their component drivers rather than statistically — and several of them are.

The suite's structure is right: a seeding contract, then per-driver-type behaviour, then composition, then projection aggregation. What is missing is mostly at the edges of that structure.

The main findings:

1. **`ConstrainedDriver`'s clamping changes the distribution, and no test measures the distortion** (§2 item 1). This is the same class of finding as the `[0.0001, 0.9999]` clamp in the distribution review: a bound that silently truncates a tail while every test still passes.
2. **The rounding convention for integer drivers is never pinned** (§2 item 2). `users == users.rounded()` establishes integrality but not which rounding rule, and `.toNearestOrAwayFromZero` versus `.toNearestOrEven` differ on exact halves.
3. **`TimeVaryingDriver`'s behaviour outside its defined periods is untested** (§2 item 3).
4. **`ProjectionResultsPercentileTests` checks percentile ordering but not the interpolation method**, which is the same gap the statistics review found in `PercentilesTests` — and the two may not agree.

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`ConstrainedDriver` clamping distorts the distribution, unmeasured** | The tests confirm that a clamped draw lands within bounds and that an unconstrained draw is passed through unchanged. Neither measures what the clamp does to the distribution's moments. For a Normal(1000, 100) driver clamped to [900, 1100] — a ±1σ window — the truncated mean is still 1000 by symmetry, but the standard deviation falls from 100 to about 60.6, and roughly 31.7% of draws land exactly on a boundary. A test asserting "mean is near 1000" passes while the distribution is no longer normal in any useful sense. | Add a test that measures the boundary mass at a known clamp, and document that clamping produces a point mass at each bound rather than a truncated distribution. If truncation (resample until in range) was intended, that is a different implementation and the tests would not currently distinguish them. |
| 2 | **The rounding rule for integer-valued drivers is unpinned** | `IntegrationExampleTests` (scenario suite) asserts `users == users.rounded()` and `headcount == headcount.rounded()`, establishing integrality. Nothing pins the rule. Swift's `.rounded()` defaults to `.toNearestOrAwayFromZero`, so 0.5 → 1 and 1.5 → 2; `.toNearestOrEven` gives 0 and 2. For a headcount driver derived as users/50, an exact half is reachable (e.g. 1025/50 = 20.5). | Pin the rule with a driver whose value lands exactly on .5, and document it. Headcount rounding that differs between platforms or between the driver and a downstream consumer is a silent payroll discrepancy. |
| 3 | **`TimeVaryingDriver` outside its defined periods** | The tests cover sampling within the defined schedule and that different periods give different values. Nothing covers a period before the first, after the last, or absent from the middle of the schedule. | Decide and pin: nil, the nearest defined value, an extrapolation, or a thrown error. A projection that silently extends a Q4 seasonal factor into the following year is the kind of error a reader would not catch. |
| 4 | **Percentile interpolation method unpinned, and possibly inconsistent** | `ProjectionResultsPercentileTests` asserts p5 < p25 < p50 < p75 < p95 and that percentiles are finite. The statistics review found the same gap in `PercentilesTests`, where the R-7 values on 1…100 are exact (5.95, 25.75, 50.5, 75.25, 95.05) but checked at ±0.1, and a `customPercentile` window admitted both R-6 and R-7. If the projection-results percentiles go through a different code path than `quantile(sorted:p:)`, the two could disagree. | Pin one method, and add a delegation test showing `ProjectionResults.percentiles` uses the same implementation as the library's `quantile`. This is the third or fourth percentile convention in the library, per the statistics review's finding on `weightedPercentile`. |
| 5 | **`CompositeDriver` name composition is asserted as a correctness property** | Noted in the scenario review: `model.revenue.name.contains("×")`. The driver suite's equivalent is testing that a composite's name reflects its operation. | Assert the value relationship at a fixed seed instead — `identical(composite.sample(for: p), a.sample(for: p) * b.sample(for: p))` — which is what the name stands in for and which the seeding contract makes checkable. |

## 3. What `SeededDriverSamplingTests` establishes, and how to use it

The seeding contract is the suite's foundation, and it enables exact composition tests that are currently statistical or ordinal. Three worth adding:

**Composite identity.** With the same seed threaded to both the composite and its components:

```swift
@Test("A composite driver is exactly the operation applied to its components")
func compositeIsExactlyItsOperation() {
    let a = ProbabilisticDriver(name: "A", distribution: .normal(mean: 1000, stdDev: 100))
    let b = ProbabilisticDriver(name: "B", distribution: .normal(mean: 100, stdDev: 10))
    let product = CompositeDriver(name: "A × B", lhs: a, rhs: b, operation: .multiply)
    for seed in seeds {
        // Each component draws from its own stream; the composite must combine
        // exactly those two draws, not two fresh ones.
        #expect(identical(product.sample(for: p, seed: seed),
                          a.sample(for: p, seed: seed) * b.sample(for: p, seed: seed)))
    }
}
```

This catches a composite that re-draws its operands, which would still produce plausible means and pass every current test.

**Constrained identity.** `ConstrainedDriver` should be exactly `min(max(inner, lower), upper)` at every seed. That is one assertion covering the pass-through case, both clamp directions, and the boundary.

**Time-varying identity.** For a period in the schedule, the value should be `identical` to the underlying driver's value scaled by that period's factor.

Each of these replaces a band or ordering assertion with an equality, and each fails for an implementation that draws from the wrong stream — the defect the seeding contract exists to make detectable.

## 4. Assertions worth tightening

| Test area | Current | Available |
|---|---|---|
| `DeterministicDriver` | Returns the configured value | `identical`, not a tolerance — it is a stored constant, the case FloatingPointClaims describes |
| `ProbabilisticDriver` mean | Band around the distribution mean | A Kolmogorov–Smirnov test against the distribution's CDF at a fixed seed, as the distribution review recommends throughout |
| `ConstrainedDriver` bounds | Draw lands within [lower, upper] | Exact identity (§3), plus boundary mass (§2 item 1) |
| `TimeVaryingDriver` | Different periods give different values | Exact per-period values from the schedule |
| Composite arithmetic | Result is finite and plausibly scaled | Exact identity against components (§3) |
| `ProjectionResults` percentiles | p5 < p25 < p50 < p75 < p95 | Exact percentiles for a fixed, seeded sample; plus the interpolation-method pin (§2 item 4) |
| `ProjectionResults` statistics | mean and stdDev finite, stdDev > 0 | Both exact for a fixed seeded sample; `identical` against `mean(values)` and the library's `stdDev` |

The ordering assertions on percentiles are definitional for any sorted-percentile implementation, so they cost nothing and prove little. The statistics-versus-percentiles relationship is more interesting: for a fixed sample, `statistics.mean` should be `identical` to the arithmetic mean of the same values, and any divergence points at two different accumulation paths.

## 5. Coverage gaps

**Driver types.**

- **Degenerate distributions.** A `ProbabilisticDriver` with zero standard deviation should behave as a `DeterministicDriver`; nothing checks this, and it is the natural analogue of the scenario suite's good `percentileCalculationWithEdgeCases`.
- **Invalid constraints.** `ConstrainedDriver` with lower > upper, or with NaN bounds. Currently no contract.
- **Empty or single-entry `TimeVaryingDriver` schedules.**
- **Composite with a zero divisor.** Division by a driver that can sample zero — for a Normal driver this is probability zero but reachable in principle, and for a clamped driver whose lower bound is zero it is not.
- **Deeply nested composites.** A composite of composites, which tests that seeding threads correctly through more than one level. This is where a re-drawing bug would compound.

**Projection aggregation.**

- **Single iteration.** `ProjectionResults` from one draw: stdDev is either 0 or NaN depending on the ddof convention, and every percentile equals the single value. The scenario suite tests `iterations: 1` for the simulation path; the driver path should too.
- **All-identical values.** stdDev exactly 0, percentiles all equal — the deterministic case at the aggregation layer.
- **Period with no draws.** If a period is absent from every projection, is the entry nil or an empty statistics object?

**Cross-cutting.**

- **Reproducibility of a whole projection.** Two `projectDeterministic` calls with the same inputs should be `identical` element-wise. This is the driver-layer version of the check the simulation review recommends for `runScenario`.
- **`AnyDriver` type erasure.** That wrapping a driver in `AnyDriver` preserves its sampling exactly — `identical(AnyDriver(d).sample(for: p, seed: s), d.sample(for: p, seed: s))`. The distribution review flags the analogous existential-dispatch trap: if `sample` became an extension-only member, the erased wrapper could silently dispatch to a protocol default and still return a finite, plausible number.

## 6. Recommended order of work

1. **Pin the rounding rule** (§2 item 2). Small, and it is a correctness property of any headcount or unit-count driver.
2. **Add the three composition identities** (§3). These are the highest-value additions, because the seeding contract already makes them cheap and they catch the stream-selection bugs that band assertions cannot.
3. **Measure the clamping distortion** (§2 item 1) and document whether clamping or truncation is intended.
4. **Pin the `TimeVaryingDriver` out-of-schedule contract** (§2 item 3).
5. **Pin the percentile interpolation method** and add the delegation test (§2 item 4). Coordinate with the statistics review's `weightedPercentile` finding, since that is the same decision.
6. **Add the degenerate cases** from §5: zero-variance driver, single iteration, all-identical values, invalid constraints.
7. **Add the `AnyDriver` and whole-projection reproducibility checks.**

## 7. Gate rules this suite exercises

No new rules. Existing proposals that apply:

- **Transitive unseeded set.** Any driver sampling path without a seed parameter, same as the scenario suite.
- **Ordering assertions that are definitional (advisory).** The percentile-monotonicity checks are the clearest instance in the batch: true for any sorted implementation. Worth folding into the assertion-strength rule as a recognised weak shape, alongside range and sign checks.
- **Existential dispatch.** The `AnyDriver` gap is the same shape the distribution review describes for `normalSeedableExistential` — a test that asserts only finiteness where the property at stake is which implementation got called.

One observation for the gate's fixture-coverage report: this suite is a good case for it. The driver *types* are well covered, but the report would show that `ConstrainedDriver`'s distortion, `TimeVaryingDriver`'s out-of-range behaviour and `AnyDriver`'s dispatch have no test at all — gaps that reading the files does not make obvious, because the files look thorough.

## Appendix. Reference values

**Clamping distortion, Normal(1000, 100) clamped to [900, 1100]:**

| Quantity | Unclamped | Clamped |
|---|---|---|
| Mean | 1000 | 1000 (symmetric) |
| Standard deviation | 100 | ≈ 60.6 |
| Mass at each boundary | 0 | ≈ 15.87% each (Φ(−1)) |
| Total boundary mass | 0 | ≈ 31.73% |

**Rounding rule divergence:**

| Value | `.toNearestOrAwayFromZero` (Swift default) | `.toNearestOrEven` |
|---|---|---|
| 0.5 | 1 | 0 |
| 1.5 | 2 | 2 |
| 2.5 | 3 | 2 |
| 20.5 (1025 users / 50) | 21 | 20 |

**R-7 percentiles of 1…100** (for the interpolation-method pin, matching the statistics review): p5 = 5.95, p25 = 25.75, p50 = 50.5, p75 = 75.25, p95 = 95.05. R-6 gives p10 = 10.1 and p90 = 89.9 where R-7 gives 10.9 and 90.1 — the pair that discriminates between the two methods.

**Degenerate cases:**

| Input | Expected |
|---|---|
| `ProbabilisticDriver(stdDev: 0)` | every draw exactly the mean |
| Single-iteration `ProjectionResults` | stdDev 0 (population) or NaN (sample, ddof=1); all percentiles equal the value |
| All-identical values | stdDev exactly 0; all percentiles equal |
