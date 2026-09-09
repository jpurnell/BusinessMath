# Handoff — 2026-09-08 (evening)

**v2.15.0 is released. Fifteen commits since, all pushed, all green. The tree is clean and
nothing is in flight.** Work in progress is the marketing leg toward 3.0.0, shipping
additively as point releases.

## State

| | |
|---|---|
| branch | `main` at `caa583c2`, pushed |
| last tag | `v2.15.0` (`be704795`), released and CI-green |
| tests | 7,429 in 661 suites |
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
| **3 — Marketing core** | Value ✅, Pricing ✅, Response/CampaignDepth ✅, Segmentation/RFM ✅ — **four files remain** | *in progress* |
| **5 — Attribution** | `Attribution/`, `Basket/`, `Segmentation/Behavioural` | blocked on 3 |
| **6 — Templates** | SaaSModel / SubscriptionBox delegation | blocked on 3; carries a breaking item |

### What is left in stage 3

Four files, all **surfaces over things that now exist** rather than new mathematics —
which is the shape §3.2 intended and makes them comparatively cheap:

- `Marketing/Response/ResponseModel.swift` — over `LogisticRegression`
- `Marketing/Response/Uplift.swift` — two-model and class-transformation uplift
- `Marketing/Pricing/PriceResponse.swift` — demand-curve fitting
- `Marketing/Value/CohortRetention.swift` — cohort table, over `Statistics/Survival`

Stage 5's attribution is flagged in §3.5 as the schedule risk: largest single piece,
least slack, and it needs both stage 3 and stage 4. Stage 4 is done, so stage 3 is the
only thing holding it.

## How this work has been done, and why it keeps paying

Strict TDD — RED, GREEN, commit at each green state — with one rule that has mattered more
than any other:

**Verify against an identity, not a fixture.** Every piece so far is checked by something
that must be true rather than by stored numbers:

- IRLS against an independent BFGS likelihood maximisation
- AUC against the Mann–Whitney statistic — exact, including the half-credit for ties
- Kaplan–Meier against the empirical survival function it must reduce to without censoring
- Gini against its own second definition
- Modularity's all-one-community identity, exactly zero
- A Markov chain reproducing the conversion rate of the journeys it was built from
- Finite-horizon CLV converging on the perpetuity formula

Several of those need no reference implementation at all. See
`feedback-exact-oracle-beats-tolerance` in memory: a method that is wrong everywhere can be
exact at the one point you tested, and that has happened in this repo.

**The other half is refusing rather than returning a plausible number.** Separated logistic
data has no MLE; a single outcome class has zero AUC pairs, not an AUC of zero; a survival
sample with no failures means short follow-up, not immortality; inelastic demand has no
optimal price and the closed form returns a *negative* one; a divergent CLV perpetuity
likewise. Each is a case where the wrong answer is indistinguishable from the right one by
inspection.

## Traps, in the order they will bite

**Commit with an explicit pathspec.** `git commit -- <paths>`, never a bare `git commit`
after `git add`. Git builds from the whole index, so another session's staged work comes
along — this happened here in a *foreground* commit, putting another session's file rename
into `affa6c91`. See `feedback-background-commit-race`.

**Do not reach for the suppression markers.** `// stochastic:exempt` and
`// fp-safety:disable` exist and are used elsewhere, but every case this work would have
needed one was avoidable by reusing something that already existed. Zero added across
fifteen commits.

**`doc-run` timeouts scale with machine load, not with code.** Three errors at load 335, one
at 130, zero at 22, on an unchanged tree. Re-run it alone on a quiet machine before blaming
a change — this cost two false attributions in one session. See
`feedback-docrun-load-sensitive`.

**My own recurring mistakes, so the next session can skip them:**
- A doc `///` fence must compile standalone. Three fences this session referenced bindings
  they did not define. Write the bindings into the fence from the start.
- An empty array or dictionary literal in a test gives the compiler nothing to infer a
  generic parameter from — annotate it. Four times.
- A test method named after the function under test *shadows* it inside the suite.
  `func optimalPrice()` broke six call sites.

## Where to pick up

Finish stage 3's four remaining files, then stages 5 and 6 open together. Read
`MarketingLeg.md` §3.2 for the file list and §4 for the committed API shapes before
starting — the API surface is specified, not left open.
