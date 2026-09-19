# Handoff — 2026-09-19 (Tier 2: seven items closed, nine defects)

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
| branch | `main`, local == remote |
| tags | latest **`v3.0.0-alpha.7`** (2026-09-18, tagged by the peer session) |
| tests | **7,898+ in 719+ suites**, exit 0, **1 known issue** (deliberate — see below) |
| gate | `--no-cache --check all` → 45 of 45 ran, **0 errors and 0 warnings outside `doc-run`** |
| `doc-run` | **flaky under load, not a regression** — see §4 |
| guidelines repo | `../../development-guidelines` clean at `a5f9292`, `v2.4.0` tagged and pushed |
| CI | not verified since the Tier 2 sweep began; every commit since is source-touching |

**The one known issue is deliberate and unchanged.** `SaaSModel` does not validate `churnRate`;
a rate above 1 drives the customer count negative. Rejecting it is source-breaking on two public
initialisers, so the requirement is a `withKnownIssue` that starts failing the day validation
lands. **A run reporting exactly one known issue is the steady state; two is a regression.**

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

Highest unexamined scores after this session:

| Score | Function | Where |
|---:|---|---|
| 131 | `icc` | `Statistics/Descriptors/Agreement/iccMissingData.swift:80` |
| 131 | `fitGeneralLME` | `Statistics/MixedModels/Fitting/fitGeneralLME.swift:28` — already fixed twice by oracle, so a third look is cheap |
| 121 | `generalAIREMLUpdate` | same file, line 653 |
| 101 | `bayesianICC` | `Statistics/Estimation/bayesianICC.swift:415` |
| 95 | `extractVariableShift` | `IntegerProgramming/VariableShift.swift:207` — and the shift machinery just produced a defect one layer up |
| 85 | `gStudy` | `Statistics/Reliability/gStudy.swift:133` |

Re-run the gate rather than trusting that table after any refactor.

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
