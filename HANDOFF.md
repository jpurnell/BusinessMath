# Handoff — 2026-09-18 (Tier 2 of the quality programme, mid-sweep)

**`main` is `39ed2885`, pushed, local == remote.** Twenty-two commits sit above
`v3.0.0-alpha.6`; twelve of them are this session's. The suite is green and the gate is at
**zero errors and zero warnings**.

The work queue is **`project/plans/TIER2_COMPLEXITY_QUEUE.md`** — the 205 functions the
complexity checker scores over threshold, captured from the last full gate run. That file is
the plan; this file is the state, the one open defect, and the traps.

## State

| | |
|---|---|
| branch | `main` at `39ed2885`, local == remote |
| tags | latest **`v3.0.0-alpha.6`** (2026-09-15); **22 commits are untagged above it** |
| tests | **7,870 in 714 suites**, exit 0, **1 known issue** (deliberate — see below) |
| gate | `quality-gate --no-cache --check all` → **45 of 45 PASSED, 0 errors, 0 warnings** |
| working tree | clean once this commit lands |
| guidelines repo | `../../development-guidelines` clean at `a5f9292`, **`v2.4.0` tagged and pushed** |
| CI | not verified since the Tier 2 sweep began; every commit since is source-touching |

**The one known issue is deliberate and unchanged.** `SaaSModel` does not validate `churnRate`;
a rate above 1 drives the customer count negative. Rejecting it is source-breaking on two public
initialisers, so the requirement is a `withKnownIssue` that starts failing the day validation
lands. **A run reporting exactly one known issue is the steady state; two is a regression.**

**The gate warning count is now 0, not the 10–11 the previous handoff recorded.** The ten
standing `[test-quality]` warnings were cleared at `5de783ca`, and the last one — a `DebugTrace`
error-value-type declaration — at `2af9e0ff`. **Any warning at all is now yours.**

Always `--check all`. Plain `--no-cache` runs a subset and prints an identical PASSED line.
`--check` takes **one** checker per flag; `--check a,b,c` prints *"No checkers enabled"* and exits 0.
Tagging does not change what the gate runs — measured both ways on `346a50ad`.

---

## 1. Resume here — the open defect, diagnosed but not fixed

**`BytecodeOptimizer.algebraicSimplificationPass` miscompiles any expression containing a
ternary.** Found by a randomized differential test, 13 disagreements in 2,000 expressions.

### The reproducer

```
expression: (1.0 + (input[0] ? -0.0 : 7.0))
bytecode  : [constant(1.0), input(0), constant(-0.0), constant(7.0), select, add]
optimised : [constant(1.0), input(0), constant(7.0), select]
inputs=[0.0]   plain = 8.0   optimised = 0.0
```

The optimised program computes `input0 ? 1.0 : 7.0` — a different expression entirely.

### The cause

The pass walks the bytecode maintaining a `stack: [StackValue]`. Every operator case pops the
number of operands it actually consumes — except the `default:` branch at the bottom of the
switch, which pops **exactly one** regardless of arity:

```swift
default:
    guard stack.count >= 1 else { continue }
    let operand = stack.removeLast()          // ← one, always
```

`.select` is ternary and `.power` / `.min` / `.max` / the comparisons are binary, so each of them
leaves its unconsumed operands sitting on the stack where a *later* instruction sees them. In the
reproducer the `constant(-0.0)` belongs to `select`, but `add` finds it exposed, matches the sound
`a + (-0.0) → a` identity against it, and deletes both.

The identity rules are correct. The stack discipline underneath them is not.

### The fix

`default:` needs the instruction's real arity. Enumerate the `Bytecode` cases rather than adding
`case .select:` alone — every non-unary operator in that branch has the same bug, `select` is
merely the one with three operands and therefore the one the generator hit.

Verify with the test described next; then full suite, then `--check all`, then CHANGELOG, then
commit. Note that `algebraicSimplificationPass` is itself **complexity 49** on the Tier 2 queue,
so this is the queue paying out again rather than an unrelated errand.

### The test — parked, not deleted

`project/plans/upcoming/parked/BytecodeDifferentialTests.swift.red` (268 lines) is the RED test
that found this. **Step one of resuming is to move it back to
`Tests/BusinessMathTests/Simulation Tests/BytecodeDifferentialTests.swift`**, confirm it still
fails, then fix.

It is parked rather than committed in place for two reasons: a failing test in `Tests/` turns
`main` red, and — less obviously — the pre-commit gate builds the *working tree*, not the index, so
even leaving it untracked would have blocked every subsequent commit. Parked, it is tracked and
durable, and SPM never sees it. Commit it back into `Tests/` together with the fix.

It is worth keeping rather than rewriting. `Expression` ships no evaluator, so the file carries its
own independent recursive tree-walker as the oracle, which buys two differentials from one
generator:

| Test | Compares | Status |
|---|---|---|
| `compiledMatchesTheTreeWalk` | tree-walk vs `interpret(compile(e))` | **green** — the compiler is clean |
| `optimisedMatchesUnoptimised` | `interpret(compile(e))` vs `interpret(optimize(compile(e)))` | **RED, 13 / 2,000** |
| `conditionalsDoNotShortCircuit` | pins that all three operands evaluate | green |

If that file is ever lost, the reproducer above is enough to rebuild it.

---

## 2. The other two open items

The user named three; `evaluate` above is the first. These two are untouched.

| # | Target | Score | Where |
|---|---|---:|---|
| 2 | `linearRobustCounterpart`, and `CuttingPlaneMaster.minimize` with it | 59 / 38 | `AdvancedOptimization/RobustOptimizer.swift:651`, `Optimization/Nonsmooth/CuttingPlaneMaster.swift:119` |
| 3 | `solveRelaxation` — the decomposition Tier 2 originally set out to do | **291** | `Optimization/IntegerProgramming/BranchAndBound.swift:848` |

`solveRelaxation` is the highest-scoring function in the package and the one the whole tier was
opened for. It has been deferred twice now because opening its neighbours kept turning up defects
first; that is a good reason, but it has stopped being a new one.

Note that the `104 evaluate` row on the queue is `MonteCarloExpressionModel.evaluate:209`, a
*different* function from the bytecode path above — the differential test was written to get an
oracle onto that area and found the optimizer defect on the way. `MonteCarloExpressionModel.evaluate`
itself is still unexamined.

---

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
- **`doc-run` is also load-sensitive.** Re-run it on a quiet machine before blaming code.
- **Never background a `git commit` here.** The pre-commit hook takes ~9 minutes; a 2-minute
  command budget SIGTERMs it mid-gate. Give it a long timeout and let it run in the foreground.
- **CI skips docs-only pushes.** A commit touching only Markdown gets no run at all — prove it by
  diffing against the last CI-green commit, not by waiting.
- **The scratchpad is `/private/tmp` and does not survive a reboot.** Anything worth keeping goes
  into the repo. Done this session: see §5.

---

## 5. Housekeeping done for this handoff

| File | Action |
|---|---|
| `Tests/.../ZZProbeTests.swift` | **deleted** — scratch probe; its output is quoted in §1 |
| `project/plans/TIER2_COMPLEXITY_QUEUE.md` | **new** — the 205-function queue, rescued from a gate log in `/private/tmp` |
| `project/plans/upcoming/parked/OneDimensionalInterpolator.swift.parked` | **rescued** from `/private/tmp` — approved ("do both, additively") but never wired up. Not compiled; the `.parked` extension and the location outside `Sources/` both keep SPM away from it |
| `Tests/.../BytecodeDifferentialTests.swift` | **moved** to `project/plans/upcoming/parked/BytecodeDifferentialTests.swift.red` — RED, and the gate builds the working tree, so it could not stay in `Tests/`. See §1 |
| `HANDOFF.md` | rewritten; the previous version described `077562dd`, twelve commits ago |

## 6. Open decisions, none blocking

- **Twenty-two commits are untagged above `v3.0.0-alpha.6`.** No decision has been made about
  whether they become `alpha.7` or wait. Nothing depends on it.
- **`CLAUDE.md` is gitignored**, so the reading-list correction recorded in it does not survive a
  fresh clone. Not fixed; fixing it means either un-ignoring the file or moving the correction
  into `project/`.
