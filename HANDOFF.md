# Handoff — 2026-09-12 (end of day)

**`main` is `e417c78b`. History was rewritten today — read §1 before running any git command.**
**Phase 1 of `REVIEW_simulation_tests.md` §6 is complete**, all five items, in four commits. The
next piece of work is **Phase 2, GPU test integrity**, whose first step is decision 5.2 — the Mac
CI job must fail rather than skip when Metal is unavailable.

## State

| | |
|---|---|
| branch | `main` at `e417c78b` |
| tags | **89** (was 109). Latest `v3.0.0-alpha.4` |
| tests | **7,731 in 691 suites**, exit 0 (was 7,700 in 689) |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 45/45, **0 errors**, 11 warnings |
| the 11 warnings | all pre-existing: 10 `non-strict-improvement` notices in other suites, plus `CHANGELOG has no entry for version 3.0.0-alpha.4`. Not the skipped-test inventory, whatever older handoffs said |
| working tree | clean except `project/plans/proposals/excel_function_coverage_matrix_bak.tsv` — **your backup, deliberately untracked, leave it alone** |

Always `--check all`. Plain `--no-cache` runs 40 of 45 and prints an identical PASSED line.

---

## 1. The history was rewritten today. Read this first.

The BusinessMathExcel session ran `git filter-repo --path project/library/ --invert-paths` to remove
~90 MB of third-party copyrighted books from a public repo. **Every commit from `ca7afd83` onward
has a new SHA.**

- All 1,025 commits survive; only the books are gone. 141.22 → 60.62 MiB.
- **88 tags at or below `v2.5.1` keep their original SHAs** — deliberately, so SwiftPM's
  trust-on-first-use fingerprints still match. **20 affected tags were deleted, not re-pointed**,
  because no version number may ever point at two commits. `v3.0.0-alpha.4` is the fresh tag above.
- Verified independently here: **no surviving remote tag carries `project/library`**.

**Consequences for you.**

- **Any SHA in a document older than today is dead.** This file's own history, the CHANGELOG, and
  both review documents may quote pre-rewrite SHAs. Commit *subjects* still resolve; SHAs do not.
- **Never `git pull` from a stale clone.** `git fetch --prune --prune-tags origin && git reset --hard origin/main`.
- **`git fetch` does not prune tags.** After the rewrite this checkout still held all 20 deleted
  tags, pointing at old-history commits that still contained the books — one `git push --tags` from
  undoing the whole operation. Pruned here; **any other machine or CI runner with a persistent
  checkout still has them.**
- 19 surviving tags, `v2.5.1` among them, are no longer *ancestors* of `main` — filter-repo forked
  the chain slightly earlier than `ca7afd83`. Harmless; they resolve and carry nothing.
- Still open, not ours: GitHub holds the unreferenced blobs until a support request expires them.

---

## 2. What shipped this session

| Commit | Contents |
|---|---|
| `6735df37` | The four Bessel functions, fixture and 21 tests |
| `5365e270` | Miller's seed order bounded by the order, not a shared constant |
| `bb05023a` | `factorial` states its ceiling as a `precondition` |
| `1d927726` | Exit tests skip under a sanitizer instead of passing without running |
| `0297a2ed` | `REVIEW_simulation_tests.md` — validated |
| `11262208` | Three Numerical Recipes transcriptions re-expressed, bit-identically |
| `d3543352` | `REVIEW_statistics_tests.md` — validated, eight conventions decided |
| `7f76a9fe` | This file and `STATUS.md` caught up to the rewrite they describe |
| `88af88d7` | **Phase 1 item 1** — antithetic SE from pair means, plus Welford |
| `292868a3` | **Phase 1 item 2** — the unit-interval lattice, and a trap with it |
| `0195cf31` | **Phase 1 items 3–4** — optimizer soundness |
| `4df8a678` | **Phase 1 item 5** — the CPU/GPU contract |
| `9f661666` | additive identity made sign-exact; 17 silent-pass guards removed |
| `f5b4454e` | safe math, the per-opcode differential, and `PROPOSAL_gpu_error_parity.md` |
| `e417c78b` | **GPU error parity** — the proposal built, §8 answered |

CI green throughout up to `d3543352`. The four Phase 1 commits are local-gate-green (45/45,
0 errors) and **have not yet been seen by CI** — watch the run after the push.

---

## 3. Phase 1 is done. What it found, beyond what the review said.

Each item was confirmed to fail by reintroducing the defect, and each fix ran the full suite.

1. **Antithetic SE** (`88af88d7`). Reported ÷ realised over 200 fixed seeds went from **1.449 to
   1.079**; the reported reduction against plain went from none to **0.746** against a realised
   0.659. Welford replaced `E[X²] − E[X]²` — not tidying: on a payoff antithetic sampling cancels
   exactly, the naive form loses every digit to cancellation and would have reported a spurious
   4e-8, failing the new oracle on arithmetic rather than on the defect. The price keeps its
   original accumulation and is bit-identical.
   **New, not in the review:** a single-path antithetic request had `paths / 2 == 0`, so the loop
   never ran and the mean divided 0.0 by 0.0 — a NaN price with `pathCount` 0. One pair is now the
   floor.
2. **The lattice** (`292868a3`). **Bigger than the review recorded.** Beyond the 5e-8 downward bias,
   every uniform below 1e-7 quantized to exactly 0.0 — measured at **1.0000000006e-07 of the word
   space, one draw in ten million**. `distributionGeometric` is `ceil(ln U / ln(1−p))` then `Int(_:)`,
   so a zero draw gave −inf, then +inf, then **a trap**. Confirmed in isolation: exit 133. The
   comment above that line claimed the code used `1−U` to avoid `log(0)`; it never did. Blast
   radius of removing the lattice, measured: **none** — no other test pinned it.
3. **`a * 0 → 0`** (`0195cf31`). Removed, not guarded: `a` is an input or a computed sequence and
   nothing in the compiler tracks finiteness. Where `a` is a constant, folding already handled it
   exactly. **New, not in the review:** the additive identities were unsound too, and
   **`9f661666` made them strict** at Justin's direction. There is exactly one exact additive
   identity — `a + (-0.0) → a`, equivalently `a - (+0.0) → a`. Being strict uncovered a second
   defect: **`a - 0 → a` was already firing on `-0.0`**, because `case .constant(0.0)` matches
   through `==`. The conditions now read `.sign`, and this pass has no rewrite that can change a
   result, in any bit, for any input.
4. **Folding vs interpreter errors** (`0195cf31`). `evaluateBinaryOp`/`evaluateUnaryOp` return
   `Double?` and decline the three the interpreter throws on.
5. **CPU/GPU contract** (`4df8a678`). Opcodes live once in `GPUOpcode`; the kernel is generated from
   it and contains no numbers. `GPUBytecodeValidator` runs before both `runSimulation` overloads.
   `gpuNarrowingIssues()` reports constants that overflow or underflow Float32.

**The trap that mattered most here**, stated correctly on the second attempt: `MonteCarloGPUDevice`
compiles its kernel inside a *failable* initializer, so a broken shader makes it return nil. The
`.requiresMetalGPU` trait does **not** hide that — it compiles a trivial kernel of its own and stays
enabled. What hid it was seventeen sites spelling "could not run" as `guard … else { print; return }`,
which reports **passed**. Measured by breaking the generated MSL, same three suites, 29 tests:
**4 failures before, 16 after** `9f661666` converted them all to `try #require`. Twelve tests
exercised the GPU, found no device, and passed. An earlier draft of this file said the *whole* GPU
surface went green; it was twelve of twenty-nine, because fourteen `#require` sites already failed
honestly. Review §4.6 calls those seventeen guards dead code under their suite traits — **they were
not**: the trait rules out an absent GPU, not our own kernel failing to compile.

### Settled since, and how

- **Error parity is DONE** (`e417c78b`). The kernel tests each operand *before* the operation and
  writes a code into a per-thread buffer; `GPUError.iterationsFailed` names the count, the first
  failing iteration and the condition. **§8 decided by Justin: throw by default,
  `onIterationError: .collect` to opt out.** Four entry points, sync and async.
  **Breaking in effect if not in signature** — a batch that used to return values with an `inf`
  among them now throws unless `.collect` is passed.
- **Why explicit guards and not result inspection.** Reading an error back out of a NaN means
  trusting the optimizer to have preserved IEEE. Measured: the whole contract suite passes under
  `mathMode = .fast` as well as `.safe`, so reporting no longer depends on the flag.
- **Fast math stays off, on a narrower basis than before.** Two residues the guards do not cover:
  a recorded failure still leaves the IEEE value in the output slot, and `inf * 0` is a NaN the
  interpreter does not throw on so nothing guards it. ~10% at 100k iterations, on a path the same
  benchmark clocks at 1.2–1.4× the CPU. **A performance decision now, reversible in one line
  (`compileOptions`), with the contract suite as evidence reporting survives the flip.**
- **A retraction worth reading before trusting any GPU measurement here.** A probe measured the
  kernel returning `1.0` for `0 / 0` under fast math. It was an artifact: the probe wrote `v / v`,
  which fast math folds via `x / x → 1`; the kernel divides two stack slots at runtime indices the
  compiler cannot follow. Re-measured in the kernel's real shape, fast and safe agree on every
  condition. **The proposal keeps the wrong version in §2.1 on purpose.**

## 3a. Next: Phase 2, GPU test integrity — partly done already

From §6, with what `9f661666` and `f5b4454e` already landed struck through:

- ~~three exposed guards to traits, 14 dead ones removed~~ — **done**, all 17 converted to
  `#require`; and they were not dead.
- ~~CPU-versus-GPU differential per opcode~~ — **done**, 22 operations, exact inputs through
  degenerate uniforms.
- ~~error parity~~ — **done** (`e417c78b`), though it belongs to §3.7 rather than Phase 2.
- **a CI-aware trait so the Mac job fails rather than skips** (decision 5.2). Still open, and §3
  is the concrete reason it matters.
- **KS per kernel distribution.** Open. Review §8 question 2 — per-family tolerance or the
  proposed α = 1e-5 two-sample critical value of 0.0156 at n = m = 50,000 — is unanswered.
- **samplers and evaluator into `MetalShaderSource`.** Open; `GPUOpcode.mslDeclarations` shows the
  shape to follow.
- **the two disabled tests to `withKnownIssue` + `.bug`.** Open.

---

## 4. The two reviews, and what was decided

Both incoming reviews were **accurate**; both had corrections worth keeping.

**`REVIEW_simulation_tests.md`** — 6 corrections, 1 escalation. The escalation is the antithetic SE
above: filed as test-quality, actually a library bug. Corrections include the GPU guard count (17,
not 25 — and 14 sit inside `.requiresMetalGPU` suites and cannot report false green) and the
`integrate` fix being half stale.

**`REVIEW_statistics_tests.md`** — 3 corrections, **eight conventions decided** (§3), which unblocks
32 assertions written as `isNaN || ≈ 0`. The load-bearing decision: **free functions return
`T.nan`; composed and checked entry points throw** — the `factorial`/`factorialChecked` shape.
Also: `weightedPercentile` → R-7; `weightedVariance` gains a weight-kind flag defaulting to
`.frequency` (its docstring says "reliability weights" and its formula is the frequency
denominator — the formula is the intent); QQ plotting positions gain a `PlottingPosition` flag
defaulting to **Blom**; `binomialPMF` moves to log-space (it **traps** at n = 2000 today).

`confidenceInterval` → `coverageInterval` plus a real `confidenceInterval` (μ ± zσ/√n) is decided
and lives in the simulation review's §5.3. Breaking; belongs with the 3.0.0 line.

---

## 5. Traps, in the order they bite

**`gh run view --job --log` truncates at ~9.5 MB, and these jobs pass `-v`.** Every compiler
invocation is a ~6 KB line, so the log ends ~100 seconds in, mid-build — **on passing runs too**.
Read cold it looks exactly like a hang. That cost two wrong conclusions today. Get the archive:
`gh api repos/<owner>/<repo>/actions/runs/<id>/logs > run.zip && unzip run.zip`. The real message
was 25 MB into one step.

**Compare against a passing run before reading anything into the shape of a failing one.** That is
what broke the above open, not a cleverer hypothesis.

**A green GPU suite can mean the GPU suite was deleted.** `MonteCarloGPUDevice` compiles its kernel
inside a failable initializer. A syntax error in the MSL returns nil, `MetalAvailability.canRunKernels`
is unaffected — it compiles a trivial kernel of its own — and every `.requiresMetalGPU` suite skips
on reaching for a device. The run is green with the GPU path untested. Never take a passing GPU run
as evidence that a shader edit compiled; `MetalKernelCompilationTests` is what makes it evidence.

**The pre-push gate is load-sensitive.** It blocked a push, then passed unchanged on retry minutes
later. Re-run quietly before hunting for what you broke.

**Exit tests are vacuous under any sanitizer.** The re-launched child aborts in sanitizer start-up
before the closure runs, and that abort is a non-zero exit, so `processExitsWith: .failure` is
satisfied by the sanitizer killing the child. `.requiresUnsanitizedRuntime` now skips them.

**A runaway-loop backstop is not a correctness bound.** `besselIterationLimit` is 1,000,000 and was
capping a search whose answer starts near `n`; at order 1,000,000 it returned a plausible number
wrong by 12×.

**In Steed's continued fraction the opening step is not the loop's step.** The opening is
`b + i·a·ξ/(p+iq)`; every later step is `b + a/c`. They differ by a factor of `i`. This bit twice
today — once writing the CF, once re-expressing it — and both times cost three significant figures.

**Numerical Recipes: the algorithms are not theirs, the expression is.** Steed, Temme, Lentz and
Barnett published the mathematics. Copying NR's naming and bookkeeping is what creates a problem on
a public AGPL repo. Three routines were re-expressed today, verified **bit-identical over 60,048
values**. Distinctive identifiers to watch for: `delh`, `dels`, `qnew`, `qab`/`qap`/`qam`. **Do not**
use `q1`/`q2` as evidence — 45+ files use them as fiscal quarters.

**An oracle is a measurement, not an authority.** SciPy is out by 1.8e-12 on `jv(200, 3000)` and
~5 ulp on `binom.pmf(15, 30, 0.5)`. Both incoming reviews cite that Bessel finding approvingly and
then take a reference value from scipy anyway. For anything with a closed form or an exact rational,
compute it exactly.

**Reviews carry stale claims to each other.** The `normalCDF` lower-tail claim has now appeared in
two reviews, having been fixed at `91ca7f03` before either was written. Check the code, not the
previous review.

**`quality-gate --check` takes ONE checker per flag.** `--check a,b,c` prints *"No checkers
enabled"* and **exits 0**.

**The gate rejects `==` on floating-point operands** against a non-zero literal. Use
`isEqual(to:)` where the comparison is deliberate; `== 0.0` is permitted.

**Budget nine minutes for a commit and a push** — both hooks run the gate, and the harness caps a
foreground command at 10 minutes, so a commit will appear to time out while still succeeding.
**Check `git log` before retrying.**

**`git commit -- <paths>` is the only safe form here.** A peer session shares this index and has had
work staged in it more than once.

**No suppression markers, ever.**

---

## 6. Cross-session context

**BusinessMathExcel** is a peer session on this machine, reachable at
`uds:/tmp/cc-socks/14089.sock`. It owns the Excel lane and the provenance audit; it ran today's
history rewrite. The lane split is settled: **mathematics here, spreadsheet argument semantics
there.** It shares this git index — always commit with explicit paths.

Still outstanding on its side, not ours: GitHub's unreferenced blobs, and 270 MB of orphaned
worktree copies of the books that Justin is deleting locally.

---

## 7. How this work has been done

**Prove the arithmetic did not move.** The NR re-expression preserved every operation exactly and
was verified bit-identical across 60,048 values. That turns a risky rewrite of numerical code into
a mechanical check.

**Write the stub.** *What is the simplest wrong implementation that still passes this?* Every
regression test added today was confirmed to fail against the defect it names, by reintroducing it.

**Print the value.** The 40% SE overstatement, the e³¹² seed-order overestimate, the 54.5% coin
flip and the `binomialPMF` trap were all found by running the code, none by reading it.

**Derive the bound, do not tune it.** Where a tolerance had to open, the mechanism was measured
first and written into the test as named terms.
