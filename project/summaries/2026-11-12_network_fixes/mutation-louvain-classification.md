# Louvain mutation pass (scratch SwiftPM package outside the repo; 25 hand-written mutants of Community.swift)

Raw outputs beside this file: `mutation-louvain-first-pass.txt` (against the 9 tests committed in 99ed9670),
`mutation-louvain-final.txt` (against the final 15-test suite). Eigenvector mutation outputs:
`mutation-eigenvector-first-pass.txt` (against the first suite, 20 mutants) and
`mutation-eigenvector-rerun.txt` (the first-pass survivors re-run against the final 17-test suite).

First pass survivors (10 of 25): L04, L05, L08, L10, L20, L21, L22, L23, L24, L25.

| Mutant | First pass | Final | Disposition |
|---|---|---|---|
| L01 no contraction | killed | killed | |
| L02 contraction after first pass only | killed | killed | |
| L03 maxPasses+1 rounds | killed | killed | |
| L04 `max(maxPasses, 1)` removed | **survived** | killed | closed red-first by `zeroPassesIsOnePass` |
| L05 aggregated weight counted as 1 | **survived** | killed | closed red-first by `bondedRingsMatchReference` (needs several parallel edges between neighbouring communities and 3+ levels; the planted and hierarchical graphs tried first did not kill it) |
| L06 internal weight dropped | killed | killed | |
| L07 existing self-weight dropped | killed | killed | |
| L08 level-0 self-loop weight 2 | **survived** | killed | closed red-first by `plantedMatchesReference` (self-loop aware dense reference) |
| L09 degree omits self-weight | killed | killed | |
| L10 output order descending | **survived** | killed | closed red-first by `orderedByLowestNode` |
| L11 tie-break direction reversed | killed | killed | |
| L12 strict improvement `>=` | killed | killed | |
| L13 gain sign | killed | killed | |
| L14 gain expected factor 2 | killed | killed | |
| L15 gain attraction factor 2 | killed | killed | |
| L16 community degree not reduced on leaving | killed | killed | |
| L17 community degree credited as 1 | killed | killed | |
| L18 baseline links ignored | killed | killed | |
| L19 one local-moving sweep | killed | killed | |
| L20 local moving never exits early | survived | survived | **equivalent**: the sweep loop only stops early when a full sweep moves nothing; without the `break` the remaining sweeps also move nothing (same state, deterministic), so the result is identical and only time is wasted (bounded by the 1000-sweep backstop). |
| L21 contraction guard `<=` | survived | survived | **equivalent**: it only differs when every node is alone; the contracted graph is then isomorphic with identical numbering, the next round again moves nothing, and membership is unchanged. The result is identical, rounds are wasted. |
| L22 redundant `twiceEdges > 0` guard removed | survived | survived | **equivalent**: `edgeCount > 0` is checked first and every edge (self-loops included) adds to a degree, so `twiceEdges > 0` always holds there. |
| L23 candidate loop no longer skips the current community | survived | survived | **equivalent**: the current community's gain equals the baseline and the comparison is strict `>`, so it can never win. |
| L24 super-nodes renumbered by last member | **survived** | killed | closed red-first by `plantedMatchesReference` (numbering changes tie resolution at later levels) |
| L25 `squared > 0` guard in `modularityGain` removed | survived | survived | **equivalent**: `squared = twiceEdges^2` and `twiceEdges > 0` is guaranteed by the callers; dividing by it cannot trap or change a value. |

Red-first means: the new test was written, run against the named mutant (fails, test name in `mutation-louvain-final.txt`),
and run against the real code (passes). The new tests also passed on the real code first time, so none of them found a defect in the shipped code.

The six after-the-fact guard tests of 99ed9670 matter: `neverBelowSingleLevel` kills L11, L12, L19; the `maxPasses: 1` test kills L03, L09, L13; the self-loop
test alone killed nothing (L07 and L09 were killed by the ring tests), so it is the weakest of the six.
