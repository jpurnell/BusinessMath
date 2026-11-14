# Design Proposal: `Centrality.eigenvectorByComponent` and the `eigenvector-centrality-by-component` metric

**Status:** Proposed 2026-11-14, implemented on `feature/network-eigenvector-by-component` (off `origin/main` ae06466f). Owner approved
the upstreaming ("upstream to BusinessMath"); the design itself is ClassGraph's ADR-015 and is moved here unchanged, so this proposal
records the placement, the stored contract and the parts of the move that could not be identical.
**Master Plan Reference:** `project/plans/upcoming/NetworkWeightedGraph.md` (Network steps 0 to 4 done; this is a step-6 follow-on,
the one ClassGraph's cutover proposal called "recommended, not done"); ADR-006 to ADR-009; new ADR-010.
**Source:** ClassGraph `Sources/ClassGraphMetrics/ComponentwiseEigenvector.swift` at main d38b363, its tests, its ADR-014/ADR-015 and
`project/summaries/2026-11-14_businessmath_cutover/` (read only).

## 1. Objective

Give `Network/Weighted` an eigenvector centrality that is defined on a graph that is not connected, so that a caller with isolates and
many small components (the class graph) is not left with `eigenvector-centrality` 5's refusal and no alternative. Move ClassGraph's
component-wise implementation here so ClassGraph can later delete its copy and keep reading its own stored
`eigenvector-centrality-by-component` version 1 records byte for byte.

## 2. Motivation

`Centrality.eigenvector` refuses a disconnected graph (ADR-009 item 5), correctly: the leading eigenvector lives on one component and
everything else decays toward zero, which reads as "unimportant" rather than "not comparable". The refusal's own documentation points
callers at "score the components separately", which every caller must then write, including the cross-component scale, which is a
convention and the easiest part to get wrong. ClassGraph wrote it (ADR-015) against BusinessMath's public API and asked for it to be
upstreamed once the convention had survived real use.

## 3. Proposed Architecture

**New files**
- `Sources/BusinessMath/Network/Weighted/EigenvectorByComponent.swift`: `extension Centrality { static func eigenvectorByComponent }`
  beside `eigenvectorConvergence`, and the internal positive-tie component finder.
- `Sources/BusinessMath/Network/Metrics/Values/ComponentwiseScores.swift`: `ComponentScoring`, `ComponentwiseScores` (a `MetricValue`).
- `Sources/BusinessMath/Network/Metrics/ComponentwiseEigenvectorMetric.swift`: the registered metric.

**Modified files:** `MetricRegistry.swift` (`standard` gains the metric), tests that count the standard registry (11 to 12),
`CHANGELOG.md`, the plan's Status, `architecture_decisions.md` (ADR-010).

**Module placement:** `Network/`, the existing module. No new target, no new dependency.

**The convention (unchanged from ClassGraph ADR-015).**
- Components are read through ties of positive weight, as `eigenvectorConvergence` reads connectivity.
- Each component is scored on its own subgraph (positive ties only) by `eigenvectorConvergence`, so the iteration is the one
  implementation of the arithmetic.
- Scale across components: with `s` the per-component scores (largest 1) and `rms = sqrt(mean(s^2))`, a node scores
  `s * min(rms over components) / rms`. The most peaked component keeps its scale, so the largest score is exactly 1.
- A node with no tie of positive weight scores exactly 0 (never the 1 that `eigenvector` gives a one-node graph); they are counted in
  `isolatedCount`, not listed.
- One component and no isolate: the whole graph goes to `eigenvectorConvergence` unchanged, so scores and report are bit-identical to
  `eigenvector-centrality` 5.
- Convergence: the aggregate is the worst case (converged only if every component did; most passes; largest residual); `components`
  holds one entry per component of two or more nodes, in order of its lowest node, with its own report and the scale applied.

## 4. API Surface

```swift
extension Centrality {
	public static func eigenvectorByComponent<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, maxIterations: Int = 200, tolerance: Double = 1e-10
	) throws -> ComponentwiseScores<Node>
}
public struct ComponentScoring<Node>: Sendable, Hashable { anchor, size, convergence, scale }          // Codable where Node: Codable
public struct ComponentwiseScores<Node>: Sendable, Hashable { scores, convergence, components, isolatedCount, unconverged, diagnosed }
public struct ComponentwiseEigenvectorMetric<Node>: GraphMetric                                         // output ComponentwiseScores
```

**Deviation from the task wording, and why.** The brief says "returning `DiagnosedScores` with a per-component convergence detail".
`DiagnosedScores` has two keys (`scores`, `convergence`) and ClassGraph's stored payload has four (`scores`, `convergence`,
`components`, `isolatedCount`), so a `DiagnosedScores` cannot carry what ClassGraph reads back, and widening `DiagnosedScores` would
change a stored shape that eigenvector 4/5 and pagerank 3 already use. So the function returns `ComponentwiseScores`, which holds the
same two fields plus the detail, encodes with ClassGraph's four keys, and has a `diagnosed` property giving the plain
`DiagnosedScores` view. The names `ComponentScoring`, `ComponentwiseScores` and `ComponentwiseEigenvectorMetric` are ClassGraph's, so
its later cutover is a deletion, not a rename.

## 5. MCP Schema

N/A for this change. No MCP tool is added; the metric reaches `businessMathMCP` only through the registry listing
(plan section 14), which is unchanged in kind.

## 6. Constraints & Compliance

**Concurrency:** all new types are immutable `Sendable` value types. **Determinism:** no randomness; components and members are
ordered by node order, the registry is keyed by identifier, so the result does not depend on hash seed (tested over repeated
processes). **Generics:** `Double` throughout, as the neighbouring weighted code (`WeightedGraph` weights are `Double`; plan open
question 1 settled that). **Safety:** no force unwrap; iteration bounded by the ceiling per component.

**How it signals errors.** Reuses `GraphMeasureError`, adds no case. `eigenvectorByComponent` is `throws` because it calls
`eigenvectorConvergence` and builds subgraphs with `WeightedGraph(edges:)`, both of which are declared `throws`; it throws only what
they throw. `GraphMeasureError.disconnectedGraph` is unreachable from it (a component is connected by construction), and a graph in
pieces is the case it exists to answer, so nothing about disconnection is an error here. Bad weights are refused when the graph is
built (`GraphError`), before this runs. `maxIterations` below 1 is run as 1 and reported as 1, `tolerance` is taken as given: the
idiom of `eigenvectorConvergence`. Silent edges, recorded rather than hidden: see section 16 (an overflowing weight scale).

## 7. Source & API Compatibility

**Breaking changes:** none. New API; no existing function changes; `eigenvector-centrality` stays version 5 and still refuses a
disconnected graph. `MetricRegistry.standard` gains a twelfth entry: a caller that counts `standard.available` sees 12 (the three
tests that did are updated); `registering(_:)` keeps the first of two metrics with the same identifier, so ClassGraph's
`standard.registering(ClassGraphMetric)` keeps working while both exist. **Name collision for ClassGraph:** while ClassGraph keeps its
own `ComponentwiseScores`, `ComponentScoring` and `ComponentwiseEigenvectorMetric`, a file that imports BusinessMath whole and
ClassGraphMetrics sees two of each; the cutover removes its copy. **Type-checking risk:** no overload of an existing function.

## 8. Backend Abstraction

N/A: CPU, O(n + m) per pass per component; no backend.

## 9. Resource Budget

N/A: pure computation over a graph the caller already holds. Allocates O(n + m) scratch: one subgraph per component (every positive
tie copied once) and one score array per component, all released on return.

## 10. Dependencies

Internal: `Centrality.eigenvectorConvergence`, `WeightedGraph` (`nodes`, `nodeCount`, `adjacency`, `init(edges:)`), `NodeScores`,
`ConvergenceReport`, `MetricValue`, `GraphMetric`, `MetricRegistry`. External: none.

## 11. Test Strategy

**Reference truth.** Closed forms, derived by hand: a path a-b-c has leading eigenvector (1, sqrt 2, 1)/2, so scores (0.7071, 1, 0.7071);
a three-leaf star (sqrt 3, 1, 1, 1)/sqrt 6, so (1, 0.5774, 0.5774, 0.5774); `rms(path) = sqrt(2/3)`, `rms(pair) = 1`,
`rms(star) = sqrt(1/2)`. These are ClassGraph's own validation traces, ported.
**Parity with ClassGraph (the contract).** Constants generated by a scratch program outside both repositories that compiles a copy of
ClassGraph's `ComponentwiseEigenvector.swift` against BusinessMath ae06466f's Network sources, over synthetic graphs (connected,
several components with and without isolates, zero-weight ties, edgeless, lone, empty, a low ceiling, a custom tolerance): the encoded
`MetricEnvelope` (sorted keys) and the descriptor, committed as string constants. The new code must reproduce each byte for byte.
**Other categories:** value tests; one-component bit-identity with `eigenvectorConvergence` on karate, the kite, a path, a star and
two weighted graphs; trivial graphs (empty, lone, edgeless, zero-weight ties); convergence aggregation; the stored shape
(keys, round trip, envelope read as `NodeScores`, `envelope.convergence` is the aggregate); the registry; determinism and
property tests over random multi-component graphs (SwiftDeterminism's `SplitMix64`); a golden test run in 10+ separate processes.
Hand-written mutation audit (50+ mutants) in a scratch package outside the repository.
**Linux:** not runnable locally; the budget rules for Swift 6.2.1 (three operators per `#expect`, typed intermediates) are followed.

## 12. Architecture Decision Review

- [x] Reviewed `architecture_decisions.md` (ADR-006 to ADR-009).
- [ ] Supersedes an existing ADR: No.
- [x] Amends: ADR-009 item 5 (the refusal now has a defined alternative; the refusal itself is unchanged). Recorded in the new ADR.
- [x] New ADR required: ADR-010, "Component-wise eigenvector centrality is a BusinessMath measure, stored as `eigenvector-centrality-by-component` 1".

## 13. Adversarial Review

**Strongest case for a different approach.** Do not upstream a convention the owner has not yet seen working on real data: a measure
here is a public-API and stored-identifier commitment, and ClassGraph's own plan said to wait. Version 1 of an identifier cannot be
edited, only superseded by 2.
**Where this design is most likely wrong.** The cross-component scale. Mean-square equalisation is defensible and documented as a
convention, but it is the one choice a user may want different; changing it is a version 2, not an edit. Second: the claim in
ClassGraph's mutation notes that its `?? 1` and `rms > 0` guards are unreachable is false for weights large enough to overflow
(section 16), so the code has a silent branch ClassGraph believed it did not.
**What an experienced critic would say.** "You moved an unreviewed convention into a library, with a silent branch." We proceed
because the owner approved the move, the identifier and shape are frozen by a parity test either way, the silent branch is inherited from
`eigenvectorConvergence` (not introduced) and is written down, and the alternative (every caller reimplementing the scale) is worse.

## 14. Alternatives Considered

1. **Widen `DiagnosedScores` with optional `components`/`isolatedCount`.** Rejected: changes a stored shape in use by three metrics and
   its memberwise API; ClassGraph's payload then has no type of its own to decode into.
2. **A `Centrality.eigenvector(_:onDisconnected:)` mode.** Rejected: ADR-009 made the refusal the behaviour of `eigenvector`; a flag
   re-opens it, and the by-component result needs a richer return type than `NodeScores`.
3. **Throw for a graph with a component that cannot be scored (overflow).** Deferred, section 16: a new `GraphMeasureError` case is a
   source break for exhaustive switches (ClassGraph has one), and `eigenvector` itself is silent on the same input.
4. **Leave it in ClassGraph.** The status quo; every other consumer reimplements it.

## 15. Future Directions

- A version 2 with another cross-component convention could register beside version 1.
- `PageRank` is already defined on a disconnected graph; a documentation cross-link could compare the two.
- The weighted-eigenvalue option (ClassGraph's rejected option D) could be offered as a separate measure.

## 16. Open Questions

1. **Overflow.** With weights near 1e200 `eigenvectorConvergence` returns all zeros, reported converged (its own comment says "predates
   ADR-009 and is not addressed"). Here that component then has `rms` 0 and keeps scale 1 silently. Recommended: leave as inherited,
   document, characterise in one test; the fix belongs in `eigenvectorConvergence` (rescale before squaring), a behaviour change that
   needs its own version bump. Owner to decide.
2. ClassGraph's `classGraph` registry and its own types while both exist (section 7).

## 17. Documentation Strategy

**Documentation Type:** API Docs Only (DocC on every public symbol, compiling examples), plus the CHANGELOG entry and ADR-010. The
explanation is under 50 lines and extends `NetworkMeasuresGuide` only by a sentence, if that article exists.
