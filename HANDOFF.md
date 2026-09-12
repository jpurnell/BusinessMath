# Handoff — 2026-09-12

**`main` is `d3543352`, pushed and verified. History was rewritten today — read §1 before running
any git command.** Two test-suite reviews are validated, decided and committed. The next piece of
work is **Phase 1 of `REVIEW_simulation_tests.md` §6**, and every decision it needs is settled.

## State

| | |
|---|---|
| branch | `main` at `d3543352`, local == remote by `ls-remote` |
| tags | **89** (was 109). Latest `v3.0.0-alpha.4` |
| tests | 7,700 in 689 suites, exit 0 |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 45/45, **0 errors**, 10 warnings |
| the 10 warnings | pre-existing `non-strict-improvement` notices in other suites. Not the skipped-test inventory, whatever older handoffs said |
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

CI green throughout. `Release Tests` green on both platforms and Thread Sanitizer, verified for the
right reason: 7,700 tests ran and the three exit tests report **skipped**, not passed.

---

## 3. Next: Phase 1 of `REVIEW_simulation_tests.md` §6

Library correctness, non-breaking. In order:

1. **The antithetic standard error is wrong by 40%.** `MonteCarloEngine.price` pools 2N negatively
   correlated paths as independent instead of taking the variance of the N/2 **pair means**.
   Measured over 200 seeds: realised sd(price) 0.3010 plain vs **0.2084** antithetic — a real 31%
   variance reduction — while reported SE is 0.2926 vs 0.2921, i.e. no reduction reported.
   `MonteCarloPricingResult` documents "price ± 2 · standardError with 95% confidence"; for
   antithetic runs that interval is 40% too wide. The guarding test
   `antitheticReducesStandardError` passes **109 of 200 seeds (54.5%)** — a coin flip that seed 42
   wins. **Fix the SE, then replace that test with the SE-honesty check.**
2. **`integrate` samples on a biased lattice.** `distributionUniform` is
   `(u * 10_000_000).rounded(.down) / 10_000_000` — a systematic **downward bias of ~5e-8**, not
   merely a 1e-7 lattice. Drop the wrapper; `openUnitUniform` underneath is already correct.
   Direction matters: bias does not average out with more samples.
3. **`a * 0 → 0` is unsound** (`BytecodeOptimizer.swift:299–306`, unconditional). `inf*0` and
   `NaN*0` are NaN, and a negative `a` gives −0.0. Restrict to known-finite operands. `a * 1 → a`
   is sound and needs nothing.
4. **Constant folding must preserve interpreter errors.** `BytecodeInterpreter` throws on
   divide-by-zero (`MonteCarloExpressionModel.swift:246`), `sqrt` of negative (:281) and `log` of
   non-positive (:287). `log(0) * 0` returns 0 optimized and **throws** unoptimized.
5. **CPU/GPU contract.** Pinned opcode table (assertions today are only `>= 0` and `<= 16`, so any
   renumbering passes), stack-depth rejection, `Float` constant narrowing, malformed-bytecode
   validation, error parity.

Everything after that is in §6 of the same document: GPU test integrity, the breaking API set,
assertion strength, test infrastructure, gate rules.

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
