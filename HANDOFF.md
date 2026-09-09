# Handoff — 2026-09-08 (late)

**v2.15.0 is released. Twenty commits since, all green. Stage 3 of the marketing leg is
complete, which unblocks stages 5 and 6 — the last two.** Work ships additively as point
releases toward 3.0.0.

## State

| | |
|---|---|
| branch | `main` at `d60f4672` |
| last tag | `v2.15.0` (`be704795`), released and CI-green |
| tests | 7,476 in 665 suites |
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
| **2 — Experiment** | SequentialTesting; the other three files and the deprecations shipped in 2.7.0 | **done** |
| **4 — Graph consumers** | Markov, Centrality, Projection, Community | **done** |
| **3 — Marketing core** | Value, Pricing, Response, Segmentation — all eight files | **done** |
| **5 — Attribution** | `Attribution/`, `Basket/`, `Segmentation/Behavioural` | **open** |
| **6 — Templates** | SaaSModel / SubscriptionBox delegation | **open**; carries a breaking item |

Stage 3's last four landed as `f7d00ed3` (ResponseModel), `7823e20e` (Uplift), `065b3fbf`
(PriceResponse) and `d60f4672` (CohortRetention).

### What stages 5 and 6 need

Both dependencies are now satisfied, so they can run in parallel. §3.5 flags **stage 5 as
the schedule risk**: the largest single piece with the least slack, and everything it
needs already exists.

- `Attribution/AttributionModel.swift` — the protocol plus first/last/linear/decay heuristics
- `Attribution/MarkovAttribution.swift` — over `Network/Markov/RemovalEffect`, which is done
  and already uses the matrix-surgery definition (Anderl), not path truncation
- `Attribution/ShapleyAttribution.swift` — exact enumeration for small channel sets; §10.2
  gives efficiency and symmetry as the identities
- `Basket/AssociationRules.swift` — over `Network/Projection/BipartiteProjection`
- `Segmentation/BehaviouralSegments.swift` — over KMeans and `Network/Community/Louvain`
- Stage 6 — `SaaSModel` / `SubscriptionBoxModel` delegating to `customerLifetimeValue`.
  This one is breaking; hold it for the real 3.0.0 rather than a point release.

**Owed at release time:** CHANGELOG.md has no `Unreleased` section for any of the twenty
commits since 2.15.0, and `project/master_plan.md` does not mention the marketing leg at
all. Both must be reconciled before anything is tagged — that is the standing
doc-housekeeping rule, and twenty commits of drift is what it exists to prevent.

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

Stages 5 and 6 are both open and mutually independent. Take stage 5 first — it is the
schedule risk, and every dependency it has now exists. Read `MarketingLeg.md` §3.2 for the
file list and §10.1–10.2 for the reference truth and identities each piece is owed; the API
surface is specified, not left open.

Stage 6 is breaking. Hold it for the real 3.0.0 rather than slipping it into a point
release.
