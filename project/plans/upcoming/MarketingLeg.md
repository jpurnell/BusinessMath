# Design Proposal: The Marketing Leg

**Author:** Justin Purnell + Claude
**Date:** 2026-08-23
**Status:** Approved 2026-08-24. Promoted to `upcoming/`; build begins with 2.7.0.
**Supersedes:** the audit draft `MarketingAnalytics.md`, removed here and folded into §2. Its
full text is at commit `3c7d618` if the evidence trail is wanted separately.
**Amends:** `proposals/NetworkAnalysis.md` — placement and scope, see §3.4
**Target release:** v3.0.0, per `upcoming/v3.0.0_SCOPE.md`

---

## 1. Objective

**Objective:** Establish marketing analytics as a first-class discipline in BusinessMath,
on the same footing as Finance, Operations, and Strategy.

**Master Plan reference:** New leg. `project/master_plan.md` does not currently name
Marketing as a domain, which is itself the finding — see §2.

BusinessMath stands on four legs. Three are load-bearing:

| Leg | State |
|---|---|
| **Finance** | Deep. Valuation, options, derivatives, financial statements, ratios, portfolio, risk. |
| **Operations** | A dedicated module — inventory, EOQ, newsvendor, safety stock. |
| **Strategy** | Scenario analysis, forecasting, optimization, Monte Carlo, decision models. |
| **Marketing** | **Absent as a discipline, present as a side effect.** |

This proposal closes the fourth leg and, in doing so, fixes two shipped defects and
consolidates a graph engine the library already depends on without having named it.

---

## 2. Motivation

### 2.1 The causal direction is backwards

Marketing numbers exist in the library. `calculateLTV()`, `calculateCACPayback()`,
`calculateRetentionRate()`, and `calculateLTVtoCAC()` all ship today — inside
`Fluent API/Templates/SaaSModel.swift` and `SubscriptionBoxModel.swift`, as **methods on a
financial model**.

`SaaSModel.calculateLTV()` takes ARPU, a churn rate, and a margin, and produces a number.
That is finance: modelling a business and reporting a consequence.

**Marketing analytics runs the other way.** It starts with customer transaction data and
*derives* the segments, the retention curve, the churn rate, the value per segment. The
churn rate is the output, not the input.

**Current workaround:** none is possible. There is no function in BusinessMath that accepts
a table of customers and returns anything. A user with customer data must leave the library.

### 2.2 The gap under the gap: no binary outcomes

The regression module offers `linearRegression`, `polynomialRegression`,
`multipleLinearRegression`, and `NonlinearRegression` — every one a continuous response.
**There is no logistic regression and no classifier of any kind.**

Marketing is overwhelmingly a binary-outcome discipline. Did they respond, convert, click,
redeem, churn, subscribe, refer. This sits underneath most of what a first pass would call
the marketing feature list:

| Wanted | Requires |
|---|---|
| Lift / gains / decile | a score, from a response model |
| Propensity scoring | *is* logistic regression |
| Churn prediction | a classifier over customer features |
| Uplift modelling | two classifiers, differenced |
| Next-best-action | a classifier per action |

And there is no way to evaluate one: zero occurrences of ROC, AUC, KS, or confusion matrix
across 553 source files. `Statistics/Regression/ModelValidation.swift` is parameter
recovery for regression, not model evaluation.

Set that against `Forecasting/Evaluation/`, which is genuinely rigorous —
`RollingOriginBacktest`, `Baselines`, `ScaledError`, `Forecastability`, `BacktestReport`.
**The library knows exactly how to evaluate a forecast honestly and has no equivalent for a
classifier.**

### 2.3 Three false friends

A term-frequency scan suggests coverage that is not there. Naming these prevents the audit
being re-run to the same wrong conclusion:

- **`logistic`** — six files, all either the logistic *growth curve*
  (`Time Series/Growth/TrendModel.swift`) or the logistic *distribution*
  (`Simulation/distributionLogistic.swift`). Neither is logistic regression.
- **`hazard` / `survival`** — eight files, all under `Valuation/CreditDerivatives` and
  `Valuation/Debt`. The Cox process in `HazardRateModel.swift` is stochastic default
  intensity, not Cox proportional hazards.
- **`precision`** — 37 files, every one about floating point.

### 2.4 A shipped defect: `sampleSize`

```swift
/// Computes the minimum number of observations for each variant of an A/B test
/// to determine the significance of that test.
public func sampleSize<T: Real>(ci: T, proportion p: T, n: T, error: T) -> T
```

The body is Cochran's finite-population survey formula — `z²pq/e²` with a
finite-population correction. It is a **single-sample margin-of-error calculation** and is
missing everything a two-arm power calculation needs:

- **No power term.** Only `z_α`; there is no `z_β`. The function cannot express "80% power"
  because it has no notion of power.
- **No second sample.** An A/B test compares two arms; the variance of the difference is
  the sum of two variances. One arm's variance appears.
- **No minimum detectable effect.** `error` is a margin of error around one proportion, not
  a difference between two.

The parameter documentation discusses surveys, population size, and "the researcher." **The
formula is correct for what its parameters describe and wrong for what its summary line
claims.**

| At 95% confidence, p = 0.5, e = 0.05, large population | Per arm |
|---|---|
| What `sampleSize` returns | **384** |
| Correct two-proportion sizing, 80% power, detecting 0.50 → 0.55 | **1,565** |
| Understated by | **4.1×** |

*(Both values computed during this audit; the second is reproducible against R's
`power.prop.test(p1 = 0.50, p2 = 0.55, power = 0.80)`.)*

A team following this documentation runs a test at roughly a quarter of the sample it
needs, fails to reach significance, and reads the null result as "no difference." This is
the fail-silent failure mode: a plausible number, confidently returned, leading to a wrong
decision.

### 2.5 The library already has a graph engine

`Model Definition/DependencyReport.swift` contains a complete, deterministic Tarjan
strongly-connected-components implementation:

```swift
static func components(of graph: [String: [String]]) -> [[String]]
```

`O(V + E)`, one depth-first pass, deterministic by sorted vertex entry, with a companion
walk that recovers a readable cycle path. It is `internal`, typed as a dictionary, and
scoped to financial-model dependency analysis.

**BusinessMath depends on graph algorithms for correctness today and has not named them as
a capability.** A `Network/` module is therefore not a new dependency being introduced for
marketing's sake — it is the formalisation of something already load-bearing, with
marketing as one consumer among several (§3.4).

---

## 3. Proposed Architecture

### 3.1 The placement rule

**Fundamental techniques live with their specialty. Marketing-specific formulas that build
on them live in `Marketing/`.**

The test is: *would a non-marketer reach for this?* Logistic regression is used in credit
scoring, medicine, and political science — it goes in `Statistics/Regression/`. RFM
segmentation is used by marketers — it goes in `Marketing/`.

This keeps `Marketing/` thin and honest, and it means every technique built here is
available to the other three legs without an inappropriate import.

### 3.2 New files, by module

**`Statistics/Regression/`** — technique
```
LogisticRegression.swift          Binomial GLM via IRLS; separation detection
```

**`Statistics/Classification/`** *(new area)* — domain-neutral model evaluation
```
ConfusionMatrix.swift             Counts, rates, threshold sweep
ROC.swift                         ROC curve, AUC, Mann-Whitney identity check
Calibration.swift                 Reliability curve, Brier score, calibration slope
KolmogorovSmirnov.swift           KS statistic for score separation
GainsTable.swift                  Decile/percentile buckets, lift, cumulative gains
```

**`Statistics/Survival/`** *(new area)* — domain-neutral
```
KaplanMeier.swift                 Empirical survival with right-censoring
LogRank.swift                     Two-group survival comparison
SurvivalCurve.swift               Shared curve type; median survival; restricted mean
```

**`Statistics/Concentration/`** *(new area)* — domain-neutral
```
Gini.swift                        Gini coefficient, two independent formulas
Lorenz.swift                      Lorenz curve points
ParetoShare.swift                 Top-k share, the "80/20" question
```

**`Statistics/Experiment/`** *(new area)* — domain-neutral
```
Experiment.swift                  Design type: arms, metric, allocation
PowerAnalysis.swift               Two-proportion and two-mean sizing, MDE
SequentialTesting.swift           Alpha spending, group-sequential boundaries
EffectSize.swift                  Absolute/relative lift with intervals
```

**`Network/`** *(new top-level area)* — domain-neutral, see §3.4
```
Graph/Graph.swift                 Undirected/directed, deterministic ordering
Graph/WeightedGraph.swift         Weighted edges
Traversal/TopologicalSort.swift   DAG ordering
Traversal/StronglyConnected.swift Tarjan — lifted from Model Definition
Traversal/Components.swift        Connected components, reachability
Projection/BipartiteProjection.swift  Membership → affinity, weighting schemes
Centrality/Degree.swift           Degree and strength
Centrality/PageRank.swift         With convergence refusal
Centrality/Betweenness.swift      Brandes' algorithm; brokerage, not popularity
Centrality/Closeness.swift        Harmonic variant, so disconnection is defined
Centrality/Eigenvector.swift      With the localisation refusal (§3.4)
Community/Louvain.swift           Modularity maximisation
Community/Modularity.swift        Scoring a partition
Markov/TransitionMatrix.swift     Construction, row-stochastic validation
Markov/SteadyState.swift          Stationary distribution
Markov/Absorption.swift           Absorbing states, expected steps
Markov/RemovalEffect.swift        Channel removal — attribution's engine
```

**`Marketing/`** *(new top-level area)* — the marketing-shaped surfaces
```
Ingest/CustomerRecord.swift       The canonical model — see §3.7
Ingest/CustomerDataSource.swift   Adapter protocol + ConformanceReport
Ingest/Adapters/                  DataTable, CSV, Codable, tuple-array
Segmentation/RFM.swift            Recency/frequency/monetary tiers
Segmentation/BehaviouralSegments.swift  Surface over KMeans and Louvain
Value/CustomerLifetimeValue.swift Canonical CLV, named variants
Value/AcquisitionCost.swift       CAC, CAC payback, LTV:CAC
Value/CohortRetention.swift       Cohort table; surface over Survival
Response/ResponseModel.swift      Surface over LogisticRegression
Response/CampaignDepth.swift      Profit-optimal decile depth
Response/Uplift.swift             Two-model and class-transformation uplift
Attribution/AttributionModel.swift  Protocol + heuristics (first/last/linear/decay)
Attribution/MarkovAttribution.swift Removal effect over Network/Markov
Attribution/ShapleyAttribution.swift Exact for small channel sets
Basket/AssociationRules.swift     Support, confidence, lift over projection
Pricing/PriceElasticity.swift     Own- and cross-price elasticity
Pricing/PriceResponse.swift       Demand curve fitting
Pricing/OptimalPrice.swift        Profit-maximising price
```

### 3.3 Modified files

| File | Change |
|---|---|
| `AB Test.swift` | `sampleSize` deprecated; `pValue` retained as a primitive |
| `Fluent API/Templates/SaaSModel.swift` | LTV/CAC/retention methods delegate to `Marketing/Value/`, deprecated |
| `Fluent API/Templates/SubscriptionBoxModel.swift` | Same |
| `Model Definition/DependencyReport.swift` | SCC delegates to `Network/Traversal/` |
| `Statistics/Regression/ModelValidation.swift` | Unchanged; classification evaluation is a separate area |

### 3.4 `Network/` is domain-neutral, with named consumers

`proposals/NetworkAnalysis.md` was written as a general-purpose module and should stay
that way. Marketing draws on it; it does not own it.

**What ships in 3.0.0**, and who requires it:

| Capability | Required by | Status |
|---|---|---|
| Graph types, deterministic ordering | everything below | new |
| Topological sort | `Model Definition`; future scheduling | **absent today** |
| Strongly connected components | `Model Definition` | **exists, unformalised — generic on lift, see below** |
| Bipartite projection | `Marketing/Basket`, segmentation | new |
| Degree / strength centrality | `Marketing` seeding | new |
| PageRank | `Marketing` seeding | new |
| Betweenness (Brandes) | brokerage questions — see below | new |
| Closeness (harmonic) | diffusion and time-to-reach | new |
| Eigenvector | hub-structured graphs; refuses on localisation | new |
| Louvain + modularity | `Marketing/Segmentation` | new |
| Markov chains + removal effect | **`Marketing/Attribution`** | new |

The Markov work is the highest-leverage item in the module, because one implementation
serves three legs:

- **Marketing** — attribution by removal effect; customer state transitions
- **Finance** — credit rating migration matrices, natural neighbours of
  `Valuation/CreditDerivatives/CreditTermStructure.swift`
- **Operations** — machine-state and queueing models

### The SCC lift is generic, and fixes an unchecked precondition on the way

Today:

```swift
static func components(of graph: [String: [String]]) -> [[String]]
```

Lifted:

```swift
public static func components<Node: Hashable & Comparable & Sendable>(
    of graph: [Node: [Node]]
) -> [[Node]]
```

`Model Definition` consumes it at `Node == String` and is otherwise unchanged.

`Comparable` is not decoration — it is what the determinism guarantee rests on. The current
implementation iterates `graph.keys.sorted()` precisely so that nothing depends on
`Dictionary` iteration order, and a generic version keeps that requirement or loses the
guarantee. The cost is that a node type which is `Hashable` but not `Comparable` — an
opaque ID struct, say — cannot be used directly. That is the right trade: a graph algorithm
whose output order varies run to run is not usable in a library that tests for
reproducibility.

**The lift also has to fix something the current code documents rather than enforces.** Its
doc comment reads:

> Deterministic: vertices are entered in sorted order and **each adjacency list is assumed
> already sorted**, so nothing about the result depends on `Set` or `Dictionary` iteration.

Inside `Model Definition` that assumption holds, because `accountNames(in:)` returns sorted
output and there is exactly one caller. **As a public generic API it becomes a silent
correctness hazard:** a caller who passes unsorted adjacency gets non-deterministic
component *ordering* with no error, no warning, and output that looks entirely correct on
any single run. That is the fail-silent pattern this release exists to remove, arriving
through the front door.

Two options, and the second is better:

1. Sort adjacency defensively inside the algorithm — `O(E log E)` added, and it makes the
   guarantee unconditional.
2. **Make the sortedness a property of the type rather than a precondition on the call.**
   `Graph.init` sorts once at construction, and `components` takes a `Graph` rather than a
   raw dictionary. The cost is paid once per graph instead of once per algorithm, every
   algorithm in the module inherits the guarantee, and the precondition stops being
   something a doc comment has to ask for.

Option 2 is the design. The raw-dictionary entry point survives as a convenience
initialiser that sorts.

**The full centrality suite ships.** An earlier draft cut betweenness, closeness, and
eigenvector on the strength of the downstream finding that degree matched PageRank to
within noise. That reasoning does not survive examination, and §12.3 now records why:
**the evidence was about predictive value on one dataset, not about whether the algorithms
belong in the API.** Those are different claims and the draft conflated them.

Three positive reasons, beyond withdrawing a bad argument:

- **Betweenness measures something degree cannot approximate.** A node with two edges can
  have maximal betweenness if it is the only bridge between two clusters. Brokerage and
  popularity are different questions, and in supply-chain, org-network, and counterparty
  analysis brokerage is usually the one being asked.
- **The finding may be about that graph's topology rather than about the algorithms.** A
  co-membership projection is highly clustered and hub-poor, which is exactly the regime
  where eigenvector methods and degree converge. It says little about a graph with genuine
  hub structure — a referral network, a citation graph, an exposure network.
- **Marginal cost is low and the alternative is worse.** Once the graph type and traversal
  exist, these are bounded textbook algorithms with published test vectors. Omitting them
  means a user with a brokerage question reaches for a different library and takes their
  graph construction with them.

**Still deliberately excluded from 3.0.0:** everything in §14 — flow, shortest path,
CPM/PERT, MST filtering, contagion. Those are separate bodies of work with no 3.0.0
consumer, not algorithms sharing an engine that already ships.

### 3.5 Build order

Everything below ships in 3.0.0; the order is a dependency ordering, not a priority
ranking. Each stage is independently releasable to `main` behind the quality gate, so the
release can be assembled incrementally rather than merged at the end.

| Stage | Contents | Blocked by |
|---|---|---|
| **0 — Foundation** | `LogisticRegression`, `Statistics/Classification/`, `Statistics/Survival/`, `Statistics/Concentration/` | nothing |
| **1 — Graph** | `Network/Graph`, `Traversal`, the `Model Definition` parity cut | nothing; parallel with stage 0 |
| **2 — Experiment** | `Statistics/Experiment/`, `sampleSize` deprecation | nothing; parallel with 0 and 1 |
| **3 — Marketing core** | `Value/`, `Segmentation/RFM`, `Response/`, `Pricing/` | stage 0 |
| **4 — Graph consumers** | `Network/Projection`, `Centrality`, `Community`, `Markov` | stage 1 |
| **5 — Attribution** | `Attribution/`, `Basket/`, `Segmentation/Behavioural` | stages 3 and 4 |
| **6 — Templates** | `SaaSModel` / `SubscriptionBoxModel` delegation and deprecation | stage 3 |

Three notes on the ordering:

**Pricing is early, not late.** It sits in stage 3 with the rest of the marketing core
rather than in a second wave. Elasticity is a log-log regression coefficient — it depends
on machinery that already ships — so it is cheap, and it is the bridge to the finance leg
(§3.1). Nothing is gained by deferring it.

**Attribution is last because it is downstream, not because it is optional.** It needs both
the marketing core and the Markov work, so it cannot start earlier. That makes it the
schedule risk: it is simultaneously the largest single piece and the one with the least
slack. If any stage slips, this is where it shows.

**Stages 0, 1, and 2 are mutually independent** and are the natural fan-out point if this
is built with parallel agents.

### 3.6 The separation refusal

`LogisticRegression` must **refuse** when the data is perfectly or quasi-perfectly
separated. Under separation the maximum-likelihood coefficients diverge to infinity; the
optimizer stops somewhere arbitrary and most libraries return whatever it had.

That returned model has enormous coefficients, a perfect in-sample AUC, and no predictive
validity — a plausible-looking artifact, which is precisely what the release theme exists
to prevent. The function throws `LogisticRegressionError.separation(variables:)`, naming
the offending predictors, and the documentation points at Firth's penalised likelihood as
the remedy.

This is the clearest demonstration of the 3.0.0 theme inside the marketing work, and it is
the design detail most likely to be quietly dropped under schedule pressure.

---

### 3.7 Getting real data in: a conformance contract, not typed arrays

§12.2 names this as the second-most-likely way this design is wrong — that marketing data
arrives as clean typed arrays. It does not. Real customer data is messy, keyed, and joined
across tables, and the ergonomics of getting it *into* these functions plausibly matter
more to adoption than the functions themselves.

The answer is a canonical model with pluggable adapters: any source conforms its data to
one clean format, and everything downstream consumes only that.

```swift
/// The canonical record. Everything in `Marketing/` consumes this and nothing else.
public struct CustomerRecord<T: Real & Sendable>: Sendable, Identifiable {
    public let id: String
    public let acquired: Date?
    public let attributes: [String: AttributeValue]
    public let transactions: [Transaction<T>]
}

/// Any source of customer data. Adapters conform to this; the library ships several.
public protocol CustomerDataSource: Sendable {
    associatedtype Value: Real & Sendable
    func conform() throws -> ConformanceResult<Value>
}
```

Adapters ship for `DataTable`, CSV with a column mapping, `Codable` collections, and plain
arrays of tuples for the simple case. The protocol is public so a caller can write one for
a warehouse, an API, or a proprietary export without waiting on us.

**The part that matters more than the adapters.**

An adapter's job is to conform imperfect data, which means some rows will not conform. The
obvious implementation drops them. **A silently dropped row makes every downstream number
wrong and says nothing** — a CLV computed over 97% of a cohort is not a CLV, and a library
that returns one anyway has committed exactly the failure this release is named for.

So conformance is reported, never silent:

```swift
public struct ConformanceResult<T: Real & Sendable>: Sendable {
    public let records: [CustomerRecord<T>]
    public let report: ConformanceReport
}

public struct ConformanceReport: Sendable, Codable {
    public let rowsRead: Int
    public let rowsAccepted: Int
    public let rejections: [Rejection]     // row index, field, reason
    public var acceptanceRate: Double { get }
}

public enum ConformancePolicy: Sendable {
    case strict          // any rejection throws — the default
    case reporting       // proceed, and the report travels with the result
}
```

Under `.reporting`, the report is **carried on every downstream result**, not merely
returned once at ingestion. `CLVResult` and `LiftTable` hold the report of the data they
were computed from, so the number and the caveat cannot be separated by the time they reach
a slide. Under `.strict` — the default — a single unconformable row stops the run.

This is the same principle as §3.6's separation refusal and spine 1's GPU contract, applied
to the boundary where data enters. It is also, per §12.2, the part most likely to determine
whether any of the rest gets used.

---

## 4. API Surface

```swift
// MARK: - Statistics/Regression

public struct LogisticRegression<T: Real & Sendable & Codable>: Sendable {
    public init(predictors: [[T]], outcomes: [Bool], intercept: Bool = true)
    public func fit(maxIterations: Int = 25, tolerance: T) throws -> LogisticFit<T>
}

public struct LogisticFit<T: Real & Sendable & Codable>: Sendable, Codable {
    public let coefficients: [T]
    public let standardErrors: [T]
    public let logLikelihood: T
    public let iterations: Int
    public func probability(_ predictors: [T]) -> T
}

public enum LogisticRegressionError: Error, Sendable {
    case separation(variables: [Int])
    case didNotConverge(iterations: Int, gradientNorm: Double)
    case rankDeficient(columns: [Int])
}

// MARK: - Statistics/Classification

public struct ClassifierEvaluation<T: Real & Sendable>: Sendable {
    public init(scores: [T], outcomes: [Bool])
    public var auc: T { get }
    public var ks: T { get }
    public func confusionMatrix(threshold: T) -> ConfusionMatrix
    public func calibration(buckets: Int) -> CalibrationCurve<T>
    public func gains(buckets: Int) -> GainsTable<T>
}

// MARK: - Statistics/Experiment

public struct Experiment<T: Real & Sendable>: Sendable {
    public static func twoProportion(baseline: T, minimumDetectableEffect: T) -> Experiment
    public func sampleSizePerArm(power: T, alpha: T, tails: Tails) -> Int
    public func analyze(_ observed: ArmResults<T>) -> ExperimentResult<T>
}

public struct ExperimentResult<T: Real & Sendable>: Sendable {
    public let absoluteLift: T
    public let relativeLift: T
    public let interval: ClosedRange<T>     // the answer; pValue is the footnote
    public let pValue: T
}

// MARK: - Network

public struct WeightedGraph<Node: Hashable & Comparable & Sendable>: Sendable {
    public init(edges: [(Node, Node, Double)])
    public static func projecting(
        memberships: [Node: Set<String>], weighting: ProjectionWeighting
    ) -> WeightedGraph
}

public struct TransitionMatrix<T: Real & Sendable>: Sendable {
    public init(paths: [[String]]) throws            // observed sequences → chain
    public func steadyState(tolerance: T) throws -> [String: T]
    public func removalEffect(of state: String) throws -> T
}

// MARK: - Marketing

public func customerLifetimeValue<T: Real & Sendable>(
    cohort: [CustomerHistory<T>],
    definition: CLVDefinition,               // §12.5 — the variant is explicit
    discountRate: T,
    horizon: Int
) throws -> CLVResult<T>

public protocol AttributionModel: Sendable {
    func attribute(journeys: [Journey]) throws -> [String: Double]
}

public func optimalCampaignDepth<T: Real & Sendable>(
    gains: GainsTable<T>, contactCost: T, marginPerResponse: T
) -> CampaignDepth<T>
```

---

## 5. MCP Schema

The BusinessMath MCP server exposes the library to AI tooling; every public entry point
here needs a schema. Representative example:

**Tool Description:** Fit a logistic regression and report coefficients with standard
errors. Refuses when the data is separated.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "predictors": [[1.0, 22.5], [0.0, 31.0], [1.0, 45.2]],
  "outcomes": [true, false, true],
  "intercept": true,
  "maxIterations": 25,
  "tolerance": 1e-8
}
```

**Parameter Types:**
- `predictors` (array of arrays of number): Design matrix, one row per observation. All
  rows must have equal length. Required.
- `outcomes` (array of boolean): Binary response, same length as `predictors`. Required.
- `intercept` (boolean): Whether to fit an intercept term. Default `true`.
- `maxIterations` (integer): IRLS iteration cap. Must be > 0. Default 25.
- `tolerance` (number): Convergence tolerance on the gradient norm. Default 1e-8.

**Errors returned to the caller as structured refusals**, not as values:
`separation`, `didNotConverge`, `rankDeficient`.

**New tools, by group:** `fit_logistic_regression`, `evaluate_classifier`,
`calculate_auc`, `calculate_calibration`, `calculate_gains_table`, `kaplan_meier`,
`log_rank_test`, `calculate_gini`, `calculate_lorenz`, `design_experiment`,
`experiment_sample_size`, `analyze_experiment`, `build_graph`, `project_bipartite`,
`calculate_centrality`, `detect_communities`, `build_transition_matrix`,
`markov_removal_effect`, `calculate_rfm`, `calculate_clv`, `calculate_cac`,
`cohort_retention`, `attribute_conversions`, `association_rules`, `price_elasticity`,
`optimal_price`, `campaign_depth`, `uplift_model`.

No function here consumes randomness except `ShapleyAttribution` above four channels
(Monte Carlo permutation sampling), which takes a required `seed`.

---

## 6. Constraints & Compliance

**Concurrency:** Every type is an immutable value type and `Sendable`. No shared mutable
state; no `@unchecked Sendable`, so no justification comments are required.

**Determinism:** Graph algorithms iterate vertices in sorted order — the discipline
`Model Definition/DependencyReport.swift` already established and the reason its output is
reproducible. Louvain is order-dependent by nature and therefore takes an explicit seed and
documents that different seeds yield different partitions. Shapley sampling takes a seed.
Nothing else consumes randomness.

**Generics:** Generic over `Real` per coding rules, with `Sendable & Codable` where results
cross isolation or persist. Graph nodes require `Comparable` for deterministic ordering.

**Safety:** No force unwraps. Every division guarded on its divisor rather than on a
proxy — this includes rate calculations with zero denominators, which are endemic in
marketing (a cohort with no customers, a decile with no responders).

**Auditor compliance:** The 45 SwiftSyntax auditors run against this code. Specific risks:
`RecursionAuditor` on graph traversal — Tarjan is written iteratively with an explicit
stack, following `DependencyReport`'s existing precedent; `PointerEscapeAuditor` on any
Accelerate path in IRLS — no pointer obtained inside a `withUnsafe*` block escapes;
`ConcurrencyAuditor` — no `DispatchQueue` inside actor-isolated contexts.

**Expression complexity:** Statistical formulas exceed the three-operator-per-expression CI
rule readily. Intermediate `let` bindings are named for the statistical quantity they hold
(`pooledVariance`, `zAlpha`, `zBeta`), which serves readability rather than merely
satisfying the linter.

**MCP ready:** Schemas in §5; all types explicit; errors structured.

---

## 7. Source & API Compatibility

**Breaking changes — three, all deliberate:**

1. **`sampleSize(ci:proportion:n:error:)` deprecated.** §2.4. Replaced by
   `Experiment.sampleSizePerArm(power:alpha:tails:)`. Deprecation carries a message naming
   the defect, not merely the replacement, so a user who follows the warning learns their
   past tests were undersized.

2. **`SaaSModel.calculateLTV()` and siblings deprecated.** The canonical functions become
   the implementation; templates call them. Where a template's inputs are assumptions
   rather than customer data, the delegation is to a `fromAssumptions` variant that keeps
   the current arithmetic — so the deprecation is a redirection, not a behaviour change.

3. **`Model Definition` SCC delegates to `Network/`.** Internal only; no public surface
   moves. Behaviour must be identical — see the parity test in §10.

**Incremental adoption:** Yes. `Statistics/*` and `Network/` additions are purely additive.
A user who never imports `Marketing` sees only the two deprecations.

**Type-checking risk:** `lift` is a plausible name collision across `GainsTable` and
`AssociationRules`; both are namespaced under their types rather than free functions. No
free function proposed here shares a name with an existing one.

**Non-breaking mitigation — taken.** The corrected power calculation ships additively in
2.7.0, with the deprecation alongside it and the deletion held for 3.0.0. Scoped in
`completed/v2.7.0_SCOPE.md` (shipped in 2.7.0). See §12.1.

---

## 8. Backend Abstraction

`Statistics/Regression/MatrixOperations/` already defines `MatrixBackend` with CPU,
Accelerate, and Metal implementations. This work reuses it rather than introducing a
second abstraction.

| Operation | Backend use | Threshold |
|---|---|---|
| IRLS weighted least squares | `MatrixBackend` per iteration | Accelerate above ~1,000 rows |
| Markov steady state | `MatrixBackend` power iteration | Accelerate above ~200 states |
| Louvain | CPU only | — |
| Graph traversal | CPU only | — |
| AUC, gains, Gini | CPU; sort-dominated | — |

**Fallback:** CPU always available; Linux server deployments (roseclub.org) take the
CPU path for Metal-backed operations. Nothing here consumes seeded randomness on a GPU
path, so the `GPUAttempt` contract in §1 of the 3.0.0 scope does not apply — with the
single exception of Shapley permutation sampling, which is CPU-only by design for exactly
that reason.

---

## 9. Dependencies

**Internal:**
- `Statistics/Regression/MatrixOperations/` — IRLS, Markov steady state
- `Statistics/Descriptors/` — `descriptives`, `correlationCoefficient`
- `Optimization/Heuristic/KMeansClustering.swift` — behavioural segmentation surface
- `Simulation/distributionWeibull.swift` — parametric retention fit
- `Statistics/Probability Distribution/` — normal quantiles for power calculations
- `Model Definition/DependencyReport.swift` — the SCC being lifted
- `Bayes/Bayes.swift` — adjacent to future bandit work, unused here

**External:** None. swift-numerics only, as today.

**Deliberately not depended on:** `Valuation/CreditDerivatives/HazardRateModel.swift`.
Churn and credit default are the same mathematics, but the credit code fits parametric
intensities for pricing, while retention needs the empirical estimator. Kaplan-Meier is
written fresh in `Statistics/Survival/`; unifying the two is future work (§14) and should
not block this.

---

## 10. Test Strategy

The user requirement is that 3.0.0 holds until all of this works **and is verified as
correct**. This section is therefore the load-bearing one.

### 10.1 Reference truth, by component

No expected value in the table below is asserted from memory. Each names a source the
implementer must run or read, and the derived number becomes the test assertion.

| Component | Reference truth |
|---|---|
| Logistic regression | R `glm(family = binomial)` on Hosmer & Lemeshow's low-birth-weight dataset — coefficients and standard errors |
| Separation refusal | A constructed separable dataset; R emits "fitted probabilities numerically 0 or 1 occurred". We must throw. |
| AUC | `pROC::auc` in R, plus the internal identity in §10.2 |
| Calibration / Brier | Published worked example; Brier is a mean squared error and hand-checkable |
| Kaplan-Meier | Freireich et al. leukaemia remission data — the canonical censored dataset, tabulated in Kleinbaum & Klein |
| Log-rank | Same dataset; χ² statistic as published |
| Gini | Two independent formulas must agree (§10.2), plus a published national Gini |
| Two-proportion power | R `power.prop.test`. **Computed during this audit:** `p1 = 0.50, p2 = 0.55, power = 0.80, alpha = 0.05 → n = 1,565 per arm.** |
| Sequential boundaries | O'Brien-Fleming and Pocock boundaries as tabulated in the original papers |
| Louvain / modularity | Zachary's karate club — the canonical benchmark. Community count and modularity as reported by Newman; verify against `python-louvain` rather than from memory. |
| PageRank | Original Page & Brin worked example, plus the invariants in §10.2 |
| Tarjan SCC | **Parity against the existing implementation** — see §10.3 |
| Markov removal effect | Anderl et al., *Mapping the Customer Journey*; small chains are hand-computable |
| Shapley attribution | Exact enumeration for ≤ 4 channels; the efficiency axiom in §10.2 |
| Association rules | Any published market-basket worked example; support and confidence are counting |
| RFM | Definitional — tiering is specified, not discovered; tests pin tie-breaking |
| Price elasticity | Textbook worked examples (Nagle); log-log regression coefficient *is* the elasticity |

### 10.2 Property tests — the strongest tier

Reference values verify one input. Properties verify all of them, and several of these are
identities that a subtly wrong implementation cannot satisfy by accident:

- **AUC equals the Mann-Whitney U statistic** normalised by `n_pos × n_neg`. Compute both
  ways from the same scores; they must agree to floating-point tolerance.
- **Gini computed from the Lorenz area equals Gini from the rank formula**
  `(2·Σ i·xᵢ)/(n·Σxᵢ) − (n+1)/n`.
- **Shapley attribution satisfies efficiency** — attributions sum to total conversions —
  and **symmetry**: two channels with identical marginal contributions receive equal credit.
- **Kaplan-Meier is monotone non-increasing**, starts at 1.0, and with no censoring reduces
  exactly to the empirical survival function.
- **Louvain's returned partition has modularity ≥ the singleton partition's**, for every
  seed.
- **PageRank sums to 1** and is invariant under node relabelling — which is also the
  determinism test.
- **A transition matrix's rows sum to 1**; steady state is a fixed point, `πP = π`.
- **At logistic convergence the gradient norm is below tolerance** — the optimizer's own
  claim, checked independently.
- **Power calculation round-trips:** sizing for a given MDE and power, then computing
  achieved power at that n, returns the requested power.
- **Bipartite projection with uniform weights reproduces the co-occurrence count matrix.**

### 10.3 The parity test

Lifting Tarjan out of `Model Definition` is the one change here that can break working,
correctness-critical code. It gets the same treatment the downstream project used when
reprojecting 627,760 pairs: **run both implementations over every model definition in the
test corpus and require identical component membership and identical ordering.** Not
equivalent — identical, including the sorted-order determinism guarantee.

The old implementation stays in the tree until parity passes, then is deleted in the same
commit that proves it.

### 10.4 Categories

- **Golden path** — every reference value in §10.1
- **Properties** — every invariant in §10.2, over generated inputs
- **Edge cases** — empty cohort; single customer; all-responders and no-responders (AUC
  undefined, must refuse rather than return 0.5); a decile with zero denominator; a
  disconnected graph; a single-node graph; an absorbing-only chain; zero-variance predictor
- **Refusals** — separation, non-convergence, rank deficiency, non-stochastic transition
  matrix, negative weights where undefined. Each asserts the *specific* error case, not
  merely that something threw.
- **Determinism** — same seed and same input yields identical output for Louvain and
  Shapley; graph algorithms are deterministic without a seed
- **Documentation** — `doc-code` and `doc-comment-code` over every public symbol, per §16

---

## 11. Architecture Decision Review

**ADR check:**
- [x] Reviewed `architecture_decisions.md` for related decisions
- [ ] Supersedes an existing ADR? **No**
- [ ] Amends an existing ADR? **Yes** — whichever ADR records the module-boundary
      convention needs the placement rule in §3.1 appended.
- [x] New ADRs required? **Yes — three.**

**ADR draft 1 — Technique placement**
- Title: Fundamental techniques live with their specialty; domain surfaces live in domain modules
- Category: architecture
- Key decision: A statistical technique used outside one business domain belongs in
  `Statistics/`; only domain-specific formulas built on it belong in a domain module.

**ADR draft 2 — One graph representation**
- Title: `Network/` owns the library's graph algorithms
- Category: architecture
- Key decision: Graph algorithms live in `Network/` and are consumed by other modules;
  no module maintains a private graph implementation.

**ADR draft 3 — Refusal under separation**
- Title: Model fitting refuses when the estimate is undefined
- Category: api
- Key decision: A fit whose maximum-likelihood estimate diverges throws rather than
  returning the optimizer's last iterate. Extends the fail-silent principle from execution
  paths to statistical estimation.

---

## 12. Adversarial Review

### 12.1 The strongest case against this proposal

**Two shipped defects are being held hostage to a feature programme.**

`sampleSize` returns a number 4× too small today. The GPU seeding bug returns wrong answers
under seed today. Both are in users' hands. Tier 0 plus attribution plus pricing plus a
graph module is a large body of work, and every week it takes is a week those defects
remain shipped.

A reviewer would say: **release 3.0.0 as the correctness release it was scoped to be, and
ship Marketing as 3.1.** The theme argument in §2 is elegant, but elegance is not a reason
to delay a fix.

**Response — and this changed the plan. Adopted 2026-08-23, scoped in
`completed/v2.7.0_SCOPE.md`.** The correct power calculation shipped additively in 2.7.0 with
the deprecation beside it; the deletion waits for the major. It is purely additive and
needs none of this proposal, so the defect stops shipping in weeks rather than months. The
same treatment should be considered for any other defect this work surfaces.

That decouples the argument entirely. The remaining question — whether 3.0.0 waits for the
whole leg — is now a scheduling preference rather than a correctness one, and
`v3.0.0_SCOPE.md` §0.1 records what actually forces the major so the bundling stays a
choice rather than hardening into an assumption.

### 12.2 Where this design is most likely wrong

**The load-bearing assumption is that BusinessMath's users want marketing analytics.**

The evidence for the gap is entirely supply-side: the library does not have these functions.
There is no demand evidence in this proposal at all. The library's existing depth is in
valuation, derivatives, and financial statements, which suggests its users are financial
modellers — people who may never have customer-transaction data to hand.

If that assumption is wrong, this proposal builds a large, well-tested module that nobody
imports, and the cost is not merely the build but the permanent maintenance surface: every
future refactor, every Swift version bump, every auditor change now covers 40 more files.

**Nothing in §10 tests this assumption.** It is the one risk the test strategy cannot
address, and it should be named to the user rather than buried.

**A second, narrower assumption:** that marketing data arrives as clean typed arrays.
Real customer data is messy, keyed, and joined across tables. `Analysis/DataTable.swift` is
a single file, and the ergonomics of getting a customer table *into* these functions may
matter more to adoption than the functions themselves.

### 12.3 The centrality argument, and a correction to it

The downstream validation found degree centrality (−0.246) and PageRank (−0.250) within
noise of each other, both roughly doubling the predictive power of raw counting. The
finding was that **weighting the graph matters and the algorithm does not** — on that
graph.

An earlier draft treated this as grounds for cutting most of the centrality suite. That was
an error, and naming it precisely matters more than reversing it: **a finding about
predictive value on one dataset was used as an API scoping decision.** "PageRank does not
outperform degree at predicting reunion attendance" and "PageRank does not belong in the
library" are different claims, and only the first has evidence behind it.

The draft also committed the exact overreach it accused the design of. It criticised
generalising from thin evidence, then generalised from n=1 — one graph, one domain, one
outcome variable — to a permanent API exclusion. A co-membership projection is highly
clustered and hub-poor, the regime where eigenvector methods and degree provably converge;
it is close to the least informative topology on which to test whether eigenvector methods
add anything.

**The surviving version of the objection is narrower and still worth honouring:** the
library should not *market* the centrality suite as predictive machinery, because our own
evidence says the weighting does the work. The documentation should say so plainly — that
building the graph correctly matters more than the choice of measure, and that degree is
the right default. That is an honest claim the library can make and most cannot.

### 12.4 The graph module's consumers are mostly hypothetical

Only two are real: `Model Definition` (which already works fine with its private
implementation, so consolidation is tidiness rather than capability) and
`Marketing/Attribution` (which genuinely needs Markov chains). The credit-migration and
portfolio-MST consumers in §3.4 and §14 are speculative — nobody has asked for them.

**Response:** the Markov requirement alone justifies the module, and attribution is in
scope by the user's decision. The rest of §3.4 should be read as *why the module is
domain-neutral*, not as *why it is large*. The exclusion list exists for this reason.

### 12.5 "Correct" may be undefined in this domain

§2 argues the doc-checkers are a differentiator because marketing formulas are contested.
A critic turns that around: **if there are four definitions of CLV, verifying that the code
matches its documentation proves internal consistency, not correctness.** A user who wants
definition three gets a library that is rigorously, verifiably computing definition one.

**Response — and this changed the design.** `CLVDefinition` in §4 is an explicit parameter
rather than a hidden choice, and every contested primitive follows the same pattern: the
common variants ship as named cases, the documentation states what each computes, and the
checker proves the mapping. The library's claim becomes "we compute exactly the definition
you named," which is defensible in a way "we compute CLV" is not.

### 12.6 The critic's one sentence

> *You have written a strong audit and turned it into a large feature programme, and the
> only part with proven demand is the bug fix.*

**Proceeding anyway** because the user has explicitly accepted the schedule cost and
because §12.1's mitigation removes the defect-delay objection entirely. **What changed in
response:** the 2.7 additive fix (§12.1), the explicit `CLVDefinition` (§12.5), the
centrality cuts (§3.4), and the demand assumption promoted from unstated to §12.2 where the
user can weigh it.

---

## 13. Alternatives Considered

**Alternative 1 — Put everything in `Marketing/`, including logistic regression.**
- *Advantage:* one module, one review, clean boundary; the marketing story is self-contained.
- *Disadvantage:* logistic regression is used in credit scoring, medicine, and quality
  control. Burying it in `Marketing/` means the credit module cannot reach for it without
  an import that misrepresents what it is doing — and BusinessMath has a deep credit module.
- *Why rejected:* the user's placement rule, which is correct. It also produces the better
  outcome for the other three legs.

**Alternative 2 — Marketing as a separate package depending on BusinessMath.**
- *Advantage:* keeps the core library's identity sharp; §12.2's demand risk lands on a
  package users opt into; independent versioning.
- *Disadvantage:* the fluent templates in core would need to depend on it, or keep their
  own LTV, which is the inversion §2.1 exists to fix. Two repos, two quality gates, two
  release processes.
- *Why rejected:* the dependency runs the wrong way. Core needs CLV, so CLV cannot live
  downstream of core. This is the strongest of the four alternatives.

**Alternative 3 — Skip Tier 0; ship lift, RFM, and retention over user-supplied scores.**
- *Advantage:* dramatically smaller; ships in weeks; no logistic regression, no classifier
  evaluation, no separation-refusal design.
- *Disadvantage:* the library computes lift charts for scores produced elsewhere, which
  means the interesting half of the work happens in someone else's tool. §2.2's dependency
  table is the argument.
- *Why rejected:* the user's explicit answer — "Tier 0 is critical."

**Alternative 4 — Use an existing Swift ML package for the classifier.**
- *Advantage:* less code; someone else maintains IRLS.
- *Disadvantage:* no Swift package provides logistic regression with standard errors,
  separation detection, and `Real`-generic arithmetic. Those that exist are `Double`-only
  and return point estimates without inference. BusinessMath's whole proposition is
  auditable statistical correctness; a dependency that cannot report a standard error
  cannot serve it.
- *Why rejected:* would import a dependency and still leave the inference work undone.

---

## 14. Future Directions

Named because §3.4's exclusion list is more credible with the alternatives visible. All
"could," none committed.

**Graph, with plausible business consumers:**
- **Shortest path** — Dijkstra, Bellman-Ford. Bellman-Ford's negative-cycle detection over
  log-transformed exchange rates *is* triangular arbitrage detection, which would be a
  finance-native consumer.
- **Network flow** — max-flow/min-cut, min-cost flow, transportation, assignment
  (Hungarian). Operations consumers in logistics and capacity planning. Design question:
  specialise, or delegate to the existing `solve_linear_program`?
- **CPM / PERT project scheduling** — DAG longest path with slack; the three-point estimate
  would compose with the existing Monte Carlo engine. A conspicuous absence for a business
  library that already covers inventory and newsvendor.
- **Minimum spanning tree / PMFG correlation filtering** — reduces a correlation matrix to
  its structural skeleton. Consumers in `Portfolio` and `Risk`.
- **Contagion and systemic risk** — DebtRank and cascade default over exposure networks.
  Graph-theoretic and finance-native; neighbours `CreditDerivatives`.
- **Bill-of-materials explosion** — DAG traversal with quantity multipliers, for MRP.
- **Bayesian networks and influence diagrams** — over the existing `Bayes/` module.
- **Scenario trees** — structure for `optimize_multiperiod`.

**Marketing:**
- Marketing mix modelling — adstock and saturation transforms feeding existing regression
- Discrete choice — multinomial logit, underpinning conjoint and brand switching
- Survey instruments — NPS with an interval, top-2-box, Likert, MaxDiff, van Westendorp
- Sample weighting — post-stratification and raking; the library consumes weights but
  constructs none
- Bass diffusion
- Bandits — Thompson sampling, beside `Bayes/`
- Reach and frequency

**Consolidation:**
- Unify `Statistics/Survival/` with `Valuation/CreditDerivatives/HazardRateModel.swift`,
  once both exist and the shared abstraction is visible rather than guessed at.

---

## 15. Open Questions

1. **Does the 2.7 additive power fix happen?** §12.1. This is the only item that changes
   what ships to users in the near term, and it is independent of everything else here.
2. **Does PageRank stay?** §12.3 argues our own evidence undercuts it. Degree is cheaper,
   explainable, and performed identically on the one dataset we have.
3. ~~**What is the input ergonomics story?**~~ **Answered: §3.7.** A canonical
   `CustomerRecord`, a `CustomerDataSource` adapter protocol, and a `ConformanceReport`
   that travels with every downstream result so a dropped row can never become a silently
   wrong number. Remaining sub-question: does `Analysis/DataTable.swift` need work to be a
   good adapter target, or is it already sufficient?
4. **Which CLV variants ship as named cases?** §12.5 makes the variant explicit; it does
   not decide the list. Four is the number cited in the audit, but the enumeration needs
   settling before the API freezes.
5. **Is `Statistics/Experiment/` the right home for the A/B lifecycle**, or does
   `Experiment` belong beside the existing `AB Test.swift`? The technique is domain-neutral
   by §3.1, but the existing file is a discoverability anchor.
6. **Does attribution need journey data the library has no way to represent?** A `Journey`
   type appears in §4 without a source. Where does it come from, and is there an ingestion
   story?

---

## 16. Documentation Strategy

**Documentation type:** API docs **and** narrative articles.

**Complexity threshold check:**
- Combines 3+ APIs? **Yes** — a response model chains logistic regression, classifier
  evaluation, gains, and campaign depth.
- Explanation requires 50+ lines? **Yes**
- Needs theory/background? **Yes** — attribution and survival both do.

**Articles required** (none matching a Swift symbol name, per the DocC parser constraint):
- `MarketingAnalyticsGuide.md` — the leg, and the causal-direction argument from §2.1
- `ResponseModellingGuide.md` — logistic regression through to campaign depth
- `AttributionGuide.md` — the models, their assumptions, and what each is wrong about
- `NetworkAnalysisGuide.md` — the graph engine and its consumers across all four legs
- `ExperimentDesignGuide.md` — sizing, stopping, and reading a result; states plainly that
  `sampleSize` was wrong and what to do about past tests

**Two module-wide rules**, arising from §2.4's defect and the checker limitation it exposed:

1. **Every public function ships an executable example carrying a checked numeric result.**
   Not optional. `sampleSize` escaped for years because prose is unverifiable and it had no
   example. A function with documentation and no example is unverified regardless of how
   carefully the prose was written.

2. **Every contested primitive names its definition in the first documentation line** —
   which CLV convention, which retention basis, which attribution model, which elasticity.
   The checker then proves documentation and code agree, and §12.5's objection is answered
   on the page where the user reads it.
