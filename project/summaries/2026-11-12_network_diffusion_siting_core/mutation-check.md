# Mutation check: diffusion and siting (step 3, part 1)

Script: `mutation-check.py` (hand-written mutants; 101 of them). It works on a scratch copy outside the
repository (`/private/tmp/claude-501/mutlab`, set up by `mutation-lab-sync.sh` and
`mutation-lab-Package.swift.txt`): a small package whose module is also called `BusinessMath` and which holds
only the diffusion and siting sources, `WeightedGraph` and the ported tests (without the integer-program suite,
which is slow and does not exercise internals). Each mutant is one textual change asserted to match exactly
once; the file is restored after each. Output: `mutation-output.txt`.

Result: **101 mutants: 88 killed, 13 survived.** Of the 13: 10 are equivalent (reasoning below) and 3 were
closed by tests written against them (re-run: killed). No mutant failed to compile.

Spread across the code: `TrialRandomness` 10 (stream derivation, salt, packing, mask, bit shift, scale, key
mixing), cascade support and independent cascade 19 (seed bounds, duplicates, `draw < p` strictness, draw
direction, re-activation, weight scaling, validation, `hasSubmodularTrials`, generator overload), linear
threshold 9 (tolerance window and sign, strict threshold, share, re-activation, degree guard), estimator 11
(trial indexing, trial range, sum of squares, sample variance, guards, standard error), `DiffusionGraph` 6,
`SiteProblem` 10, `PMedian` 31 (argument bounds, site order, exact/heuristic boundary, subset count and its
saturation and overflow, enumeration order and count, tie-breaks in enumeration, greedy, swap and assignment,
swap tolerance and its floor and strictness, pass limit), `SiteAssignment` 5.

## Closed by new tests (red against the mutant first)

| Mutant | Change | Test |
| --- | --- | --- |
| C16, C17 | `IndependentCascade.hasSubmodularTrials` false; protocol default true | `DiffusionModelDeclarationTests`: the cascade declares true, the threshold model and a model that says nothing are false. SeedSelector (step 3 part 2) depends on this flag, and no part-1 test looked at it. |
| P22 | swap tolerance scaled by the best candidate instead of the objective being improved on | `swapToleranceScalesWithCurrent`: a table objective on which the two tolerances settle on different sets ({1, 2} against {0, 3}). |

## Equivalent survivors

| Mutant | Why it cannot change a result |
| --- | --- |
| C8 `min(1, ...)` removed | The draw is in [0, 1), so `draw < p` is true for every `p >= 1`: a probability above 1 fires exactly as 1 does. |
| C10 scale 1 instead of 0 when `maxWeight == 0` | `maxWeight == 0` means every weight is 0, so `base * 0 * scale` is 0 whatever the scale. |
| C12 queue walk `0..<(n - 1)` | Position `n - 1` of the queue exists only if all `n` nodes are active, and then nothing is left to activate. |
| C13 `isFinite` removed from validation | NaN fails `p >= 0`, `+inf` fails `p <= 1`, `-inf` fails `p >= 0`. |
| L8 zero-degree guard removed | Degree 0 means the edge weight is 0, so the share is `0 / 0 = NaN`, and `NaN + 1e-12 >= theta` is false: the node never activates, the same outcome as the guard. |
| E11 `numerator >= 0` | At 0 the expression is `0 / x = 0`, the value the other branch returns. |
| P5 non-strict minimum in the objective | A minimum is the same value whichever of equal costs is taken. |
| P12 enumeration loop `0..<subsets` | The extra step finds the successor of the last subset, `i < 0`, and breaks. |
| P15 `current[i] >= n - k + i` | `current[i] <= n - k + i` is an invariant of the lexicographic successor, so `>=` is `==`. |
| P28 exact result not re-sorted | `enumerate` returns subsets in ascending order, so `picked` is already `chosenSorted`. |

## What the check does not cover

Mutants of the doc comments (they are compiled by the gate, not executed), of the Linux/Swift 6.2.1 behaviour
(not runnable here), and of the integer-program oracle itself. The oracle is checked differently: it must agree
with an enumeration written inside its own test file on four instances for p = 1, 2, 3 before it is trusted to
judge `PMedian`.
