# Exact rank-sum critical values, with ties, for any panel

**2026-11-12** · branch `feature/rank-sum-critical-values`, two commits on `ad632af9` (main, after
v3.0.0-alpha.13), unreleased and intended as 3.0.0-alpha.14 · 9,047 tests / 844 suites

Asked for by WineTaster's owner: a tasting that allows ties must not use the untied breakpoints
("We're not sending something out that is knowingly wrong"), and the exact figure should hold for
panels larger than any published table.

---

## What was added

- `rankSumDistribution(judgeRanks:)` → `RankSumDistribution<T>`: the exact null distribution of
  one item's rank sum over m judges. Each judge's ranking is a random permutation of that judge's
  own ranks (averaged for ties), so the item's rank from a judge is uniform over that judge's
  ranks, independently across judges. The distribution is their convolution, over doubled sums.
- `rankSumCriticalValues(judgeRanks:alpha:method:)` and `RankSumDistribution.criticalValues(alpha:)`
  → `RankSumCriticalValues<T>`: `lower` is the largest attainable L with P(S ≤ L) ≤ α/2, `upper` the
  smallest U with P(S ≥ U) ≤ α/2, a sum at or beyond either is significant; the tails achieved, the
  non-significant range, `canReachSignificance`, `isDegenerate`.
- `.normalApproximation` (tie-corrected σ), labelled as an approximation, never the default.
- Input the same as `concordanceAnalysis`. Refused by name: no judges, fewer than two items, ragged
  rows, non-finite values, values not multiples of ½, ties not averaged, α outside (0, 1).
- All judges tie everything: a single point, reported (`isDegenerate`, no bounds, nothing
  significant), not thrown.
- DocC article `2.6-RankSumSignificance`, including the multiple-comparison caveat, stated and not
  corrected.

## Exactness

The decision is in exact integer arithmetic: outcome counts are multi-limb integers
(`RankSumExactCounts.swift`, internal; BusinessMath has no big-integer type), and a tail is
compared as count · 2^(k+1) ≤ M · n^m with α = M / 2^k exactly. A float64 pmf with a plain `≤`
gets 2 judges × 20 items wrong (P(S ≤ 5) is exactly 1/40). "Exact" is relative to α as a `Double`
holds it; that can differ from a decimal 0.05 only when n^m exceeds about 10¹⁷ and a tail falls in
a 1.4e-18 gap.

## How it was checked

- Brute force (every position combination, and separately every permutation of every row), nine
  panels up to 5 × 4, with and without ties: pmf to 1e-15.
- Exact Python integers, NumPy and R 4.6.2 on 16 panels up to 100 × 50 and 200 × 20, tied and
  untied: critical values identical at α = 0.01, 0.05, 0.10.
- Monte Carlo, 400,000 permutations of a tied 24 × 12 panel: within one standard error.
- Kramer 1963 (WineTaster's "original" table, after its one-row shift), 165 cells: no single α
  reproduces it (54 cells at 5% two-sided, 82 at 10%); ten cells are asymmetric slips.

## Timings (release, arm64)

100 × 50 in 0.03–0.14 s, 200 × 50 in 0.2–1.3 s, 500 × 50 in 6–23 s; time grows about with the cube
of the judges. Tables beyond 2²⁶ limbs are refused with `resourceExhausted` before allocating.

## Honest notes

- Tests were written first, but the green steps were not committed one by one: the owner's
  mid-task "exact for large panels" change replaced the core, so the history is two commits.
- Testing every item at α flags at least one item in about 44% of null panels on a tied 24 × 12
  panel. Documented, not corrected.
- This summary was written by the coordinating session; the stream's own environment could not
  write it.

## Next

- Owner: review, push, tag v3.0.0-alpha.14.
- WineTaster pins it and uses the exact values for tied tastings, for the method that replaces
  "Calculation", and past the published tables.
