# Handoff — 2026-09-18 (Tier 2, the three named items closed)

**`main` is the tip of this commit, pushed.** The three items the last session named — the
bytecode `evaluate` area, `RobustOptimizer`/`CuttingPlaneMaster`, and `solveRelaxation` — are all
closed. Two more defects found, one clean sweep recorded, and the package's worst complexity
score cut from **291 to 55**.

The work queue is **`project/plans/TIER2_COMPLEXITY_QUEUE.md`**. That file is the plan; this file
is the state and the traps.

## State

| | |
|---|---|
| branch | `main`, local == remote |
| tags | latest **`v3.0.0-alpha.6`** (2026-09-15); **26 commits untagged above it** |
| tests | **7,882 in 716 suites**, exit 0, **1 known issue** (deliberate — see below) |
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

**Nothing is half-finished.** The three named items are closed, the suite is green, and the
working tree is clean. Pick the next target from `project/plans/TIER2_COMPLEXITY_QUEUE.md`.

The method has not changed and has not stopped paying: **open a function by building an
independent oracle, not by reading it.** Across the whole sweep, every defect was found by
differencing against a second opinion and none by inspection, with a green 7,800-test suite
endorsing each wrong answer throughout.

Highest unexamined scores, after this session's work:

| Score | Function | Where |
|---:|---|---|
| 160 | `solve` | `IntegerProgramming/BranchAndBound.swift:315` — the outer search, next to the one just decomposed |
| 131 | `icc` | `Statistics/Descriptors/Agreement/iccMissingData.swift:80` |
| 131 | `fitGeneralLME` | `Statistics/MixedModels/Fitting/fitGeneralLME.swift:28` — already fixed twice by oracle, so a third look is cheap |
| 121 | `generalAIREMLUpdate` | same file, line 653 |
| 104 | `evaluate` | `MonteCarlo/Compilation/MonteCarloExpressionModel.swift:209` — **still unexamined**; the differential test written for this area found the optimizer defect on the way and never reached it |
| 101 | `bayesianICC` | `Statistics/Estimation/bayesianICC.swift:415` |

Re-run the gate rather than trusting that table after any refactor.

## 2. What closed, and what it cost

### The bytecode optimizer miscompiled every ternary

`BytecodeOptimizer.algebraicSimplificationPass`'s `default:` branch popped **one** operand
whatever the instruction's arity. `select` takes three and the thirteen binary operators take
two, so each left operands on the stack for the *next* instruction's identity rules to match
against. `(1.0 + (input[0] ? -0.0 : 7.0))` optimised into a program computing
`input0 ? 1.0 : 7.0` — 0.0 where the answer is 8.0. Replaced with an exhaustive
`operandCount(of:)`, so adding a `Bytecode` case now fails to compile until its arity is stated.

Found by `BytecodeDifferentialTests`, which carries its own recursive tree-walker because
`Expression` ships no evaluator: 13 disagreements in 2,000 expressions, now 6,000 clean. Both
minimal reproducers were **confirmed to fail against the pre-fix source**, not assumed to.

### The cutting-plane certificate was not a certificate

`CuttingPlaneMaster` read its lower bound from the model minimised *over the trust region*.
Restricting a minimisation can only raise its value, so that is not a bound on anything outside
the box the method drew itself. In the default configuration `min |x − 1000|` from `x = 0`
returned `x = 100` with `optimalityGap: 0.0` and `converged: true`, after one round.

The bound now comes from a second master solve over the caller's constraints alone — where
Kelley's method takes it — and the trust region doubles on a boundary step instead of only ever
shrinking. Every pre-existing test placed its optimum inside the first trust region, which is
why none could see it.

### `solveRelaxation`: 529 lines and complexity 291 → 258 lines and 55

The round loop was a pipeline with no names on its stages. Each is now a method in
`BranchAndBoundCutting.swift`. Behaviour is a lift, verified against the 215 tests in 34
integer-programming suites the sweep had already built.

### `RobustOptimizer`: clean

`linearRobustCounterpart` (complexity 59) got a hand-derived minimax, its maximising mirror, a
grid-confirmed three-scenario problem, and the law that the reported value is attained at the
reported point. **No defect.** The LP route was confirmed to fire by instrumentation (8 of 8
cases) rather than assumed — iteration count does *not* separate the two routes, so that is not
the signal to read.

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
