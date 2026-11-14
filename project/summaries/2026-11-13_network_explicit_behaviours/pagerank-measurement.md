# PageRank convergence: measurements (PageRankConvergence.md section 6, step 1)

Synthetic graphs only. Scratch package: `/private/tmp/claude-501/-Users-jpurnell-Documents-Princeton-Class-of-2000-Events-2028/afdd3956-2eca-4229-b368-a078e9c2e4d7/scratchpad/pagerank-measure/`.
`Sources/PRLib/` holds verbatim copies of `WeightedGraph.swift`, `NodeScores.swift` (MetricValue/Codable extensions removed), and `Centrality.pageRank` (the function body diffed identical to the original). No SwiftDeterminism needed. No repository was edited. Swift 6.4.2, arm64, macOS 27.2, `-c release`. Machine load average was ~470 during the runs (affects wall time only).

Method: `Centrality.pageRank` returns only scores, so pass counts and deltas come from a replica of its loop body in `Sources/measure/main.swift` (same arithmetic, same order, instrumented). The replica is validated against the real function: in the theory table every row's real `pageRank` output equals the replica's iterate at the pass where the real function stops (`min(fire pass, 200)`), bit for bit (column "pageRank == replica": yes in all 66 rows). Reference solutions: iterate the same map 20,000 passes with tolerance 0 (n~1100); for n~289 a dense Gaussian solve of `(I - d M) x = (1-d)/n` was compared too (iterative reference vs dense: L1 <= 6.7e-14 across all families and dampings, table at the end of section 1). Error is L1.

## Reproduce

```
cd /private/tmp/claude-501/-Users-jpurnell-Documents-Princeton-Class-of-2000-Events-2028/afdd3956-2eca-4229-b368-a078e9c2e4d7/scratchpad/pagerank-measure
swift build -c release
B=$(swift build -c release --show-bin-path)/measure
$B theory  > theory.out    # section 1 and 4 (a few minutes under load)
$B noise   > noise.out     # section 2, ER sparse graphs, n 1k..100k
$B noise2  > noise2.out    # section 2, adversarial shapes
$B probe   > probe.out     # section 2, graphs where the rule never fired
$B stars   > stars.out     # section 2, star scaling and hub fraction
$B bisect  > bisect.out    # section 2, smallest star n that fails at 0.85
$B edge    > edge.out      # section 3
$B slow    > slow.out      # section 1 supplement: slow-mixing graphs
```
(Do not rebuild while a run is in progress: replacing the binary killed one of my runs; I copied binaries to `measure*.bin` for the final runs.)

## 1. Theory check (n ~ 1,100, tol 1e-12, default ceiling 200)

Full 66-row table: `theory.out`. Summary of what it shows (families: path, star, ring, 33x33 grid, Erdos-Renyi deg 6, preferential attachment m=3, 10 planted communities (n=1149), 80% isolated/dangling, star49+isolated, no edges, sparse ER deg 0.5; dampings 0.5, 0.7, 0.85, 0.9, 0.95, 0.99).

**Pass count to the stopping rule vs predicted `ceil(ln(tol/2)/ln d)`:** predicted is 41, 80, 175, 269, 553, 2819 for the six dampings. Observed fire pass was at or below predicted+1 in 65 of 66 rows, and usually far below (ER deg 6 at 0.85: 54 vs 175; at 0.99: 82 vs 2819). The prediction is tight only on the star (41, 80, 175, 269, 552 observed). The one exception:

- **star, d=0.99, n=1089: the rule never fired in 20,000 passes** (predicted 2,819). This is the noise floor of section 2, not a convergence failure: min delta is 2.82e-12 (a constant, see `probe.out`). I did not separately measure the true error of the iterate there.

**Does 200 passes suffice at tol 1e-12?** Fires within 200: yes for every family at d <= 0.85 (max 175, star); the stopping rule does not fire within 200 at d=0.9 on path (203), grid (203), star (269), star49+isolated (233), sparse ER deg 0.5 (236); at d=0.95 on path, star, grid, communities, etc. So the plan's statement "above about 0.88, 200 passes no longer reach 1e-12" is right for slow-mixing shapes (path, grid, star, tails) and wrong for fast-mixing ones (ER, preferential attachment, dangling-heavy), which converge well inside 200 even at 0.99 (82 and 74 passes).

**Bound error_k <= 2 d^k:** checked at every k from 1 up to the last k where 2d^k > 1e-10 (up to 3,000), for every row against the converged reference. **No violation.** Worst measured ratio error_k / (2 d^k) over all rows was 0.610 (dangling 80% at 0.99, k=1); the star is the worst structural case at ~0.51 (k=2359 at 0.99). Error at 200 passes was below 2 d^200 in every row (column "bound ok @200"; at errors below 1e-13 the bound comparison is treated as satisfied since noise dominates). The bound is tight within a factor of about 2 on the star and loose by orders of magnitude on everything else.

Slow-mixing supplement (`slow.out`): fire pass vs predicted, real `pageRank` error at its own stop vs a long-run reference.

| graph | n | d | fire pass | predicted | fires within 200? | real pageRank L1 err at its own stop |
|---|---|---|---|---|---|---|
|  path  |  1000  |  0.85  |  132  |  175  |  yes  |  4.43e-13  |
|  path  |  1000  |  0.9  |  204  |  269  |  NO  |  6.68e-13  |
|  path  |  1000  |  0.95  |  418  |  553  |  NO  |  3.42e-08  |
|  path  |  1000  |  0.99  |  2131  |  2819  |  NO  |  1.36e-04  |
|  path  |  1000  |  0.999  |  21436  |  28311  |  NO  |  1.02e-03  |
|  star49+isolated  |  1000  |  0.85  |  152  |  175  |  yes  |  4.22e-13  |
|  star49+isolated  |  1000  |  0.9  |  234  |  269  |  NO  |  1.65e-11  |
|  star49+isolated  |  1000  |  0.95  |  480  |  553  |  NO  |  8.41e-07  |
|  star49+isolated  |  1000  |  0.99  |  2451  |  2819  |  NO  |  3.29e-03  |
|  star49+isolated  |  1000  |  0.999  |  never(57622)  |  28311  |  NO  |  2.02e-02  |
|  ER60  |  60  |  0.85  |  109  |  175  |  yes  |  4.03e-13  |
|  ER60  |  60  |  0.9  |  145  |  269  |  yes  |  4.66e-13  |
|  ER60  |  60  |  0.95  |  212  |  553  |  NO  |  2.05e-12  |
|  ER60  |  60  |  0.99  |  329  |  2819  |  NO  |  8.56e-09  |
|  ER60  |  60  |  0.999  |  375  |  28311  |  NO  |  5.40e-08  |
|  ring+1 tail  |  601  |  0.85  |  135  |  175  |  yes  |  4.53e-13  |
|  ring+1 tail  |  601  |  0.9  |  209  |  269  |  NO  |  1.11e-12  |
|  ring+1 tail  |  601  |  0.95  |  428  |  553  |  NO  |  5.68e-08  |
|  ring+1 tail  |  601  |  0.99  |  2182  |  2819  |  NO  |  2.26e-04  |
|  ring+1 tail  |  601  |  0.999  |  21917  |  28311  |  NO  |  1.70e-03  |
|  two cliques bridged  |  80  |  0.85  |  4  |  175  |  yes  |  5.76e-16  |
|  two cliques bridged  |  80  |  0.9  |  4  |  269  |  yes  |  2.31e-15  |
|  two cliques bridged  |  80  |  0.95  |  4  |  553  |  yes  |  6.09e-16  |
|  two cliques bridged  |  80  |  0.99  |  4  |  2819  |  yes  |  2.21e-15  |
|  two cliques bridged  |  80  |  0.999  |  4  |  28311  |  yes  |  1.36e-15  |

Notes on this table: (a) "real pageRank err" is at the pass where the 1e-12 rule stops (not at pass 200), so it is *not* comparable with 2 d^200. It is bounded by about d/(1-d) x tol: 5.7e-12 at 0.85, 1e-10 at 0.99, and measured 4e-13 to 1e-3 where the ceiling (200) cuts the run first. (b) Where the stop is the ceiling, error is large: path n=1000 at 0.99 returns with L1 error 1.4e-4, at 0.999 with 1.0e-3, and `pageRank` says nothing. (c) `star49+isolated` at 0.999 never fires in 57,622 passes (noise floor again, section 2). (d) "two cliques bridged" converges in 4 passes at every damping: structure, not damping, decides the actual count; the bound is worst-case.

Dense cross-check (n=289 versions of each family, d in {0.5, 0.85, 0.95}): `L1(dense, iterative reference)` <= 6.7e-14; `L1(dense, real pageRank)` was 1e-16..5e-12 at d <= 0.85 and up to 3.4e-5 at d=0.95 on star (ceiling-limited, 2 d^200 = 7e-5). Full table at the end of `theory.out`.

## 2. Noise floor

### 2a. Sparse random graphs (ER, average degree 6, d=0.85, tol 0, 400 passes) from `noise.out`

| n | min delta | pass of min | delta@400 | min < 1e-12? | abs rule (1e-12) fires | delta/L1norm < 1e-12 fires | delta/n < 1e-12 fires | true L1 err at delta/n stop | true L1 err at abs stop |
|---|---|---|---|---|---|---|---|---|---|
|  1000  |  7.11e-17  |  86  |  7.12e-17  |  yes  |  55  |  55  |  39  |  4.89e-10  |  3.37e-13  |
|  5000  |  2.54e-17  |  93  |  2.54e-17  |  yes  |  56  |  56  |  36  |  2.76e-09  |  6.98e-13  |
|  10000  |  4.02e-17  |  98  |  4.02e-17  |  yes  |  55  |  55  |  35  |  3.46e-09  |  4.38e-13  |
|  50000  |  2.08e-17  |  212  |  2.08e-17  |  yes  |  108  |  108  |  42  |  2.02e-08  |  4.37e-13  |
|  100000  |  2.81e-17  |  132  |  2.81e-17  |  yes  |  66  |  66  |  30  |  5.00e-08  |  7.32e-13  |

**The floor is far below 1e-12 on sparse random graphs at every size, and does not grow with n** (it shrinks: 7e-17 at 1k to 3e-17 at 100k; also 2.9e-17 at n=200,000 and 3e-17 at ER avg degree 100, n=50,000). The proposal's estimate (roughly n x 1e-16 per pass, so above 1e-12 at about 10,000 nodes) is **not borne out for random graphs**: rounding errors there are incoherent and the iterates settle to an exact fixed point or ulp-level cycle with delta around 1e-17. Other families, n=100,000 (`noise2.out`): grid 316x316 3.6e-18, path 4.9e-19, ring 0, preferential attachment 4.7e-17, planted communities 1.0e-19, 80% dangling 2.7e-18: all fire between pass 1 and 107.

### 2b. Where the proposal's concern is real: a hub summing many equal contributions

| graph | n | d | min delta | passes with delta<1e-12 (60,000 run) | abs rule fires |
|---|---|---|---|---|---|
| star | 100,000 | 0.85 | 7.57e-12 | 0 (400-pass run) | NEVER |
| star | 1,089 | 0.99 | 2.82e-12 | 0 | NEVER |
| star | 10,000 | 0.99 | 2.60e-11 | 0 | NEVER |
| star | 1,089 | 0.95 | 5.29e-13 | 59,449 | 552 |
| star | 1,089 | 0.85 | 9.85e-14 | 59,826 | 175 |
| star | 100 | 0.99 | 2.68e-13 | 57,180 | 2,821 |
| star49 + 950 isolated | 1,000 | 0.999 | 1.45e-12 | 0 | NEVER |
| star49 + 950 isolated | 1,000 | 0.99 | 1.06e-13 | 57,550 | 2,451 |

On these the delta is a constant for the entire tail (`probe.out`: 1 distinct value in the last 20 passes), i.e. a rounding limit cycle, not slow convergence. Star scaling at d=0.85, 400 passes (`stars.out`):

| n | min delta | min delta/(n*2.22e-16) | abs 1e-12 fires | delta/n<1e-12 fires | err at delta/n firing | delta < n*2.22e-16 fires | err there |
|---|---|---|---|---|---|---|---|
| 1000 | 9.39e-14 | 0.4 | 175 | 132 | 4.42e-10 | 185 | 1.23e-13 |
| 2000 | 1.51e-13 | 0.3 | 175 | 128 | 8.48e-10 | 180 | 1.17e-13 |
| 5000 | 3.79e-13 | 0.3 | 175 | 122 | 2.25e-09 | 174 | 3.28e-13 |
| 10000 | 7.87e-13 | 0.4 | 175 | 118 | 4.31e-09 | 169 | 1.44e-12 |
| 20000 | 1.83e-12 | 0.4 | NEVER | 114 | 8.26e-09 | 165 | 2.48e-12 |
| 50000 | 4.53e-12 | 0.4 | NEVER | 108 | 2.19e-08 | 161 | 6.15e-12 |
| 100000 | 7.57e-12 | 0.3 | NEVER | 104 | 4.20e-08 | 156 | 5.86e-12 |
| 200000 | 3.00e-11 | 0.7 | NEVER | 100 | 8.04e-08 | 150 | 5.27e-12 |

`bisect.out` (d=0.85, star): fires at n=10,000 (pass 175, min delta 7.9e-13); **never fires from n=11,000** (min delta 1.04e-12), through 17,000 tested and 200,000 in the scaling table. So **the smallest n at which the default 1e-12 rule can no longer fire is about 11,000, but only for a star-like hub whose neighbours all contribute equal terms** (floor is about 0.3 to 0.7 x n x 2.22e-16). On a graph that merely contains a hub (n=100,000 ER background, hub linked to 0.1% to 100% of nodes) the floor stays at 6e-18 to 3e-17 and the rule fires at pass 40 to 58 (`stars.out`, second table). On ordinary graphs I could not find any n up to 200,000 at which it fails at d=0.85. The floor also rises with damping, roughly proportional to 1/(1-d): 0.4, 2.2 and 11.7 times n x eps for d=0.85, 0.95, 0.99 on a star. At d=0.99 a 1,089-node star already fails; at 0.999 a 50-leaf star with 950 isolated nodes fails.

Class-sized graphs (n ~1,100, real-looking degree distribution) are safe: every non-star row of the n~1,100 theory table fires, including d=0.99 for non-star families.

### 2c. Relative rules

At fixed mass 1 (this loop conserves the sum, section 4), **delta / L1-norm is identical to the absolute rule** (L1 norm = 1 to within 1e-13), so it fires exactly where the absolute rule fires and fails exactly where it fails (e.g. never on stars from n=11,000; table 2a, column "delta/L1norm" equals the abs column). It fixes nothing.

**delta / n < 1e-12 always fires** (even on stars, passes 100 to 132), but it is a much weaker criterion: true L1 error at stop grows with n: 4.9e-10 (n=1k), 3.5e-9 (10k), 5.0e-8 (100k ER); star 8.0e-8 at 200k. Error per node stays about 4e-13, so it is sound as a mean-per-node criterion, not as an L1 criterion. It would change returned scores at the 1e-8 level.

A floor-aware rule I also tried on stars: stop when delta < max-style `n x 2.22e-16` (i.e. one ulp of mass per node): fires at every star size 1k to 200k (passes 150 to 185) with true error 1.2e-13 to 6e-12 (within d/(1-d) x delta). It is not an off-the-shelf recommendation: the floor also scales with 1/(1-d) (above), so at d=0.99 the star floor is 11.7 x n x eps and this rule would still not fire. An empirical envelope that covered every floor I measured is `floor <= 0.12 x n x eps / (1 - d)`; I measured it only on stars and one star+isolated graph.

## 3. Damping edge behaviour (real `Centrality.pageRank`, defaults otherwise; `edge.out`)

Graphs: ER60 with dangling nodes, and ring60.

| damping passed | what happens | NaN scores | sum of scores |
|---|---|---|---|
| 0.999 | accepted as is | 0 | 1 +/- 7e-16 |
| 1.0, 1.0000001, 2.5, +infinity | **clamped to 0.999**; output bit-identical to damping 0.999 | 0 | 1 +/- 2e-15 |
| 0.0 | teleport only: uniform 1/n | 0 | 1 + 1.3e-15 |
| -0.3, -infinity | **clamped to 0**; bit-identical to damping 0.0 (uniform) | 0 | 1 + 1.3e-15 |
| **NaN** | `min(max(NaN, 0), 0.999)` stays NaN: **every score is NaN**, sum NaN; no trap, no throw | 60 of 60 | NaN |

So out-of-range finite or infinite damping is silently clamped; only NaN produces garbage, silently. Clamp consequences: damping 0.999 needs about 28,311 passes in theory (the ceiling leaves L1 error 1.0e-3 on path n=1000 per the slow table, 1.7e-3 on a ring-with-tail, 2.0e-2 on star49+isolated); on ER60 it happened to fire at pass 375 > 200 with 5.4e-8 error at 200. A caller passing 1.0 (probably meaning "no teleport") gets 0.999 results that are not converged at the default ceiling and no signal.

## 4. Dangling nodes and mass conservation

From the 66-row `theory.out` (11 families including 80% isolated, star49+isolated, no edges; 6 dampings; real `pageRank`, default arguments): **max |sum - 1| over all outputs = 1.22e-13, under the 1e-12 threshold (PASS)**. Largest individual errors were on path/star/dangling shapes (1e-14 to 1.2e-13); ER and grid at 1e-15. Section 3 sums: <= 2e-15 on 60 nodes. 100k-node sums were not recorded (I did not measure mass there). The mass error is rounding accumulation, so it grows slowly with n; I did not measure how.

## RECOMMENDATION

A convergence flag is warranted, mainly for non-default damping: at the default 0.85 and tol 1e-12 the rule fires in 175 passes at worst (star; 132 on path/grid, 150 on star49+isolated) and error at 200 passes is below 1.5e-14 everywhere, so the default call cannot return an unconverged answer, but at damping 0.9 five of eleven families exceed the ceiling and at 0.99 most do (path error 1.3e-4, star 0.13, with no signal), which is the same silent failure as eigenvector. The stopping rule's tolerance is sound on sparse random, grid, path, ring, preferential-attachment, community and dangling-heavy graphs at every size tested (to 200,000 nodes, floor about 1e-17), so the proposal's "n x 1e-16, fails near 10,000 nodes" is wrong for those; it is true only for a star-like hub with many equal-weight leaves (fails from n about 11,000 at 0.85, and from n about 1,089 at 0.99), where a false "did not converge" is possible. Making the rule relative does not help (delta / L1 norm is the same number as the absolute rule because mass is conserved; delta / n always fires but accepts L1 error growing to 8e-8 at 200,000 nodes), so a flag must either also report the residual alongside the boolean or treat "residual stuck at a constant for several passes" as converged-to-noise. A justified ceiling at default damping and tol 1e-12 is `ceil(ln(tol/2)/ln d) + 1` = 176 passes, so 200 holds with a 24-pass margin (not "175 of 200 thin" in practice: no graph needed more than 175); for any other damping use that formula, whose value is 269 / 553 / 2,819 at 0.9 / 0.95 / 0.99, and the bound 2 d^k held on every graph tested (worst ratio 0.61). Treat damping as `0 <= d < 1`: NaN currently yields all-NaN scores with no error and should be rejected (or defaulted); d >= 1 and d < 0 are silently clamped to 0.999 and 0 today, and the 0.999 clamp is itself unconverged at the default ceiling (28,311 passes), so either throw or report non-convergence rather than clamping quietly.

## What I could not verify

- Whether the star noise-floor limit cycle appears on the user's real class graph (not touched, by instruction); n~1,100 non-star synthetic graphs are all clear.
- The 0.12 x n x eps / (1 - d) envelope: measured on stars only (about 10 points); not a derivation.
- Reference quality for n~1,100 graphs is iterative (20,000 passes), cross-checked against a dense solve only at n~289. At d=0.99 on slow-mixing graphs the iterative reference is limited by the same floor (about 3e-12), so error numbers below that level are not meaningful.
- Mass conservation was measured at n~1,100 and 60 only, not at 100k.
- Bound check range: k up to where 2 d^k fell below 1e-10, and at most 3,000; beyond that the reference's own noise dominates.
- Timing/wall clock was not measured (machine heavily loaded).
- Results are for arm64 / Swift 6.4.2 release; roseclub.org is x86_64 and could differ at the ulp level (limit-cycle floors are rounding-dependent), I did not run there.
