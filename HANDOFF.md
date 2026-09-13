# Handoff — 2026-09-13

**`main` is `43aaba32`, pushed and verified by `ls-remote`. `v3.0.0-alpha.5` is tagged and
CI-green.** The work queue is **`project/plans/TEST_REVIEW_ROADMAP.md`** — read that before
anything else; this file is the state and the traps, that file is the plan.

The next piece of work is **Phase A3**, and it needs no decisions.

## State

| | |
|---|---|
| branch | `main` at `3c979828`, local == remote by `ls-remote` |
| tags | latest `v3.0.0-alpha.5` = `82bff1ee`, verified on remote by `ls-remote` |
| tests | **7,757 in 696 suites**, exit 0, **1 known issue** (L17, deliberate) |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 0 errors |
| working tree | clean |
| CI | green on `82bff1ee` (all jobs, 21m52s) |

Nothing is unpushed. `v3.0.0-alpha.5` = `82bff1ee`; A1 and the roadmap ordering sit above it and
will go into alpha.6.

Always `--check all`. Plain `--no-cache` runs a subset and prints an identical PASSED line.
`--check` takes **one** checker per flag; `--check a,b,c` prints *"No checkers enabled"* and exits 0.

---

## 1. What this session was

Twenty-two incoming test-suite reviews were validated against the code, a roadmap was built from
them, and then **the six defects blocking 3.0.0 were fixed and shipped as `v3.0.0-alpha.5`**.

### Shipped in alpha.5 — the six blockers

| | Defect | What it was |
|---|---|---|
| B1 | DSO/DIO/DPO **4.01×** | An annual day count divided by a per-period turnover rate. DIO reported 91.25 days in a 91-day quarter where the answer is 22.75 — and 91.25 sits a quarter-day from the quarter's length, so it survived every sanity check |
| B2/B6 | Fiscal year varied by time zone | 17 source sites read `Calendar.current`. Measured with the package's own `ZoneInvariance.sweep`: 1 January 2025 was fiscal 2025 in Tokyo and **2024** in New York |
| B3 | Sharpe returned **0** at zero risk | Reported the best possible case — positive excess, zero risk — as mediocre. Guard deleted; `±∞` and `NaN` each answer for themselves |
| B4 | `bayes` NaN by accident | No contract. Now stated, pinned, paired with `bayesChecked`, and generic over `T: Real` (L2 landed with it) |
| B5 | "Is `enableCuttingPlanes` inert?" | **It never was.** Four of five return paths discarded the accumulated statistics for a fresh empty object (L16) |

Earlier in the session, Phase 1 of `REVIEW_simulation_tests.md` and the GPU error-parity work also
shipped into the same tag.

### And A1 and A2, since the tag

**A1** — `runFinancialSimulation` gained a seed, **additively, not breaking**, because the
randomness was never there. See §4.

**A2** (`43aaba32`) — `StochasticTestHelpers` is deleted; its 13 call sites across 6 process
suites take `DeterministicRNG` and the library's `boxMullerSeed(using:)`. Two corrections worth
carrying: the roadmap said users should take "the TestSupport Box-Muller" and **there isn't one** —
TestSupport has no normal transform, and the library's is the right target because its
`openUnitUniform` is open *by construction*. And the helper's contract bugs were *reproduced*, not
taken on the review's word: its recurrence is a **full-period** LCG (modulus 2⁶⁴, increment 1,
multiplier ≡ 1 mod 4), so Hull-Dobell makes both endpoints **guaranteed** rather than unlikely, and
inverting it gives the seeds. `4568919932995229531` → `u == 0.0`, where the `max(u1, 1e-15)` guard
yields **z = 8.31**, an 8.3σ normal delivered deterministically; `9137839865990459062` → `u == 1.0`,
unguarded, where `log(1) = 0` collapses the draw to **exactly 0.0**. At one hit per 2⁶⁴ draws both
were latent — the live defect was that it was *shared*.

---

## 2. Next: Phase A3, then the rest of Phase A

`TEST_REVIEW_ROADMAP.md` §5.2 is the order. Every item carries a **done when**, so no further
decisions are needed to proceed.

**A3 — document the debt asymmetry (L4).** `debtToAssets` should say it uses total liabilities, as
`interestBearingDebt` already says it uses interest-bearing debt, and both values pinned on the
shared fixture.

**Done when:** both are documented and both values are pinned on the shared fixture.

Then A4 (365 vs 365.25), A5 (the outlier rule), A6 (the counter asymmetry — closing it would clear
the one known issue). Then Phase B.

**On the gate's 10 warnings.** `--no-cache --check all` reports 0 errors and **10 warnings**, all
from `[test-quality]` and all one class: a test *claims* an improvement but asserts `<=` or `>=`,
which an unchanged implementation also satisfies. They sit in ten different directories, none of
them touched by A1 or A2. This is **Phase B1's material**, not drift — leave them until B, where
the roadmap says not to sweep past a red.

---

## 3. Decisions already taken — do not reopen

| Decision | Made by |
|---|---|
| **Keep taking reviews**; do not freeze intake | Justin |
| **Build durable quality infrastructure**, in service of a strong 3.0.0 with **correctness first** | Justin |
| `sharpeRatio` at zero risk: **delete the guard**, let IEEE answer | Justin |
| `bayes` zero denominator: **`nan` from the free function**, throw from `bayesChecked` — the `factorial`/`factorialChecked` shape | convention from the statistics review |
| Activity-ratio day count: **actual days**, so a leap year counts 366 | stated in the API docs |
| **ISDA is the right standard for accrual**, and the library already implements a subset. It is **not** the standard for DSO/DIO/DPO — that is dimensional, not conventional | §5a |

---

## 4. What the work taught, that the reviews did not

**Gate rules cannot deliver correctness.** Tested against the ten library defects found: a static
rule catches three, partially catches two, **misses five outright — and those five are the ones
that make the library wrong.** L11's 4.01× is type-correct and dimensionally wrong; no linter finds
that. This is §2b, and it is why intake stays open: the reviews are the only detector that finds
semantic defects, and four of the six blockers came from them.

**Every review count is a lower bound** (§2a). Measured corpus-wide against the best single-review
claim: `?? 0` 93 → **225**; `Calendar.current` in tests 73 → **152**; `Date()` 16 → **210**;
`#expect(true)` 13 → **75**; type-only error assertions ~300 → **530**. Structural, not sloppiness —
each review is domain-scoped and counts honestly within its domain. **Measure corpus-wide before
scheduling any thread.**

**An enabling fix wakes dormant assertions.** Fixing L16 made a guarded assertion execute for the
first time and it failed immediately (L17). Six such guards exist in the integer-programming suite
alone. This is ordering principle 4, and it is why Phase B precedes Phase D.

**Two defects were found by fixing, not by reviewing** — L16 and L17. Neither appears in any of the
22 reviews.

**Three reviews' claims were refuted**, and one pattern explains two of them: reviews cite each
other instead of the code. "DIO on 365 vs DSO on 150" does not exist; it was sourced to a batch
that has never arrived. **Valuation batch 2 is still referenced and still not received.**

**Five instances of "the code is right and the comment is wrong"** — `npvExcel` ×2, the H-model
test, `TVMReferenceTests`' header, `ClassifierEvaluationTests`' tie values. When a comment's
arithmetic disagrees with the code, check the code first; it has won every time.

---

## 5. Traps, in the order they bite

**`ZoneInvariance.sweep` mutates `NSTimeZone.default`, and its own documentation says the calling
suite must be `.serialized`.** I missed that and got an order-dependent test: it passed inside its
suite and failed in isolation, because a sweep had already moved the default zone before `Period`
first looked.

**A grep for `Calendar.current` is not a search for ambient time.** `Calendar(identifier: .gregorian)`
looks fixed and carries `TimeZone.current`. One such site put January's value in the previous
year's Q4, and the grep could not see it.

**A statistic can be zero while the feature works.** Cutting planes did the entire job — closing an
IP at the root with no branching — while `totalCutsGenerated` read 0. I concluded "cuts never fire"
from the counter and was wrong. Trace the behaviour, not the telemetry.

**A green GPU suite can mean the GPU suite was removed.** `MonteCarloGPUDevice` compiles its kernel
inside a *failable* initializer, so a broken shader returns nil and suites skip. Measured: breaking
the MSL took three suites from 4 failures to 16 only *after* 17 `guard … else { return }` sites
became `#require`.

**`.requiresMetalGPU` is a runtime trait, not a compile guard.** It cost a red CI on Linux, where
`MonteCarloGPUDevice` does not exist at all. The guard has to be lexical `#if canImport(Metal)`.

**The pre-commit gate takes ~9 minutes and the harness caps a command at 10.** A commit will look
like it timed out while succeeding. **Check `git log` before retrying, and never background a
commit** — a peer session shares this index.

**The pre-commit hook runs a *bare* `quality-gate`** — no `--no-cache`, no `--check all`. That is
the cached subset, and it prints a PASSED line indistinguishable from a full run. **A green commit
is not evidence the gate is clean; run it yourself.** The hook's own header records the sibling
lesson — it used to pipe through `| tail -3`, keeping the summary and discarding the findings above
it, so "a blocked commit reported only that it had been blocked."

**`git add -- <path>` on an already-deleted file fails with `fatal: pathspec … did not match`, and
that aborts the *entire* add** — every other path on the same command line goes unstaged, silently.
Commit "with explicit paths" then produces a commit holding only whatever was already in the index.
It bit A2: the deletion had been staged by `git rm`, so the commit landed as *delete the helper,
keep the six files that call it* — a broken tree that still reported success. Stage the deletion
separately (or let `git rm` carry it) and **read the `--stat` line the commit prints**: "1 file
changed" where you expected eight is the whole tell.

**The gate rejects `==` on floating-point operands** against a non-zero literal. Use `isEqual(to:)`
where the comparison is deliberate; `== 0.0` is permitted. Auditor justification comments must be
**single-line, on the line immediately above**.

**`doc-claims` will block a push** when a documented number drifts. Its advice is right: find out
which one is wrong before changing either. A bond price moved two cents because the old figure was
never canonical — it was this machine's answer.

---

## 6. Cross-session context

**BusinessMathExcel** is a peer session on this machine, reachable at `uds:/tmp/cc-socks/14089.sock`.
It owns the Excel lane. **It shares this git index — always commit with explicit paths.**

History was rewritten on 2026-09-12 (`git filter-repo`, ~90 MB of third-party books removed). Any
SHA quoted in a document older than that is dead; commit *subjects* still resolve. Never `git pull`
from a stale clone — `git fetch --prune --prune-tags origin && git reset --hard origin/main`.

---

## 7. How this work has been done

**Validate every review claim against the code.** Twenty-two for twenty-two contained something
that changed the fix — 3 refutations, ~11 corrections, 4 resolutions of questions the review left
open, and 11 findings that were in no review at all.

**Confirm RED by reintroducing the defect.** Every fix this session was verified by putting the
defect back and watching the new test fail, with the failure message carrying the argument:
*"inventory turned 4.0 times in 91.0 days, so it cannot sit for 91.25"*.

**Measure the blast radius; do not estimate it.** B2 broke 75 tests in 5 files, and two of those
were real defects rather than test churn.

**Print the value.** The 4.01×, the zone disagreement, the cut counter and the reseeding collapse
were all found by running code, none by reading it.
