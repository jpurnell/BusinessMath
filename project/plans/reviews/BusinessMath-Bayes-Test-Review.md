# BusinessMath Bayes tests: review

*September 2026. Covers Bayes Tests.swift — one suite, five tests, one function (`bayes(_:_:_:)`). Companion to the distribution, simulation, statistics and time-series reviews.*

*All reference values recomputed in Python.*

## 1. Summary

Five tests, no structural problems, and every fix is mechanical. The file has no unseeded randomness, no self-recomputation, no silent skips and no stress tests. Its weaknesses are of two kinds:

1. **The one case that can actually break — a zero denominator — is not tested.** The test that looks like it probes the denominator (`perfectTestAccuracy`) probes it in the one direction that cannot fail.
2. **Three of five tests use ranges or loose tolerances where the exact value is available.**

There is also one missing property: nothing in the file can detect a transposed sensitivity and false-positive rate, and the test that appears designed to catch that is invariant under the swap.

The function is `P(D|+) = P(D)·P(+|D) / (P(D)·P(+|D) + P(¬D)·P(+|¬D))`, so all of this is checkable exactly.

## 2. The zero-denominator gap

`perfectTestAccuracy` uses prior 0.10, sensitivity 1.0, FPR 0.0. The denominator is 0.10·1.0 + 0.90·0.0 = 0.1, a perfectly ordinary number, and the result is exactly 1.0. So the test named for the degenerate case exercises none of the degeneracy.

The cases where the denominator is genuinely zero:

| Inputs | Denominator | Current result |
|---|---|---|
| prior 0.0, sensitivity anything, FPR 0.0 | 0·s + 1·0 = 0 | 0/0 = NaN |
| prior 1.0, sensitivity 0.0, FPR anything | 1·0 + 0·f = 0 | 0/0 = NaN |
| prior 0.0, sensitivity 0.99, FPR 0.02 | 0 + 0.02 | 0.0 — fine, and worth pinning |
| prior 1.0, sensitivity 0.99, FPR 0.02 | 0.99 + 0 | 1.0 — fine, and worth pinning |

The first two are the ones with no contract. A negative test result on a disease with zero prevalence has no defined posterior, and NaN is a defensible answer — but it should be the *stated* answer, not an accident of the arithmetic. This is the same open-contract pattern as the binomial descriptors in the statistics review: pick NaN or throw, then pin it.

```swift
@Test("A zero denominator has a defined result")
func degenerateDenominator() {
    // Both inputs impossible: no evidence pathway exists.
    #expect(bayes(0.0, 0.99, 0.0).isNaN)
    #expect(bayes(1.0, 0.0, 0.5).isNaN)

    // A zero prior with a nonzero false-positive rate is not degenerate.
    #expect(identical(bayes(0.0, 0.99, 0.02), 0.0))
    #expect(identical(bayes(1.0, 0.99, 0.02), 1.0))
}
```

The two boundary rows are exact — `0.0 * 0.99 / 0.02` is exactly 0 and `0.99 / 0.99` is exactly 1 — so `identical` is the right claim, not a tolerance.

## 3. Exact values for the loose assertions

| Test | Current assertion | Exact value |
|---|---|---|
| `medicalTestCase` | `abs(r - 1/3) < 1e-6` | exactly 1/3 = 0.3333333333333333 |
| `highPriorProbability` | `r > 0.95` | 36/37 = 0.9729729729729729 |
| `lowPriorImperfectTest` | `0.01 < r < 0.02` | 0.018664047151277015 |
| `symmetricCase` | `abs(r - 0.80) < 1e-9` | exactly 0.8 |
| `perfectTestAccuracy` | `abs(r - 1.0) < 1e-6` | exactly 1.0 |

Notes on the exactness claims:

- **`medicalTestCase`.** The arithmetic is 0.0099 / 0.0297. In binary that is not exactly representable as 1/3, so `identical(r, 1.0/3.0)` may fail by an ulp depending on the order of operations. A relative bound near 1e-15 is the honest claim, and it is nine orders of magnitude tighter than the current 1e-6.
- **`symmetricCase` and `perfectTestAccuracy`.** 0.5·0.8 / (0.5·0.8 + 0.5·0.2) = 0.4/0.5, and 0.1/0.1. Both are exact in binary, so `exactlyEqual` states the claim. The existing 1e-9 on `symmetricCase` is already the tightest bound in the file, which suggests the author knew it was exact.
- **`highPriorProbability` and `lowPriorImperfectTest`** are the two assertions that currently prove almost nothing. `> 0.95` admits any value in a 5-point range; `0.01 < r < 0.02` admits a 2× range around a value known to 17 digits. Both are computed from four multiplications and one division, so ~1e-15 relative is achievable.

`lowPriorImperfectTest` deserves to stay as a *named* case even after tightening: it is the base-rate-fallacy illustration (a 95%-sensitive test on a 0.1%-prevalence disease yields a 1.9% posterior), and the comment says so. Pinning the value keeps the pedagogical point and adds a real check.

## 4. The missing property: sensitivity/FPR transposition

A plausible implementation error is swapping the second and third arguments, or applying `P(+|¬D)` to `P(D)` instead of to `P(¬D)`. Nothing in the file catches that:

- `symmetricCase` looks designed for it, but at prior 0.5 with `s = 0.8` and `f = 0.2` the formula is invariant under the swap (both give 0.8), so it cannot distinguish them.
- `perfectTestAccuracy` has `f = 0.0`, so a swap gives 0.1·0 / (0.1·0 + 0.9·1) = 0 rather than 1 — it would catch this one. But it is the only test that would, and only by accident.

The discriminating check is the odds form, which is also the property most worth documenting:

```swift
@Test("Posterior odds are prior odds times the likelihood ratio")
func posteriorOddsIdentity() {
    for (prior, sensitivity, fpr) in [(0.01, 0.99, 0.02), (0.3, 0.8, 0.15), (0.75, 0.6, 0.4)] {
        let posterior = bayes(prior, sensitivity, fpr)
        let priorOdds = prior / (1.0 - prior)
        let expected = priorOdds * (sensitivity / fpr)
        let posteriorOdds = posterior / (1.0 - posterior)
        #expect(abs(posteriorOdds - expected) / expected < 1e-14)
    }
}
```

This is not self-recomputation in the sense the statistics review warns about: the odds form is an algebraically distinct route to the same quantity, and it is asymmetric in `sensitivity` and `fpr`, so a transposition fails it at every one of those three points.

Two related properties worth one test each:

- **Monotonicity in the prior.** With `sensitivity > fpr`, the posterior strictly increases in the prior. Asserting this over a grid catches a sign or placement error in the `(1 - prior)` term.
- **An uninformative test returns the prior.** When `sensitivity == fpr`, the posterior equals the prior exactly, for any prior. That is a one-line exact check and it pins the normalisation.

## 5. Input validation

No test covers:

| Input | Question |
|---|---|
| prior < 0 or > 1 | NaN, clamp, or throw? |
| sensitivity or FPR outside [0, 1] | Same |
| any argument NaN | Propagate? |
| any argument infinite | — |

The library is already inconsistent on this class of question elsewhere (the statistics review lists `mean` propagating NaN while `harmonicMean` throws), so this is a decision to make once and apply. Given that `bayes` is a three-probability function, a `precondition` or a throwing overload both read reasonably; silent NaN is the weakest option because a NaN posterior deep in a decision model is hard to trace back to a bad prior.

## 6. Smaller items

- **Naming.** The parameters are `probabilityD`, `probabilityTrueGivenD`, `probabilityTrueGivenNotD`, which is clear, but the test comments call the third one both "2% false positive rate" and "(1 - specificity)". Those are the same thing; saying it once avoids the impression that two different quantities are in play.
- **`import Numerics`** is unused in this file.
- **Coverage of the type.** Every test uses `Double`. If `bayes` is generic over a floating-point type, one `Float` case confirms the constraint compiles and the arithmetic holds.
- **No `Float`/generic tests and no `identical` usage.** This file predates the FloatingPointClaims vocabulary; the exact cases in §3 are where it applies.

## 7. Recommended file after the changes

Eight tests instead of five:

1. `medicalTestCase` — base-rate classic, pinned to 1/3 at ~1e-15 relative.
2. `lowPriorImperfectTest` — base-rate fallacy, pinned to 0.018664047151277015.
3. `highPriorProbability` — pinned to 36/37.
4. `symmetricCase` — `exactlyEqual(r, 0.8)`.
5. `perfectTestAccuracy` — `exactlyEqual(r, 1.0)`, renamed to say it is the no-false-positive case rather than the degenerate one.
6. `degenerateDenominator` — the four rows in §2.
7. `posteriorOddsIdentity` — transposition and normalisation.
8. `uninformativeTestReturnsPrior` — `sensitivity == fpr` over a grid of priors.

Plus a validation test once §5 is decided.

## 8. Gate rules this file exercises

Nothing new, but three existing proposals apply:

- **Contract-free behaviour at boundaries.** The zero-denominator case is not currently asserted at all, so no gate flags it. The fixture-coverage report proposed in the statistics review — public functions with no boundary test — is what would surface it.
- **Tolerance looser than the reference's own precision.** `medicalTestCase` at 1e-6 against a value known exactly is the mild form of this; `highPriorProbability` at `> 0.95` is the range form.
- **Display name versus body.** `perfectTestAccuracy` describes a degenerate case its body does not reach. The rule flags names referencing a symbol the body never calls; this is the weaker semantic version, which no static rule will catch — it is a review finding, not a gate finding.

## Appendix. Verified values

| Inputs (prior, sensitivity, FPR) | Posterior |
|---|---|
| 0.01, 0.99, 0.02 | 1/3 = 0.3333333333333333 |
| 0.80, 0.90, 0.10 | 36/37 = 0.9729729729729729 |
| 0.10, 1.00, 0.00 | 1.0 exactly |
| 0.001, 0.95, 0.05 | 0.018664047151277015 |
| 0.50, 0.80, 0.20 | 0.8 exactly |
| 0.0, 0.99, 0.0 | NaN (0/0) |
| 1.0, 0.0, 0.5 | NaN (0/0) |
| 0.0, 0.99, 0.02 | 0.0 exactly |
| 1.0, 0.99, 0.02 | 1.0 exactly |
| any prior, sensitivity == FPR | the prior, exactly |
