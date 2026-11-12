# Red/green log: network fixes (2026-11-12)

Every entry is output copied from a run in this worktree.

## Task 1 eigenvector: RED (unmodified Centrality.swift, commit ad2a2ed8)

Command: `swift test --filter EigenvectorCentralityBipartiteTests` (first build of the fresh worktree took 6m08s on a loaded machine).
Failures are assertions on wrong values, not compile errors. Per-test result lines, then samples of the wrong values
(expected by hand: path-3 middle 0.7071, star hub 0.7071):

```
Suite "Eigenvector centrality on bipartite graphs" failed after 0.647 seconds with 381 issues.
Test "Failing to converge within maxIterations is nil, not the last iterate" failed after 0.028 seconds with 2 issues.
Test "Path of 3 is (1/2, 1/sqrt2, 1/2)" failed after 0.045 seconds with 3 issues.
Test "Random connected graphs (mostly trees, hence bipartite) match the Jacobi reference" failed after 0.646 seconds with 325 issues.
Test "Relabelling the nodes permutes the answer and changes nothing else" passed after 0.046 seconds.
Test "Stars: hub 1/sqrt2, each leaf 1/sqrt(2n)" with 4 test cases failed after 0.042 seconds with 25 issues.
Test "The answer does not depend on the parity of maxIterations" failed after 0.060 seconds with 12 issues.
Test "The result is an eigenvector: A v = lambda v" failed after 0.060 seconds with 4 issues.
Test run with 13 tests in 1 suite failed after 0.647 seconds with 381 issues.
hub: 0.3015113445777629, expected 0.7071067811865475
hub: 0.37796447300922703, expected 0.7071067811865475
hub: 0.5773502691896257, expected 0.7071067811865475
leaf0: 0.30151134457776363, expected 0.22360679774997896
leaf0: 0.37796447300922725, expected 0.2886751345948129
leaf0: 0.5773502691896257, expected 0.5
p1: 0.46291004988627577, expected 0.5
p1: 0.5773502691896257, expected 0.7071067811865475
```

## Task 1 eigenvector: GREEN (shift s = edgeCount/nodeCount, nil on non-convergence)

Command: `swift test --filter "EigenvectorCentralityBipartiteTests|CentralityTests"`
```
Suite "Centrality" passed after 0.007 seconds.
Suite "Eigenvector centrality on bipartite graphs" passed after 0.484 seconds.
Test run with 23 tests in 2 suites passed after 0.484 seconds.
```

## Task 2 Louvain: RED (unmodified Community.swift)

Run in a scratch SwiftPM package holding verbatim copies of Graph.swift, Community.swift and the new test file, because the worktree build directory was locked by the pre-commit gate. Evidence that shipped behaviour is single-level local moving: on a ring of 12 triangles it returns exactly the one-community-per-triangle partition (Q = 3/4 - 1/12 = 0.6667, hand closed form), where the closed form for adjacent pairs is 7/8 - 2/12 = 0.7083.
```
Q = 0.6666666666666669, pairing adjacent triangles gives 0.7083333333333334
Q = 0.7946428571428571, pairing gives 0.8035714285714286
ring 10x3: Q = 0.6499999999999999, reference 0.6749999999999999
ring 12x3: Q = 0.6666666666666669, reference 0.7083333333333334
ring 16x4: Q = 0.7946428571428572, reference 0.8035714285714287
ring 24x3: Q = 0.708333333333333, reference 0.7916666666666666
Suite "Louvain multi-level" failed after 8.985 seconds with 7 issues.
Test "Modularity never exceeds the exhaustive optimum on graphs of 8 nodes or fewer" passed after 8.984 seconds.
Test "Planted structure: relabelling the nodes gives the same partition structure" passed after 0.009 seconds.
Test "Properties on seeded random graphs: range, coverage, determinism" passed after 0.059 seconds.
Test "Ring of 12 triangles reaches at least the paired partition (closed form 7/8 - 2/12)" failed after 0.006 seconds with 2 issues.
Test "Ring of 16 K4 cliques beats one community per clique (closed form)" failed after 0.007 seconds with 1 issue.
Test "The production result matches the multi-level reference on rings of cliques" failed after 0.038 seconds with 4 issues.
Test run with 6 tests in 1 suite failed after 8.985 seconds with 7 issues.
```

### Mutation-closing tests added after the first green (red under the named mutant, green on the real code)

budgetIsExact and toleranceIsStrict were written after mutation testing showed iteration-count and tolerance-comparison mutants surviving. They were verified red against the mutants in the scratch package (see summary.md table), then green on the real code (15 tests, 0.135s, scratch package).

## Task 2 Louvain: GREEN (real contraction)

Scratch package run, then worktree run: `swift test --filter "LouvainMultiLevelTests|ProjectionAndCommunityTests|EigenvectorCentralityBipartiteTests|CentralityTests|GraphTests|MarkovTests"`
```
Suite "Projection and community" passed after 0.014 seconds.
Suite "Graph, components and ordering" passed after 0.014 seconds.
Suite "Markov chains" passed after 0.014 seconds.
Suite "Centrality" passed after 0.014 seconds.
Suite "Eigenvector centrality on bipartite graphs" passed after 0.172 seconds.
Suite "Louvain multi-level" passed after 2.437 seconds.
Test run with 70 tests in 6 suites passed after 2.437 seconds.
```

Tests that passed on the OLD Community.swift too (written as guards after the fix, so NOT red-first): maxPasses monotone, never-below-single-level, self-loop, properties, relabelling, exhaustive-optimum bound. Red-first on old code: ring of 12 triangles, ring of 16 K4, production-vs-reference on rings (7 issues, output above).
