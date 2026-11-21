# Design Proposal: `Statistics/GroupedRanking` — conditional logit, Plackett-Luce, a prior-centred penalty (also on `LogisticRegression`), per-group ranking metrics, group bootstrap, grouped cross-validation and a held-out comparison

**Status:** BUILT 2026-11-21 (phases B1 to B7); ADR-011 accepted. Phases C (ClassGraph migration) and D (MCP tools, in businessMathMCP) are pending. No release tag: the owner decides. Owner decisions of 2026-11-21 are built in (section 16a); the deviations from this proposal that the build made are recorded in ADR-011. This is the BusinessMath-side proposal derived from ClassGraph's draft of the same name (ClassGraph branch `bm-grouped-ranking-proposal`, commit `8c01683`, which stays there as history).
**Master Plan Reference:** `project/master_plan.md` (Statistics area); the portfolio principle that generic machinery lives here and what is specific to a consumer stays there (ClassGraph ADR-014 moved its generic graph metrics here, ADR-010 here took the eigenvector-by-component measure); new **ADR-011** (ADR-010 is the last in `project/decisions/architecture_decisions.md`, checked 2026-11-21).
**Source:** ClassGraph `Sources/ClassGraphCore/Backtest/` at `main` c81c833 (7 files, about 2,100 lines: a conditional-logit fitter, a per-group ranking evaluator, a group bootstrap and a nested grouped 5-fold, and `BacktestRandom`, a copy of SplitMix64), its ADR-022 and `YearbookMentionGraph.md` Amendment A. Read only; nothing is copied until phase B1.
**Upstream check (done 2026-11-21):** BusinessMath is at `v3.0.0-alpha.17` (`main`, release commit `99de37f5`). ClassGraph pins revision `ae06466`, which is 4 commits behind; those commits touch only `Sources/BusinessMath/Network` (4 files, +416 lines). Nothing in `Statistics` changed, so none of what follows exists upstream. WineTaster 4 pins `3.0.0-alpha.16` exactly and is unaffected until it chooses to move.

---

## 1. Objective

Add a domain-free **grouped-ranking toolkit** to `Statistics/`, so that any analysis of the shape "within each group, which items were chosen, and what predicts the choice" has a correct, tested implementation, ClassGraph deletes its private copy, and the same pieces are exposed through the MCP server (a follow-up in that repository, section 5).

The shape, with no reference to any domain: there are **groups** (a customer, a user, a query, a rater). Each group has a **candidate set** of items, each described by a feature vector, and either a **chosen subset** (the positives) or a **ranking** of its top choices. The data are one row per group-and-item. A model scores items; we want to (1) fit the feature weights, (2) measure how well they rank each group's chosen items among that group's own candidates, and (3) say how sure we are, and whether a refit beats a reference set of weights on groups the fit never saw.

Seven pieces, each separately useful and separately gated:

1. **Conditional logit over groups** (the exact subset likelihood, `likelihood: .subset`).
2. **Plackett-Luce** (the ordered top-*m* likelihood, `likelihood: .ranking`) on the same data type. The two coincide when each group chooses exactly one item and differ otherwise (section 3.2).
3. **A prior-centred penalty** with optional non-negativity, for the grouped models.
4. **The same kind of penalty on the existing `LogisticRegression`**, which today refuses separated data (section 3.9).
5. **Per-group ranking metrics** (mean percentile, top-*k* share) with a stated tie rule.
6. **Bootstrap over groups** and **grouped and nested k-fold**.
7. **`HeldOutComparison`**, a generic result type for "does a refit beat the reference weights on held-out groups": the paired difference in a metric, its bootstrap interval, and whether the interval excludes zero. It carries no decision threshold.

**The split with ClassGraph (agreed 2026-11-21).** Here: the estimators, the metrics, the resampling, the held-out comparison. Stays in ClassGraph: the label definitions (what counts as "named"), the mapping of its 16 weights to features, the candidate weights file, the rescale-to-keep-density step, the privacy rules, and the **adoption thresholds** (a weight must move 25 percent, a feature needs 20 named pairs). Those thresholds are decision policy, not statistics; the library reports the interval and the counts and the caller decides.

## 2. Motivation

**The problem the pieces answer.** Pooling every group-and-item row into one ordinary logistic regression learns *which groups choose a lot*, not *what makes an item chosen*. In ClassGraph's backtest this was the central design decision: a talkative group (a person who names many others) contributes many positives, and a pooled model assigns weight to any feature that merely correlates with talkative groups. Comparing each group only against itself removes that. `LogisticRegression` is the pooled model; it cannot do this.

**Why it belongs here.**
- It is domain-neutral, which this library already values: `ClassifierEvaluation` documents that it lives in `Statistics/` and not under marketing because a response model, a credit scorecard and a churn model are the same object. A choice model over groups is likewise the same object in discrete-choice demand, search and recommendation ranking, offer selection, and any "which of these did they pick" data.
- The consumer's own rule (its `Package.swift`, `shared_packages.md`) is that generic machinery is not hand-rolled in a consumer. The backtest breaks it twice: the statistics, and `BacktestRandom`, a copy of the SplitMix64 that SwiftDeterminism provides and this library re-exports.
- **It is easy to get subtly wrong, and the first version was.** The first likelihood was a softmax per chosen item; ClassGraph's build agent measured a scale bias of about 40 percent on a synthetic class generated from the intended model (ClassGraph's record says the softmax *overstates* the weight; **that direction was wrong**: the B2 recovery test fits a true weight of 1 at about 0.64, so the softmax *understates* it, a bias of about 36 percent. The size agrees; the direction is corrected here and in ADR-011) and replaced it with the exact conditional likelihood. A library with a recovery test that fails the softmax is where that lesson should live.
- It closes a gap this library's own documentation states. `LogisticRegression` says the remedy for separation is Firth's penalised likelihood, "not implemented here". A penalised fit is the natural next step (section 3.9).

## 3. Proposed Architecture

### 3.1 Where it lives, and why not a shared `Statistics/Ranking`

```
Statistics/GroupedRanking/
  GroupedChoiceData.swift        // groups, candidates, chosen flags or rankings, validation, sparse form
  ChoiceLikelihood.swift         // .subset (conditional logit) and .ranking (Plackett-Luce): value and gradient
  GroupedChoiceFit.swift         // the penalised, optionally non-negative fit, prior-centred
  GroupRankingMetrics.swift      // per-group percentile, top-k share, summary, pooled helper
  GroupResampling.swift          // bootstrap weights, fold assignment
  GroupedCrossValidation.swift   // held-out likelihood, nested penalty selection
  HeldOutComparison.swift        // paired difference, interval, excludes-zero
Statistics/Regression/LogisticRegression.swift   // gains a penalised fit (additive; section 3.9)
```

**Decision on a shared `Statistics/Ranking` area (owner asked for it to be considered).** Not proposed. What was read: `Statistics/Comparison Statistics/` holds Friedman, Kendall's W, rank sums (exact distribution and critical values), the exact tie-aware Spearman test and Nemenyi's critical difference. WineTaster 4 reaches them through `Significance Breakpoints/BusinessMathBridge.swift` (`kendallW`, `friedmanChiSquare`, `concordanceAnalysis`, `fStatistic`, `spearmanCriticalValues`, and the rank-sum critical values named in its `Package.swift` comments and README). Every one takes a judge-by-item matrix of ranks and answers **"do the judges agree, and is this pair or this wine significant"**. The new toolkit takes **feature rows** and answers **"what predicts the choice, and how well does it rank"**. Different inputs, different question, no shared code. A parent folder would either force moving `Comparison Statistics` (churn in a folder WineTaster's pinned API depends on, for no gain) or be an empty umbrella. So: new folder `GroupedRanking`, nothing existing moves, and the DocC article cross-links the two so a reader looking for "ranking" finds both. I read only WineTaster's README, `Package.swift` and the bridge file, not its other sources, so I make no claim about what else it might want; nothing there currently needs this toolkit.

### 3.2 The two likelihoods, and exactly how they relate

For a group *g* with *n* candidates, linear scores `s_i = β · x_i`, `w_i = exp(s_i)`.

- **Subset (conditional logit).** If the group chose exactly *m* items as an unordered set *S*, then with a per-group intercept that cancels, `P(S) = Π_{i∈S} w_i / e_m(w)`, where `e_m` is the *m*-th elementary symmetric polynomial of the `w_i` (the sum over every size-*m* subset of the product). It is computed by dynamic programming in `O(n·m)` per group with a forward table and a rolling backward sum giving each item's inclusion probability for the gradient, with a log-sum-exp shift for stability. How many items a group chooses cannot move the weights (the intercept cancels).
- **Ranking (Plackett-Luce).** If the group's top *m* choices are an ordered list `π_1,…,π_m`, then `P = Π_{j=1..m} w_{π_j} / Σ_{l ≥ j} w_{π_l}` with the sum over the items not yet taken (the first denominator is the whole candidate set). `O(n·m)` per group.

**Precisely what "special case" means.** With **exactly one chosen item per group** the two are the same function (both reduce to `w_i / Σ w`, the multinomial logit). With *m* > 1 they are **different likelihoods**: the subset form does not know an order, and Plackett-Luce multiplied over an arbitrary order of an unordered set would make the answer depend on the order chosen. The API therefore takes one data type and a `likelihood:` argument, and the unordered-set case must use `.subset`. (This is also the correct reading of the failed softmax: a softmax per chosen item over the *whole* candidate set never removes items already taken, which Plackett-Luce does, and which the subset form accounts for by conditioning on the set.)

**Why not a softmax per chosen item.** Stated above. The recovery test (section 11) makes the failure permanent: it includes the softmax as a deliberately wrong comparison to show it is biased and the subset likelihood is not.

**Groups with no variation** (no chosen item, or every item chosen) carry no information and are skipped, exactly as in the backtest; the count of skipped groups is reported.

### 3.3 The prior-centred penalty (grouped models)

The fitted weights are multiplicative on a **reference**: `β_k = m_k · r_k`, where `r_k ≥ 0` is the supplied reference weight and `m_k ≥ 0` a multiplier. The objective is

`NLL(m) / (total chosen) + (λ / 2) · Σ_k (m_k − 1)²`

so λ pulls each multiplier toward 1 (the reference) and `m_k ≥ 0` is enforced by projection. The solver is projected accelerated gradient descent with a backtracking line search and a restart when the objective rises; the objective is convex, so the optimum is unique. A **scale** (one number turning reference points into log-odds) is fitted first by bracketed secant search with the Illinois correction, then held fixed; the API exposes it as a separate step so a joint fit can be added later without changing the data types.

**Relative-change form only (owner, 2026-11-21).** The penalty is on `m_k − 1`, not on the weight in its own units. A stated consequence: features with small reference values can barely be distinguished from the reference, so they will usually read "hold". An absolute form is Future Directions. (For `LogisticRegression` there is no reference scale, so section 3.9 uses the coefficient form; that is a flagged deviation, Open Question 1.)

### 3.4 Per-group ranking metrics

For each group with at least one chosen and one unchosen item:
- **Percentile:** for each chosen item, the share of the group's unchosen items scored strictly below it, ties counting half, averaged over the group's chosen items. 0.5 is chance. It is the group-wise analogue of AUC, computed per group so a large group does not dominate.
- **Top-own:** the share of the group's chosen items inside its top *m* (*m* = how many it chose), places shared out among tied scores.
- **Top-*k*:** the same for a stated *k*.

The summary averages over groups (each group counts once) and reports how many were compared. The **pooled** ROC area is not reimplemented: it is `ClassifierEvaluation(scores:outcomes:).auc` applied to the pooled comparable rows, and the toolkit provides the pooling helper. (ClassGraph's equivalent swap is already built, phase M0a.)

### 3.5 Bootstrap over groups

Resample **groups** with replacement; a resample is a vector of integer weights (how many times each group appears), so a fit takes `groupWeights` and never copies data. Intervals are percentile intervals over the resamples. Group-level resampling matters because rows within a group share the group's propensity; a row-level bootstrap would understate uncertainty.

### 3.6 Grouped and nested k-fold

- **Fold assignment:** balanced, shuffled by seed, every fold used, whole groups per fold.
- **Held-out likelihood and metrics:** fit on the training groups; score the held-out groups by conditional log-likelihood and the metrics of section 3.4.
- **Nested selection:** the penalty λ (and which features are free) is chosen **inside each training set** by an inner grouped k-fold on the training groups only; the outer fold never chooses it. Ties go to the stronger penalty.

### 3.7 `HeldOutComparison` (the generic part of the adoption question)

A value type holding, for a chosen metric: the per-fold and pooled **reference** and **refit** values, the **paired difference** (refit minus reference) over held-out groups, its **bootstrap interval** at a stated level, the number of held-out groups, and `intervalExcludesZero` (lower end above zero for a "better" test). It states a fact about the data. It does **not** say "adopt", and it does not know about 25 percent moves or minimum counts: those thresholds are ClassGraph policy and stay there. The toolkit also exposes the per-feature counts of chosen items carrying each feature so the caller can apply its own evidence rule.

### 3.8 Randomness and determinism

Generators come from SwiftDeterminism (`SplitMix64`; `Xoshiro256StarStar` is also available), which this library already depends on and re-exports. **SwiftDeterminism is the ground truth (owner, 2026-11-21).** Every public function that draws takes a generator (`inout`) or a seed and documents that the same seed gives the same result; none touches the system generator. ClassGraph's `BacktestRandom` is a hand-rolled copy and is to be **replaced** (phase M0b); if its mixing differs from SwiftDeterminism's, the fold assignment and resamples in the real-archive backtest change and its figures (0.22 points held-out improvement, interval -0.07 to 0.45) may shift slightly. The owner accepted that the parity re-run is recorded both ways (the old figures stay in the ADR amendment as the baseline). Whether the two generators are bit-identical was **not** checked here; the parity test answers it.

### 3.9 The penalty on `LogisticRegression`

Today `LogisticRegression.fit` calls `refuseSeparation()` and throws `LogisticRegressionError.separation(variables:)`; its documentation names Firth's penalised likelihood as the remedy and says it is not implemented. This proposal adds a **ridge-type penalty centred on a supplied value** as an additive entry point:

`NLL(β) + (λ / 2) · Σ_{k ∈ slopes} (β_k − c_k)²`, centre `c` defaulting to zero, the intercept unpenalised.

With λ > 0 the objective is strictly convex, so the estimate exists and is unique under separation and under a rank-deficient design; the penalised path therefore does not throw `separation` or `rankDeficient` (it still throws `malformedInput` and `didNotConverge`). **The existing `fit(maxIterations:tolerance:)` is untouched**, so every current caller behaves exactly as before; the penalised fit is a new method (`fit(penalty:maxIterations:tolerance:)`), not a new default. The coefficient-space form is the only meaningful one here because `LogisticRegression` has no reference weights; it is **not** the relative-change form of section 3.3, and that difference is flagged as Open Question 1. It is not Firth's penalty (Jeffreys-prior) and the documentation will say so; adding Firth later is not precluded. Standard errors under a penalty are not the classical ones; Open Question 3.

## 4. API Surface (sketch; names are proposals)

Conventions read from the current library: generic over `T: Real & Sendable & BinaryFloatingPoint` (as `ClassifierEvaluation`, `LogisticRegression`); failable `init?` when the data cannot support the call; a typed `Error` enum with associated detail; public value types are `Sendable`, and `Codable` for fits (as `LogisticFit`); DocC with a worked example on every public symbol; tab indentation.

```swift
public enum ChoiceLikelihood: Sendable, Equatable { case subset, ranking }

public struct GroupedChoiceData<T: Real & Sendable & BinaryFloatingPoint>: Sendable {
	public let groupCount: Int
	public init?(groups: [[(features: [T], chosen: Bool)]])            // subset form
	public init?(rankedGroups: [(candidates: [[T]], ranking: [Int])])  // top-m by candidate index
	public init?(sparseGroups: ...)                                    // Open Question 4: in B1
	public var informativeGroups: [Int] { get }
}

public enum GroupedChoiceError: Error, Sendable, Equatable {
	case noInformativeGroups
	case malformedInput(reason: String)
	case didNotConverge(iterations: Int, gradientNorm: Double)
}

public struct GroupedChoiceFit<T>: Sendable, Codable {      // multipliers, scale, iterations, converged
	public let multipliers: [T]; public let scale: T; public let iterations: Int; public let converged: Bool
}

public struct GroupedChoiceModel<T> {
	public init(data: GroupedChoiceData<T>, reference: [T], likelihood: ChoiceLikelihood)
	public func negativeLogLikelihood(_ fit: GroupedChoiceFit<T>, groupWeights: [T]) -> (total: T, chosen: T)
	public func fit(groupWeights: [T], penalty: T, frozen: Set<Int> = [], start: [T]? = nil) throws -> GroupedChoiceFit<T>
}

public enum GroupRankingMetrics {
	public static func perGroup<T>(scores: [T], data: GroupedChoiceData<T>, k: Int) -> [GroupRanking<T>?]
	public static func summary<T>(_ r: [GroupRanking<T>?]) -> GroupRankingSummary<T>
	public static func pooledEvaluation<T>(scores: [T], data: GroupedChoiceData<T>) -> ClassifierEvaluation<T>?
}
public enum GroupResampling {
	public static func bootstrapWeights<G: RandomNumberGenerator>(groups: Int, using: inout G) -> [Double]
	public static func foldAssignment<G: RandomNumberGenerator>(groups: Int, folds: Int, using: inout G) -> [Int]
}
public enum GroupedCrossValidation { choosePenalty(...); heldOutComparison(...) -> HeldOutComparison<T> }
public struct HeldOutComparison<T>: Sendable, Codable { reference, refit, difference, interval, level, groups, intervalExcludesZero }

extension LogisticRegression {   // Regression/, additive
	public func fit(penalty: LogisticPenalty<T>, maxIterations: Int = 25, tolerance: T = T(1) / T(100_000_000)) throws -> LogisticFit<T>
}
public struct LogisticPenalty<T> { public let lambda: T; public let centre: [T]? }   // centre nil = zero
```

`penalty` is non-optional in `fit`: "do not refit" is the caller keeping the reference, not a mode of the fitter (an unpenalised grouped fit can diverge under quasi-separation, so it is not offered; a very small λ gives the nearly unpenalised optimum). Public names are settled at review; the shape is the point.

## 5. MCP Schema

**Wanted for all seven pieces (owner, 2026-11-21); built as a follow-up in `businessMathMCP`, a separate repository** that pins this library, has its own `CLAUDE.md` and its own design-proposal process (it names this repository's `design_proposal.md` template), and registers tools with `MCPToolInputSchema` / `MCPSchemaProperty`. **Correction to the ClassGraph draft:** that draft said a dataset does not fit the MCP pattern. It does: `multiple_linear_regression` there already takes a predictor matrix `X` as an array of rows, so a grouped dataset is an array of groups of rows. Nothing in this proposal blocks the tools; none is built here.

Tools to be specified in that repository's proposal, one thin tool per capability: `fit_conditional_logit`, `fit_plackett_luce`, `group_ranking_metrics`, `group_bootstrap_intervals`, `grouped_held_out_comparison`, `fit_penalized_logistic`. Every tool takes a **required `seed`** where anything is drawn, so results are reproducible. Sketch of the core one:

````markdown
**Tool Description:** Fit a conditional-logit (or Plackett-Luce) choice model within groups, with a penalty toward reference weights. Each group is compared only with its own candidates; a pair nobody chose is unknown, not rejected, so scores are rankings, not probabilities.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "likelihood": "subset",
  "groups": [
    { "features": [[1, 0], [0, 1], [1, 1]], "chosen": [0, 2] },
    { "features": [[0, 1], [1, 0]], "chosen": [1] }
  ],
  "reference": [2.0, 1.5],
  "penalty": 0.05,
  "seed": 42
}
```

**Parameter Types:**
- likelihood (string): "subset" (unordered chosen set) or "ranking" (ordered top choices, Plackett-Luce).
- groups (array): each group has features (array of rows, one per candidate, equal width) and chosen (array of candidate indices; for "ranking", in order, best first).
- reference (array of numbers, >= 0): one per feature column.
- penalty (number, > 0): pull toward the reference; larger = closer to it.
- seed (integer): required where resampling is used.
````

The MCP-side proposal finalises names and adds a registry test per tool; this repository's gate is unaffected.

## 6. Constraints & Compliance

- Swift 6 strict concurrency: value types, `Sendable`; the generator is passed `inout` and none is held.
- No force unwraps, `try!` or force casts; division guards on every ratio (empty groups, zero chosen, zero total weight); guard-driven early returns; fail-silent principle (never return a plausible-but-wrong result): non-convergence and no-informative-groups throw.
- Numerical stability: log-sum-exp shift; groups where `e_m` is not positive and finite are skipped and counted.
- **Type-checking discipline (this repository's `CLAUDE.md`):** CI is Swift 6.2.1; local 6.4 is no evidence about timeouts. At most 3 arithmetic operators per generic expression; intermediates bound to named `let`s with explicit `: T`; no arithmetic inside `#expect` messages. This matters here because the inner loops are generic arithmetic over `T`.
- Floating-point comparisons in tests use accuracy, never `==`; tolerances are measured, per `correct_answers.md`.
- DocC on every public symbol with a worked example; this repository's `.quality-gate.yml` and baseline apply.

## 7. Source & API Compatibility

**Breaking changes: none.** Everything is additive: a new folder, and one additive method on `LogisticRegression`. No existing symbol changes; `LogisticRegression.fit(maxIterations:tolerance:)` is untouched, still refuses separation and rank deficiency, and its tests are untouched and must stay green. No existing default changes. `Statistics/Comparison Statistics` is not touched, so WineTaster's pinned API is unaffected. New public type names (`GroupedChoiceData`, `GroupedChoiceModel`, `GroupRankingMetrics`, `HeldOutComparison`, `ChoiceLikelihood`, `LogisticPenalty`) are checked against the library for collisions before B1. Consumers: ClassGraph pins by revision, so nothing changes there until the pin is bumped (phase C); WineTaster pins `alpha.16` exactly and moves only by its own decision. **Type-checking risk:** new generic overloads on an existing type (`fit`) are the shape that has caused CI timeouts here; the penalised `fit` has a different label set and is not an overload of the existing call.

## 8. Backend Abstraction

N/A. CPU, pure Swift, no Accelerate. Cost: `O(n·m)` per group per likelihood evaluation. ClassGraph's measured baseline for the code being generalised: 200 bootstrap resamples on a 532-group, about 141,000-row class took 229 seconds in a release build with a flat sparse layout (`zStart/zIndex/zValue`); a dense `[[T]]` layout would be slower, which is why Open Question 4 asks to put a sparse constructor in the first phase.

## 9. Dependencies

None new. `Numerics` (for `Real`), already used by `ClassifierEvaluation`; SwiftDeterminism (already a dependency, `from: 1.2.0`) for the generator.

## 10. Resource budget

Allocation is `O(rows × features)` for the data plus `O(n·m)` scratch per group (reused). The bootstrap holds weight vectors, not data copies. No new global state.

## 11. Test Strategy

Strict TDD (this repository's rule), deterministic synthetic data, reference truth independent of the code (`correct_answers.md`).

- **Likelihood, hand-computed:** two groups, three candidates, one or two chosen; `e_m` computed by hand **and by brute-force subset enumeration** in the test, compared to the dynamic-programming value to 1e-12; the gradient against a central finite difference. For Plackett-Luce: brute-force over permutations for small *n*, and the first-choice case equals the multinomial logit exactly.
- **The two likelihoods differ:** a hand-worked group with *m* = 2 where the subset and ranking probabilities are computed by hand and are different numbers; with *m* = 1 they are equal. Asserts the section 3.2 statement.
- **Recovery (the test that fails the softmax):** generate groups from known β with group intercepts (some groups choose many, some few); the subset fit recovers β within a measured tolerance on a fixed seed; the softmax-per-choice likelihood is included as a deliberately wrong comparison and is shown biased. A Plackett-Luce recovery test generates rankings by sequential draws and recovers β.
- **Null:** no signal: multipliers stay near 1 under a positive penalty, mean percentile near 0.5, the held-out interval includes zero.
- **Talkative-group bias:** a feature predicting only *which groups choose many* gets no weight from the conditional fit while a pooled `LogisticRegression` assigns it weight; both asserted.
- **Penalty and constraints:** λ very large returns the reference; λ tiny approaches the unpenalised optimum; non-negativity binds (a feature that truly predicts the opposite way ends at 0); `frozen` features stay at 1.
- **Penalised `LogisticRegression`:** perfectly separated data that the existing `fit` refuses gives a finite, unique estimate under λ > 0; λ → large gives the centre; on non-separated data and small λ it approaches the existing unpenalised fit within a measured tolerance; **the existing `fit` is byte-identical in behaviour** (its current tests run unchanged); a rank-deficient design fits under λ > 0.
- **`HeldOutComparison`:** the same model as reference and refit gives difference exactly 0 and an interval containing 0; a deliberately better model gives a lower bound above 0; counts are reported; no threshold is applied.
- **Ranking metrics with ties:** all-equal scores give percentile 0.5 and top-*k* share equal to chance; hand-computed half-credit and shared-places cases; groups without variation return `nil`.
- **Determinism:** same seed gives identical folds, resamples and intervals, a different seed differs; no dependence on `Set` iteration order; a golden run in 10+ separate processes (as ADR-010's did).
- **Fold discipline:** no group in both training and held-out; inner folds never see the outer held-out groups (an adversarial held-out group on a synthetic class).
- **Edge cases:** no informative groups; one group; more folds than groups; zero total group weight; non-finite features rejected at `init?`; a ranking with an index out of range or repeated.
- **Parity (for ClassGraph phase C):** a fixed-seed synthetic class run through the new toolkit and a verbatim copy of ClassGraph's private code gives the same multipliers to a measured tolerance; kept as a regression test.
- **Mutation audit** by the builder (commit before mutating), 50+ mutants across the likelihoods, the penalty and the metrics.
- **Linux:** not runnable locally; the 6.2.1 budget rules of section 6 are followed and the CI run is watched.

## 12. Architecture Decision Review

- [x] Reviewed `architecture_decisions.md` (through ADR-010).
- [ ] Supersedes an existing ADR: No.
- [x] Amends: none. Note for ADR-011 that it does not change `LogisticRegression`'s existing refusals; it adds a penalised path beside them.
- [x] New ADR required: **ADR-011**, "Grouped choice models live in `Statistics/GroupedRanking`; the subset likelihood is the conditional logit and is distinct from Plackett-Luce; the penalty is prior-centred." Cross-reference ClassGraph ADR-022 (the origin) and, in ClassGraph, an ADR-022 amendment recording that the private implementation moved here.

## 13. Adversarial Review

**Strongest case for a different approach: leave it in ClassGraph.** The code works, is gated, mutation-audited (50 of 50 killed) and used once. Moving it costs a proposal, an upstream build, a pin bump and a parity migration for one consumer today. *Response:* the owner decided to upstream (2026-11-21) on the portfolio rule, on a plausible second use (any "who chose what" data, and the MCP exposure he wants), and because a private copy is where the softmax error would be re-learned. If no second use appears the saving is only the rule and the MCP tools; the proposal stops at B-phases that stand on their own (each is gated and useful separately).

**Critic: "this ships an analysis protocol, not a library tool."** The *combination* (prior-centred penalty, non-negativity, nested grouped CV, group bootstrap) is a particular protocol. *Response:* each piece is separately exposed and tested, the protocol is a thin layer a caller can ignore, and **the decision policy is deliberately not here**: `HeldOutComparison` reports an interval and counts; "adopt if the lower end is above zero and one weight moved 25 percent with at least 20 pairs" stays in ClassGraph.

**Critic: "Plackett-Luce is scope creep."** *Response:* it shares the data type, the group structure, the metrics, the bootstrap and the folds, and costs one likelihood function and its tests; it is its own phase (B5) so it can be dropped without touching the rest. Nothing I read in WineTaster needs it today; I do not claim it does.

**Failure modes named.**
- **Quasi-separation** in the grouped fit: a feature that perfectly picks the chosen items drives its multiplier up. The penalty bounds it; an unpenalised grouped fit is not offered.
- **Candidate-set choice is a modelling decision.** "Everyone else with a page" is a different universe from "everyone"; the data type makes the candidate set explicit.
- **Unlabelled negatives.** An unchosen item is unknown, not rejected. The documentation says so in its first paragraph, because absolute probabilities are not calibrated; the outputs are rankings, by design.
- **Subset versus ranking misuse.** Passing an unordered set to `.ranking` makes the answer depend on an arbitrary order. The constructors are separate (`groups:` versus `rankedGroups:`), so the unordered form cannot be built as a ranking by accident.
- **The relative penalty** makes small-reference features hard to move (section 3.3); stated, with the absolute form as Future Directions.
- **The coefficient-space penalty on `LogisticRegression` differs from the relative form** and the centre defaults to zero, which can surprise a caller who expects shrinkage toward a reference. Documented; Open Question 1.
- **A parity migration can mask a real difference** (including the generator swap); the parity test runs before ClassGraph's copy is deleted and stays as a regression test.
- **Speed.** Dense rows are slower than the sparse layout the backtest uses (section 8); hence Open Question 4.

## 14. Alternatives Considered

**Alternative 1: leave it in ClassGraph.** Zero cost, working. Violates the portfolio rule, no MCP exposure, a second consumer would copy it. Rejected by the owner's decision; remains the fallback if no second use appears.

**Alternative 2: a separate small package.** Small clean dependency. Another repository and pin; this library already holds `ClassifierEvaluation`, Spearman and the SwiftDeterminism dependency these compose with, and the portfolio's direction has been toward folding generic pieces into this library (SwiftGraphMetrics into `Network`, ClassGraph ADR-014). Not recommended.

**Alternative 3: `LogisticRegression` with a group-indicator column per group (fixed effects as dummies).** No new fitting code. With hundreds of groups it hits the separation and rank-deficiency refusals (groups with none or all chosen), is slow (an `(n+k)` system), and gives the unconditional fixed-effects logit, biased with few choices per group. The conditional likelihood exists to avoid exactly this. Rejected.

**Alternative 4: swap only the evaluation pieces and keep the fit private.** Smallest change. That is phase M0 in ClassGraph, a step in this plan, already partly built; it does not remove the duplicated fitter.

**Alternative 5: pooled regression with a "talkative-group" covariate.** The covariate is a proxy; the conditional likelihood removes the group effect exactly. Rejected.

**Alternative 6: a shared `Statistics/Ranking` parent with `Comparison Statistics` moved under it.** Considered at the owner's request; rejected in section 3.1 (churn in a folder a pinned consumer depends on, no shared code, a different question).

## 15. Future Directions

Each would be its own gated proposal; none is promised.
- Joint fit of scale and multipliers; an **absolute** penalty and an L1 option; Firth's penalty on `LogisticRegression`.
- Ties inside a Plackett-Luce ranking; group-level covariates; time-varying choices.
- Plackett-Luce with no covariates (latent item strengths from judge rankings), which would sit next to, not inside, `Comparison Statistics`; only worth a proposal if a consumer (WineTaster is the obvious candidate, not read beyond its README, `Package.swift` and bridge here) asks for it.
- A calibration step for absolute probabilities where unchosen items are known negatives.

## 16. Documentation Strategy

- A DocC article beside `2.7-SpearmanSignificance.md` ("Choosing among candidates: conditional logit, Plackett-Luce and ranking evaluation"), with the talkative-group example, the unlabelled-negatives warning, the subset-versus-ranking table, and a cross-link to the Comparison Statistics articles. A short section on the penalised `LogisticRegression` in its article, replacing "not implemented here" with what is and is not.
- `CHANGELOG.md` entry per phase; ADR-011; `project/master_plan.md` Statistics entry reconciled at the end.
- ClassGraph (its own repository): ADR-022 amendment, CHANGELOG, runbook line, master plan; the `weights backtest` output and meaning are unchanged.

### 16a. Owner decisions incorporated (2026-11-21)

Split agreed; held-out comparison result type upstream, thresholds stay in ClassGraph; Plackett-Luce included with the first-choice case shared (made precise in 3.2); the penalty also on `LogisticRegression`; generic over `T: Real & Sendable & BinaryFloatingPoint`; relative-change penalty only for now; SwiftDeterminism is the ground truth and the generator swap is accepted with both runs recorded; MCP exposure for everything, as a follow-up in `businessMathMCP`; do it now as a diversion and return to ClassGraph when resolved; upstream check done.

---

## Phasing and process

| Step | What | Where | Gate |
|---|---|---|---|
| 0 | This proposal and ADR-011 (proposed) | BusinessMath | **owner approval**, section 17 |
| M0a | Replace the hand-written pooled ROC area and the score-band table with `ClassifierEvaluation`; add `BusinessMath` as a `ClassGraphCore` dependency (ADR-022 note). **Built** on ClassGraph branch `backtest-businessmath` at `84f988b` (per its build report; I did not inspect the branch); calibration and gains were not swapped because their buckets do not match the score bands. Awaiting merge | ClassGraph | its gate passed 51/51 |
| M0b | Replace `BacktestRandom` with SwiftDeterminism's `SplitMix64`; parity run and record both figures. **Not built.** Can wait for C | ClassGraph | gate 0/0; real-archive re-run, counts only |
| B1 | `GroupedChoiceData` (dense, and sparse per Q4) and the **subset** likelihood with gradient, unpenalised evaluation only; brute-force and finite-difference tests | BusinessMath | repo gate 0/0; mutation audit **Built** `6a828ae4`; mutation 21 of 22. |
| B2 | The prior-centred penalty, non-negativity, scale step, `fit`; recovery (fails the softmax), null, talkative-group, penalty tests | BusinessMath | gate; mutation audit **Built** `78ce5d88`; mutation 10 of 15 (the rest equivalent, optimiser-path or unreached). |
| B3 | Per-group metrics and the pooled helper | BusinessMath | gate; mutation audit **Built** `f4d7895b`; mutation 11 of 11. |
| B4 | Group bootstrap, grouped and nested k-fold, `HeldOutComparison` | BusinessMath | gate; mutation audit; determinism across processes **Built** `05abf47b`; mutation 18 of 19. |
| B5 | Plackett-Luce (`likelihood: .ranking`), tests including "the two likelihoods differ" | BusinessMath | gate; mutation audit **Built** `a7097fc9`; mutation 11 of 11. |
| B6 | Penalised `LogisticRegression.fit(penalty:)`; separation and rank-deficiency tests; the existing `fit` unchanged | BusinessMath | gate; mutation audit; existing tests untouched **Built** `ca9ff4ea`, `7527f049`, `c1b1cc0d`, merged as `274c72a8`; mutation 22 of 25 applicable. |
| B7 | DocC article, CHANGELOG, ADR-011 accepted, `master_plan.md`; a release tag only on the owner's decision (Open Question 5) | BusinessMath | gate 0/0 **Built** (branch `feature/grouped-ranking-docs`): DocC article 2.8, ADR-011 accepted, CHANGELOG and master plan reconciled, no tag. |
| C | Bump ClassGraph's pin; parity test (new toolkit versus the private code on a fixed-seed class); delete `BacktestFitter`, the metrics, `BacktestRandom`, the bootstrap and fold code; ADR-022 amendment | ClassGraph | gate 0/0; real-archive re-run reproduces the recorded figures within the stated tolerance |
| D | The MCP tools (section 5), after B7, in `businessMathMCP` under its own proposal and process, pinning this library | businessMathMCP | that repository's gate |

B1 to B7 are separately gated and each is useful alone; B5 and B6 are independent of B2 to B4 once B1 exists and can be reordered or dropped. For scale: the ClassGraph code being generalised is about 2,100 lines across 7 files and was built, gated and mutation-audited in one agent build cycle; B1 to B7 add generics, a second likelihood, the `LogisticRegression` addition and documentation, so expect more than one cycle, in separate worktrees, one phase per branch.

Process: merges only on the owner's explicit approval after `git branch --show-current`; no push and no tag without asking; builds in sibling worktrees; builders use synthetic data only; the real-archive runs are the ClassGraph parent's, counts and figures only.

## 17. Open Questions (those that truly remain)

1. **Penalty form on `LogisticRegression`.** The owner's "relative change only, for now" applies to the grouped models, which have a reference scale. `LogisticRegression` has none, so I propose the coefficient-space form `(β_k − c_k)²`, centre default zero (ridge), not Firth's. Recommended: **yes, coefficient form on `LogisticRegression`, relative form on the grouped models**, documented side by side.
2. **Plackett-Luce scope.** Strict, untied, top-*m* orderings only; the unordered-set case stays on `.subset`; ties in a ranking are Future Directions. Recommended: **yes**.
3. **Inference under a penalty.** Classical standard errors are not valid for a penalised fit. Proposed: the penalised `LogisticRegression` fit returns the coefficients and convergence but **no classical standard errors**; intervals come from the group bootstrap (grouped models) or a caller-supplied bootstrap. Recommended: **yes**.
4. **Sparse constructor in B1 or later?** The backtest's 229-second figure depends on a flat sparse layout; a dense-only first release would make ClassGraph's parity run slower. Recommended: **include the sparse constructor in B1**, not in Future Directions.
5. **Release cadence.** ClassGraph pins by revision, so a tag is not needed for it; WineTaster pins an exact tag and does not need this. Recommended: **one tag (the next alpha) after B7, at the owner's decision**, not per phase.

## Proposal Review Checklist

### Architecture
- [x] Module placement follows the `Statistics/` layout (section 3.1); no shared-parent move (reasoned)
- [x] Naming and error style follow `ClassifierEvaluation` and `LogisticRegression`
- [x] Swift 6 concurrency (value types, `Sendable`, generator passed in)
- [x] No forbidden patterns
- [x] Domain-free: nothing about people or friendship in the toolkit

### Compatibility & Evolution
- [x] Additive; the existing `LogisticRegression.fit` untouched; `Comparison Statistics` untouched (section 7)
- [x] Incremental adoption (phases separately gated)
- [x] Future directions use "could" or are separately gated
- [x] Six alternatives with advantages and disadvantages

### MCP Readiness
- [x] Schema sketched and follow-up phase D defined (section 5); a stale claim in the draft corrected

### Backend Abstraction
- [x] N/A (section 8)

### Testing & Dependencies
- [x] Hand-computed, brute-force, finite-difference, recovery (fails the softmax), null, talkative-group, penalty, determinism, ties, edge cases, parity
- [x] Reference truth independent of the code
- [x] No new dependencies
- [x] Open questions listed with recommendations

### Adversarial Review
- [x] Counter-design (section 13, Alternative 1)
- [x] Failure modes named
- [x] Critics' objections with responses

### Honest limits of this proposal
- No BusinessMath code was written or run; the API in section 4 is a sketch, and names are proposals.
- ClassGraph's M0a branch (`backtest-businessmath`, `84f988b`) is described from its build report, not inspected; M0b's generator swap is not built.
- The "about 40 percent" softmax scale bias is the ClassGraph build agent's measurement on a synthetic class, recorded in its ADR-022. The B2 recovery test re-measured it in this repository: a true weight of 1 fitted at about 0.64, so the softmax **understates** (ClassGraph's ADR-022 says "overstates" and needs the same correction there).
- Whether ClassGraph's `BacktestRandom` is bit-identical to SwiftDeterminism's `SplitMix64` was not checked.
- That the penalised `LogisticRegression` path can skip the separation and rank-deficiency checks safely was reasoned from the objective's convexity, not by reading every line of `fit`; B6's first tests settle it.
- WineTaster was read at its README, `Package.swift` and `BusinessMathBridge.swift` only.
- The `businessMathMCP` tool pattern was read from `multiple_linear_regression` and its `CLAUDE.md`, not from the whole repository, and its pinned BusinessMath revision was not checked.
- Linux (Swift 6.2.1) behaviour of the generic code is unverified until CI runs.
