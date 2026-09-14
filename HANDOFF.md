# Handoff — 2026-09-13 (Phase A complete)

**`main` is `06d997ad`, pushed and verified by `ls-remote`. `v3.0.0-alpha.5` is tagged and
CI-green.** The work queue is **`project/plans/TEST_REVIEW_ROADMAP.md`** — read that before
anything else; this file is the state and the traps, that file is the plan.

**Phase A is complete.** The next piece of work is **B1**, and it needs no decisions.

## State

| | |
|---|---|
| branch | `main` at `06d997ad`, local == remote by `ls-remote` |
| tags | latest `v3.0.0-alpha.5` = `82bff1ee`, verified on remote by `ls-remote` |
| tests | **7,781 in 700 suites**, exit 0, **0 known issues** |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 0 errors, 10 warnings |
| working tree | clean |
| CI | green on `82bff1ee`; nothing since has been CI-verified |

Nothing is unpushed. Everything above `82bff1ee` goes into alpha.6.

**The known-issue count is 0 for the first time in this programme** — L17's marker came out when
L18 was fixed. If a run reports a known issue, something regressed; it is no longer the
steady state.

**The 10 gate warnings are the standing set** — all `[test-quality]`, all one class ("claims an
improvement but asserts `<=`/`>=`, which an unchanged implementation also satisfies"), in ten
directories. They are **B1's material**. They have not moved all session; treat any change in that
count as yours.

Always `--check all`. Plain `--no-cache` runs a subset and prints an identical PASSED line.
`--check` takes **one** checker per flag; `--check a,b,c` prints *"No checkers enabled"* and exits 0.

---

## 1. How we got here

Twenty-two incoming test-suite reviews were validated against the code, a roadmap was built from
them, and **the six defects blocking 3.0.0 were fixed and shipped as `v3.0.0-alpha.5`**. Since the
tag, **Phase A has been completed in full** — six items, five commits, one new defect found and
fixed along the way.

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

### Phase A, since the tag — all six done

| | Item | Commit | What it turned out to be |
|---|---|---|---|
| A1 | `seed:` on `runFinancialSimulation` | pre-session | Additive, not breaking — the randomness was in the caller's builder closure. See §4 |
| A2 | delete `StochasticTestHelpers` | `43aaba32` | 13 sites across 6 suites onto `DeterministicRNG` + `boxMullerSeed(using:)` |
| A3 | document the debt asymmetry | `f49472c8` | **Two shipped doc comments stated a formula the code does not implement** |
| A4 | decide 365 vs 365.25 | `03220a61` | **Not a convention at all**, applied to a seconds interval, at ten sites |
| A5 | decide the outlier rule | `e3f69aa2` | **The review's claim was refuted**; a sharper defect found in its place |
| A6 | decide the counter asymmetry | `06d997ad` | **A solver feature that had never once worked** (L18) |

**The one finding worth carrying forward is L18.** Gomory cuts were emitted over tableau columns —
structural variables *and slacks* — and imposed over the structural variables alone. On
`max x+y` s.t. `x+2y ≤ 7`, `2x+y ≤ 7`, the cut was `[0, 0, -0.7071, -0.7071] · x ≤ -0.7071`: both
non-zeros on slack columns, so over `(x, y)` the left side is identically zero and the constraint
reads `0 ≤ -0.7071` — **false at every point**, including all three integer optima. The LP went
infeasible on the first cut, every time.

**It failed safe, which is why it lasted.** The infeasible re-solve breaks the loop, the node-local
constraints are discarded, branch-and-bound continues unaided. Answers were always right —
`enableCuttingPlanes: true` simply bought nothing and cost the work. Measured before: cuts on and
cuts off both gave 4.0 at (3,1) in 3 nodes. After: **1 node**. **Deliberately not in the CHANGELOG**
— no caller ever got a wrong answer, and the only user is Justin.

**A2's detail worth keeping**, because it is the shape of proof this programme wants: the deleted
helper's recurrence is a **full-period** LCG (modulus 2⁶⁴, increment 1, multiplier ≡ 1 mod 4), so
Hull-Dobell makes both endpoints **guaranteed** rather than unlikely, and inverting it gives exact
seeds. `4568919932995229531` → `u == 0.0`, where the `max(u1, 1e-15)` guard yields **z = 8.31**, an
8.3σ normal delivered deterministically; `9137839865990459062` → `u == 1.0`, unguarded, where
`log(1) = 0` collapses the draw to **exactly 0.0**. Both latent at one hit per 2⁶⁴ — the live
defect was that the helper was *shared*. Also: the roadmap said to use "the TestSupport
Box-Muller" and **there isn't one**; the library's is the right target because its
`openUnitUniform` is open *by construction*.

---

## 2. Next: B1, then the rest of Phase B

`TEST_REVIEW_ROADMAP.md` §5.2 is the order. Every item carries a **done when**, so no further
decisions are needed to proceed.

**B1 — the 18 vacuous optimizer assertions.** Seven `.rounded()` comparisons and eleven
always-true convergence disjunctions. Each must assert the real bound.

**Done when:** each asserts the bound it claims to. Either the suite stays green — ~18 unknowns
become evidence — or it turns red on a solver defect. **Do not sweep past a red here.**

**The 10 standing gate warnings are the same material**, and they name their own tests: a test
*claims* an improvement but asserts `<=` or `>=`, which an unchanged implementation also satisfies.
`noCombinationBeatsTheReportedScore`, `seasonalBeatsGrid`, `nonSeasonalBeatsGrid`,
`testDuPontImprovementStrategies`, `testMultiStartImprovement`, `optimalBetterThanEqual`,
`optimizerBeatsEqualWeights`, `cvarIsNeverBetterThanVaR`, `testCutsImproveDualBound`,
`tighterConstraintsDontImprove`. Closing B1 should take that count down.

**Take the warning about a red seriously.** A6 was filed as a naming decision and the subsystem
next door turned out to contain a feature that had never worked. Two of B1's eleven are in
optimization and one — `testCutsImproveDualBound` — is in the cutting-plane code that L18 just
changed, so it is now asserting against a solver that behaves differently.

Then B2 (3 stale integer-programming assertions), B3 (`Phase1_CutValidityTests` — **note L18
changed the cut path underneath it**), B4 (wall-clock assertions behind `.benchmarkOnly`).
Then Phase C.

---

## 2a. Doc debt, deliberately deferred

**No CHANGELOG entry exists for any of Phase A.** The convention here is roadmap-at-the-time,
CHANGELOG-at-release, which is how A1 was handled. At release, alpha.6 needs:

- **A4 is breaking.** Bond prices move — measured 12¢ / 31¢ / 55¢ at 2 / 10 / 30 years per 1,000 of
  face. Source compatibility is unchanged (`dayCount:` is defaulted everywhere).
- **A5 adds public API** — `ModifiedZScoreAnomalyDetector`, `IQRAnomalyDetector`.
- **A3 and A6 are documentation and tests**; L18 is deliberately omitted, per above.

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
| Day counts: **a convention is at stake where a counterparty settles on the number; everywhere else 365 or 365.25 is a modelling choice and has to say so.** Bonds route through `DayCountConvention` (default `.actual365`); CAGR keeps 365.25 *because* it is not a day count | A4 |
| L18 gets **no CHANGELOG entry** — no caller ever received a wrong answer, and the only user is Justin | Justin |
| Anomaly detection keeps **all three rules**. The rolling z-score tracks a moving level; the two robust rules assume a stable level and resist contamination. Neither replaces the other | A5 |

---

## 4. What the work taught, that the reviews did not

**The reviews are a detector, not an oracle — and that is the sharpest thing Phase A taught.**
Every one of A2 through A6 differed materially from its roadmap entry. A3 was filed as "document one
property" and was two shipped doc comments stating a formula the code does not implement. A4 was
filed as "pick 365 or 365.25" and was a *non-convention* applied to a seconds interval at ten sites.
A5's premise was **refuted outright**. A6 was filed as a naming decision and was a solver feature
that had never once worked.

So §2b's claim survives but its mechanism changes. The reviews are not valuable because they are
right — four of five were wrong in some material way. They are valuable because they **point at the
right file with enough specificity that someone runs the code**. The engine of this programme is the
rule that every claim gets validated against a running program, and the reviews are what aim it.

**A corollary worth acting on:** two roadmap rows have now recorded a claim as "verified" when only
the *arithmetic* had been checked and the code path never run (L12 most recently). When a row says
verified, check what was verified.

**Gate rules cannot deliver correctness.** Tested against the ten library defects found: a static
rule catches three, partially catches two, **misses five outright — and those five are the ones
that make the library wrong.** L11's 4.01× is type-correct and dimensionally wrong; no linter finds
that. L18 is the same shape: a cut in the wrong vector space is type-correct and arithmetically
meaningless, and no linter finds that either.

**A `withKnownIssue` can be a tripwire pointing forward at its own resolution, and should be.**
L17's marker carried the note "fixing the asymmetry makes this marker fail, which is the point of
recording it this way" — and after L18 was fixed, the *only* failure in 7,781 tests was
`Known issue was not recorded`. Record markers so that fixing the cause breaks the build. A
suppressed expectation that stays quiet forever is just a deleted test.

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

**A gate failure can be the machine, not the code.** A commit was blocked by the pre-commit hook
immediately after a full suite plus a full gate had just run, and the identical command passed a
minute later with nothing changed. Load-sensitive checkers time out. **Re-run quiet before
believing a gate failure**, and check `git log` — the commit had not landed.

**Inserting a stored property above a `public init` steals the init's documentation.** `doc-coverage`
dropped to 99% with "Public initializer 'init' is missing documentation" ×3 after `dayCount` was
declared between each init's doc block and the init. The declaration goes *above* the doc block,
and the new parameter needs its own `- Parameters:` entry.

**Doc-comment fences must be self-contained.** Two new examples referenced a `periods` they never
bound; `doc-comment-code` rejected both. The preamble is Foundation plus this module, on purpose —
whatever the fence needs to compile is what a reader copying it out of Quick Help has to type.

**Swift Testing's message parameter is a `Comment`, not a `String`.** A `"literal" + interpolation`
concatenation does not compile there. Bind the values first, then use one interpolated literal.

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
