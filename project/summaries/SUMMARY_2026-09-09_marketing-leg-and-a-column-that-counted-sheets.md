# The marketing leg, verified by identity — and a column that counted sheets

**2026-09-08 – 09** · shipped **2.16.0** at `e67f2fde`, **2.17.0** at `dcb7f3b9`, **2.18.0** at
`7069e5e1` · 7,476 tests / 665 suites, then 7,532 / 670, then 7,590 / 675 · quality-gate
45/45, 0 errors, 0 warnings with release-readiness passing at each · CI green on all three

Reconstructed on 2026-10-05 from the git history and the CHANGELOG; it is not a contemporaneous
note.

Fifty-eight commits from `434daf21`, two of them merges. Three additive minor releases in about
thirty-two hours, with no signature changed and nothing removed. The code is the larger part by
volume. The part worth carrying forward is smaller: **a search shaped like a name finds only
what is named that way**, and that one mistake recurred in five different places across the two
days, once at the cost of most of a morning.

---

## What shipped

| Release | Content |
|---|---|
| **2.16.0** | Twenty-eight new source files: `LogisticRegression`, `Statistics/Classification/`, `Statistics/Survival/`, `Statistics/Concentration/`, `SequentialTesting`, a top-level `Network/` (graph engine, Markov chains, centrality, bipartite projection, Louvain) and a top-level `Marketing/` (CLV, pricing, campaign depth, RFM, response, uplift, demand curves, retention triangle) |
| **2.17.0** | `Marketing/Attribution/` (heuristics, `MarkovAttribution`, `ShapleyAttribution`), `AssociationRules`, behavioural segmentation, and `constraintPenaltyWeight` on all five constrained heuristics |
| **2.18.0** | `TimeSeries.fitETS(seasonality:config:)`, `ETSSeasonality`, `smape(_:_:)`, `Complex` `notation` / `init?(notation:)`, the GPU read-back fix, and DocC chapter 7 |

The stated theme of 2.16.0 is refusal: separated logistic data, a survival sample with no
observed failures, inelastic demand and a cohort that has not reached an offset each return
`nil` or throw where the closed form gives a well-formed wrong number. Verification is by
identity wherever one exists. AUC is checked against the Mann-Whitney statistic, Kaplan-Meier
against the empirical survival function, Gini against its pairwise definition, the two uplift
estimators against each other, and three demand-curve optima against the Lerner condition.

One internal change: `DependencyGraph.components(of:)` now delegates to the generic Tarjan in
`Network/`. The old body was deleted in `ecee4c6c`, the commit that proved parity over six
graphs with component ordering included.

---

## Worth carrying forward

### 1. A name-shaped search, five times

- **Interior Point** (`9dc4f57d`). The gap audit searched for the identifier `InteriorPoint` and
  found nothing. `git log --all -S"logBarrier"` returns six commits: `InequalityOptimizer` had a
  log-barrier method until `14d75899` removed it on 2025-12-12. Still absent, but reversing a
  considered decision, not greenfield.
- **The compatibility survey** (`011e379e`, `9065c5e0`). A probe for free functions named five
  of 26 distributions absent. Three reach `quantile` through an
  `extension …: ContinuousDistribution`. Two are really absent, `CHISQ.TEST` and `F.TEST`.
- **The penalty weight** (`4888ef7b`). A grep for `= <digit>` found four hardcoded `100`s.
  `IslandModel` writes `V.Scalar(100)`, so there were five.
- **The IM\* family** (`6c0c9b7d`). `^IM` matches 26 rows, but one is `IMAGE`, a lookup
  function. The family is also 26 only because `COMPLEX` belongs to it.
- **The Excel work list** (`ab0531c4`). `businessmath_work.tsv` said 45 of 49 rows absent. Row by
  row against `Sources/` it is 45 present, 3 maths-no-sampler and one absent,
  `ImportanceSampling`. The list matched Excel's names against a library that names functions
  for what they compute: `RATE` is `periodicRate`, `ACCRINT` is `accruedInterest`.

### 2. Four explanations for a column that was mislabelled

The coverage matrix carries a `books` column. A disagreement between two sessions over Psi call
counts produced four successive accounts of it in `f68706df`, `a9f8c07b` and `a10ab288`:
different populations, three denominators, a back-filled column. Two of them were written into
the README as findings and then retracted.

`1e7e367f` settled it by reading `testWhichFunctionsTheCorpusCalls` in the sibling repository
`BusinessMathExcel`. The accumulator is `sheetsByName`, incremented once per sheet. SUM in 338
"books" from a 79-workbook sweep is 338 sheets. There was never a discrepancy.

`f5052f63` records the cost. The README had named the generator since `819f1868`, and the file
was opened with `head -6`, seven lines short of that sentence. **When you truncate a file you
are consulting for provenance, you have not consulted it**, and the generator is not necessarily
in the repository that holds the data.

### 3. Assertions a wrong implementation satisfies

- `designsSpendTheirAlpha` was green with boundaries `[6.25, 6.25, 6.25, 6.25, 1.96]`. The
  solver had never iterated and the final boundary absorbed the error. Only the shape tests
  caught it: a conservation check can be satisfied by nonsense that conserves (`088be563`).
- "Fitted SSE no worse than the defaults" is satisfied by a fitter that returns its starting
  point. `fitETS` is tested against a 0.1-resolution grid instead, 1,331 trainings seasonal and
  121 not, which contains any fixed-point stub's answer by construction (`b0e0f630`, `9fb6169a`).
- The first Markov removal-effect fixture was symmetric, so every channel returned 0.5. The
  campaign-depth fixture was rebuilt to have an interior optimum for the same reason
  (`4218245f`, `ca391194`).

### 4. "Remove the channel" has two readings

The literature's removal effect is surgery on the transition graph. Truncating the observed
paths and rebuilding the chain also recomputes the start row. On the fixture they give 0.646 /
0.250 / 0.333 against 0.833 / 0.333 / 0.333. The implementation was right and the test fixture
was computing the other one, which is how it surfaced. Both are documented at the call site
(`4218245f`).

### 5. A constant no caller could reach, and an argument that expired

Every constrained heuristic minimised `objective + 100 · violation²`. Against an objective
scaled by a million the shipped weight leaves a violation above 0.5 and the result says nothing.
`8b1c4cb0` made it a parameter with the default unchanged; a non-positive or non-finite value
falls back, because a weight of zero deletes the constraint. The ETS proposal had cited the
hardcoded weight as a reason to reparameterise, so `2d5a1eb2` replaced that argument forty
minutes later with one that still held: a sum of squared residuals has no principled weight.

### 6. A crash that never fired

Both GPU optimizers appended a read-back vector only when `V.fromArray` succeeded, then indexed
the batch by population size. A failed conversion would be an out-of-range trap. It is
unreachable today because both gate the GPU on `VectorN<Double>`, and one conformance away from
reachable. `VectorSpace.vectors(fromFlat:count:dimension:)` returns every element or `nil`
(`331ee163`).

### 7. A justification written without checking it

The complex-notation proposal recommended a retroactive `LosslessStringConvertible` conformance
so `Complex` could be used at the package's generic sites. `Complex` is not a `Real`, so it
satisfies none of them. It shipped as two members, and `description` still returns
`"(3.0, 4.0)"` (`743bc80e`, `9e8fb11f`). The site count was itself corrected from three to five
in `a0cb3f8f`.

---

## Process

**A pathspec is only as precise as what it names.** `git add project/plans` swept the user's
deliberately untracked backup into `601fcffa`; `099c0935` removed it with `--cached`. Later the
same day a pathspec naming only the new path of a `git mv` left the deletion staged, which
blocked a merge (`29b120e2`). A rename touches two paths.

**An in-worktree gate run examines zero files and prints PASSED**, because `.quality-gate.yml`
excludes `**/.claude/worktrees/**`. The `fitETS` gate figure came from a copy of the config with
that exclusion removed (`9fb6169a`).

**The doc checkers caught what review would not.** Chapter 7 documented
`CLVDefinition.perpetuityDue`, which exists only on the unmerged stage-6 branch, and `doc-run`
executed an uplift fixture that separated and was correctly refused (`d5cec8d9`). The parameter
insertion in `8b1c4cb0` had orphaned five initialisers' doc comments.

**Recurring scaffolding mistakes were written down** in `e719d34c` and `7d24c2d3`: doc fences
referencing undefined bindings, a test method shadowing the function under test, the pre-commit
hook outrunning a two-minute command budget, and the gate rejecting `!= nil`. `7d46c9ab` adds
that a test omitting a defaulted `seed:` is flagged even when the default is a constant.

**Twenty commits landed with no CHANGELOG entry** before `44a85100` reconciled it, along with a
`master_plan.md` whose priorities still opened on cutting 2.6.0.

**`doc-run` timed out four articles at load 41** and passed clean at 10.8 on the same tree
(`f5052f63`).

---

## Not done

Open as of `7069e5e1`; later sessions may have closed some of these.

- Adapting the penalty weight across restarts, the other branch of open question 10.5.
- Inverse-propensity reweighting for class-transformation uplift away from a half.
- The coverage sweep still labels its sheet count `books` and records no workbook count.
- What Excel emits for `COMPLEX(5, 0, "j")`, and the alpha-saturation question, which was
  settled on argument and explicitly not measured (`3f28acc7`).
- Marketing stage 6 is written and parked on its branch as the third breaking item.
- `fd355cfa` leaves the next step as a question the user had not settled: Excel statistical
  coverage as further point releases, or a branch accumulating the breaking items.
