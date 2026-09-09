# Handoff — 2026-09-09

**v2.16.0 is released. Stage 5 of the marketing leg is complete — only stage 6 is left,
and it is deliberately held for the real 3.0.0 because it is the breaking one.** Work
ships additively as point releases.

## State

| | |
|---|---|
| branch | `main` at `265e2130`, pushed |
| last tag | `v2.16.0` (`c9d0c650`), released, GitHub release published |
| tests | 7,528 in 669 suites |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 45/45, 0/0 |
| working tree | clean except `project/plans/proposals/excel_function_coverage_matrix_bak.tsv` — **the user's own backup, deliberately untracked, leave it alone** |

Always `--check all`. Plain `--no-cache` runs 40 of 45 and prints an identical PASSED line.

## The plan being executed

Both plans are approved and current:
- `project/plans/upcoming/MarketingLeg.md` — the spec. §3.5 has the build order, §4 the API surface.
- `project/plans/upcoming/v3.0.0_SCOPE.md` — four spines, and §0.1 on what actually forces the major.

**Strategy the user chose:** ship the marketing leg additively as point releases — a
"shadow 3.0.0" — and cut the real 3.0.0 later for the breaking items only.

**Only three things genuinely force the major**, and none has been done:
1. DE/PSO `optimizeDetailed` → `throws` (spine 1, GPU determinism)
2. Deleting `sampleSize` — deprecated in 2.7.0, deletion waits
3. `SaaSModel` / `SubscriptionBoxModel` LTV delegation

## Build-order progress

| Stage | Contents | State |
|---|---|---|
| **0 — Foundation** | LogisticRegression, Classification, Survival, Concentration | **done** |
| **1 — Graph** | `Network/Graph`, Traversal, Model Definition parity cut | **done** |
| **2 — Experiment** | SequentialTesting; the rest shipped in 2.7.0 | **done** |
| **3 — Marketing core** | Value, Pricing, Response, Segmentation — eight files | **done** |
| **4 — Graph consumers** | Markov, Centrality, Projection, Community | **done** |
| **5 — Attribution** | `Attribution/`, `Basket/`, `Segmentation/Behavioural` | **done** |
| **6 — Templates** | SaaSModel / SubscriptionBox LTV delegation | **open**, and breaking |

Stage 5 landed in three commits: `744c316d` (the attribution trio), `f7396c95`
(association rules), `265e2130` (behavioural segmentation).

### What is left, and the order the user wants it in

**Stage 6 is the only thing left in the leg, and it should not ship as a point release.**
Delegating `SaaSModel` / `SubscriptionBoxModel` to `customerLifetimeValue` is source-
breaking, so it belongs with the other two breaking items in the real 3.0.0:

1. DE/PSO `optimizeDetailed` → `throws` (spine 1, GPU determinism)
2. Deleting `sampleSize` — deprecated in 2.7.0
3. The stage 6 delegation

**Before stage 6, the user expects more statistical work for Excel coverage.** Their
words: *"I think there may be some more statistical function implementations to get to
100% coverage of Excel's functionality, so we'll probably take that before we get to
stage 6, or we may just implement it in a branch until we've got everything we want for
v3.0.0b in place."* So the next question to settle is which of those two — Excel
statistical coverage on `main` as more point releases, or a `v3.0.0b` branch that
accumulates the breaking work. Ask before assuming.

**Another session is working the Excel coverage buckets.** It identified itself as
SwiftExcelFunctions and has a plan landing in `project/plans/proposals/excel-coverage/`.
Coordinate before starting Excel statistical work — that is its territory, and the
overlap with stage 6 sequencing is exactly what the user flagged.

**Owed at the next tag:** CHANGELOG has no `Unreleased` section for the four commits since
`v2.16.0`, and `master_plan.md`'s Current Status still describes the leg as unreleased
with stages 5 and 6 open. Both were fully reconciled at `2aab7e86`, so this is small.

## How this work has been done, and why it keeps paying

Strict TDD — RED, GREEN, commit at each green state — with one rule that has mattered more
than any other:

**Verify against an identity, not a fixture.** Every piece so far is checked by something
that must be true rather than by stored numbers:

- IRLS against an independent BFGS likelihood maximisation
- The binomial score equation `Σ(y − p) = 0` — fitted propensities average to the observed
  response rate whenever an intercept is fitted, whatever the other predictors are
- AUC against the Mann–Whitney statistic — exact, including the half-credit for ties
- Kaplan–Meier against the empirical survival function it must reduce to without censoring
- Cohort retention against Kaplan–Meier, and its area against the restricted mean
- Gini against its own second definition
- Modularity's all-one-community identity, exactly zero
- A Markov chain reproducing the conversion rate of the journeys it was built from
- Finite-horizon CLV converging on the perpetuity formula
- Two-model and class-transformation uplift, algebraically the same number on a balanced
  saturated design and agreeing to 1e-9 through independent code paths
- The Lerner condition `(P* − c)/P* = −1/ε(P*)` at the optimum of all three demand forms —
  one identity checking three closed-form optima against three elasticity functions
- The efficiency axiom across every `AttributionModel` — credit sums to the converted
  value for heuristics, removal effect and Shapley alike, tested in one loop over the
  protocol rather than per implementation
- Shapley's null player, which is exact rather than approximate: a channel that changes no
  coalition's worth is paid `== 0`, the one assertion in attribution needing no tolerance
- `support(A ∪ C) = confidence · support(A)`, conditional probability rearranged
- A basket's co-occurrence count against the shared-count weight of a `BipartiteProjection`
  over the same transactions — one quantity, two modules, no shared code
- Both segmentation methods partitioning: every customer in exactly one segment, sizes
  summing to the input count

Several of those need no reference implementation at all. See
`feedback-exact-oracle-beats-tolerance` in memory: a method that is wrong everywhere can be
exact at the one point you tested, and that has happened in this repo.

**The other half is refusing rather than returning a plausible number.** Separated logistic
data has no MLE; a single outcome class has zero AUC pairs, not an AUC of zero; a survival
sample with no failures means short follow-up, not immortality; inelastic demand has no
optimal price and the closed form returns a *negative* one; a divergent CLV perpetuity
likewise. Each is a case where the wrong answer is indistinguishable from the right one by
inspection. Stage 3 added four more: a mis-shaped population scored as a column of one
halves, a break-even ratio above one, an uplift bucket with no controls, and a retention
column averaged with cohorts that never reached it.

## Traps, in the order they will bite

**Budget nine minutes for a commit.** The pre-commit hook runs a 40-of-45 gate, which
outruns the Bash tool's two-minute default and gets killed at exactly the wrong moment.
Pass an explicit long `timeout`. Do **not** background the commit to get around it — see
`feedback-background-commit-race`.

**Commit with an explicit pathspec.** `git commit -- <paths>`, never a bare `git commit`
after `git add`. Git builds from the whole index, so another session's staged work comes
along — this happened here in a *foreground* commit, putting another session's file rename
into `affa6c91`.

**Do not reach for the suppression markers.** `// stochastic:exempt` and
`// fp-safety:disable` exist and are used elsewhere, but every case this work would have
needed one was avoidable by reusing something that already existed. Zero added across
twenty commits.

**`doc-run` timeouts scale with machine load, not with code.** Three errors at load 335, one
at 130, zero at 22, on an unchanged tree. Re-run it alone on a quiet machine before blaming
a change — this cost two false attributions in one session. See
`feedback-docrun-load-sensitive`.

**The gate flags a test call that omits a defaulted `seed:`.** Even when the default is a
fixed constant, so the test is deterministic today — the point is that it would silently
stop being so if the default ever changed, and nothing in the test recorded the
dependency. State the seed at the call site. Do **not** reach for the
`// Justification:` escape the diagnostic offers; that is a suppression annotation.

**The gate rejects `#expect(x != nil)` and `#expect(x != 0)`** as weak assertions, and it
is right to. Assert the value. When that reads as awkward the fixture is usually wrong: the
fix here was to replace a "does it fit at all" check with data that hits its choke price
exactly, so the assertion became a slope and an intercept.

**My own recurring mistakes, so the next session can skip them:**
- A doc `///` fence must compile standalone. Three fences in one session referenced bindings
  they did not define. Write the bindings into the fence from the start.
- An empty array or dictionary literal in a test gives the compiler nothing to infer a
  generic parameter from — annotate it. Four times.
- A test method named after the function under test *shadows* it inside the suite.
  `func optimalPrice()` broke six call sites.
- **Do not assert a number you have not measured.** "The wrong form still scores above
  0.99" was a guess; it is 0.975. Compute it, then write it down — and say in the comment
  that it was measured.

## Where to pick up

Ask the user which of the two paths they want before writing anything: Excel statistical
coverage as further point releases on `main`, or a `v3.0.0b` branch accumulating the three
breaking items. They raised both and settled neither.

Either way, coordinate with the SwiftExcelFunctions session first — the Excel coverage
buckets are its work, and duplicating them would waste both sessions.

Stage 6 itself is small and specified: `MarketingLeg.md` §3.3 for the delegation,
`v3.0.0_SCOPE.md` §0.1 for why it forces the major.
