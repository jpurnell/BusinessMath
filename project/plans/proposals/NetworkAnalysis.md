# Design Proposal: Network Analysis Module

**Author:** Justin Purnell + Claude
**Date:** 2026-08-22
**Status:** Draft — for review
**Master Plan Reference:** Extends BusinessMath into relational data — the structure *between* entities rather than the properties of one

---

## 1. Objective

### Problem Statement

BusinessMath models entities and their attributes: a portfolio, a cohort, a
balance sheet, a distribution. It has no way to model the **relationships
between** entities — which customers introduce other customers, which accounts
transact with the same counterparties, which suppliers a business cannot route
around, which people in an organisation hold it together.

That is a whole class of business question the library currently cannot answer,
and the gap is visible from inside: `KMeansClustering` already lives in
`Optimization/Heuristic`, so grouping entities by similarity is in scope. What is
absent is grouping them by **connection**.

A downstream project, ClassGraph, has spent this cycle building exactly this
substrate — a weighted co-membership graph over 1,121 people, seven centrality
measures, Louvain community detection, k-core decomposition, and a composite
ranking across measures — because BusinessMath offered nothing to build on. That
work is now validated against a real outcome and should not stay in one
consumer's private module.

### Goals

1. Provide textbook-correct, generic graph algorithms with the same rigour the
   library applies to statistics.
2. Frame them as **business analysis**, not graph theory: what the algorithm
   finds, not what it is called in the literature.
3. Ship the verification apparatus alongside — reference graphs with published
   expected values, and independent brute-force implementations checking the
   fast ones.
4. Compose with what already exists: `kendallW` and `concordanceAnalysis` are the
   natural partners for comparing two rankings of the same entities.

### Non-Goals

- Graph *storage*. `SwiftGraphStore` already binds an embedded graph engine; this
  module operates on in-memory adjacency and does not compete with it.
- Visualisation and layout.
- Graph databases, query languages, or persistence of any kind.

---

## 2. Proposed Architecture

A new top-level `Network/` area under `Sources/BusinessMath/`, in four parts.

```
Network/
├── Graph/
│   ├── WeightedGraph.swift          the substrate: nodes, weighted edges, index
│   └── GraphBuilder.swift           construction from pairs, matrices, bipartite projection
├── Centrality/
│   ├── Degree.swift                 weighted degree, strength
│   ├── Eigenvector.swift            power iteration, with localisation detection
│   ├── PageRank.swift               damped random walk
│   ├── Betweenness.swift            Brandes
│   └── Proximity.swift              closeness, harmonic
├── Community/
│   ├── Louvain.swift                modularity maximisation
│   ├── Modularity.swift             scoring a given partition
│   ├── KCore.swift                  peeling decomposition
│   └── Components.swift             connected components
└── Ranking/
    ├── CompositeRanking.swift       combining several measures by position
    └── SmallGroupFloor.swift        size-aware weight adjustment
```

### Why this shape

**The substrate is separate from the algorithms.** `WeightedGraph` is a value
type holding an edge list and a node index; every algorithm is a pure function
of it. Nothing mutates, nothing caches, and a graph can be built once and
measured many ways.

**Centrality and community are siblings, not a hierarchy.** They answer different
questions — *who matters* versus *what are the groups* — and consumers routinely
need both.

**Ranking is its own concern.** Combining several measures into one ordering is a
general problem (portfolio screens, vendor scorecards, credit models all do it),
and it belongs beside `kendallW` rather than buried inside centrality.

---

## 3. API Surface

### Construction

```swift
public struct WeightedGraph<T: Real>: Sendable {
    public init(edges: [(String, String, T)], isolatedNodes: [String] = [])

    /// Projects a two-mode graph — entities connected through shared groups —
    /// into a one-mode graph of entity-to-entity ties.
    ///
    /// The common business shape: customers sharing a product, accounts sharing
    /// a counterparty, employees sharing a project.
    public static func projecting(
        memberships: [String: Set<String>],
        weighting: GroupWeighting<T> = .inverseSize
    ) -> WeightedGraph<T>
}
```

### Centrality — named for what it finds

Each function keeps its literature name as the canonical spelling, with a
business-framed alias where one reads more clearly at a call site.

| Function | Answers |
|---|---|
| `degreeCentrality(_:)` | How many connections, weighted by strength |
| `eigenvectorCentrality(_:)` | Who is connected to well-connected others |
| `pageRank(_:damping:)` | Who a random walk through the network keeps returning to |
| `betweennessCentrality(_:)` | **Who sits on the paths between others** — single points of failure, brokers, chokepoints |
| `closenessCentrality(_:)` | Who can reach everyone else quickly |
| `harmonicCentrality(_:)` | Closeness that survives a disconnected graph |
| `clusteringCoefficient(_:)` | How tightly a node's neighbours connect to each other |

### Community

```swift
public func louvainCommunities<T: Real>(_ g: WeightedGraph<T>, resolution: T) -> Partition
public func modularity<T: Real>(_ g: WeightedGraph<T>, partition: Partition) -> T
public func kCoreDecomposition<T: Real>(_ g: WeightedGraph<T>) -> [String: Int]
public func connectedComponents<T: Real>(_ g: WeightedGraph<T>) -> [String: Int]
```

### Ranking

```swift
/// Combines several measures into one ordering by summed position.
///
/// Positions, not scores: PageRank sums to one across the graph so no figure
/// exceeds a fraction of a percent, normalised betweenness tops out near 0.01,
/// and degree is a count in the tens. Adding the raw values lets whichever
/// measure has the largest numbers decide the answer entirely.
public func compositeRanking<T: Real>(_ measures: [String: [String: T]], limit: Int) -> [CompositeRank]
```

This pairs directly with the existing `concordanceAnalysis(_:)` — two rankings of
the same entities are two judges, and Kendall's W is the correct measure of
whether they agree.

---

## 4. MCP Schema

Business-framed tool names for the MCP surface, where the literature name is a
poor search term for the person who needs the answer:

| Tool | Wraps | Business question |
|---|---|---|
| `find_network_chokepoints` | betweenness | Which suppliers, staff, or systems cannot be routed around? |
| `detect_related_clusters` | Louvain | Which accounts or entities form connected groups? |
| `rank_network_influence` | PageRank + composite | Who should be engaged first to reach the most people? |
| `measure_network_cohesion` | k-core + components | How fragmented is this network, and who is peripheral? |
| `project_shared_membership` | bipartite projection | Turn a customer-product or account-counterparty table into a network |

Each returns the underlying measure alongside the framing, so a caller can audit
the number rather than trust the label.

---

## 5. Constraints & Compliance

| Rule | Application |
|---|---|
| `<T: Real>` generics | **The main porting cost.** ClassGraph's implementations are concrete `Double`. Betweenness and eigenvector are the risky conversions. |
| 3-operator-per-expression | Brandes' accumulation step and the Louvain modularity delta both exceed this today and must be decomposed. |
| Division safety | Every normalisation divides by node count, edge weight totals, or `(n-1)`. Each needs a guard. |
| No force unwraps | Adjacency lookups currently use `[]` subscripting with implicit assumptions about index validity. |
| Swift 6 strict concurrency | `WeightedGraph` is a `Sendable` value type; all algorithms are pure functions. No shared state. |
| **Fail-silent principle** | See §9. This is the constraint that matters most here, and the one with hard-won evidence behind it. |

### Determinism

Louvain iterates over a dictionary, and Swift seeds its hasher per process — so
the same graph produced different partitions on different runs until ClassGraph
pinned the iteration order. Any port must sort node traversal explicitly. The
library already depends on `SwiftDeterminism`; this is exactly its remit.

---

## 6. Dependencies

None beyond what the package already has. `Numerics` supplies `Real`;
`Collections` supplies the ordered structures Brandes needs. No new external
dependency.

---

## 7. Test Strategy

This is the part that differentiates the module, and it comes across intact from
ClassGraph.

### Reference graphs with published expected values

Two graphs whose centrality values are established in the literature:

- **Krackhardt's kite** — the canonical demonstration that degree, betweenness,
  and closeness identify *three different people* as most central. Every measure
  has a known answer.
- **Zachary's karate club** — 34 nodes, the standard benchmark for community
  detection, with a known ground-truth split.

Expected values are pinned as test constants. A refactor that changes a number
is a decision, not a drift.

### Independent implementations

Every fast algorithm is checked against a naive one that is obviously correct:

| Fast | Checked against |
|---|---|
| Brandes betweenness | O(n³) all-pairs shortest-path enumeration |
| Power-iteration eigenvector | dense matrix multiplication to convergence |
| k-core peeling | repeated filtering until stable |

The naive implementations ship in the test target, not the library. On a
1,121-node graph the enumeration takes minutes and the fast path takes
milliseconds — which is the point, and also why both must exist.

### Property tests

- Centrality is invariant under node relabelling.
- Modularity of the trivial partition (everything in one community) is zero.
- Betweenness of a leaf node is zero.
- Louvain is deterministic across processes on the same input.

---

## 8. Architecture Decision Review

### ADR candidate: graph algorithms belong in BusinessMath

**Considered and rejected: a separate `SwiftNetworkAnalysis` package.**

The argument for separation is that network analysis is a distinct discipline
from financial mathematics. The argument against is stronger on three counts:

1. **Clustering is already here.** `KMeansClustering` groups entities by
   attribute similarity. Community detection groups them by connection. Splitting
   those into different packages would be an arbitrary line through one problem.
2. **The composition is the value.** `compositeRanking` needs `kendallW`.
   Validating a network measure against an outcome needs `correlationCoefficient`
   and `concordancePermutationTest`. Across a package boundary these become
   someone else's integration problem.
3. **Five projects already depend on BusinessMath.** A sixth package is a sixth
   version to resolve.

---

## 9. Adversarial Review

### The strongest objection: the sophisticated algorithms may not earn their place

ClassGraph validated its graph against a real outcome — 2,696 reunion
attendances across 21 years, recovered from a hand-signed book — and the result
should temper any marketing of the centrality suite.

| Predictor | Correlation with attendance |
|---|---|
| Raw affiliation count, no graph at all | −0.138 |
| **Degree on the weighted graph** | **−0.246** |
| PageRank | −0.250 |
| Betweenness | −0.233 |

**The graph roughly doubles the predictive power of counting. The choice of
centrality algorithm contributes almost nothing.** Degree matches PageRank to
within noise.

That is not an argument against shipping the algorithms — different measures
answer different questions, and betweenness finds brokers that degree cannot see.
It is an argument against selling them as where the accuracy comes from. **The
value is in the weighting and thresholding that build the graph**, which is why
`GroupWeighting` and the bipartite projection are part of this proposal rather
than an afterthought.

### The second objection: confident wrong answers

The same downstream project spent this cycle discovering, repeatedly, that a
matching routine which reports certainty without earning it is worse than one
that fails loudly. A unique-surname match against a closed roster returned the
*wrong person*, flagged `certain`, from a single misread letter — nine times
before a human caught them.

BusinessMath's stated fail-silent principle — *never return plausible-but-wrong
results* — applies directly to two places in this module:

- **Eigenvector centrality localises.** On a graph with one dense cluster, power
  iteration concentrates nearly all weight on that cluster and returns values
  that look like a ranking but are an artifact. ClassGraph detects this and says
  so; the port must keep that, not silently return the numbers.
- **Betweenness on a disconnected graph** is computed within components and is
  not comparable across them. Returning one merged ranking implies a comparison
  that does not exist.

Both should return a result type that carries the caveat, not a bare dictionary.

---

## 10. Open Questions

1. **How much of the generic conversion is safe?** Betweenness accumulates over
   shortest-path counts; those are naturally integers, and forcing them through
   `T: Real` may cost precision and compile time both. Possibly `BinaryInteger`
   internally with `T` only at the boundary.
2. **Does `SmallGroupFloor` generalise?** It adjusts a tie weight by group size
   using `1/(n−1)`. In ClassGraph it is defensible; whether it is a *general*
   correction or a Princeton-specific one is untested elsewhere.
3. **Should `GroupWeighting` ship all six schemes?** ClassGraph implements
   uniform, Newman `1/(n−1)`, inverse-size, log-damped, capped, and per-category.
   Most consumers will want two.

---

## 11. Documentation Strategy

DocC for every public symbol, per the library standard. Two additions specific to
this module:

- **An article per business question**, not per algorithm — *Finding single
  points of failure in a supply chain*, *Detecting related-party clusters* — each
  showing the projection from a flat table through to the ranked answer.
- **The Krackhardt kite as a worked example** in the module's landing page. It is
  the clearest possible demonstration that "most central" is three different
  people depending on the question, and it inoculates a reader against picking a
  measure at random.

---

## Implementation Plan

Each phase is independently shippable and independently revertible.

| Phase | Content | Gate |
|---|---|---|
| 1 | `WeightedGraph`, construction, bipartite projection | Reference graphs load; structure assertions pass |
| 2 | Degree, PageRank, eigenvector + localisation detection | Kite values pinned; eigenvector cross-checked against dense matrix |
| 3 | Betweenness (Brandes) | Cross-checked against O(n³) enumeration on both reference graphs |
| 4 | Closeness, harmonic, clustering coefficient | Kite values pinned |
| 5 | Louvain, modularity, k-core, components | Karate club split recovered; determinism test across processes |
| 6 | `compositeRanking`, `SmallGroupFloor` | Composition test against `kendallW` |
| 7 | MCP tool surface | Schema tests |

**Phase 1 and the reference-graph fixtures come first regardless**, because
every later phase is verified against them.

---

## Coda: four smaller gaps from the same work

Not part of this proposal, but surfaced by the same project and worth their own:

- **Decile / quintile lift analysis.** Sort by a predictor, bucket, compare each
  bucket's rate to the base rate. It is the standard CRM and credit-scoring
  analytic, it is how every validation in ClassGraph was expressed, and it is
  absent.
- **Concentration measures — Gini, Lorenz.** 437 of 828 classmates attended once
  or twice; four attended twenty times. Revenue concentration, customer value,
  and inventory movement all have that shape.
- **Point-biserial correlation.** A continuous predictor against a binary
  outcome. `correlationCoefficient` computes it correctly but does not name it,
  so nobody looking for it will find it.
- **Cohort retention curves.** Attendance by years-since-graduation is a
  retention curve. So is subscriber churn and repeat purchase.
