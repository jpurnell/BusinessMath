# Network fixes: eigenvector centrality on bipartite graphs, Louvain contraction

**2026-11-12** · branch `fix/network-eigenvector-louvain` from origin/main (`ad2a2ed8`, 3.0.0-alpha.14).
Red/green output is in `red-green.md` beside this file.

## Task 1: eigenvector centrality

**Defect.** Power iteration on `A` does not converge on a bipartite graph because `-lambda` ties
`+lambda`. The brief's measurement (path of 3 returns all 0.577) was not re-run by me; my red run on the
unmodified code showed star hubs of 0.378, 0.577 and 0.302 for 6, 3 and 10 leaves (truth 0.7071 each,
which is how the iterate behaves: 1/sqrt(n+1)), results that depended on the parity of `maxIterations`, and the
last iterate returned from a 1- or 2-iteration budget instead of `nil`.

**Fix.** Iterate on `A + sI`, `s = edgeCount / nodeCount`. Same eigenvectors; the `-lambda` eigenvalue becomes
`s - lambda`, strictly smaller in modulus than `lambda + s`. Returns `nil` on non-convergence.

**Reference values (hand derivations in the test file header).** star with n leaves: hub `1/sqrt2`, leaf
`1/sqrt(2n)`; path 3: `(1/2, 1/sqrt2, 1/2)`; path 5: `sin(k pi/6)/sqrt3`; cycles `1/sqrt n`; K(p,q): `1/sqrt(2p)` on the
p-side and `1/sqrt(2q)` on the q-side. Plus a Jacobi eigen-solver written in the test, used against 60 seeded
random connected graphs (two thirds trees, so bipartite).

### Mutation testing (hand-written, scratch SwiftPM package outside the repo holding copies of `Graph.swift`, the
eigenvector function and the test file; 20 mutants)

| Mutant | Result |
|---|---|
| M1 shift negative | killed |
| M2 shift zero | killed |
| M3 shift 0.01 x mean degree (too small) | killed |
| M4 shift fixed at 1 | survived the first suite, then killed by `budgetIsExact`, which pins the documented shift via the iteration count. Behaviourally equivalent for an unweighted graph; the kill is the test pinning the documented value |
| M5 shift 100 x mean degree | killed |
| M6 tolerance comparison flipped (`>`) | killed |
| M7 tolerance `<=` | survived; closed by `toleranceIsStrict` (tolerance 0 on a cycle) |
| M8 iterations `maxIterations - 1` | survived; closed by `budgetIsExact` |
| M9 iterations `maxIterations + 1` | survived; closed by `budgetIsExact` |
| M10 normalisation removed | killed |
| M11 L1 length instead of L2 | killed |
| M12 last iterate returned on non-convergence | killed |
| M13 shift term dropped from update | killed |
| M14 shift added as a constant, not times the score | killed |
| M15 disconnected guard removed | killed |
| M16 no-edges guard removed | survived, **equivalent**: with no edges the graph is disconnected (n>1, killed by the connectivity guard) or one node, where `lengthSquared == 0` returns `nil` |
| M17 movement as a sum, not a max | survived; closed by `budgetIsExact` |
| M18 movement never updated | killed |
| M19 start vector not unit length | survived, **equivalent**: the first pass normalises, and the first movement is never below tolerance |
| M20 shift `count / 2` | survived; killed by `budgetIsExact` (pins mean degree) |

`budgetIsExact` and `toleranceIsStrict` were added after the first mutation run; they pass on the real code
(15 tests, 0.13s in the scratch package).

## Task 2: Louvain

**Decision, with evidence: the doc comment was true of the intent and false of the shipped behaviour.** The loop never
built a contracted graph; it was single-level local moving. Evidence is a ring of 12 triangles joined by single
edges. By hand, with m = 4k: one community per triangle has Q = 3/4 - 1/k = 0.6667; adjacent pairs have
Q = 7/8 - 2/k = 0.7083 (pairing wins when k > 2(e+1) = 8). The shipped code returned exactly 0.6667 (the
test output in `red-green.md`); a multi-level reference written in the test (aggregate into a weighted dense graph,
repeat) reached 0.7083. Rings of 16 K4 (0.7946 against 0.8036), 24 triangles (0.7083 against 0.7917) and 10
triangles showed the same gap. So the fix is real contraction, not a doc correction.

**Fix.** Local moving (same gain formula, same strict-improvement and ascending-community tie-breaking) alternates with
contraction into a weighted level graph (super-nodes numbered by lowest member; inter-community weights summed;
internal weight kept as a self-weight so `2m` is invariant). `maxPasses` now means contraction rounds. Modularity code
is untouched; no error was found in it.

**Oracles in the tests.** Hand closed forms for the rings; a multi-level reference and a single-level reference (test code);
exhaustive optimum over all Bell(8) = 4140 partitions on 25 seeded random 8-node graphs (shipped Q never exceeds it, and
stays within 0.1 of it); property tests on 40 seeded random graphs (Q in [-0.5, 1), every node placed once, deterministic).
Relabelling invariance is asserted on a planted-structure graph only: greedy local moving is legitimately order dependent
on unstructured graphs, so asserting it there would assert something false.

Louvain mutation pass: see `mutation-louvain-classification.md` (25 mutants, 10 survived the first suite; 5 closed red-first, 5 classified equivalent).

## What I could not verify (original list; see the final report for the follow-up run)

- Linux / Swift 6.2.1 CI. Everything ran on macOS (local Swift toolchain, `swift test`), so type-checker timeouts on the Linux
  toolchain are untested. Expressions in the new code were kept to at most three operators and intermediates are explicitly typed.
- Eigenvector centrality on a very large or poorly conditioned graph now returns `nil` if 1000 passes at 1e-12 do not suffice; that
  is intended, but I did not measure where the boundary falls for large graphs.

## Quality gate

See the final report; the pre-commit hook runs the repo's quality gate and the commit was blocked or accepted by it.

## Follow-up (owner decisions)

- Default `maxIterations` stays 1000 with `nil` on non-convergence; documented in the doc comment and CHANGELOG, with
  characterisation tests (not red-first). The measured passes-needed table for the shipped shift differs from the owner's
  (shipped shift is the mean degree, twice `m/n`): a path of 30 nodes needs 1016 passes, 61 nodes 3773.
- Louvain mutation pass done; outputs committed in this directory.
