# Design Proposal: Weighted graphs and graph metrics in `Network/`

**Status:** Approved by the owner 2026-11-12; step 1 in progress.
**Owner decisions already given (2026-11-12):** the licence question is settled (the code moves under
BusinessMath's AGPLv3 / commercial dual licence); ClassGraph accepts a dependency on the full
BusinessMath package; the weighted graph is added beside `Graph`, not in place of it; the eigenvector and
Louvain fixes are done first and separately (section 6, step 0).
**Master Plan Reference:** `project/plans/completed/marketing/NetworkAnalysis.md`, section 8 ("graph algorithms
belong in BusinessMath"; a separate `SwiftNetworkAnalysis` package was considered and rejected) and its
promised-but-unshipped `WeightedGraph` and validation oracles.

## 1. Objective

Give `Network/` the weighted, undirected graph and the graph measures that currently live in a separate,
MIT-licensed package (SwiftGraphMetrics, "SGM", used by the ClassGraph app), then retire that package.
Concretely: a validated `WeightedGraph`, weighted and unweighted-equivalent centrality and community measures,
Burt's constraint, diffusion and seed selection, p-median siting, and the metric protocol/registry/record layer
that makes a result reproducible after the code has moved on.

## 2. Motivation

**Current situation.** `Network/` (1,416 source lines, 46 tests) has a directed, unweighted `Graph` and one
implementation of degree, eigenvector, PageRank, betweenness, harmonic closeness, modularity and Louvain.
A weighted co-membership graph (people connected by how many affiliations they share) cannot be represented
without discarding the strength of each tie. The ClassGraph app therefore carries its own package, which
duplicates part of `Network/` and adds a good deal that `Network/` lacks.

**The duplication was a mistake.** `shared_packages.md` and the NetworkAnalysis plan both say to extend
BusinessMath. SGM was designed without checking, and a comparison against this repository on 2026-11-12
(`scratchpad/upstream/comparison.md`, summarised in section 12) found:

- On unweighted undirected graphs the overlapping measures agree to all printed digits (degree, PageRank,
  betweenness, harmonic closeness, modularity, Louvain partitions) on every graph tried.
- **`eigenvectorCentrality` is wrong on every bipartite graph** (trees, stars, paths, even cycles). Path a-b-c
  returns (0.577, 0.577, 0.577) where the L2 truth is (0.5, 0.707, 0.5); a 3-leaf star returns all 0.5 where the
  truth is hub 0.707, leaf 0.408. Plain power iteration oscillates because -lambda ties +lambda in modulus, and
  the function returns the last iterate with no signal. Its tests use one non-bipartite fixture and would not
  catch it. SGM found and fixed the same defect independently (ADR-006 there).
- `louvainCommunities` documents contracting communities between passes (`Community.swift:76-80`) but never
  does (`:124-149`).
- SGM has no counterpart in `Network/` for: weights and weight validation; classic closeness, clustering,
  k-core, undirected components; multi-level weighted Louvain with a resolution; Burt's constraint; diffusion
  models, spread estimation and seed selection (about 1,035 source lines, 1,930 test lines); p-median siting;
  the metric protocol layer; convergence reporting.

**Workaround today.** Depend on two packages, and on SGM's duplicate of the measures BusinessMath already has.
**Drawback.** Two implementations to keep correct, one of which is MIT and unreviewed by this repository's gate.

## 3. Proposed Architecture

**Module placement:** `Sources/BusinessMath/Network/`, additive. `Graph`, `Traversal`, `Markov`, `Projection`
and the existing algorithm extensions are not modified by this proposal (the two bug fixes in section 6 step 0
are the exception and ship first, separately).

**New files** (names follow SGM's so stored results and call sites carry over; collisions are checked in step 1):

```
Network/Weighted/WeightedGraph.swift        // undirected, weighted, validated; GraphError
Network/Weighted/GraphBridges.swift         // Graph <-> WeightedGraph
Network/Weighted/Centrality.swift           // degree, eigenvector (+convergence), PageRank, betweenness,
                                            // closeness (Wasserman-Faust), harmonic, clustering
Network/Weighted/Community.swift            // modularity, multi-level Louvain (resolution), k-core, components
Network/Weighted/BurtConstraint.swift       // Brokerage.constraint
Network/Metrics/                            // MetricValue, GraphMetric, AnyGraphMetric, MetricRegistry,
                                            // MetricDescriptor, MetricRecord, MetricEnvelope/JSONValue,
                                            // NodeScores, NodePartition, NodeSelection, ConvergenceReport,
                                            // DiagnosedScores, ConvergenceNote, StandardMetrics
Network/Diffusion/                          // DiffusionModel, IndependentCascade, LinearThreshold,
                                            // DiffusionGraph, TrialRandomness, SpreadEstimator, SeedSelector
Network/Siting/                             // SiteProblem, PMedian, SiteAssignment, SiteSelector
Tests/BusinessMathTests/Network Tests/Weighted/ ...   // SGM's suites, ported with the code
Tests/TestSupport/ ...                      // independent implementations and reference graphs (test target, not library)
```

**Where SGM departs from BusinessMath convention, and the decision:**
- SGM ships `ReferenceGraphs` and `IndependentImplementations` in its library target. BusinessMath puts test
  support in `Tests/TestSupport`. They move there, as test-only code.
- SGM's `WeightedGraph<Node>` is generic over `Node` with `Double` weights. The NetworkAnalysis plan expected
  `WeightedGraph<T: Real>`. Keeping `Double` preserves stored-record reproducibility bit for bit; a `Real`
  generalisation later would be source-breaking and is recorded as a known trade-off in the ADR.

## 4. API Surface

```swift
public struct WeightedGraph<Node: Hashable & Comparable & Sendable>: Sendable {
    public init(edges: [(Node, Node, Double)], isolatedNodes: [Node] = []) throws   // GraphError on NaN/inf/negative/overflow
    public init(unweightedEdges: [(Node, Node)], isolatedNodes: [Node] = [])         // weight 1, cannot throw
    public init(_ graph: Graph<Node>)                                                // symmetrise; weight 1
    public let nodes: [Node]; public let nodeCount: Int; public let edgeCount: Int; public let totalWeight: Double
    public func weightedDegree(_ index: Int) -> Double
}
public enum GraphError: Error, Equatable { case invalidWeight(from: String, to: String, weight: Double); case weightSumOverflow }

public enum Centrality { static func degree / eigenvector / eigenvectorConvergence / pageRank / betweenness / closeness / harmonic / clustering }
public enum Community  { static func modularity / louvain(resolution:maxPasses:) / kCore / connectedComponents }
public enum Brokerage  { static func constraint(_:) -> [Node: Double] }

public protocol MetricValue: Sendable, Codable { static var kind: String { get } }
public protocol GraphMetric: Sendable { associatedtype Node: ...&Codable; associatedtype Output: MetricValue
    static var descriptor: MetricDescriptor { get }; func compute(on: WeightedGraph<Node>) throws -> Output }
public struct MetricRegistry<Node> { public static var standard: MetricRegistry<Node>; public func record(...) -> MetricRecord<Context> }
```

(The full public surface is SGM's, listed in `SGM: Sources/SwiftGraphMetrics`. It is not redesigned here.)

**Naming collision check.** The type names `Centrality`, `Community`, `Brokerage`, `NodeScores`, `MetricRegistry` are
generic in a single flat module. **None of the 19 type names collides today** (`Centrality`, `Community`, `Brokerage`,
`NodeScores`, `NodePartition`, `NodeSelection`, `MetricRegistry`, `MetricRecord`, `MetricEnvelope`, `MetricValue`,
`GraphMetric`, `ConvergenceReport`, `DiffusionModel`, `SeedSelector`, `PMedian`, `SiteProblem`, `WeightedGraph`,
`GraphError`, `JSONValue`, `MetricDescriptor`: grep for struct/enum/class/protocol/actor/typealias declarations
over `Sources/`, 2026-11-12). If one does at
implementation time, the fallback is a caseless namespace (`Network.Centrality`), decided in the ADR, not ad hoc.

## 5. MCP Schema

BusinessMath is consumed by AI tools through `businessMathMCP`. The new API is exposed as three tools. All are
deterministic given a seed.

**Tool `network_centrality`** — score the nodes of a weighted undirected graph.
```json
{
  "edges": [["a", "b", 1.0], ["b", "c", 1.0]],
  "isolated_nodes": ["x"],
  "metric": "eigenvector-centrality",
  "options": {"max_iterations": 200, "tolerance": 1e-10}
}
```
- `edges` (array of `[string, string, number]`): endpoints and a finite, non-negative weight. Invalid weights are
  an error, not a coercion.
- `metric` (string, enum): `degree`, `eigenvector-centrality`, `pagerank`, `betweenness-centrality`,
  `closeness-centrality`, `harmonic-centrality`, `clustering`, `k-core`, `louvain`, `components`, `burt-constraint`.
- Result carries `kind`, `payload`, the metric `identifier` and `version`, and for iterative metrics a
  `convergence` object (`converged`, `iterations`, `residual`, `tolerance`, `max_iterations`).

**Tool `network_seed_selection`** — choose seeds to maximise expected spread (exploratory).
```json
{"edges": [["a","b",1.0]], "model": "independent-cascade", "probability": 0.05,
 "budget": 3, "trials": 400, "seed": 2000}
```
`model`: `independent-cascade` | `linear-threshold`. `seed` (integer) is required; the same seed gives the same picks.

**Tool `network_site_selection`** — p-median over weighted demand.
```json
{"demand": {"East": 287, "West": 218}, "sites": ["New York", "Chicago"],
 "costs": {"East": {"New York": 1.0, "Chicago": 5.5}, "West": {"New York": 9.0, "Chicago": 7.0}}, "count": 1}
```

## 6. Constraints & Compliance

- **Fail-silent principle.** SGM returns the last iterate silently in two places the BusinessMath standard
  forbids: PageRank at its ceiling, and an out-of-range damping, which it clamps. SGM also does not validate a
  partition given to `modularity`, and does not refuse an eigenvector on a disconnected graph. These are ported
  as they are in step 4 (stored records must not move) and **closed in step 5 by explicit metric-version bumps**,
  each with its own test and ADR note. They are not folded silently into the move.
- **Concurrency:** all value types are `Sendable`; `SeedSelector.computeAsync` uses structured concurrency.
- **Determinism:** randomness only through `SwiftDeterminism.SplitMix64`, already a dependency; seeds are explicit.
- **Safety:** no force unwraps; guard clauses; division guards; NaN-closed validation (`WeightedGraph` rejects
  non-finite and negative weights at construction, which is the contaminated-input rule applied at the boundary).
- **Generic type-check budget:** BusinessMath's CI runs Swift 6.2.1 on Linux and times out on generic arithmetic
  that 6.4 solves instantly. SGM code is Double-based and mostly non-generic in the arithmetic; it is swept for
  the three-operator rule and every test expression is checked against the `#expect` budget before the port is
  called done. A green local build is not evidence; CI is.
- **Metric records are a stored-format contract.** Metric identifiers, versions and the `Codable` shape of every
  value (`kind`, payload keys) are preserved exactly, and a golden test pins them (section 10).

## 7. Source & API Compatibility

**Breaking changes:** none to existing public API from the move itself: it is additive (new files, new types, no
overloads of existing functions). The two fixes in step 0 change results: the eigenvector answer on bipartite
graphs (the old answer was wrong) and, if contraction is implemented, the Louvain partition on some graphs. Both
are stated in the CHANGELOG as answer changes, as alpha.11 did.
**Incremental adoption:** yes. `import BusinessMath` and use `WeightedGraph` independently of `Graph`.
**Type-checking risk:** low for overloads (no existing function is overloaded). The risk that matters is the
Linux type-check budget in section 6.
**For ClassGraph:** it declares five typealiases over the SGM types. After the cutover it declares the same five
over BusinessMath's and `import BusinessMath` in one shim target. It does **not** re-export BusinessMath: that
would put a very large public namespace into every file that imports `ClassGraphMetrics`.

## 8. Backend Abstraction

`SeedSelector` is the only compute-intensive piece (greedy selection with lazy evaluation where sound; a sweep
over probabilities). **CPU only, with batched parallel evaluation through structured concurrency.** No GPU
backend is proposed: the work is irregular graph traversal, not dense arithmetic, and the measured cost at the
size of interest (1,121 nodes) ranged from 0.016 s to 12.6 s depending on the spread probability. Linux is
CPU-only by construction. Note: seed selection under the linear threshold model refreshes every candidate each
round (ADR-005 in SGM) and its cost at this size is not yet measured; the port records that.

## 9. Dependencies

**Internal:** `Network/Graph.swift` (bridges), `Simulation/SplitMix64.swift` / `Determinism` (re-exports
`SwiftDeterminism`), the existing `Statistics` types only if a result type should reuse them (none required).
**External:** none new. `SwiftDeterminism` is already a dependency of BusinessMath.

## 10. Test Strategy

SGM's suites (364 tests, 6,629 lines) move with the code. They were strengthened by a full mutation audit in
November 2026: 461 mutants in the siting/diffusion/Burt files and 653 in the centrality/community files, each
survivor classified equivalent or closed by a test.

**Test categories:** golden path against published values; edge cases (empty, single node, isolates, edgeless,
disconnected); invalid weights; determinism (same seed, same result, any insertion order); property tests
(relabelling invariance, weight-scaling invariance, bounds, Codable round trips, orderings and tie-breaks);
independent implementations (brute-force betweenness, dense-matrix eigenvector, k-core by peeling, exhaustive
modularity optimum over all partitions of 8 nodes, exhaustive p-median).

**Reference truth (independently verifiable, never the code under test):**
- Kite graph and Zachary's karate club published values; hand-computed closed forms for path, star, triangle.
- NetworkX (generated once by `Scripts/reference-fixtures/generate.py` per BusinessMath ADR-004) for
  centrality and Louvain, with the one documented difference that Burt's constraint here ignores zero-weight
  ties (SGM ADR-003) and so differs from `networkx.constraint` on graphs containing them.

**Validation trace (REQUIRED):**
- Path a-b-c, eigenvector, L2-normalised: (0.5, 0.7071, 0.5). The current `Graph` version gives (0.5774, 0.5774,
  0.5774); this is the red test for step 0.
- Star with 3 leaves, eigenvector L2: hub 0.7071, leaf 0.4082.
- Burt's constraint: star centre 1/n, each leaf 1; triangle each 1.125; path ends 1, middle 0.5 (hand-derived from
  `c_i = sum_j (p_ij + sum_q p_iq p_qj)^2`).
- PageRank, path a-b-c, damping 0.85: (0.256757, 0.486486, 0.256757) in both implementations.
- p-median over regional headcounts 287, 186, 65, 123, 79, 96, 218, 65 with the planning cost table: mean cost
  5.2078 / 6.1189 / 5.3852 hours (New York wins) and $301.65 / $368.99 / $300.50 (Philadelphia wins), recomputed
  independently in Python.

**Process note.** The existing SGM tests were written against SGM's code, partly after it. In this proposal they
are ported to BusinessMath first against stubbed signatures so that the red is behavioural, then the code moves.
That is the honest form of red-first for a move of verified code; it is recorded in each phase's summary and is
not claimed to be new design.

**Cross-check test (permanent):** BusinessMath's unweighted `Graph` metrics equal the `WeightedGraph` metrics on
symmetrised unweighted graphs (degree, PageRank, betweenness, harmonic exactly; eigenvector after rescaling;
modularity and Louvain partitions as sets). This was verified by hand on seven graphs in the comparison and
becomes a test so the two implementations cannot drift apart.

**Golden stored-record test:** a fixed set of `MetricRecord`s is encoded by SGM today, committed as JSON, and
decoded and re-encoded byte-for-byte by the ported layer, including a version-3 eigenvector record.

## 11. Architecture Decision Review

- [x] Reviewed `project/decisions/architecture_decisions.md` (ADR-001 to ADR-005) and the NetworkAnalysis plan.
- Supersedes an existing ADR? No.
- Amends an existing ADR? No. NetworkAnalysis section 8 records the "belongs here" decision as a candidate; this
  proposal makes it an ADR.
- **New ADR required: yes. ADR-006: Weighted graphs and graph measures live in `Network/`.**
  - Category: architecture.
  - Key decision: `WeightedGraph` is a new type beside `Graph`; metric identifiers, versions and record shapes are
    preserved from the prior package; behaviour changes that SGM made silently are made explicit by version bumps.
  - Alternatives rejected: modify `Graph` in place; a protocol over both graph types; a separate package.

## 12. Adversarial Review

**Strongest case for a different approach.** Keep a small, dependency-light metrics package for ClassGraph and
let BusinessMath depend on it, rather than moving 3,700 lines into a 140,000-line module whose build ties in
swift-syntax, swift-crypto and Metal excludes. A reviewer would point out that a metrics layer for a CLI does not
need a financial-mathematics library. This might be better for build time and licence separation. It is rejected
here because it recreates the duplication the NetworkAnalysis plan rejected, and because the owner has decided
to accept the full dependency.

**Where this design is most likely wrong.**
- *Reproducibility of stored records across the move.* If any `Codable` output, trial hashing or tie-break changes,
  every stored metric record and seed selection silently differs. Mitigated by the golden-record test and the
  seed-for-seed diffusion test, but the mitigation is only as good as the fixture set.
- *The flat module namespace.* Generic names like `Centrality` and `Community` in one 526-file module may collide
  later even if they do not today.
- *Linux.* Nothing here has been built on Linux. The CI type-check timeout is a known recurring failure and cannot
  be ruled out locally.
- *I measured the overlap on small graphs.* The claim that BusinessMath's single-level Louvain differs from the
  multi-level version on larger graphs is a prediction from reading the code, not a reproduced result.

**What an experienced critic would say.** "You are moving a lot of untested-on-Linux code into a public alpha in
one go." We are proceeding because each phase is its own reviewable change with its own gate, the move is
additive, the stored-record contract is pinned by golden tests, and the two bug fixes land first on their own.

## 13. Alternatives Considered

1. **Add weights and an `isDirected` flag to `Graph`.** One type, but it changes a public struct used by
   `DependencyGraph` and `BipartiteProjection`, and every algorithm's semantics must be re-specified for
   directed, undirected and weighted cases. Too risky for an alpha that has already broken source twice.
2. **A protocol (`GraphProtocol`) that both graph types conform to.** Cleanest long term. Protocol dispatch in
   hot inner loops hurts the index-based performance the weighted code relies on, and it is a larger rewrite.
   Could be revisited once both types exist.
3. **Keep a separate package.** Rejected by the NetworkAnalysis plan and by the owner.
4. **Route the registry to BusinessMath's existing `eigenvectorCentrality` and `pageRank`.** Would silently
   change stored numbers (L2 vs max normalisation, different tolerance and ceiling, `nil` instead of a vector)
   and would carry the bipartite defect. Rejected: the ported loops are reused as they are, and behaviour
   unifies only through explicit version bumps.

## 14. Future Directions

- A `GraphProtocol` over `Graph` and `WeightedGraph` could remove the duplicated algorithms.
- A `WeightedGraph<T: Real>` could generalise the scalar, at the cost of a source break.
- Directed weighted graphs could be added for flow-style measures.
- The metric registry could surface in `businessMathMCP` as a discoverable list of measures.

## 15. Open Questions

1. Keep `Double` weights (reproducibility) or `Real` (the plan's intent)? Recommended: `Double` now.
2. Should the registry live in BusinessMath, given BusinessMath already has MCP and `Diagnostics` surfaces? Recommended: yes, as the
   stored-record contract is the reason the layer exists.
3. ~~Does `Optimization/` already contain a p-median or facility-location routine?~~ **Answered 2026-11-12 by grep over
   `Sources`, `Tests` and `project/plans`:** no. There is no p-median, k-median or location-allocation routine in
   `Sources/`. The integer-programming module (`5.8-IntegerProgramming.md`) has a *Facility Location* worked example
   and a `facility_location` problem type in its diagnostics, so BusinessMath's own branch-and-bound solver can
   express the problem. Consequence: `PMedian` is new and goes in `Network/Siting/`, and its tests gain a second,
   independent oracle: the same instance formulated as an integer program and solved by BusinessMath's solver, in
   addition to SGM's exhaustive enumeration. Whether the siting code should *delegate* to the IP solver instead of
   carrying its own enumeration and swap heuristic is left open: it would cut code but change the heuristic path
   (and the tie-breaking that stored results depend on), so the recommendation is to keep SGM's selector and use
   the solver as a test oracle only.
4. Which release carries this? Additive, so a point alpha; the eigenvector answer change needs its own line in the CHANGELOG.
5. Should ClassGraph's cutover keep SGM as a compatibility facade for one release, or repoint directly and archive SGM?
   Recommended: repoint directly, since SGM has no remote and no other users.

## 16. Documentation Strategy

**Documentation Type:** Narrative Article Required.

**Complexity Threshold Check:**
- Combines 3+ APIs? **Yes** (graph, measures, registry, records, diffusion, siting).
- Explanation requires 50+ lines? **Yes.**
- Needs theory/background context? **Yes** (why eigenvector centrality localises, why PageRank does not, what
  Burt's constraint measures, why seed selection is exploratory).

**Article names:** `NetworkMeasuresGuide.md` (choosing a measure; SGM's "Choosing a metric" guide moves here),
`ReproducibleMetricRecordsGuide.md`, `SeedingAndSitingGuide.md`. None match a Swift symbol name.
Every public symbol carries DocC with a compiling example (the quality gate compiles doc fences).

---

## Phasing (one reviewable change each)

| Step | Change | Gate |
|---|---|---|
| 0 | **Fix `eigenvectorCentrality` (bipartite) and Louvain (contraction or documentation), as their own PR.** Already in progress. | red-first tests on path, star, odd/even cycles, K(2,3); dense reference solver; mutation audit |
| 1 | Collision check; ADR-006; `WeightedGraph`, `GraphError`, bridges; `GraphTests`, `WeightValidationTests` | ported tests green; round trip `Graph` <-> `WeightedGraph` |
| 2 | Port weighted measures with their suites and independent implementations; cross-check test against the unweighted measures | ported suites; cross-check; Linux CI |
| 3 | Port the metric protocol layer; golden stored-record test; keep identifiers and versions | golden JSON byte-identical; v3 eigenvector decode |
| 4 | Make silent behaviours explicit with version bumps: PageRank convergence (see SGM `PageRankConvergence.md`, measure first), modularity partition validation, damping NaN rejection | each its own red test, ADR note |
| 5 | Port diffusion and siting; siting tests add BusinessMath's integer-programming solver as an independent oracle; seed-for-seed golden test | golden seeds and spreads identical; PMedian optimum equals the IP optimum on small instances |
| 6 | ClassGraph cutover (typealiases, `Package.swift`), full ClassGraph suite; archive SGM with a pointer | ClassGraph tests and gate green; stored-record sample identical before and after |
