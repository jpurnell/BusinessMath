# Design Proposal: The Marketing Leg

**Author:** Justin Purnell + Claude
**Date:** 2026-08-23
**Status:** Draft — for review
**Relationship to other work:** Frames `proposals/NetworkAnalysis.md` as one part of a
larger gap, and identifies breaking changes that belong in `upcoming/v3.0.0_SCOPE.md`

---

## 1. Objective

### The diagnosis

BusinessMath stands on four legs. Three are load-bearing:

| Leg | State |
|---|---|
| **Finance** | Deep. Valuation, options, derivatives, financial statements, ratios, portfolio, risk. |
| **Operations** | A dedicated module — inventory, EOQ, newsvendor, safety stock — with its own proposal. |
| **Strategy** | Scenario analysis, forecasting, optimization, Monte Carlo, decision models. |
| **Marketing** | **Thin, and thin in a specific way.** |

The specific way matters more than the thinness. Marketing numbers *are* present —
`calculateLTV()`, `calculateCACPayback()`, `calculateRetentionRate()`, `calculateLTVtoCAC()`.
But they live inside `Fluent API/Templates/SaaSModel.swift` and
`SubscriptionBoxModel.swift`, as **methods on a financial model**.

That inverts the direction of causation. `SaaSModel.calculateLTV()` takes assumptions —
ARPU, a churn rate, a margin — and produces a number. That is finance: modelling a
business and reporting a consequence.

**Marketing analytics runs the other way.** It starts with customer transaction data and
*derives* the segments, the retention curve, the churn rate, the value per segment. The
churn rate is the output, not the input.

BusinessMath currently has no way to go in that direction. There is no function that takes
a table of customers and purchases and returns anything.

### What is actually absent

Checked against the live tree at v2.6.0, 553 source files:

| Primitive | State |
|---|---|
| **Binary-outcome regression** | **absent** — see §2, this blocks most of the rest |
| **Classifier evaluation** — AUC, ROC, KS, confusion, calibration | **absent** |
| Lift / gains / decile analysis | **absent** |
| RFM segmentation | **absent** |
| Cohort retention curves | **absent** — though the hazard machinery exists, see §2 |
| Concentration — Gini, Lorenz, Pareto | **absent** |
| Market basket — support, confidence, lift | **absent** |
| Multi-touch attribution | **absent** |
| Adstock and saturation curves (MMM) | **absent** |
| Bass diffusion | **absent** — every "diffusion" file is a stochastic process |
| Price elasticity, price response, optimal price | **absent** — one doc comment |
| Discrete choice / multinomial logit | **absent** |
| Survey instruments — NPS, top-2-box, Likert, MaxDiff, conjoint | **absent** |
| Sample weighting — post-stratification, raking | **absent** |
| Reach and frequency | **absent** |
| Uplift / incrementality | **absent** |
| Bandits — Thompson sampling, epsilon-greedy | **absent** |
| A/B testing | `pValue`, `sampleSize`. **`sampleSize` is wrong for its stated purpose — §3.** |
| CLV, CAC, retention | Present, but **only as methods on financial-model templates** |
| Behavioural clustering | `KMeansClustering` exists and is directly usable |
| Survival modelling | Exists — but scoped entirely to credit default. See §2. |
| Forecast evaluation | **Genuinely rigorous.** Rolling-origin backtest, baselines, scaled error. |

Three false friends in that list are worth naming, because a term-frequency scan of the
repository suggests coverage that is not there:

- **`logistic`** appears in six files. All six are either the logistic *growth curve*
  (`Time Series/Growth/TrendModel.swift`) or the logistic *distribution*
  (`Simulation/distributionLogistic.swift`). Neither is logistic regression.
- **`hazard` / `survival`** appear in eight files, all under `Valuation/CreditDerivatives`
  and `Valuation/Debt`. The Cox process in `HazardRateModel.swift` is a stochastic-intensity
  model for default timing, not Cox proportional hazards.
- **`precision`** appears in 37 files, every one of them about floating point.

---

## 2. The Gap Under the Gap: No Binary Outcomes

This is the finding that reorders the whole proposal.

**BusinessMath cannot model a binary outcome.** The regression module offers
`linearRegression`, `polynomialRegression`, `multipleLinearRegression`, and
`NonlinearRegression` — every one of them a continuous response. There is no logistic
regression, no discrete choice model, and no classifier of any kind.

Marketing is overwhelmingly a binary-outcome discipline. Did they respond, convert, click,
redeem, churn, subscribe, refer. Nearly every question a marketer models is *yes or no*,
and the library has no way to express it.

### It blocks Tier 1, not just Tier 3

The lift-analysis signature sketched in an earlier draft of this proposal takes scores as
an *input*:

```swift
public func liftAnalysis<T: Real>(
    scores: [String: T], responded: Set<String>, buckets: Int = 10
) -> LiftTable<T>
```

That quietly assumes something else produced the scores. Nothing in BusinessMath can. The
dependency runs deeper than one function:

| Wanted | Requires |
|---|---|
| Lift / gains / decile | a score, from a response model |
| Propensity scoring | *is* logistic regression |
| Churn prediction | a classifier over customer features |
| Uplift modelling | two classifiers, differenced |
| Next-best-action | a classifier per action |

Ship Tier 1 without this and the library can *display* a lift chart for scores computed
somewhere else, which is not the same as doing marketing analytics.

### And there is no way to evaluate one

Zero hits for ROC, AUC, KS, or confusion matrix. `Statistics/Regression/ModelValidation.swift`
is parameter recovery for regression, not model evaluation.

Set that against `Forecasting/Evaluation/`, which is a genuinely rigorous discipline —
`RollingOriginBacktest`, `Baselines`, `ScaledError`, `Forecastability`, `BacktestReport`.
**The library knows exactly how to evaluate a forecast honestly and has no equivalent for a
classifier.** Given the fail-silent principle, shipping a propensity model with no AUC and
no calibration curve would be off-brand in a way the forecasting module already avoids.

**Calibration deserves specific emphasis**, because it is the metric marketing needs most
and the one most often omitted. A model that says "12% of this decile will respond" and
gets 4% is badly calibrated even when its *ranking* is perfect — and ranking is all AUC
measures. Marketers set budgets off the predicted rate, not off the rank order. A library
that reports AUC and stays silent on calibration is reporting the metric that matters less.

### The survival machinery is already here, pointed the wrong way

`Valuation/CreditDerivatives/HazardRateModel.swift` and `CreditTermStructure.swift` exist
to answer *when does this obligor default*. **Churn is the same question with a different
noun.** A customer "defaults" by cancelling; a retention curve is a survival function;
time-to-churn is a hazard rate.

This reframes cohort retention from new work into a second consumer of machinery already
written and tested. The work is a non-credit surface over an existing engine, plus the
empirical estimator (Kaplan-Meier) that the credit side never needed because it fits
parametric intensities instead.

---

## 3. A/B Testing: A Documented Defect

`AB Test.swift` offers two functions. One is fine. **The other does not compute what its
documentation says it computes.**

```swift
/// Computes the minimum number of observations for each variant of an A/B test
/// to determine the significance of that test.
public func sampleSize<T: Real>(ci: T, proportion p: T, n: T, error: T) -> T
```

The body is Cochran's finite-population survey formula — `z²pq/e²` with a
finite-population correction. That is a **single-sample margin-of-error calculation**, and
it is missing everything a two-arm power calculation needs:

- **No power term.** Only `z_α` appears; there is no `z_β`. The function cannot express
  "80% power" because it has no notion of power at all.
- **No second sample.** An A/B test compares two arms and the variance of the difference is
  the sum of two variances. One arm's variance is in the formula.
- **No minimum detectable effect.** `error` is a margin of error around one proportion, not
  a difference between two that you want to be able to detect.

The parameter documentation gives it away — it discusses surveys, population size, and "the
researcher." **The formula is correct for what its parameters describe and wrong for what
its summary line claims.**

### The size of the error

At 95% confidence, `p = 0.5`, `error = 0.05`, large population:

| | Per arm |
|---|---|
| What `sampleSize` returns | **384** |
| Correct two-proportion sizing, 80% power to detect 0.50 → 0.55 | **1,565** |
| Understated by | **4.1×** |

A team following this documentation runs a test at roughly a quarter of the sample it
needs, fails to reach significance, and reads the null result as "no difference." That is
the fail-silent failure mode exactly: a plausible number, confidently returned, that leads
to a wrong decision.

### What the entry point should be

Two loose functions with inconsistent parameter vocabulary and no relationship to each
other is the deeper problem. An experiment has a lifecycle, and the API should follow it:

```swift
let design = Experiment.twoProportion(baseline: 0.05, minimumDetectableEffect: 0.005)
design.sampleSizePerArm(power: 0.80, alpha: 0.05)   // how many do I need
design.check(interim)                                // may I stop yet
design.analyze(final)                                // what did I learn
```

The third returns an effect size with an interval, not a bare p-value. "Significant" and
"worth shipping" are different questions, and only the interval answers the second.

Deprecating `sampleSize` is a breaking change. It is also unambiguously a **bug fix**,
which makes it the easiest item in the 3.0.0 bundle to justify.

---

## 4. Where Network Analysis Fits

`proposals/NetworkAnalysis.md` was written as a general-purpose module. Read against this
gap, it supplies **three areas directly** — and one of them is not an analogy but the
identical primitive.

### Market basket analysis *is* bipartite projection

The network proposal specifies:

```swift
WeightedGraph.projecting(memberships: [String: Set<String>], weighting: .inverseSize)
```

Customers who share a product, projected into product-to-product affinity, is the same
computation as classmates who share an activity projected into person-to-person ties. The
weighting question is the same too: a product bought by everyone carries no signal, which
is exactly why `.inverseSize` exists. **Market basket analysis is this function with
different labels on the axes.**

Completing it needs only the three association measures — support, confidence, lift — on
top of the projection that already exists.

### Segmentation by connection

`KMeansClustering` groups customers by *attribute similarity*: spend, frequency,
demographics. Louvain groups them by *co-behaviour*: who buys the same things, who refers
whom. These find different segments, and marketing wants both. Having only the first is
the current state.

### Influence and seeding

"Which customers should we activate first to reach the most people" is a centrality
question, and it is the question a referral or advocacy programme exists to answer.

It is also the question the downstream validation was built around — and the finding there
should temper the pitch. Against a real outcome, the weighted graph correlated at −0.246
where raw activity-counting managed −0.138, **but degree matched PageRank to within
noise**. The graph roughly doubles the predictive power of counting; the choice of
centrality algorithm contributes almost nothing. For marketing that is a useful, sellable
result — *build the graph properly and a simple measure will do* — but it is not "you need
thirteen centrality measures."

### What network analysis does not supply

Most of the leg. It is roughly a third, and §2 shows it is not even the foundational third.

---

## 5. Proposed Scope

Revised from the earlier draft, because §2 changes what "Tier 1" means. **Tier 0 is new,
and nothing above it works without it.**

### Tier 0 — the foundation

**Binary-outcome regression.** Logistic regression with the same care the linear
regression module already shows: coefficients, standard errors, and a refusal when
separation makes the fit meaningless.

**Classifier evaluation.** AUC and ROC, KS statistic, confusion matrix at a chosen
threshold, and — with equal billing — a **calibration curve**, per §2.

**Empirical survival.** Kaplan-Meier over the existing hazard machinery, giving churn and
retention a non-credit surface.

### Tier 1 — the questions marketers ask weekly

**Lift / gains / decile analysis.** Sort a population by score, bucket into deciles,
compare each bucket's response rate to the base rate. The single most common analytic in
direct marketing, CRM, and credit scoring. Every validation in the downstream project was
expressed this way and hand-written each time.

**RFM segmentation.** Recency, frequency, monetary value, scored into tiers. The workhorse
of retail segmentation, and what a marketer reaches for before k-means.

**Cohort retention curves.** Retention by period since acquisition, with a fitted decay.
`distributionWeibull` supplies the parametric fit; Tier 0 supplies the empirical one.

**Concentration — Gini, Lorenz, Pareto.** Customer value, revenue, and product movement are
all heavily skewed, and "what share of revenue comes from the top decile" has no answer in
the library today.

**Experimentation, properly.** §3. Sizing with power, sequential stopping, effect sizes
with intervals.

### Tier 2 — supplied by Network Analysis, plus one completion

Everything in `proposals/NetworkAnalysis.md`, plus **association rules** — support,
confidence, and lift over the bipartite projection, which completes market basket analysis.

### Tier 3 — the second wave

- **Multi-touch attribution** — the largest single piece, and the one marketers ask for
  first. Being scoped separately; see §9.
- **Pricing analytics** — own-price and cross-price elasticity, price-response functions,
  optimal price under a demand curve. Worth arguing up a tier: **pricing is where Marketing
  and Finance actually meet**, which makes it the natural bridge for a library whose
  finance leg is already deep. It is also the highest financial leverage of the four Ps.
- **Marketing mix modelling** — adstock (carryover) and saturation (diminishing returns)
  transforms, feeding the regression that already exists.
- **Discrete choice** — multinomial logit, underpinning conjoint, brand switching, and
  channel choice. Depends on Tier 0.
- **Survey and stated preference** — NPS with an interval, top-2-box, Likert scoring,
  MaxDiff, conjoint, van Westendorp. Currently zero coverage, and half of marketing
  research lives here. The library can compute a margin of error but has nothing to compute
  it *of*.
- **Sample weighting** — post-stratification and raking. `weightedCorrelation` and
  `weightedAverage` consume weights; nothing constructs them.
- **Bass diffusion** — new-product adoption. Small, well-defined, textbook.
- **Uplift modelling** — treatment effect on the persuadable. Depends on Tier 0.
- **Bandits** — Thompson sampling and epsilon-greedy, sitting naturally beside the existing
  `Bayes/` module.
- **Reach and frequency** — GRP, effective frequency. Adjacent to MMM.

---

## 6. Breaking Changes for v3.0.0

**Lift CLV, CAC, and retention out of the model templates.**

```swift
// today — a method on a financial model, taking assumptions
SaaSModel.calculateLTV() -> Double

// proposed — a function over customer data, deriving the answer
public func customerLifetimeValue<T: Real>(
    cohort: [CustomerHistory<T>], discountRate: T, horizon: Int
) -> CLVResult<T>
```

The canonical functions become the implementation; the fluent templates call them. Template
methods stay, deprecated, delegating where the inputs allow. After this, LTV is something
the library *derives* and the SaaS template *consumes*, rather than a number a financial
model asserts.

**Deprecate `sampleSize` in favour of a real power calculation.** §3. A bug fix that
happens to break a signature.

**Consolidate the A/B testing entry point.** §3. `pValue(obsA:convA:obsB:convB:)` survives
as a primitive; the supported path becomes the `Experiment` lifecycle.

---

## 7. Why the Documentation Checkers Matter Here Specifically

`doc-code` and `doc-comment-code` execute documented examples and verify they produce the
values they claim. Across the library that is good hygiene. **In marketing analytics it is
a differentiating claim**, for a reason peculiar to the domain.

Marketing formulas are contested in a way financial ones are not. Black-Scholes has one
definition. "Customer lifetime value" has at least four in common use, differing on whether
to discount, whether to include acquisition cost, whether to cap the horizon, and whether
to net out margin. Retention rate can be computed on customers or on revenue. NPS is
reported without an interval almost universally, despite being a difference of proportions.
Attribution has no agreed answer at all.

The consequence is that marketing libraries routinely document one formula and implement
another, and nothing catches it. A library where every documented example is executed and
its claimed output verified is making a much stronger promise in this domain than anywhere
else in BusinessMath.

### The limitation §3 exposes

`sampleSize` is the counter-example, and it should be stated plainly rather than glossed.
Its doc comment is wrong about what the function does, and **the checkers did not catch
it** — because it has no executable example with a claimed value. The checkers verify that
examples produce what they claim; they cannot verify that a prose summary describes the
formula beneath it.

Two consequences for the Marketing module:

1. **Every public function ships with an executable example carrying a checked numeric
   result.** Not optional, not "where it makes sense." A function with prose and no example
   is unverified regardless of how carefully the prose was written.
2. **Every contested primitive names its definition in the first line of its
   documentation** — which CLV convention, which retention basis, which attribution model.
   The checker then proves the documentation and the code agree.

That turns a general-purpose tool into a domain-specific correctness claim, which is
exactly the argument for putting marketing in this library rather than another one.

---

## 8. Consequence for the v3.0.0 Scope

`upcoming/v3.0.0_SCOPE.md` currently has one spine: determinism across every GPU path,
forced by `optimizeDetailed` → `throws`. That is a correctness release. It is necessary,
and on its own it is a hard release to announce — the headline is that a return type
changed.

Adding the Marketing leg gives 3.0.0 a second spine and a much better story:

> **BusinessMath 3.0 — the fourth leg, and answers the library has earned.**
> Marketing analytics as a first-class discipline: response modelling, segmentation, lift,
> retention, network influence. And every path that consumes randomness now either honours
> its seed or says it could not.

The two halves share a theme, which is why they belong in one release rather than two.
The GPU work exists because a path that fails silently and returns a plausible answer is
worse than one that stops. §9 of the network proposal exists for the same reason —
eigenvector centrality that localises returns an artifact shaped like a ranking. §3 of this
proposal is a third instance, already shipped: a sample-size function that returns a
confident number four times too small.

**The release theme is the library declining to answer where it cannot answer honestly.**
Marketing is where that promise is worth the most, because it is the domain where the
formulas are most contested and where a wrong number is most likely to be acted on
immediately.

---

## 9. Open Questions

1. **Does Tier 0 fit in 3.0.0?** Logistic regression, classifier evaluation, and
   Kaplan-Meier are real work — but §2 argues the leg is decorative without them. If only
   part of the marketing scope ships, this is the part.
2. **Where does the Marketing module sit?** A new `Marketing/` top-level area, or
   distributed by technique — logistic regression into `Statistics/Regression/`, survival
   alongside the existing hazard code? The Operations precedent argues for a named area;
   the risk is a module that is a thin wrapper over primitives living elsewhere. A likely
   answer: techniques live where they belong, `Marketing/` holds the marketing-shaped
   surfaces over them.
3. **Attribution is being scoped separately.** It is the most-requested marketing analytic
   and the largest single piece, and whether it lands in 3.0 or after depends on what that
   scope turns up.
4. **Should pricing move up a tier?** It is the highest-leverage of the four Ps and the
   natural bridge to the finance leg, which argues for Tier 1 rather than Tier 3.
5. **How much does `NetworkAnalysis` change if it is framed as marketing-first?** The
   proposal as written is domain-neutral. Marketing framing would put the bipartite
   projection and association rules at the centre and the centrality suite at the edge —
   which is also, per §4, where the evidence says the value actually is.
