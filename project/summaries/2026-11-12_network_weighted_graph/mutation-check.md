# Hand-written mutation check: WeightedGraph and bridges

Run 2026-11-12 in a scratch package outside the repo (the three new source files plus `Graph.swift`, the four
new test files, `ReferenceGraphs.swift`, and a local SplitMix64 stand-in for `DeterministicGenerator`),
because a mutant in the full module costs a five-minute rebuild. The mutants are in `mutate.py`; the raw
output is `mutation-output.txt`. 36 mutants, one `swift test` each.

| Result | Count |
|---|---|
| Killed | 32 |
| Survived, classified equivalent | 3 (M07, M16, M32) |
| Did not compile | 1 (M30, not applicable) |

## Survivors

- **M16 `edgeCount` computed as `(sum + 1) / 2`.** `sum` is the total of adjacency list lengths, and every
  undirected edge appears at both ends, so `sum` is always even; integer division makes `(sum+1)/2 == sum/2`.
  Equivalent. (M17, not halving at all, is killed.)
- **M32 bridge `Graph -> WeightedGraph` stops filtering `from != to`.** The self-loop then reaches
  `init(unweightedEdges:)`, which drops loops itself, and the node is kept regardless because the bridge passes
  every vertex as `isolatedNodes`. Observable output is identical. Equivalent: the filter is a redundant
  second defence. (The test `selfLoopDropped` still pins the behaviour.)
- **M07 the per-node weighted-degree finiteness check removed from the overflow guard.** The total is the
  sum of every node's merged neighbour weights, all of which are non-negative, so a node whose degree
  overflows makes the total infinite too, and the total check catches it first. Equivalent for
  non-negative weights except possibly at a one-ulp rounding boundary where the two summation orders
  (dictionary order for the total, sorted-neighbour order for the degree) disagree; I could not construct such
  an input and did not try to prove none exists. Kept as written because the source is byte-for-byte the
  prior package's.

## Not applicable

- **M30 bridge weight 2.** Does not compile: the bridge calls the non-throwing `init(unweightedEdges:)`, so
  the weight is one by construction. M23 (the unweighted initialiser weighing 2) is killed and covers the
  same behaviour.

## Notable kills

- M10 (a self-loop's node dropped along with the loop) is killed by exactly one test, `dropsSelfLoops`
  (`lonely.nodes == ["z"]`).
- M15 (adjacency sort reversed) is killed by exactly one test, `adjacencySorted`.
- No mutant needed a new test written red-first against it: every non-equivalent mutant was already killed
  by the suite as shipped.
