# Handoff — 2026-09-19 (Tier 2: ten items closed, twelve defects and one explanation)

**Six items of Tier 2 closed, seven defects.** The bytecode optimizer,
`RobustOptimizer`/`CuttingPlaneMaster` and `solveRelaxation` shipped as `e70829ac`; `solve`
(160 → 60, two defects) and `MonteCarloExpressionModel.evaluate` as `d3359c3c`; both are inside
**`v3.0.0-alpha.7`**, which a peer session tagged along with its density work. This commit —
`extractVariableShift`, three defects including a **behaviour-breaking default change** — is the
first thing above that tag.

**A peer session is working in this repo concurrently.** It landed `chi2pdf`, a `density`
requirement on `ContinuousDistribution` across 30-odd files, and the alpha.7 tag while this work
was in flight. `git fetch` before assuming the remote is where you left it, and expect
`CHANGELOG.md` to be the only file both sides touch.

The work queue is **`project/plans/TIER2_COMPLEXITY_QUEUE.md`**. That file is the plan; this file
is the state and the traps.

## State

| | |
|---|---|
| branch | `main`, pushed through the gStudy commit |
| tags | latest **`v3.0.0-alpha.7`** (2026-09-18, tagged by the peer session) |
| tests | **7,974 in 731 suites**, exit 0, **zero known issues** |
| gate | `--no-cache --check all` → 45 of 45 ran, **0 errors and 0 warnings outside `doc-run`** |
| `doc-run` | **flaky under load, not a regression** — see §4 |
| guidelines repo | `../../development-guidelines` clean at `a5f9292`, `v2.4.0` tagged and pushed |
| CI | not verified since the Tier 2 sweep began; every commit since is source-touching |

**The known issue is gone, and the invariant has flipped.** `SaaSModel` used to answer a churn
rate above 1 with a negative customer count; the `withKnownIssue` standing in for the missing
validation is now a real test. **A run reporting any known issue at all is a regression.**

Its doc claimed the fix was breaking on *two* public initialisers. `SaaSModel` has exactly one,
and the `var` half of the claim was the real obstacle — see §2.

**The gate's warning count is 0.** The ten standing `[test-quality]` warnings were cleared at
`5de783ca` and the last at `2af9e0ff`. **Any warning at all is now yours.**

Always `--check all`. Plain `--no-cache` runs a subset and prints an identical PASSED line.
`--check` takes **one** checker per flag; `--check a,b,c` prints *"No checkers enabled"* and exits 0.
Tagging does not change what the gate runs — measured both ways on `346a50ad`.

---

## 1. Resume here

Pick the next target from `project/plans/TIER2_COMPLEXITY_QUEUE.md`, and **open it by building an
independent oracle, not by reading it.** Across the whole sweep every defect was found by
differencing against a second opinion and none by inspection, with a green 7,800-test suite
endorsing each wrong answer throughout.

Highest unexamined scores, re-measured on this commit. The table this replaced was stale:
it still listed `icc` at 131 and `bayesianICC` at 101 while §2 of the same file reported both
fixed, because it was copied from the queue snapshot and never refreshed. **Re-measure rather
than trusting it** — `quality-gate --no-cache --no-index-build --check complexity`.

| Score | Function | Where |
|---:|---|---|
| **62** | `solveShape` | `Simulation/distributionMomentFit.swift:460` — now the highest unexamined |
| 60 | `solve` | `Optimization/IntegerProgramming/BranchAndBound.swift:338` |
| 59 | `linearRobustCounterpart` | `AdvancedOptimization/RobustOptimizer.swift:651` |
| 59 | `generalEMUpdate` | `Statistics/MixedModels/Fitting/fitGeneralLME.swift:654` |
| 57 | `detect` | `Forecasting/AnomalyDetection.swift:155` |

Examined, for contrast: `fitGeneralLME` 75, `icc` 73, `gibbsICCPosterior` 58.
`generalAIREMLUpdate` was 121 and is now 19; `gStudy` 85, `bootstrap` 79, `Period.next` 77
and `buildBlock` 68 are all now below the threshold.

**Nothing in `Sources/` scores above 75 any more, and the 100+ band is empty.** Measured
defect yield over the whole programme: **7 of 8 functions scoring >= 95 held a correctness
defect; 0 of 4 below 95 did** — though `buildBlock` at 68 held a *crash*, so the band below 95
is not empty of value, only of the tangled-arithmetic defects the high band was full of. Treat
15 as the gate's note level and ~90 as the "open this with an oracle" line; below that, the
value is decomposition and coverage.

## 2. What closed, and what it cost

### Shipped as `e70829ac`

- **The bytecode optimizer miscompiled every ternary.** `algebraicSimplificationPass`'s
  `default:` branch popped one operand whatever the arity, so `select` (three) and the thirteen
  binary operators left operands for the next instruction's identity rules to claim.
  `(1.0 + (input[0] ? -0.0 : 7.0))` optimised into `input0 ? 1.0 : 7.0`.
- **The cutting-plane certificate was not a certificate.** `CuttingPlaneMaster` read its lower
  bound from the model minimised over the *trust region*. `min |x − 1000|` from `x = 0` returned
  `x = 100` with `optimalityGap: 0.0, converged: true`, after one round.
- **`solveRelaxation` 291 → 55**, stages extracted into `BranchAndBoundCutting.swift`.
- **`RobustOptimizer` audited, clean.** The LP route was confirmed to fire by instrumentation
  (8 of 8 cases), not assumed — iteration count does *not* separate the two routes.

### The suppression sweep — 9 down to 1, and a silently wrong Monte Carlo

Following the bare-suppression trail through the rest of `BusinessMathDSL` found a second
defect, worse than the crash because nothing failed.

- **`Distribution.triangular` sampled from outside its own support.** Its suppression named
  the requirement *"triangular requires max > min"*, and nothing required it — `.triangular`
  is a plain enum case with no validating constructor. Over 20,000 draws, the transposed
  spelling `(0.30, 0.20, 0.10)` put **every** sample outside [0.10, 0.30] and ranged to 0.400;
  a mode outside the range put 17,578 of 20,000 outside. No NaN, no crash, just numbers.
  Now a precondition, with an exit test that checks stderr actually names the requirement.
- **`DCFModel` was the other one.** `waccRate` is now validated where it is read, and both
  divisions guarded where they are used.
- **9 suppressions to 1.** The survivor is `/ 2`, a literal constant. Most were removed by
  `Swift.max(divisor, 1)`, which puts the fact where the compiler and a reader can see it
  rather than asserting it in a comment — and which deleted two special-case branches, since
  one step falls out correctly on its own.
- **The lesson is sharper than "bare suppressions are suspect".** A justification makes a
  suppression *reviewable*, not *correct*: two of the justified ones here were false, and the
  file itself already records a third — *"u1 from random in [0,1)"* given as the reason a
  `log` was safe, which is the interval containing the pole. The only annotation that cannot
  lie is the one that is not needed.

### `buildBlock` — 68 → below threshold, and a crash found by a missing justification

- **`Sensitivity(on:range:steps: 1)` crashed the process.** `steps - 1` is zero, the step size
  came out infinite, `Double(0) * .infinity` gave a NaN multiplier, and the scenario's *name*
  formatted it with `Int(multiplier * 100)` — a trapping conversion. A degenerate range like
  `1.0...1.0` reached the same trap through `0.0 / 0.0`.
- **The marker was a bare suppression.** `Vary` has the identical division, has always
  guarded it, and its `fp-safety:disable` carries the justification that earns it — *"steps >=
  2 from guard above"*. The annotation was copied to the sensitivity path without the guard.
  Of the nine suppressions in `BusinessMathDSL`, seven say why they are safe; **the two bare
  ones are this crash and `DCFModel.swift:179`**. A suppression with nothing written after it
  is where the guard is missing — cheap to grep for, and it found this.
- **`DCFModel.swift:179` is the other one, and is left open deliberately.**
  `tv / pow(1 + waccRate, years)` is a division by zero at exactly −100% WACC, and nothing
  validates `waccRate` — line 159 above it makes the claim "always > 0" that this depends on.
  Far-fetched input, and deciding what a −100% cost of capital *should* do is a design
  question rather than a fix. Flagged, not patched.
- A scenario's name can no longer trap: `percentLabel(_:)` falls back to a plain description.
- **The cartesian product is now pinned** — stacked `Vary` multiplies (`k^n`), the first
  variation seeds rather than multiplying an empty set, and a tornado varies one parameter at
  a time (six scenarios, not nine). Expected sets enumerated directly, not folded.
- Four component cases extracted. Identical on seven declaration shapes by raw bit pattern;
  the only behaviour that changed is the input that used to crash.

### `Period.next()` — 77 → below threshold, no defect, and a lesson about mutations

- **Nine copies of one guard.** Every rung spelled out the same
  `guard let nextDate = calendar.date(byAdding:value:to:) else { return self }`. That is what
  put the function third from the top, and it is the shape that hides a rung quietly
  returning `self` instead of stepping. One `stepped(by:value:rebuild:)` carries it now and
  `next()` is a flat ten-case dispatch.
- **Eight of ten rungs had no direct assertion anywhere.** Only semiannual was tested, plus
  `nextIfSteppable()` returning nil for custom. Millisecond, second, minute, hourly, daily,
  monthly, quarterly and annual were untouched — and those hold December into January, Q4
  into Q1, and February in a leap year.
- **The oracle does calendar arithmetic without a calendar.** Julian day numbers by the
  standard integer algorithm, stepping by integer millisecond addition. `next()` is built on
  `Calendar.date(byAdding:)` and reads back through `dateComponents`, so an oracle using the
  same API could only catch a wrong unit or count. Includes **2100, which is not a leap
  year** — the hundred-year rule, reached by nothing in the package before.
- **Four mutations passed and all four were behaviourally equivalent.** A quarterly period
  re-anchors to a quarter-start month every step, so the month-to-quarter map is only ever
  asked about 1, 4, 7 and 10, exactly where the correct and off-by-one forms agree; a
  four-month step lands on 5, 8, 11, 2, whose quarters are the same sequence. Those
  expressions carry neither risk nor the possibility of proof. **A mutation that does not
  change behaviour is not evidence about a test** — `theComparisonDiscriminates` now supplies
  that evidence directly.
- Identical across eleven seeds and six steps each: start date, type and label unchanged.

### `DiscountCurve.bootstrap` — 79 → below threshold, no defect, and fifty dead lines

- **A whole first pass was computed and discarded.** Fifty lines walked every integer year,
  bootstrapped the quoted tenors and interpolated the rest, and then `dfMap.removeAll()`
  cleared the map before the real solve began. Its own trailing comment explained why that
  pass was unsound; the code was left in anyway. Nothing between the loop and the `removeAll`
  read `dfMap`, so deleting it is **bit-identical** — 79 → 34 from the deletion alone.
- **The gap interpolation was written out three times** — Newton residual, its derivative,
  and the final store. A residual disagreeing with its own derivative shows up only as slow
  convergence, which nothing measures. One helper now serves all three.
- **No defect in the algorithm.** An exact oracle chooses the curve first, derives par rates
  in closed form (`c_N = (1 - DF(N)) / SUM DF(i)`, the exact inverse of the par condition)
  and requires the bootstrap to give the curve back, at the nodes and in the gaps. Worst
  relative gap 1.58e-16, about one ulp. Three mutations caught with 48, 39 and 82 failures.
- **The existing repricing test is genuinely good** — it goes through `discountFactor(at:)`,
  so the interpolation is exercised, and gap DFs enter the annuity. What it could not do is
  check an *answer* rather than a residual, and every case it runs starts at tenor 1. Three
  new ladders quote nothing until year 2, 5 and 10 — the branch that anchors on `DF(0) = 1`
  and fills a gap below the first quoted tenor, which nothing reached before.

### `gStudy` two-facet — 85 → below threshold, and **no defect**

- **A clean sweep, and worth recording as one.** Degrees of freedom, mean squares and all
  seven variance components agree with an exact oracle. Two deliberate mutations — a swapped
  `sigma_pr` divisor, and dropping `+ MS_e` from `sigma_p` — are both caught, before and
  after the refactor.
- **The oracle builds the data rather than reading it.** Seven mutually orthogonal effects
  (main effects centred, two-way double-centred, residual triple-centred) whose sums of
  squares are known in closed form from the effect arrays. No sampling noise, no second
  implementation to be wrong the same way. Mean squares are checked separately from the
  components, so a failure names the stage.
- **5 x 4 x 3 on purpose.** Every divisor in the EMS inversion is a different product of the
  three dimensions; the existing tests use 3x2x2 and 4x2x3, where several coincide and a
  swapped divisor is invisible. A guard test asserts the six divisors stay distinct.
- **The oracle's own first fixture was broken and its guard caught it.** The residual array
  used `% 13` against a coefficient of 13, so the `r` term cancelled and the three-way
  contrast was identically zero — `MS_e` was ~1e-16 everywhere and three of the new tests
  passed against it. The truncation test failed and named it. `oracleDesignsExerciseEveryTerm`
  now asserts every constructed term contributes.
- **What the old tests asserted could not fail**: seven components exist, every variance
  `>= 0` (the function truncates negatives, so this is a tautology), `totalVariance` equals
  the sum it is computed from, percentages sum to the total they are shares of. The test
  called "Known three-way data with verifiable variance components" works four means out by
  hand in comments and asserts none of them.
- Eight helpers extracted, nothing above 18. The percentage block was duplicated across both
  overloads and is now one function. **Bit-identical** across both overloads and five designs.

### The churn rate that produced negative customers — the package's last known issue

- **Three models answered an impossible churn rate instead of refusing it.** `SaaSModel` at
  `churnRate: 1.2` returned **−20** customers for month 1. `SubscriptionBoxModel` and
  `MarketplaceModel` share the recurrence and shared the defect.
- **The contract already existed in three places and only the projections ignored it.**
  `StandardTemplates.createSaaSModel` threw for exactly this input, `retentionRate` guarded and
  returned `nil`, and `calculateCustomerCount` returned the number. The range had been written
  out four times across two files and the copies had diverged; it is now one function,
  `validatedRate(_:named:)`.
- **Checked in different places for one reason: mutability.** `SaaSModel.churnRate` is a `var`,
  so no initialiser can be the boundary — checked at the point of use, with a test that mutates
  a sound model into an unsound one. The other two hold theirs in a `let`, so construction *is*
  the boundary and **no method signature on those two types changed**.
- **Deliberately untouched:** the deprecated unit-economics methods. `calculateLTV` and its four
  siblings are already `@available(*, deprecated)` and each names a replacement that handles bad
  churn correctly. Adding `throws` to a deprecated method breaks callers for nothing.
- **Two assertions changed meaning, not shape**, and say so in their own docs: they used to build
  a box with an impossible rate and record what it answered. That box cannot be built now, so
  they assert the refusal at construction instead.

### `generalAIREMLUpdate` — 121 → 19, one defect and one it exposed

- **The Average Information matrix used a truncated projection, understating it by 13.5%.**
  `P` is not block diagonal by group. Under a trace against a block-diagonal `dV_k` only its
  diagonal blocks survive, so the score's per-group accumulation is exact — but
  `AI[j][k] = 1/2 (dV_j P r)' P (dV_k P r)` sandwiches a vector between two `P`s and needs the
  whole matrix. The source built one `nig x nig` block per group and never formed `P`.
  It is the projection error the score had, in the one place the cancellation that rescued
  the score does not reach: `Pr` is orthogonal to `X` by the normal equations, `dV_k P r` is
  not.
- **Nothing could have caught it from a converged fit.** The score fixes the optimum; the
  information only sets the step, and Newton with a wrong Hessian still lands on the right
  answer. The statsmodels comparison agrees to 1e-5 either way.
- **New oracle**: `GeneralAIREMLOracleTests` assembles the entire `N x N` projection, with a
  Gauss-Jordan inverse written in the test so it shares no path with the source's Cholesky,
  and evaluates score and information directly — at variance parameters built from the sample
  variance of `y`, never from a fit, and deliberately away from the optimum where the score is
  zero by definition. Source vs dense: score 3.36e-06, information **0.135**. Source vs the
  block-diagonal truncation: 2.99e-06 — which is what identified the mechanism rather than
  inferring it. After the fix, 2.99e-06 against the full projection.
- **`paramHasConverged` drove its absolute and relative thresholds from one number**, which
  the tolerance change below exposed: a model with no group effect ran its full budget and
  reported failure on data it had been fitting. A near-zero variance component can never pass
  the relative branch, so the absolute branch is the only thing that converges it, and
  tightening the relative test tightened that floor too. Now separate, floor fixed at 1e-8 —
  the value it already had — so nothing that converged before can stop.
- **Default `tolerance` 1e-8 → 1e-9** in `fitGeneralLME` *and both wrappers*. A correct
  information matrix is larger, so steps are smaller, so a step-size stopping rule fires
  sooner: the hardest design stopped one iteration early. One more iteration takes its
  remaining Newton step from 1.9e-05 to 2.2e-06 and its fixed effects from 1.3e-06 off
  statsmodels to 6.0e-08 — better than the 3.6e-07 that was previously the worst anywhere.
  **1e-10 is past a cliff** where the near-degenerate design stops converging; the sweep is in
  the DocC. The wrappers pass `tolerance` through, so a wrapper left on the old default makes
  `fitRandomIntercept(model)` and `fitGeneralLME(model)` disagree — which is how it surfaced.
- **Eight helpers extracted**, only two scoring above the threshold at all. **Bit-identical**
  on all six designs — every variance component, fixed effect and standard error compared as
  raw bit patterns, not within a tolerance. Dead parameters `ni` and `N` removed.

### `fitGeneralLME` — 131 → 75, and an open question closed

- **The standard-error gap against statsmodels is explained and is not ours.** An independent
  numpy implementation of `(X'V^-1 X)^-1`, fed statsmodels' *own* components, reproduces our
  numbers and still differs from statsmodels by up to 1.2%. statsmodels' SEs are consistently
  larger and the gap widens where the likelihood flattens — a covariance that also carries
  variance-parameter uncertainty. The file's "unexplained" note is now an explanation.
- **New oracle**: `standardErrorsAreTheGLSCovariance` computes the same quantity by assembling the
  whole `N x N` covariance and solving it densely, where the source accumulates block per group.
  Bound measured at 1e-5 against a worst observed 8.2e-7.
- Extracted `validateGeneralLME`, `generalSlopeVarianceStart`, `generalBLUPs`,
  `generalFeasibleStep`. **Bit-identical** on all six fixture designs.
- `generalAIREMLUpdate` is still **121** — the next target.

### `bayesianICC` — the same ICC(1,1) defect, third implementation

- After finding it in the EM estimator the **class** was swept, not the instance: every site
  turning variance components into an ICC. There were two, and `bayesianICC`'s private
  `iccFromComponents` had `case .twoWayRandom, .oneWayRandom:` as well. Fixed by **deleting** the
  duplicate — both samplers now call the shared `iccFromVarianceComponents`, so one place is left
  to get wrong. Posterior mean for ICC(1,1) moves 0.2807 → 0.1881 against a classical 0.1657.
- **Two of my own tests passed for the wrong reason and were rewritten.** A 0.2 tolerance passed
  while the defect was live (gap 0.115); it is now 0.06, measured. And "the two overloads agree on
  complete data" was testing a *delegation* — the optional overload hands a complete matrix
  straight to the other one — so it now asserts bit-identical results and a separate test removes
  a cell to reach the missing-data sweep.
- **One Gibbs sweep instead of two: complexity 101/54 → 45/32, and 17% faster.** The presence of
  a cell is now asked once at setup rather than on every cell of every sweep. Measured at `-O`:
  complete 0.6107 → 0.6013s, missing 0.7214 → **0.5974s**. A first attempt using a flat cell list
  was **27% slower** on the complete path — `s[cells.subject[c]]` is a gather where the nested
  loop hoisted `s[i]` — and was not shipped; grouping the cells by subject restores the hoist.
- **Bit-identity is the verification, and it earned it.** Two attempts changed every draw while
  leaving the posterior means almost untouched: collapsing the complete overload's ANOVA-based
  initialisation into the missing overload's heuristic, and factoring `mu + s[i]` out of a
  subtraction. A tolerance-based test would have passed both.

### `icc` (EM overload) — 131 → 73, two defects

- **`.oneWayRandom` carried the `.twoWayRandom, .absolute` formula character for character**, so
  ICC(1,1) returned the ICC(2,1) figure — 0.28976 where Shrout & Fleiss (1979) publish .17,
  overstating agreement by three quarters. The one-way subject term is `s² − r²/k`, not `s²`.
- **`maxIterations` defaulted to 200 where the EM needs up to 1263.** Eighteen of twenty-four
  single-cell deletions expired, returning `converged: false` with an estimate that was nearly
  right. Raised to 5000. Parameter-based convergence was tried and is *slower*.
- `logLikelihood` is an **independence approximation**, not the model's likelihood, and now says
  so. **Open: whether the EM should be REML** so the two `icc` overloads agree on complete data —
  they currently differ by ~0.06, which is ML bias tracking `(n-1)/n` and `(k-1)/k`.

### `extractVariableShift` — 95 → 21, three defects

- **`enableVariableShifting` defaulted to `false`**, and it is the only thing between the
  simplex's implicit `x ≥ 0` and a model that says otherwise. `x ≥ -3, minimise x` returned
  **0.0 with status `.optimal`**; `x = -3` and `-5 ≤ x ≤ -1` returned `.infeasible`. Now defaults
  to `true` on both initialisers. It cannot make a model worse — `needsShift` is false when
  nothing is negative, so only the wrong models move.
- **An equality was not treated as a bound.** Both equality spellings were skipped; pinning a
  variable at −3 bounds it below by −3, and `ConstraintSense.equal` fell through a sense test
  with no `default`.
- **The shift depended on constraint order.** Plain assignment meant the last constraint won:
  `[x ≥ -10, x ≥ -3]` gave −3, reversed gave −10. All paths now take the binding bound.

### Earlier commits

- **`solve`: 160 → 60, two defects.** Five separate result constructions, each answering "what do
  I report when nothing was found" on its own. Every no-incumbent exit reported
  `objectiveValue: +∞` regardless of sense, so a **maximisation** that found nothing reported the
  best conceivable value — beside a `bestBound` of `-∞`, an answer beating its own bound. And the
  no-incumbent exit applied the *inverse* variable shift to `initialGuess`, which was never
  shifted: a solve started `from: [0, 0]` with lower bounds at `-5` returned `[-5, -5]`. All five
  exits now route through one `makeResult`.
- **`MonteCarloExpressionModel.toClosure()` counted an unevaluable draw as `0.0`.** The
  interpreter throws for `sqrt` of a negative, `log` of a non-positive and division by zero; the
  closure discarded all of it for a number the model never produced, and `MonteCarloSimulation`
  uses that closure as its CPU path. On `log(x)` over 300 draws spanning `[-1, 3]`, 75 threw, 75
  became zero, the reported mean was 0.0707 against 0.0943 over the defined draws, and **no
  sample was non-finite**. Now `Double.nan`, which propagates.

### `evaluate`: decided, and the measurement is the lesson

`evaluate` is a flat 22-case dispatch table whose score came from a stack guard repeated in every
case. Folding those into two `@inline(__always)` pop helpers takes it **104 → 41** — and makes it
**44% faster**, not slower:

| variant | 2M evaluations, `-O` |
|---|---|
| as it was | 0.4002s |
| pop helpers, no capacity hint | 0.3206s |
| pop helpers + `reserveCapacity(maxStackDepth())` | **0.2249s** |

**The debug measurement said 34% *slower* and was nearly acted on.** At `-Onone`,
`@inline(__always)` is advisory, so every helper becomes a real call with `inout` exclusivity
checking. Debug and release disagreed on the *sign*, not the size. Benchmark anything in this
package at `-O` or not at all — the note is now on the function itself.

## 3. What this session did

Tier 2 opened on the premise that a high complexity score marks code no one has an oracle for.
**Sixteen defects in twelve commits**, every one a wrong answer that a green 7,800-test suite was
endorsing, and not one found by reading the code.

| Commit | What was wrong |
|---|---|
| `81f7d733` | Branch-and-cut **cut off the optimum** — Gomory fractional cuts applied to a mixed problem. Replaced with Gomory mixed-integer cuts; `generateMIRCut` delegates |
| `5a96e887` | Cycling detection inert (a `break` bound to the wrong loop); the global bound read from selection order, not the best open node; branches emitted as closures the solver could not read exactly |
| `0809cd1c` | **Constrained optimizers returned infeasible points as `.converged`.** Now `.infeasible` with the least-violating point and its measured violation — the user's call, so a modeller can see the conflict and fix the bounds |
| `0667be66` | Simulated annealing had **no inner Markov chain, a constant step size, and stagnation firing during exploration** — three of the algorithm's defining features. Benchmark went 7.34 → 0.00052 |
| `85e1e991` | `IslandModel` reported violation **0.0 while 2.78 outside** the feasible set; a `.zero` default on `constraintViolation` was a fail-silent trap |
| `fe71c669` | The genetic algorithm had both of annealing's defects: `generations` inert, mutation width never narrowing |
| `65b4ebca` `c18434c5` | `numericalGradient` returned **exactly zero past 1e10**, so `1.9e105` came back labelled `.converged`; `VectorN/2D/3D.norm` returned `inf` or `0` for finite norms. The same absolute-step bug was in every other finite difference in the package |
| `39ed2885` | Branch-and-bound was **non-deterministic across processes** — four `Set` iterations let Swift's per-process hash seed decide LP row order and every tie-break downstream |

Clean sweeps, no defects found: `SimplexSolver` (1,600 cases + duality), `AsyncSimplexSolver`
(600), DEA CCR/BCC (1,999), the unconstrained heuristics.

**A rule came out of it**, now in the guidelines repo at `rules/correct_answers.md`, tagged
`v2.4.0`: a test must pin the correct answer, not merely assert accurately. Where expected values
come from, why a tolerance is measured rather than chosen, and why a fixture set cannot reach the
inputs an algorithm generates for itself.

---

## 4. Traps, carried forward

- **`doc-run` is the package's only cross-process determinism test.** It executes each article
  twice in separate processes and diffs. That is how the hash-seed defect surfaced; no unit test
  could have found it, because a process agrees with itself.
- **`doc-run` is load-sensitive, and it bit again on 2026-09-18.** At load average 150–270 the
  full gate reported two `doc-run` errors: `5.11-PerformanceBenchmarking.md` killed at its
  deadline and `5.16-GPUAccelerationTutorial.md` differing on 9 of 179 output lines. Four further
  `doc-run` passes on the same tree: one clean, three with a *deadline kill* on whichever of the
  two articles lost the race, and **"0 produced different output on a second run"** every time.
  Neither article references anything this session changed — checked by grepping them for the
  type names. Treat a `doc-run` failure at high load as unproven until it reproduces quiet.
  Note also that the **pre-commit hook's default profile does not include `doc-run`**, so this
  flake cannot block a commit.
- **Never background a `git commit` here.** The pre-commit hook takes ~9 minutes; a 2-minute
  command budget SIGTERMs it mid-gate. Give it a long timeout and let it run in the foreground.
- **CI skips docs-only pushes.** A commit touching only Markdown gets no run at all — prove it by
  diffing against the last CI-green commit, not by waiting.
- **The scratchpad is `/private/tmp` and does not survive a reboot.** Anything worth keeping goes
  into the repo. Done this session: see §5.

---

## 5. Housekeeping

| File | State |
|---|---|
| `project/plans/TIER2_COMPLEXITY_QUEUE.md` | the work queue, 205 functions with locations |
| `project/plans/upcoming/parked/OneDimensionalInterpolator.swift.parked` | approved ("do both, additively") but never wired up. Not compiled — the `.parked` extension and the location outside `Sources/` both keep SPM away |
| `Tests/.../BytecodeDifferentialTests.swift` | **unparked and committed** — it is green now, so it belongs in `Tests/` |

**A note that cost a commit to learn:** the pre-commit gate builds the *working tree*, not the
index. A failing test left untracked in `Tests/` blocks every subsequent commit, not just the one
that would add it. Park such a file outside `Sources/` and `Tests/` rather than leaving it lying
around.

**`Calendar.gregorianUTC` is already shared — verified 2026-09-18.** `SwiftDeterminism` vends it
(v1.2.0, `0d002fa`), this package depends on `from: "1.2.0"` and resolves to exactly that, and
`Sources/BusinessMath/Valuation/DayCountConvention.swift:61` is a one-line alias
`let gregorianUTC: Calendar = .gregorianUTC` that all 186 call sites go through. Nothing to
migrate. The hand-built UTC calendars remaining in `Tests/` are deliberate: a suite checking
zone-invariance must construct its expectation independently of the constant under test.

## 6. Open decisions, none blocking

- **Twenty-two commits are untagged above `v3.0.0-alpha.6`.** No decision has been made about
  whether they become `alpha.7` or wait. Nothing depends on it.
- **`CLAUDE.md` is gitignored**, so the reading-list correction recorded in it does not survive a
  fresh clone. Not fixed; fixing it means either un-ignoring the file or moving the correction
  into `project/`.
