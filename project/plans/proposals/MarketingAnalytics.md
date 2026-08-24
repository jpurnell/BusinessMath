# Design Proposal: The Marketing Leg

**Author:** Justin Purnell + Claude
**Date:** 2026-08-23
**Status:** Draft — for review
**Relationship to other work:** Frames `proposals/NetworkAnalysis.md` as one part of a
larger gap, and identifies one breaking change that belongs in `upcoming/v3.0.0_SCOPE.md`

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

Checked against the live tree at v2.6.0:

| Primitive | State |
|---|---|
| Lift / gains / decile analysis | **absent** |
| RFM segmentation | **absent** |
| Cohort retention curves | **absent** |
| Concentration — Gini, Lorenz, Pareto | **absent** |
| Market basket — support, confidence, lift | **absent** |
| Multi-touch attribution | **absent** |
| Adstock and saturation curves (MMM) | **absent** |
| Bass diffusion | **absent** — every "diffusion" file is a stochastic process |
| Price elasticity | **absent** — appears once, in a doc comment |
| Uplift / incrementality | **absent** |
| A/B testing | `pValue`, `sampleSize`. No effect size, MDE, or sequential testing. |
| CLV, CAC, retention | Present, but **only as methods on financial-model templates** |
| Behavioural clustering | `KMeansClustering` exists and is directly usable |
| Survival modelling | `distributionWeibull` exists — the standard retention-curve fit |

Two of those are worth noting because they mean the leg is closer than it looks:
**k-means is already here**, and **Weibull is already here**. Segmentation and survival
have their engines; what is missing is the marketing-shaped surface over them.

---

## 2. Where Network Analysis Fits

`proposals/NetworkAnalysis.md` was written as a general-purpose module. Read against this
gap, it supplies **three of the eight areas directly** — and one of them is not an
analogy but the identical primitive.

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

### What network analysis does *not* supply

Five of the eight areas. It is a third of the leg, not the leg.

---

## 3. Proposed Scope

Three tiers, by whether the leg can stand without them.

### Tier 1 — the leg cannot stand without these

Each is small, each is heavily used, and each is currently absent.

**Lift / gains / decile analysis.** Sort a population by a predicted score, bucket into
deciles, compare each bucket's response rate to the base rate. This is the single most
common analytic in direct marketing, CRM, and credit scoring. It is how every validation
in the downstream project was expressed, and it had to be hand-written each time.

```swift
public func liftAnalysis<T: Real>(
    scores: [String: T], responded: Set<String>, buckets: Int = 10
) -> LiftTable<T>
```

**RFM segmentation.** Recency, frequency, monetary value, scored into tiers. The workhorse
of retail and e-commerce segmentation, and the thing a marketer reaches for before k-means.

**Cohort retention curves.** Retention by period since acquisition, with a fitted decay.
`distributionWeibull` already provides the standard survival fit; this is the cohort-shaped
surface over it.

**Concentration — Gini, Lorenz, Pareto.** Customer value, revenue, and product movement are
all heavily skewed, and "what share of revenue comes from the top decile" is a question
with no answer in the library today.

### Tier 2 — supplied by Network Analysis, plus one completion

Everything in `proposals/NetworkAnalysis.md`, plus:

**Association rules** — support, confidence, and lift over the bipartite projection, which
completes market basket analysis.

### Tier 3 — larger, and probably post-3.0

- **Multi-touch attribution** — Markov-chain removal effect, or Shapley over channel sets.
  A real piece of work, and the one marketers ask for most.
- **Marketing mix modelling** — adstock (carryover) and saturation (diminishing returns)
  transforms, feeding the regression that already exists.
- **Bass diffusion** — new-product adoption. Small, well-defined, textbook.
- **Uplift modelling** — treatment effect on the persuadable, not response rate.
- **A/B testing, completed** — effect size, minimum detectable effect, sequential testing
  with alpha spending. What is there now answers "is it significant" but not "is it worth
  shipping" or "can I stop the test."

---

## 4. One Breaking Change, for v3.0.0

**Lift CLV, CAC, and retention out of the model templates.**

```swift
// today — a method on a financial model, taking assumptions
SaaSModel.calculateLTV() -> Double

// proposed — a function over customer data, deriving the answer
public func customerLifetimeValue<T: Real>(
    cohort: [CustomerHistory<T>], discountRate: T, horizon: Int
) -> CLVResult<T>
```

The template methods stay, deprecated, delegating to the new functions where the inputs
allow. That is a breaking change for anyone calling them directly, which is precisely why
it belongs in the 3.0.0 that `upcoming/v3.0.0_SCOPE.md` is already gathering — the break
happens once, alongside the GPU determinism work.

It also fixes the inversion in §1: after this, LTV is something the library *derives* and
the SaaS template *consumes*, rather than a number a financial model asserts.

---

## 5. Why the Documentation Checkers Matter Here Specifically

`doc-code` and `doc-comment-code` execute documented examples and verify they produce the
values they claim. Across the library that is good hygiene. **In marketing analytics it is
a differentiating claim**, for a reason peculiar to the domain.

Marketing formulas are contested in a way financial ones are not. Black-Scholes has one
definition. "Customer lifetime value" has at least four in common use, differing on whether
to discount, whether to include acquisition cost, whether to cap the horizon, and whether
to net out margin. Retention rate can be computed on customers or on revenue. Attribution
has no agreed answer at all.

The consequence is that marketing libraries routinely document one formula and implement
another, and nothing catches it. A library where **every documented example is executed and
its claimed output verified** is making a much stronger promise in this domain than in any
other part of BusinessMath.

That should be said out loud in the module's landing page, not left implicit. Each
contested primitive should document *which* definition it implements, and the checker
proves the documentation and the code agree.

---

## 6. Consequence for the v3.0.0 Scope

`upcoming/v3.0.0_SCOPE.md` currently has one spine: determinism across every GPU path,
forced by `optimizeDetailed` → `throws`. That is a correctness release. It is necessary,
and on its own it is a hard release to announce — the headline is that a return type
changed.

Adding the Marketing leg gives 3.0.0 a second spine and a much better story:

> **BusinessMath 3.0 — the fourth leg, and answers the library has earned.**
> Marketing analytics as a first-class discipline: segmentation, lift, retention, network
> influence. And every path that consumes randomness now either honours its seed or says
> it could not.

The two halves share a theme, which is why they belong in one release rather than two.
The GPU work exists because a path that fails silently and returns a plausible answer is
worse than one that stops. §9 of the network proposal exists for the same reason —
eigenvector centrality that localises returns an artifact shaped like a ranking, and a
matcher that reports certainty it has not earned is how the downstream project put nine
wrong people into a record before a human caught them.

**The release theme is the library declining to answer where it cannot answer honestly.**
Marketing is where that promise is worth the most, because it is the domain where the
formulas are most contested and the checking is weakest elsewhere.

---

## 7. Open Questions

1. **Is Tier 1 enough to claim the leg?** Lift, RFM, retention, and concentration are four
   small pieces. They cover the questions a marketer asks weekly, but not attribution or
   mix modelling — which are what an agency would ask for first.
2. **Where does the Marketing module sit?** A new `Marketing/` top-level area, or
   distributed into `Statistics/` and `Analysis/` by technique? The Operations precedent
   argues for a named area; the risk is a module that is a thin wrapper over primitives
   living elsewhere.
3. **Does attribution belong in 3.0 at all?** It is the most-requested marketing analytic
   and the largest single piece. Shipping the leg without it invites the obvious question;
   shipping it properly is probably its own release.
4. **How much does `NetworkAnalysis` change if it is framed as marketing-first?** The
   proposal as written is domain-neutral. Marketing framing would put the bipartite
   projection and association rules at the centre and the centrality suite at the edge —
   which is also, per §2, where the evidence says the value actually is.
