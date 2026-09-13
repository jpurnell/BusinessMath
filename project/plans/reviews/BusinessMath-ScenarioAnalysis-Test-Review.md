# BusinessMath scenario analysis tests: review

*September 2026. Covers 7 files: ScenarioRunnerTests, ScenarioTests, FinancialProjectionTests, FinancialSimulationTests, SensitivityAnalysisTests, TornadoDiagramTests, IntegrationExampleTests. Companion to the distribution, simulation, statistics, time-series, Bayes and financial-ratio reviews.*

*All reference values recomputed in Python; failure rates by simulation where noted.*

## 1. Summary

This suite contains the best error-handling tests in the corpus and the corpus's weakest statistical assertions, often in the same file.

**The driver-name validation tests are exemplary.** Six tests across SensitivityAnalysisTests and TornadoDiagramTests cover a real and easily-missed defect: a misspelled driver name silently producing a flat curve rather than an error. They check the specific error case (`.invalidDriver`), the error code (`E200`), that the message names *all* unknown drivers rather than just the first ("Unknown names: Revenu, Cost"), that the message lists the available names so the user can see the typo, and — the sharpest part — that validation happens *before* any projection runs. That last one uses a `BuilderRan` sentinel error thrown by a builder that must never be invoked, so the test fails distinctly if validation is moved after the base-case projection. That is a stronger error test than anything else in the corpus.

`taxRateNoImpactOnPreTax` is the other standout: it constructs a model where the tax rate affects the balance sheet and cash flow but not pre-tax income, then asserts the tornado impact for Tax Rate is below 1e-12. A tornado implementation that varied the wrong driver, or that leaked the output metric across drivers, fails it.

**Against that, the simulation tests are unseeded and loosely bounded.** `runFinancialSimulation` takes no seed — a comment in FinancialSimulationTests says so explicitly, describing it as "one of the seedless wrappers over seeded primitives recorded in the master plan" — so about 15 tests draw fresh random values each run. Their tolerances are wide enough that this rarely flakes, which is the problem: several are wide enough to pass a badly wrong implementation too.

The main findings:

1. **`runFinancialSimulation` cannot be seeded** (§2 item 1). This is a library gap, and it is why the statistical tests are bounded the way they are.
2. **Two tests in IntegrationExampleTests are `.disabled` with no bug reference,** and the disable reasons read as descriptions rather than explanations (§2 item 4).
3. **About 20 assertions are orderings or sign checks** where a distribution-level or exact check is available.
4. **The percentile-of-a-constant test is the one genuinely fragile spot**, and it is fragile in the safe direction.

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`runFinancialSimulation` takes no seed** | The comment at FinancialSimulationTests:652 states it directly. Roughly 15 tests therefore draw fresh values per run: `financialSimulationProducesDifferentResults`, `percentileCalculation`, `confidenceIntervals`, `varCalculation`, `cvarCalculation`, `probabilityOfLoss`, `manyIterations`, `percentilesMonotonic`, `sampleMeanAndStdDev`, `cvarMonotonic`, and the ScenarioRunner probabilistic test. | Add a `seed:` parameter, as the simulation-domain review recommends for `ScenarioAnalysis` and `SensitivityAnalysis`. Until then the tolerances below must stay wide, and that is a coverage ceiling rather than a choice. |
| 2 | **`ScenarioRunner`'s probabilistic sampling is also unseeded** | `runnerWithProbabilisticDrivers` asserts `!allSame` and `abs(mean - 1000.0) < 200.0`. | Same fix. |
| 3 | **Builder errors are asserted as `(any Error).self`** | `ScenarioRunnerTests:497`. This is the loosest possible error assertion, in a file whose sibling tests pin `.invalidDriver` with its code. | Assert the specific error the builder throws, and that it propagates unwrapped rather than being rewrapped. |
| 4 | **Two `.disabled` tests with no bug reference** | `@Test(.disabled("Project deterministic path over multiple periods"))` and `@Test(.disabled("Run Monte Carlo simulation"))` in IntegrationExampleTests. Both reasons describe what the test does, not why it is off. Both bodies contain substantial assertions (percentile ordering, per-quarter counts, mean-versus-median skew). | Either fix and re-enable, or convert to `withKnownIssue` with a `.bug(…)` trait so they run and turn red when the underlying problem is fixed. As written, nobody can tell what would need to change. The corpus's own MonteCarloGPUPerformanceTests header makes this point: "disabled means nobody can run it without editing the file." |
| 5 | **`IntegrationExampleTests` asserts on generated names** | `model.revenue.name.contains("×")` and `model.profit.name.contains("-") \|\| .contains("+")`. This pins a display-string convention as a correctness property. | Assert the composed driver's *value* relationship instead (revenue = users × price at a fixed sample), which is what the name is standing in for. |
| 6 | **`profitUncertainty` ends with a commented-out intent** | "Q4 might have higher absolute uncertainty due to scale but coefficient of variation should be similar" — the CV comparison is described and not written. The test asserts only `stdDev > 0.0` per quarter. | Write the CV assertion, or delete the comment. A stated-but-unwritten property is worse than no comment, since it reads as covered. |

## 3. Fragile and loose statistical assertions

**The one genuinely fragile test:**

`percentileCalculationWithEdgeCases` uses a `DeterministicDriver` at 1000.0 and asserts p10 = p50 = p90 = 1000.0 at ±0.01. That is correct and exact — a deterministic driver has zero variance, so every percentile is 1000. Worth noting as the right pattern: it is the only simulation test in the file that is deterministic by construction rather than by luck.

**Loose assertions, with what a correct implementation would actually produce.** The driver in most tests is Normal(1000, 100):

| Test | Assertion | In standard errors / notes |
|---|---|---|
| `financialSimulationProducesDifferentResults` (n=100) | `abs(mean - 1000) < 100` | SE = 10, so 10 SE |
| `percentileCalculation` (n=1000) | `abs(p50 - 1000) < 50` | Median SE ≈ 3.96, so ~12.6 SE |
| `confidenceIntervals` (n=1000) | `abs(mean - 1000) < 100` | SE ≈ 3.16, so ~32 SE |
| `confidenceIntervals` CI-vs-percentile | `abs(ci.lowerBound - p05) < 10.0` | Discriminating if the CI is percentile-based; vacuous if it *is* the percentile. Worth checking which. |
| `probabilityOfLoss` | `probLoss > 0.0 && < 0.10` | For Normal(1000, 100) against a threshold implying a loss, P(X < 0) = Φ(−10) ≈ 7.6e-24. If the threshold is 0, `probLoss > 0.0` is essentially impossible to satisfy and this test would fail — so the threshold must be elsewhere. Worth pinning what it is. |
| `manyIterations` (n=10000) | `abs(mean - 1000) < 20` | SE = 1, so 20 SE |
| `sampleMeanAndStdDev` | `abs(mean - 1000) < 5 * se` | **Correctly derived** — the one test in the file that computes its own bound. |
| `sampleMeanAndStdDev` stdDev | `abs(sd - 100) < 15` | SE of sd ≈ 100/√(2n); at n=1000 that is 2.24, so ~6.7 SE |
| `runnerWithProbabilisticDrivers` (n=?) | `abs(mean - 1000) < 200` | Very wide |
| `varCalculation` | `abs(var95 - p05) < 1.0` | Discriminating *only* if VaR is computed independently of the p05 percentile; otherwise it is the same tautology flagged in the simulation review. |
| `cvarCalculation` | `cvar95 <= var95` | True by definition of a conditional tail expectation. |
| `cvarMonotonic` | `cvar95 <= cvar90` | Also definitional. |
| `percentilesMonotonic` | each ≥ previous | Definitional for a sorted-percentile implementation. |

`sampleMeanAndStdDev` shows the fix for all of them: derive the bound from the standard error. At 4 SE these become real tests that still essentially never flake, and they would then also survive the seeding change in §2 item 1 without re-tuning.

**IntegrationExampleTests' bands** are the widest in the suite: `avgRevenue >= 64_000 && <= 180_000` for a quantity centred near 100,000, and `avgHeadcount >= 15 && <= 30` for a value near 20. `avgFixed >= 49_000 && <= 51_000` is tight by comparison and is the model. The `validateQ4SeasonalBoost` test is better still: it asserts the boost is between 12% and 18% against a stated 15% target, with the margin explained by rounding.

## 4. Assertions that cannot fail

| Test | Why |
|---|---|
| `financialProjectionCreation`, `storesScenarioReference`, `preservesScenarioMetadata`, `withEmptyScenarioOverrides`, `multipleProjectionsMaintainIndependence` | These assert that values passed into an initialiser come back out: `projection.scenario.name == "Test Scenario"`, `projection.entity.id == "TEST"`, `assumptions["Market Growth"] == "5% annually"`. Five tests of struct field storage. `multipleProjectionsMaintainIndependence` asserts only that two differently-named scenarios have different names. |
| `emptyScenarioUsesAllProvidedDrivers` | Asserts `scenario.name == "Empty"` and `driverOverrides.isEmpty` — both restating the construction. The test's *name* promises that all provided drivers are used, which is not checked. |
| `tornadoPreservesBaseCaseValue` | Asserts `baseCaseOutput > 0.0` and that each low/high bracket contains it. The bracket property holds for any monotone response and any symmetric variation. |
| `tornadoRanksInputsCorrectly` | Asserts `topInput == "Volume" \|\| topInput == "Price"` — an either/or on a two-horse race, then `impact > 0.0` for each. The ranking itself is computable from the model. |
| `tornadoWithManyInputs` | Five inputs, asserts each impact `>= 0.0` and four specific ones `> 0.0`, plus descending order. Descending order is a sort property of the implementation, not of the model. |
| `sensitivityAnalysisFindsBaseCaseInResults` | Asserts a boolean the test itself computed by scanning for the base value. |
| `knownDriverStillMovesOutput` | `Set(outputValues.map { $0.description }).count == 9` — asserts nine distinct outputs from nine distinct inputs. Reasonable, but mapping through `.description` makes it a string-distinctness test; comparing the Doubles directly is stronger and avoids formatting coincidences. |
| `profitUncertainty` | `stdDev > 0.0` per quarter (§2 item 6). |
| `sampleAllModelComponents` bounds | `users >= 0.0`, `headcount >= 0.0`, `profit.isFinite`. The integer checks (`users == users.rounded()`) are genuinely discriminating and worth keeping. |

The tornado and sensitivity *structural* assertions (input counts, grid dimensions, `inputValues.count == 11`, row widths) are fine as-is — they are cheap contract checks on the returned shape, and the grid test correctly verifies both dimensions.

## 5. What the strong tests establish, and what to extend

The six driver-validation tests cover: single typo rejected, all typos reported, validation before projection, and the two-way variant for both the first and second driver. Three extensions are worth adding in the same style:

1. **A driver name that is valid but not in the base case's overrides.** The current tests misspell a name that exists; the other failure is naming a driver the scenario never defined. Same error, different path.
2. **An empty `inputDrivers` array** for the tornado, and a zero-width `inputRange` for sensitivity (`1000.0...1000.0`). `sensitivityWithSingleStep` covers steps = 1; a degenerate range is different.
3. **A builder that throws on a specific driver value** — the interaction between builder errors and sensitivity iteration. Currently only the base-case builder error is tested (ScenarioRunnerTests), and loosely (§2 item 3).

`taxRateNoImpactOnPreTax` also suggests a generalisation: for a model with a known analytic response, every tornado impact is computable. With price 100, volume 1000, cost 60, opex 10,000 and ±20% variation, the pre-tax income impacts are exact. Pinning all four (including Tax Rate's zero) turns the ranking tests from orderings into equalities.

## 6. Coverage gaps

- **`FinancialProjectionTests`' good tests are at the end**: `incomeStatementSumsMultipleRevenueAccounts` (uses `identical`), `accountingEquationHolds` for all periods, and `freeCashFlowEqualsOperatingPlusInvesting` at 1e-9. These are real invariants. The five field-storage tests at the top of the file should be replaced by more of this kind.
- **No scenario comparison at the statement level.** `compareProjectionsFromDifferentScenarios` pins net income at 400 and 900 exactly, which is good, but nothing checks that the *unaffected* accounts are identical across scenarios — the analogue of the tax-rate test, and the check that would catch a scenario leaking overrides into accounts it should not touch.
- **No test that two runs of the same deterministic scenario are identical.** With `DeterministicDriver` throughout, `runScenario` should be reproducible bit-for-bit; `identical` on the two results' value arrays states it.
- **Two-way sensitivity's grid orientation is only checked by `bottomLeft < topRight`.** Whether `results[i][j]` is (driver1 = i, driver2 = j) or the transpose is never pinned. With asymmetric drivers, one specific cell fixes it.
- **`ScenarioTests`** was not covered in detail above; it overlaps `ScenarioRunnerTests` on metadata and override counting.

## 7. Recommended order of work

1. **Add a seed to `runFinancialSimulation` and `ScenarioRunner`'s sampling** (§2 items 1–2). Everything statistical downstream depends on it.
2. **Resolve the two `.disabled` tests** (§2 item 4) — they contain real assertions that currently run nowhere.
3. **Convert the statistical bounds to standard-error multiples**, following `sampleMeanAndStdDev`. This is mechanical and survives the seeding change.
4. **Check whether VaR and the confidence interval are computed independently of the percentiles** they are compared against; if not, those two tests are tautologies.
5. **Pin the tornado impacts exactly** for the analytic model, generalising `taxRateNoImpactOnPreTax`.
6. **Replace the five field-storage tests** in FinancialProjectionTests with invariants in the style of its own last three tests.
7. **Assert the specific builder error** (§2 item 3) and add the three validation extensions from §5.
8. **Fix the name-based assertions** (§2 item 5) and write the CV comparison (§2 item 6).

## 8. Gate rules this suite exercises

Existing proposals that apply:

- **Transitive unseeded set.** `runFinancialSimulation` has no `seed:` parameter to omit, so the rule as originally stated passes it. This suite is a second instance of the case that motivated the transitive version: compute from the library's call graph which functions reach unseeded randomness, then flag test calls into them. That rule catches all 15 tests here.
- **`.disabled` requires `.bug(…)`.** Both IntegrationExampleTests cases.
- **Field-storage tests (advisory).** Five in FinancialProjectionTests, plus parts of ScenarioRunnerTests.
- **Error asserted by type only.** `(any Error).self` in ScenarioRunnerTests is the loosest form and worth flagging separately from `SomeError.self`.
- **String-content assertions.** `model.revenue.name.contains("×")` is the correctness-property-as-display-string case; the existing advisory rule targets `summary.contains(...)` on descriptions and should cover this shape too.

One refinement worth adding: **flag a trailing comment in a test that states a property in the subjunctive** ("should be similar", "might have higher") with no assertion after it. `profitUncertainty` is the instance. This is narrow but it catches exactly the "documented but unwritten" case, which reads as coverage in review.

## Appendix. Reference values

**Normal(1000, 100) driver, standard errors:**

| n | SE of mean | SE of median | SE of sd |
|---|---|---|---|
| 100 | 10.0 | 12.5 | 7.07 |
| 1,000 | 3.16 | 3.96 | 2.24 |
| 10,000 | 1.00 | 1.25 | 0.71 |

**Tail probability:** P(X < 0) for Normal(1000, 100) = Φ(−10) ≈ 7.62e-24.

**Tornado analytic model** (price 100, volume 1000, cost 60, opex 10,000; pre-tax income = price×volume − cost×volume − opex = 30,000):

| Driver | −20% | +20% | Impact (high − low) |
|---|---|---|---|
| Price | 10,000 | 50,000 | 40,000 |
| Volume | 22,000 | 38,000 | 16,000 |
| Cost | 42,000 | 18,000 | 24,000 |
| Tax Rate | 30,000 | 30,000 | 0 (pinned at <1e-12) |

Correct descending ranking: Price, Cost, Volume, Tax Rate. Note that `tornadoRanksInputsCorrectly` accepts `topInput == "Volume" || topInput == "Price"`; on this model Price dominates Volume by 2.5×, so the either/or is unnecessary once the values are pinned.

**Deterministic percentile case:** a `DeterministicDriver(value: 1000.0)` yields p10 = p50 = p90 = 1000.0 exactly, for any iteration count.
