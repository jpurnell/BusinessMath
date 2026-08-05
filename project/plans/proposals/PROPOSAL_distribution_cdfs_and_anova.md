# Proposal: Exact Distribution CDFs and One-Way ANOVA

**Date:** 2026-05-10
**Status:** Draft
**Scope:** Foundational infrastructure — exact F/t/chi-squared CDFs via regularized incomplete beta, plus one-way ANOVA
**Priority:** HIGH — multiple downstream proposals depend on this

## Problem

Several distribution CDFs in BusinessMath are either approximate, private, or both:

| Function | Location | Issue |
|----------|----------|-------|
| `fCDF` | `Regression/MultipleLinearRegression.swift:537` | **Private**, crude power-law approximation |
| `tCDF` | `Regression/MultipleLinearRegression.swift:465` | **Private**, crude approximation for df ≤ 100 |
| `chi2cdf` | `Probability Distribution/chi2cdf.swift` | **Public** but defined as `1 - chi2pdf(x, dF)` — i.e., complement of a numerical-integration PDF |
| `chi2pdf` | `Probability Distribution/chi2pdf.swift` | Numerical integration via loop to `x×1000` iterations — slow, imprecise for large x |
| `pValueStudent` | `Probability Distribution/pValueStudent.swift` | Actually computes the **PDF**, not a p-value (misnamed) |

The comments in `MultipleLinearRegression.swift` explicitly say "In production, would use proper incomplete beta function." This proposal delivers that.

Additionally, there is no standalone one-way ANOVA function. The ICC proposal, repeated-measures Bland-Altman proposal, and general hypothesis testing all require it.

## The Key Insight: Regularized Incomplete Beta Function

The F, t, and chi-squared CDFs are all expressible in terms of one function — the **regularized incomplete beta function** I_x(a, b):

```
F-CDF:   P(F ≤ f | d1, d2)  = I_x(d2/2, d1/2)      where x = d2/(d2 + d1×f)
t-CDF:   P(T ≤ t | ν)       = 1 - ½ × I_x(ν/2, ½)  where x = ν/(ν + t²)
χ²-CDF:  P(X ≤ x | k)       = 1 - I_x(k/2, ?)      ... or use regularized lower incomplete gamma
```

So implementing one function (`regularizedIncompleteBeta`) gives us exact CDFs for all three major test distributions.

## What Already Exists

| Component | Status | Notes |
|-----------|--------|-------|
| `T.gamma()` | ✅ via Real | Gamma function (exact, from swift-numerics) |
| `distributionBeta(alpha:beta:)` | ✅ | Random variates — sampling, not CDF |
| `distributionF(df1:df2:)` | ✅ | Random variates via chi-squared ratio |
| `normalCDF(x:mean:stdDev:)` | ✅ Public | Exact via `erf` |
| `inverseNormalCDF(p:mean:stdDev:)` | ✅ Public | Exact via `erfInverse` |
| `erfInverse` | ✅ Public | Rational approximation |
| `chi2pdf` | ⚠️ Public but slow | Numerical integration |
| `chi2cdf` | ⚠️ Public but imprecise | `1 - chi2pdf` |

## Proposed Functions

### 1. Regularized Incomplete Beta Function

The workhorse. Uses Lentz's continued fraction algorithm (same as GSL, Numerical Recipes, scipy).

```swift
/// Regularized incomplete beta function I_x(a, b).
///
/// Computes the ratio of the incomplete beta function to the complete beta function:
/// I_x(a, b) = B(x; a, b) / B(a, b)
///
/// This is the CDF of the Beta distribution and the building block for
/// F-distribution, t-distribution, and binomial CDFs.
///
/// - Parameters:
///   - x: Upper limit of integration, in [0, 1].
///   - a: First shape parameter (a > 0).
///   - b: Second shape parameter (b > 0).
/// - Returns: I_x(a, b) in [0, 1].
/// - Throws: `BusinessMathError.invalidInput` if x ∉ [0,1] or a,b ≤ 0.
public func regularizedIncompleteBeta<T: Real>(x: T, a: T, b: T) throws -> T
```

**Algorithm:** Lentz's modified continued fraction with the DLMF 8.17.22 representation. For numerical stability, use the identity `I_x(a,b) = 1 - I_{1-x}(b,a)` when `x > (a+1)/(a+b+2)`.

**Accuracy target:** Relative error < 10⁻¹² for Double, matching scipy/GSL.

### 2. Log-Beta Function

Needed internally for the continued fraction normalization.

```swift
/// Natural logarithm of the Beta function: ln(B(a, b)) = ln(Γ(a)) + ln(Γ(b)) - ln(Γ(a+b))
public func logBeta<T: Real>(_ a: T, _ b: T) -> T
```

### 3. Exact F-Distribution CDF (public replacement)

```swift
/// Cumulative distribution function of the F-distribution.
///
/// P(F ≤ f | df1, df2) using the regularized incomplete beta function.
///
/// - Parameters:
///   - f: The F-statistic value (f ≥ 0).
///   - df1: Numerator degrees of freedom (> 0).
///   - df2: Denominator degrees of freedom (> 0).
/// - Returns: Probability P(F ≤ f) in [0, 1].
public func fCDF<T: Real>(f: T, df1: Int, df2: Int) throws -> T
```

### 4. Exact t-Distribution CDF (public replacement)

```swift
/// Cumulative distribution function of Student's t-distribution.
///
/// P(T ≤ t | ν) using the regularized incomplete beta function.
///
/// - Parameters:
///   - t: The t-statistic value.
///   - df: Degrees of freedom (> 0).
/// - Returns: Probability P(T ≤ t) in [0, 1].
public func tCDF<T: Real>(t: T, df: Int) throws -> T
```

### 5. Exact Chi-Squared CDF (replaces existing)

```swift
/// Cumulative distribution function of the chi-squared distribution.
///
/// Replaces the existing approximate `chi2cdf`. Uses the regularized
/// lower incomplete gamma function (or equivalently, incomplete beta).
///
/// - Parameters:
///   - x: The chi-squared statistic value (x ≥ 0).
///   - df: Degrees of freedom (> 0).
/// - Returns: Probability P(X ≤ x) in [0, 1].
public func chiSquaredCDF<T: Real>(x: T, df: Int) throws -> T
```

### 6. Inverse F-CDF (for confidence intervals)

```swift
/// Quantile function (inverse CDF) of the F-distribution.
///
/// Finds f such that P(F ≤ f | df1, df2) = p. Uses bisection + Newton refinement.
///
/// - Parameters:
///   - p: Probability in (0, 1).
///   - df1: Numerator degrees of freedom.
///   - df2: Denominator degrees of freedom.
/// - Returns: The f value at the given quantile.
public func fQuantile<T: Real>(p: T, df1: Int, df2: Int) throws -> T
```

### 7. Inverse t-CDF (public replacement)

```swift
/// Quantile function (inverse CDF) of Student's t-distribution.
///
/// Replaces the private `tQuantile` in MultipleLinearRegression.
///
/// - Parameters:
///   - p: Probability in (0, 1).
///   - df: Degrees of freedom.
/// - Returns: The t value at the given quantile.
public func tQuantile<T: Real>(p: T, df: Int) throws -> T
```

### 8. One-Way ANOVA

```swift
/// Result of a one-way analysis of variance.
public struct OneWayANOVAResult<T: Real>: Sendable, Equatable {
    /// Sum of squares between groups.
    public let ssBetween: T
    /// Sum of squares within groups.
    public let ssWithin: T
    /// Total sum of squares.
    public let ssTotal: T
    /// Mean square between groups (ssBetween / dfBetween).
    public let msBetween: T
    /// Mean square within groups (ssWithin / dfWithin).
    public let msWithin: T
    /// F-statistic (msBetween / msWithin).
    public let fStatistic: T
    /// p-value from the F-distribution.
    public let pValue: T
    /// Degrees of freedom between groups (k - 1).
    public let dfBetween: Int
    /// Degrees of freedom within groups (N - k).
    public let dfWithin: Int
    /// Number of groups.
    public let groupCount: Int
    /// Total number of observations.
    public let totalCount: Int
}

/// One-way analysis of variance (ANOVA).
///
/// Tests whether the means of k groups are all equal against the alternative
/// that at least one group mean differs.
///
/// - Parameter groups: Array of groups, where each group is an array of observations.
///   Groups may have different sizes (unbalanced design is supported).
/// - Returns: ANOVA table with SS, MS, F-statistic, and p-value.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups
///           or any group has fewer than 1 observation.
///           `BusinessMathError.divisionByZero` if all observations are identical
///           (zero within-group variance).
public func oneWayANOVA<T: Real>(_ groups: [[T]]) throws -> OneWayANOVAResult<T>
```

## File Organization

```
Sources/BusinessMath/Statistics/Probability Distribution/
  Beta Distribution/                              — NEW directory
    regularizedIncompleteBeta.swift               — Core algorithm
    logBeta.swift                                 — ln(B(a,b))
  F Distribution/                                 — NEW directory
    fCDF.swift                                    — Exact F-CDF (public)
    fQuantile.swift                               — Inverse F-CDF
  T Distribution/                                 — NEW directory
    tCDF.swift                                    — Exact t-CDF (public)
    tQuantile.swift                               — Inverse t-CDF (public)
  chi2cdf.swift                                   — REPLACE with exact version
  chi2pdf.swift                                   — KEEP (but note: rarely needed directly)

Sources/BusinessMath/Statistics/
  ANOVA/                                          — NEW directory
    oneWayANOVA.swift

Tests/BusinessMathTests/Statistics Tests/
  Probability Distribution Tests/
    RegularizedIncompleteBetaTests.swift
    FCDFTests.swift
    TCDFTests.swift
    ChiSquaredCDFTests.swift
  ANOVA Tests/
    OneWayANOVATests.swift
```

## Implementation Plan

### Phase 1: Regularized Incomplete Beta (RED → GREEN)

This is the critical-path function. Everything else builds on it.

**Algorithm: Lentz's continued fraction**

```
I_x(a, b) = (x^a × (1-x)^b) / (a × B(a,b)) × CF(x, a, b)

where CF is the continued fraction with coefficients:
  d_{2m+1} = -(a+m)(a+b+m)x / ((a+2m)(a+2m+1))
  d_{2m}   = m(b-m)x / ((a+2m-1)(a+2m))
```

1. **RED** — `RegularizedIncompleteBetaTests`:
   - `I_0(a,b) = 0` for any a, b > 0
   - `I_1(a,b) = 1` for any a, b > 0
   - `I_0.5(1,1) = 0.5` (uniform distribution — median)
   - `I_x(1,1) = x` (uniform CDF is identity)
   - `I_x(a,b) + I_{1-x}(b,a) = 1` (symmetry identity)
   - Known values from tables: `I_0.3(2,5)` ≈ 0.83692 (scipy reference)
   - Large a, b (stability): `I_0.5(100,100)` ≈ 0.5
   - Very small x: `I_0.001(2,3)` → verify against scipy
   - x outside [0,1] → throws `invalidInput`
   - a or b ≤ 0 → throws `invalidInput`
2. **GREEN** — Implement Lentz's continued fraction with convergence tolerance 10⁻¹²
3. Dependencies: `T.gamma()` (Real protocol), `logBeta` (implement first)

### Phase 2: Exact F-CDF and Inverse (RED → GREEN)

1. **RED** — `FCDFTests`:
   - `fCDF(f: 0, df1: _, df2: _) = 0`
   - `fCDF(f: 1, df1: 5, df2: 5)` ≈ 0.5 (F(k,k) is symmetric around 1)
   - Known critical values: `fCDF(f: 4.26, df1: 3, df2: 20)` ≈ 0.98 (standard table)
   - Cross-validate against existing (approximate) `fCDF` for sanity
   - Verify `fQuantile(fCDF(f, df1, df2), df1, df2) ≈ f` (round-trip)
   - `fCDF(f: 3.89, df1: 2, df2: 46)` — verify against R/scipy reference
   - df1 or df2 ≤ 0 → throws
2. **GREEN** — Implement: `fCDF(f, d1, d2) = I_x(d2/2, d1/2)` where `x = d2/(d2 + d1×f)`
3. **GREEN** — Implement `fQuantile` using bisection + Newton refinement
4. Dependencies: `regularizedIncompleteBeta`

### Phase 3: Exact t-CDF and Inverse (RED → GREEN)

1. **RED** — `TCDFTests`:
   - `tCDF(t: 0, df: _) = 0.5` (symmetric distribution)
   - `tCDF(t: 1.96, df: ∞)` ≈ 0.975 (converges to normal)
   - `tCDF(t: 2.776, df: 4)` ≈ 0.975 (standard table value)
   - Negative t: `tCDF(t: -t, df: ν) = 1 - tCDF(t: t, df: ν)` (symmetry)
   - Large df (df=1000): should match `normalCDF` closely
   - Round-trip: `tQuantile(tCDF(t, df), df) ≈ t`
   - Compare against existing `pValueStudent` (which is actually PDF) for consistency
2. **GREEN** — Implement: `tCDF(t, ν) = 1 - ½ × I_x(ν/2, ½)` where `x = ν/(ν + t²)`, adjusted for sign
3. **GREEN** — Implement `tQuantile` using bisection + Newton
4. Dependencies: `regularizedIncompleteBeta`

### Phase 4: Exact Chi-Squared CDF (RED → GREEN)

1. **RED** — `ChiSquaredCDFTests`:
   - `chiSquaredCDF(x: 0, df: _) = 0`
   - `chiSquaredCDF(x: df, df: df)` ≈ 0.5 for large df (mean of χ² is df)
   - Known: `chiSquaredCDF(x: 7.815, df: 3)` ≈ 0.95 (standard table)
   - Known: `chiSquaredCDF(x: 3.841, df: 1)` ≈ 0.95
   - Cross-validate against existing `chi2cdf` (which should agree for moderate x)
   - Large x, small df: verify approaches 1.0 cleanly
2. **GREEN** — Implement via regularized lower incomplete gamma, or equivalently `I_x(df/2, ?)` relationship
3. Dependencies: `regularizedIncompleteBeta` (chi-squared CDF = regularized lower incomplete gamma = special case of incomplete beta)

### Phase 5: One-Way ANOVA (RED → GREEN)

1. **RED** — `OneWayANOVATests`:
   - Three equal groups with known means → verify SS_B, SS_W, MS, F manually
   - All groups identical → F = 0, p ≈ 1.0
   - Groups with very different means → large F, small p
   - Unbalanced design (groups of size 3, 5, 7) → correct df and SS
   - Single observation per group → SS_W = 0, F undefined → throws `divisionByZero`
   - Single group → throws `insufficientData`
   - Empty group → throws `insufficientData`
   - Textbook dataset (e.g., Montgomery "Design of Experiments" example)
   - Verify: `ssTotal = ssBetween + ssWithin`
   - Verify: `dfBetween + dfWithin = totalCount - 1`
   - Verify p-value against `fCDF` (internal consistency)
2. **GREEN** — Implement:
   ```
   Grand mean = mean of all observations
   SS_B = Σ n_i × (mean_i - grand_mean)²
   SS_W = Σ Σ (x_ij - mean_i)²
   df_B = k - 1
   df_W = N - k
   MS_B = SS_B / df_B
   MS_W = SS_W / df_W
   F = MS_B / MS_W
   p = 1 - fCDF(f: F, df1: df_B, df2: df_W)
   ```
3. Dependencies: `mean` (exists), `fCDF` (Phase 2)

### Phase 6: Cleanup and Migration

1. Update `MultipleLinearRegression.swift` to call the new public `fCDF` and `tCDF` instead of its private approximations
2. Remove private `fCDF`, `tCDF`, `tQuantile`, `normalCDF`, `normalQuantile` from MultipleLinearRegression.swift
3. Deprecate or replace old `chi2cdf`/`chi2pdf` — add `@available(*, deprecated, renamed: "chiSquaredCDF")` or just replace in-place
4. Fix `pValueStudent` naming — either rename to `studentTPDF` or add a proper `tPValue` that returns the actual two-tailed p-value using `tCDF`
5. All existing tests must continue to pass

## Edge Cases

- **Extreme parameters:** Very large df (>10000) — continued fraction converges slowly. Use normal approximation as fallback for df > threshold.
- **x very close to 0 or 1:** Incomplete beta can lose precision. The symmetry identity `I_x(a,b) = 1 - I_{1-x}(b,a)` handles this.
- **a or b very small (< 0.01):** Edge case for continued fraction convergence. Test with a = 0.5 (chi-squared df=1 case).
- **Overflow in `x^a × (1-x)^b`:** Work in log space: `exp(a×log(x) + b×log(1-x) - logBeta(a,b))`.
- **F = 0:** `fCDF(0, _, _) = 0` by convention.
- **t = 0:** `tCDF(0, _) = 0.5` by symmetry.

## Effort Estimate

| Phase | Estimated Lines | Test Cases | Complexity |
|-------|----------------|------------|------------|
| Regularized incomplete beta | ~80 | ~10 | High (numerical algorithm) |
| F-CDF + inverse | ~40 | ~8 | Low (wrapper) |
| t-CDF + inverse | ~40 | ~8 | Low (wrapper) |
| Chi-squared CDF | ~25 | ~6 | Low (wrapper) |
| One-way ANOVA | ~50 | ~10 | Medium |
| Cleanup/migration | ~30 (net deletion) | ~5 (regression) | Low |
| **Total** | **~265** | **~47** | |

Estimated effort: 2 sessions. Phase 1 is the bulk of the intellectual work; Phases 2–4 are thin wrappers once it exists.

## Downstream Unblocks

Once this proposal lands, the following become implementable:

| Proposal | What it unblocks |
|----------|-----------------|
| `PROPOSAL_icc.md` | F-quantile for ICC confidence intervals, one-way ANOVA for variance decomposition |
| `PROPOSAL_repeated_measures_agreement.md` | One-way ANOVA on grouped differences |
| `PROPOSAL_agreement_statistics.md` Phase 4 | More accurate CCC CI (optional improvement over normal approx) |
| Future: Two-sample t-test | Exact p-values via `tCDF` |
| Future: Chi-squared goodness-of-fit | Exact p-values via `chiSquaredCDF` |
| Future: ANOVA post-hoc tests (Tukey HSD, etc.) | Requires one-way ANOVA + studentized range distribution |

## References

- Press, W.H. et al. (2007). *Numerical Recipes*, 3rd ed. Cambridge. §6.4 "Incomplete Beta Function."
- DLMF §8.17. "Incomplete Beta Functions." https://dlmf.nist.gov/8.17
- Lentz, W.J. (1976). "Generating Bessel functions in Mie scattering calculations using continued fractions." *Applied Optics*, 15(3), 668–671.
- Didonato, A.R. & Morris, A.H. (1992). "Algorithm 708: Significant digit computation of the incomplete beta function ratios." *ACM TOMS*, 18(3), 360–373.

## Not In Scope

- Two-way ANOVA (separate proposal — needed for ICC(2,1) and ICC(3,1))
- Repeated-measures ANOVA (separate proposal)
- ANOVA post-hoc tests (Tukey HSD, Scheffé, Bonferroni) — separate proposal
- Non-central F/t/chi-squared distributions (needed for power analysis — future)
- Beta distribution PDF/CDF as named `betaCDF` wrapper (trivial once incomplete beta exists, but not high priority)
