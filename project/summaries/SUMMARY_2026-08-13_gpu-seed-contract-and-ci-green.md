# Session summary — 2026-08-13

**Outcome:** CI green across all four jobs, the nightly green including Thread Sanitizer, and the
Linux release build fixed — it had been broken. `doc-comment-code` moved 941 → 852 before the
session turned to CI. Nothing is in flight; `main` and `origin/main` agree.

Commits: `274fb7a`, `9b61914`, `7b81bce`, `d92d665`, `1f0665a`, `22d22a0`.

---

## 1. The GPU seed contract — a partial fix, completed

A previous session fixed `GeneticAlgorithm`'s `catch` branch: GPU throws → rewind the generator →
refuse to substitute the CPU on a seeded run, because the kernels compute in `Float` where the CPU
computes in `Double`. **The rule was written as a comment, in one branch, of one file.** Three
places did not inherit it.

1. The `return nil` at GA's own command-buffer guard, two dozen lines below that comment, in the
   same function. It rewound and then ran the CPU silently.
2. `DifferentialEvolution` and `ParticleSwarmOptimization` received no part of the fix — seven
   post-draw `return nil` sites between them, no snapshot, no rewind. They had *both* failure
   modes: the desynced stream and the silent algorithm swap.
3. **No GPU path in the library checked `commandBuffer.status` after `waitUntilCompleted()`.**
   `.error` is a terminal state, so the download proceeded and read whatever the shared buffer
   held — the pre-kernel population, or partial output.

What made (1) hard to see is worth keeping: **the rewind is what hides it.** Both runs agree on
every random draw and still disagree on the answer, so nothing about the symptom points at
seeding.

The rule now lives in a type. `RNGWrapper.attemptGPU(seeded:_:)` owns the rewind, and
`GPUAttemptOutcome` has no case meaning "abandoned, and you may ignore that" — the caller must
switch. Tested without a GPU: a body that draws 64 values then fails reproduces the hazard in
microseconds, where the real trigger needs a Metal command queue to refuse a buffer under
pressure. That assertion would have caught this in all three optimizers at once.

DE and PSO decline the GPU when seeded, as an interim, because their `optimizeDetailed` is
non-throwing and cannot refuse. Making it throwing forces a major →
`project/plans/upcoming/v3.0.0_SCOPE.md`.

## 2. The Linux release build was broken

Four generic expressions the Swift 6.2.1 Ubuntu type-checker rejects outright. macOS compiled all
four, so **the package did not build on Linux in release configuration while appearing healthy
locally.** Three nested Horner chains in `inverseNormalCDF`, one velocity initialiser in PSO.

Verified bit-exact rather than assumed: `inverseNormalCDF` feeds Monte Carlo, where one ulp moves
every seeded result. Compared bit patterns of 16 values across both branches and the 0.02425
breakpoint, before and after, by stashing the change. Identical in all 16.

**The documented pre-push check does not catch this class.** A local *release* build at
`-solver-expression-time-threshold=100` — five times stricter than the 500 in CLAUDE.md — still
compiles them clean on macOS. Only CI confirms it. ~30 further expressions sit at 5+ operators,
two at 8 with the same nested shape (`CallableBond.swift:245`, `BinomialTree.swift:84`); they
compiled, and were left rather than swept.

## 3. Two flakes, and one non-flake

**Stochastic optimizer:** five scenario generators passed `seed: nil` while asking the optimizer
for `seed: 42` — a seeded optimizer fed a random problem. Measured 298/300 convergence: a
1-in-150 red suite for reasons unrelated to any change under test. All five now draw from a held
`DeterministicRNG`.

A first probe of this reported 10/60 and would have been filed as an 83% optimizer defect. It was
seeding *each call* rather than the stream, so every sample came back identical and the sample
average collapsed onto a point. Corrected, the same problem converges 40/40.

**Time limits:** `fiftyDMUsModerateScale` failed CI at its 120s limit having run 281 seconds —
for **33 milliseconds** of work. Swift Testing measures elapsed wall clock per test, not work, and
tests run concurrently, so an `async` test that awaits is descheduled while others hold the cores.
Tests reporting ~25s in a full run take 0.014s alone. The binding number was never any test's
runtime; it was the suite's, because a test that starts early and awaits spans the entire run.
Under TSan the suite is ~347s against ~29s. `testHangGuard` (20 minutes) now covers all 46 sites,
sized above worst-case suite duration and below the job's `timeout-minutes: 120`, so a hang is
reported by the test that hung rather than by a timeout that names nothing.

**The SEGV that was not a defect.** `generateRandomVolatilities` crashed once under TSan
(08-13). It did not recur across three later CI runs or two local attempts. The argument is not
about the crash but about the inputs: `count: 100, seed: 20260812` through a pure xoshiro256\*\*
performs byte-identical work every run, so no property of that code can differ between the run
that crashed and the ones that did not. Environmental by elimination. **Watch, do not fix** — and
if it recurs at the same site, that argument is the thing to give up.

## 4. Documentation fixtures

`documentationFixture` on the statement types, plus `Period.documentationQuarters` and
`Entity.documentationFixture`. Doc fences compile against Foundation and this module alone, so
every example wanting a balance sheet was building an entity, four periods and a dozen accounts
before showing its one line.

The technique that scaled: **never infer a binding's type from its name; infer it from something
the example already committed to.** An argument label (`entity:`), a generic argument
(`KMeans<Vector2D<Double>>`), a method call (`.fillForward(`) — all parts of the API the author
could not have varied. `model` tells you nothing; `entity: model` tells you everything. 87
bindings in two passes.

The simulation fixture spreads nine projections across a revenue scale rather than repeating one,
because nine copies would satisfy the checker while reporting the same number for the 10th and
90th percentile — a distribution example demonstrating there is no distribution. A test asserts
`p10 < p50 < p90`.

---

## What to carry forward

**The recurring shape**, now recorded in `master_plan.md`: a check that appears to assert a
property of the code while actually measuring the environment. Three instances this session
(`.timeLimit`, `seed: nil` under a seeded optimizer, the GPU fallback), plus two in tooling (a
cached gate run; `grep -c` on an invocation that never ran, which produced two false "0 errors"
readings in a row). The tell is always the same: **the passing and failing runs are byte-identical
in the code under test.**

**Corrections made mid-session**, kept because the reasoning matters more than the conclusion:
- I claimed the TSan SEGV was why the nightly had been red. It was not — Ubuntu failed on both
  nights; TSan passed on the first.
- I dismissed the `.timeLimit` timeouts as a local artifact with no CI exposure. CI hit one on the
  very next run.
- I proposed a "headroom ratio" checker for time limits. That computes a precise number for a
  signal carrying one bit, and points the wrong way — the right rule is that limits should be
  *large*, because one tuned near observed runtime is the one that lies.

**Open:** `doc-comment-code` at 852 (the tag gate), `doc-claims` at 8, `doc-symbol-link` not yet
landed, and the v3.0.0 scope decision. See `HANDOFF.md`.
