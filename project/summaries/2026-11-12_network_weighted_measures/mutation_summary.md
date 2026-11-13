# Mutation check of the weighted measures port

127 hand-written mutants (`mutate.py`) across `Centrality` (eigenvector, PageRank, betweenness,
closeness, harmonic, clustering, degree), `Community` (modularity, Louvain move and contraction logic,
k-core peeling, components) and `Brokerage.constraint`. Run in an outside-the-repo scratch package
(`make_scratch.sh`) against the ported suites, the cross-check and the golden test. Raw output:
`mutation_output.txt`.

| Group | Mutants | Killed | Survived | Notes |
|---|---|---|---|---|
| Eigenvector / convergence (E) | 25 | 23 | 2 (E12, E19) | E12 closed by a new test, E19 equivalent |
| PageRank (P) | 17 | 16 | 1 (P14) | P14 closed by a new test |
| Betweenness (B) | 13 | 13 | 0 | |
| Closeness / harmonic (W) | 9 | 9 | 0 | |
| Clustering and degree (K) | 6 | 5 | 1 (K03) | |
| Modularity (Q) | 9 | 9 | 0 | |
| Louvain (L) | 26 | 21 | 5 | L19 killed by a crash (index out of range), the rest equivalent |
| k-core (R) | 7 | 5 | 2 | |
| Components (N) | 3 | 3 | 0 | N01 killed by non-termination (infinite BFS) |
| Burt (T) | 12 | 9 | 3 | |
| Total | 127 | 113 (111 by assertion, L19 by crash, N01 by hang) | 14 | |

The script labels L19 and N01 "BUILD ERROR" because a crash and a hang produce no test summary; both
are detected behavioural changes, not invalid mutants (each compiled). N01 left a spinning test process
that was killed by hand after ten minutes.

## Survivors

Closed by a test written red-first against the mutant (`StoppingRuleBoundaryTests.swift`; each fails with
the mutant applied and passes on the real code, both checked in the scratch package):
- **E12** eigenvector stop test `<` to `<=`: tolerance set to a residual the run produced; strict `<` needs more passes.
- **P14** PageRank stop test `<` to `<=`: tolerance set to the change of pass 6; strict `<` does not stop there.

Equivalent (no observable difference in any output), with the reason:
- **E19** `peak > 0` to `>= 0`: after the `norm > 0` guard the iterate is non-negative and has a positive entry, so `peak` is never zero; defensive guard.
- **K03** clustering without `other != index`: `neighbourSet` never contains the node itself (self-loops are dropped), so the test is subsumed by the set test.
- **L03** Louvain `>` to `>=` on `bestGain + 1e-12`: differs only when a gain exceeds the best by exactly 1e-12 in floating point; no fixture (or constructible integer-weight graph) reaches it. Not closed.
- **L13** `improved` guard removed: with no move, every node is its own community, so the next guard (`newCount < levelCount`) breaks anyway.
- **L14** `newCount < levelCount` to `<=`: contracting an unchanged level costs one extra pass and the next pass moves nothing, so the partition is identical.
- **L25** edgeless guard `>= 0`: the edgeless graph then reaches the level loop, where `guard totalWeight > 0` breaks with the identity assignment, the same partition.
- **L26** level `totalWeight > 0` guard removed: unreachable, because the top-level guard already returned for zero total weight and contraction preserves the total.
- **R02** k-core decrement without `!removed`: a removed node's degree is never read again.
- **R03** k-core selection `<` to `<=`: which of several equal-degree nodes is peeled first does not change any core number.
- **T02** Burt stamp loop `weight >= 0`: a zero-weight neighbour is stamped but the total loop skips it, so it is never summed.
- **T09** Burt `j != i` dropped: `stamp[i] == i` is never set, since a node is not its own neighbour.
- **T10** Burt `stamp[j] == i` dropped: indirect investment accrues to non-contacts, whose slots are reset before any later read.

After the two new tests: 127 mutants, 113 killed before, 2 more closed (115 killed), 12 equivalent.
