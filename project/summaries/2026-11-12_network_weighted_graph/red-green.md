# Red then green: WeightedGraph (step 1)

## Red

A compile-stub was written first: `WeightedGraph`, `GraphError` and the two bridge initialisers with the
right signatures and empty behaviour (no nodes, every degree 0, `Graph(weighted)` an empty graph, the
throwing initialiser never throwing). The tests then compiled (`swift build --build-tests`, no errors) and were
run with `swift test --skip-build --filter "WeightedGraph|WeightValidation|GraphBridge"`.

Result: **35 tests in 4 suites, 234 issues; 26 tests failed, 9 passed.** Every failure is a failed
`#expect` on a value or `Issue.record("a weight of ... was accepted")` for a missing throw; none is a compile
error. Failing tests include: nodes sorted; duplicates merge; self-loops dropped; isolated nodes kept;
integer nodes (34 nodes, 78 edges, degree 17); the kite shape; weighted degree by index; NaN, infinite and
negative weights refused (6 cases), the same for self-loops (6 cases), overflow refused (3 forms), hostile
weight at a random position (60 issues); zero legal; valid weights unchanged; unweighted weighs one; every
bridge test that needs a non-empty result (directed edge, reciprocal edges, isolated vertices, unlisted targets,
self-loop, back to Graph, zero-weight tie, round trips on symmetric, directed and karate graphs, random round
trip: 100 issues).

The 9 that passed against the stub did so vacuously, because an empty graph satisfies them: "An empty graph
is valid", "Adjacency lists are sorted", the sum-of-degrees (handshake) property, the relabelling, handshake, edge-order, duplicate-doubling and
adjacency-symmetry properties, "Every weight in a symmetrised graph is exactly one" and "The bridge agrees with
direct construction" (both empty). Their strength is established by the mutation check, not by this red run.

(Of the 35, `WeightValidationTests` carries 6 + 6 argument cases that count as one test each here.)

## Green

Real implementation ported from SwiftGraphMetrics `Graph/WeightedGraph.swift` (re-styled to tabs and DocC
only), plus bridges. Two corrections to my own tests on the way to green, not to the implementation:

1. `ReferenceGraphs.karateEdges` was missing its last pair when first copied (77 edges): a fixture error.
2. The "largest finite weight accepted" boundary test was wrong. A single edge of `greatestFiniteMagnitude`
   is refused with `weightSumOverflow`, because the total is accumulated from both ends before halving. That is
   the prior package's behaviour and is kept byte for byte; it is now pinned by its own test
   (`largestSingleWeightRefused`) and a half-range weight is tested as accepted. It refuses a graph that is
   representable, so it fails closed, never returning a wrong number; flagged for the owner in case it should
   change later.

Final: **36 tests in 4 suites pass.** Existing Network suites (filter
`Network|Graph|Centrality|Markov|Projection`) pass alongside.
