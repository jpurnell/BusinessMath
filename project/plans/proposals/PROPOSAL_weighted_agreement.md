# Proposal: Weighted Agreement Statistics

**Date:** 2026-05-10
**Status:** Draft
**Scope:** Weighted variants of agreement metrics + weighted descriptive statistics primitives
**Depends on:** `PROPOSAL_agreement_statistics.md` (Phases 1–5 must land first)

## Problem

The base agreement statistics module assumes all observations are equally important. In practice, observations often carry different weights:

- **Reliability weighting:** Some measurements are more precise (e.g., taken under better conditions, longer averaging window)
- **Sample size weighting:** When comparing aggregated data, each point may represent a different n
- **Recency weighting:** More recent observations may be more relevant for device validation
- **Clinical importance:** Measurements in a critical range (e.g., hypoglycemia) may matter more

Weighted CCC was described by Lin (1989) as an extension and formalized by King & Chinchilli (2001). Weighted Bland-Altman uses weighted mean/SD of differences.

## What Already Exists

| Component | Status | Notes |
|-----------|--------|-------|
| `weightedAverage(_:weights:)` | ✅ Exists | In `Central Tendency/weightedAverage.swift` |
| `varianceS` / `varianceP` | ✅ Exists | Unweighted only |
| `covarianceS` / `covarianceP` | ✅ Exists | Unweighted only |
| `correlationCoefficient` | ✅ Exists | Unweighted only |
| `concordanceCorrelationCoefficient` | 🔜 Proposed | Unweighted (agreement proposal) |
| `blandAltman` | 🔜 Proposed | Unweighted (agreement proposal) |

**Gap:** The library has `weightedAverage` but no `weightedVariance`, `weightedCovariance`, or `weightedCorrelation`. These are general-purpose primitives that benefit the entire library, not just agreement statistics.

## Proposed Implementation

### Part A: Weighted Descriptive Primitives (general-purpose)

These belong in the existing directories alongside their unweighted counterparts.

```swift
// In Dispersion Around the Mean/variance/

/// Weighted sample variance.
///
/// Uses reliability weights (frequency interpretation):
/// Var_w = (Σ w_i × (x_i - μ_w)²) / (Σ w_i - 1)
///
/// - Parameters:
///   - values: Observations.
///   - weights: Non-negative weights (same length as values).
///   - pop: Sample or population variance.
/// - Returns: Weighted variance.
public func weightedVariance<T: Real>(
    _ values: [T], weights: [T], _ pop: Population = .sample
) throws -> T
```

```swift
// In Dispersion Around the Mean/

/// Weighted standard deviation.
public func weightedStandardDeviation<T: Real>(
    _ values: [T], weights: [T], _ pop: Population = .sample
) throws -> T
```

```swift
// In Covariance and Correlation/

/// Weighted covariance.
///
/// Cov_w(x, y) = (Σ w_i × (x_i - μ_wx) × (y_i - μ_wy)) / (Σ w_i - 1)
public func weightedCovariance<T: Real>(
    _ x: [T], _ y: [T], weights: [T], _ pop: Population = .sample
) throws -> T
```

```swift
// In Covariance and Correlation/

/// Weighted Pearson correlation coefficient.
///
/// r_w = Cov_w(x, y) / (SD_w(x) × SD_w(y))
public func weightedCorrelation<T: Real>(
    _ x: [T], _ y: [T], weights: [T]
) throws -> T
```

### Part B: Weighted CCC

```swift
/// Weighted concordance correlation coefficient.
///
/// Extends Lin's CCC with observation weights per King & Chinchilli (2001).
///
/// CCC_w = (2 × Cov_w(x, y)) / (Var_w(x) + Var_w(y) + (μ_wx - μ_wy)²)
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series.
///   - weights: Non-negative weights (same length as x and y).
///   - confidence: Confidence level for interval.
/// - Returns: `CCCResult` with weighted CCC and confidence bounds.
public func concordanceCorrelationCoefficient<T: Real>(
    _ x: [T], _ y: [T], weights: [T], confidence: T = T(0.95)
) throws -> CCCResult<T>
```

### Part C: Weighted Bland-Altman

```swift
/// Weighted Bland-Altman analysis.
///
/// Computes weighted bias and weighted limits of agreement.
/// Useful when some observations are more reliable than others.
///
/// - Parameters:
///   - x: Measurements from method A.
///   - y: Measurements from method B.
///   - weights: Non-negative weights.
/// - Returns: `BlandAltmanResult` using weighted statistics.
public func blandAltman<T: Real>(
    _ x: [T], _ y: [T], weights: [T]
) throws -> BlandAltmanResult<T>
```

## File Organization

```
Sources/BusinessMath/Statistics/Descriptors/
  Dispersion Around the Mean/
    variance/
      weightedVariance.swift                      — NEW
    weightedStandardDeviation.swift               — NEW
  Covariance and Correlation/
    Covariance/
      weightedCovariance.swift                    — NEW
    correlation coefficient/
      weightedCorrelation.swift                   — NEW
  Agreement/
    weightedConcordanceCorrelation.swift          — NEW
    weightedBlandAltman.swift                     — NEW

Tests/BusinessMathTests/Statistics Tests/Descriptor Tests/
  Dispersion Tests/
    WeightedVarianceTests.swift
  Covariance Tests/
    WeightedCovarianceTests.swift
    WeightedCorrelationTests.swift
  Agreement Tests/
    WeightedCCCTests.swift
    WeightedBlandAltmanTests.swift
```

## Implementation Plan

### Phase 1: Weighted Variance & Standard Deviation (RED → GREEN)

1. **RED** — `WeightedVarianceTests`:
   - Equal weights → same as unweighted variance
   - All weight on one observation → variance 0
   - Known dataset with manual calculation
   - Zero weight on outlier → excludes its influence
   - All-zero weights → throws
   - Negative weight → throws
   - Mismatched lengths → throws
2. **GREEN** — Implement using the reliability-weights formula
3. Dependencies: `weightedAverage` (exists)

### Phase 2: Weighted Covariance & Correlation (RED → GREEN)

1. **RED** — `WeightedCovarianceTests`:
   - Equal weights → matches `covarianceS`
   - Perfect positive with equal weights → matches unweighted
   - Known weighted dataset
   - Mismatched lengths → throws
2. **RED** — `WeightedCorrelationTests`:
   - Equal weights → matches `correlationCoefficient`
   - Heavy weight on concordant pair → r closer to 1
   - Heavy weight on discordant pair → r closer to -1
   - Zero variance (constant) → throws `divisionByZero`
3. **GREEN** — Implement

### Phase 3: Weighted CCC (RED → GREEN)

1. **RED** — `WeightedCCCTests`:
   - Equal weights → matches unweighted CCC
   - Heavy weight on agreeing pair → CCC increases
   - Heavy weight on disagreeing pair → CCC decreases
   - Known dataset with manual calculation
   - Cross-validate: CCC_w = r_w × Cb_w
2. **GREEN** — Compose from weighted primitives
3. Dependencies: `weightedCorrelation`, `weightedVariance`, `weightedAverage`

### Phase 4: Weighted Bland-Altman (RED → GREEN)

1. **RED** — `WeightedBlandAltmanTests`:
   - Equal weights → matches unweighted result
   - Heavy weight on zero-difference pair → bias moves toward 0
   - Known manual calculation
2. **GREEN** — Weighted mean of differences, weighted SD, then LoA
3. Dependencies: `weightedAverage`, `weightedVariance`

## Effort Estimate

| Phase | Estimated Lines | Test Cases | New Dependencies |
|-------|----------------|------------|------------------|
| Weighted variance/SD | ~40 | ~8 | `weightedAverage` (exists) |
| Weighted covariance/correlation | ~50 | ~10 | Phase 1 |
| Weighted CCC | ~35 | ~8 | Phase 2 |
| Weighted Bland-Altman | ~25 | ~6 | Phase 1 |
| **Total** | **~150** | **~32** | |

Estimated effort: 1–2 sessions. The primitives (Phase 1–2) are the real work; Phases 3–4 are thin wrappers.

## Edge Cases

- **Zero total weight:** Throw `BusinessMathError.divisionByZero`
- **Single non-zero weight:** Effectively n=1. Throw `insufficientData` for variance (needs n≥2)
- **Negative weights:** Throw `BusinessMathError.invalidInput` — weights must be non-negative
- **Very large weight ratios:** Numerically stable? The reliability-weights formula handles this naturally, but extreme ratios (10⁶:1) should be tested

## References

- King, T.S. & Chinchilli, V.M. (2001). "A generalized concordance correlation coefficient for continuous and categorical data." *Statistics in Medicine*, 20(14), 2131–2147.
- Bland, J.M. & Altman, D.G. (2007). "Agreement between methods of measurement with multiple observations per individual." *Journal of Biopharmaceutical Statistics*, 17(4), 571–582.

## Not In Scope

- Robust weighted statistics (trimmed weighted means, Winsorized weighted variance)
- Kernel-weighted agreement (smooth weighting by distance from target range)
- Time-varying weights for longitudinal agreement studies
