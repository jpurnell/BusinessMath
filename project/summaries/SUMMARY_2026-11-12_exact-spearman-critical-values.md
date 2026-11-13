# Exact Spearman's ρ critical values and p-values, with ties

**2026-11-12** · branch `feature/spearman-critical-values` on `ad2a2ed8` (v3.0.0-alpha.14), commits
`40a02051`, `13a7bc6b`; released as 3.0.0-alpha.16 (with alpha.15 merged in) · 9,078 tests / 847 suites
before the merge

WineTaster tests each pair of judges' agreement with Spearman's ρ over 4 to 12 wines, using Fisher's
z with the 1.06 factor (`correlationBreakpoint`). The owner wants exact values wherever they can be
computed.

---

## What was added

- `spearmanDistribution(items:)` and `spearmanDistribution(_:vs:)` → `SpearmanDistribution`: the
  attainable ρ values, S = Σd² and their probabilities; tails, p-values and critical values.
- `spearmanCriticalValues(items:alpha:method:)` (the untied table) and
  `spearmanCriticalValues(_:vs:alpha:method:)` (two judges' own tie patterns) →
  `SpearmanCriticalValues`, with the same convention as the alpha.14 rank-sum work: the most extreme
  attainable value with a tail at most α/2 on each side, the non-significant range, and
  `canReachSignificance` (false for 4 untied wines at 5%).
- `spearmanTest(_:vs:alpha:method:)` → `SpearmanTestResult`: ρ, S and the two-sided p-value
  (min(1, 2 × the smaller tail), as R and SciPy), `nil` when a judge tied every wine, which is
  "not computable", never zero agreement.
- `SpearmanSignificanceMethod`: `.exact` (default), `.edgeworth` (R's AS 89 series, untied only) and
  `.tDistribution`; the approximations are always labelled, never chosen silently.

## The method and its guarantee

The null fixes one judge's ranking and permutes the other's averaged ranks uniformly, conditioning
on both tie patterns. The exact distribution is a dynamic programme over positions with alpha.14's
multi-limb integer counts (after van de Wiel & Di Bucchianico 2001), and every decision is made in
exact integers. A budget checked before anything is allocated (2¹⁸ states a layer, 256 MiB in all,
for iOS) admits 17 untied wines (0.3 s, 163 MB in release) and refuses 18 or more; ties shrink the
work. Beyond it, the labelled approximations.

R's `cor.test(exact = TRUE)` is exact only up to n = 9; from 10 it uses the Edgeworth series.

## How it was checked

Brute force (every permutation, n ≤ 8 in Swift, n ≤ 10 in Python); an independent exact Python
programme to n = 20; the closed-form mean and variance; R 4.6.2 (exact to n = 9, Edgeworth and t);
SciPy 1.18.1 (`spearmanr`, and `permutation_test`'s exact enumeration to n = 8, tied); a 10⁶-permutation
Monte Carlo for t on large tied panels; Zar (1984) Table B.19, 117 of 117 cells for n = 4 to 16 and
11 of 18 at n = 17 and 18, where Zar's values are approximate; Lee's York table, 90 of 90.

## What it says about WineTaster's current cutoff

Fisher's z with 1.06, against the exact 5% test, untied: too liberal at 4, 5, 6 and 9 wines (it flags
ρ = 1, 0.9, 0.829 and 0.683, whose exact p-values are 0.083, 0.083, 0.058 and 0.050); the same
decisions at 7, 8, 10, 11 and 12; slightly too strict from 13. WineTaster adopting the exact values
changes saved reports' correlation lines and needs the owner's separate approval.

## Honest notes

- Tests were written first, but no failing state was committed; the first commit is the model and
  its unit tests once green, the second the reference fixture and tests.
- The first SciPy generator passed both samples to `permutation_test`, which then enumerates (n!)²
  arrangements; it reached 5.7 GB before it was stopped. The committed script uses the one-sample form.
- Testing every pair of judges at α raises the chance that some pair is flagged by chance; stated, not
  corrected.
- This summary was written by the coordinating session; the stream's environment could not.
