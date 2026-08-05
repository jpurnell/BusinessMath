# Proposal: Repeated Measures Bland-Altman

**Date:** 2026-05-10
**Status:** Draft
**Scope:** Extended Bland-Altman analysis for repeated measures per subject
**Depends on:**
- `PROPOSAL_agreement_statistics.md` (base Bland-Altman must land first)
- `PROPOSAL_distribution_cdfs_and_anova.md` (provides `oneWayANOVA` for variance decomposition)

## Problem

Standard Bland-Altman assumes one paired measurement per subject. In many validation studies, each subject contributes multiple paired measurements:

- A wearable device worn over multiple days, each day producing a paired reading vs. reference
- A diagnostic test performed at multiple time points per patient
- Repeated calibration readings from two instruments

Using standard Bland-Altman on repeated measures violates the independence assumption — the limits of agreement are too narrow because within-subject correlation inflates the apparent sample size.

Bland & Altman (1999, 2007) describe modifications that separate within-subject from between-subject variability.

## What Already Exists

| Component | Status | Notes |
|-----------|--------|-------|
| `blandAltman` | 🔜 Proposed | Single-measurement version |
| `mean`, `variance` | ✅ | Basic building blocks |
| One-way ANOVA | 🔜 Proposed | In `PROPOSAL_distribution_cdfs_and_anova.md` |
| Mixed-effects models | ❌ Missing | Not available |

## Theory

For n subjects each with m_i replicate pairs (possibly unbalanced):

```
d_ij = x_ij - y_ij     (difference for subject i, replicate j)

Overall bias = mean of all d_ij (or weighted by 1/m_i for balanced contribution)

Variance decomposition:
  σ²_total = σ²_between + σ²_within

  σ²_between = variance of subject means (d̄_i)
  σ²_within  = mean of within-subject variances

Modified LoA = bias ± 1.96 × √(σ²_between + σ²_within)
```

For balanced designs (all m_i equal), this reduces to a one-way random-effects ANOVA on the differences.

## Proposed API

```swift
/// Result of a repeated-measures Bland-Altman analysis.
public struct RepeatedMeasuresBlandAltmanResult<T: Real>: Sendable, Equatable {
    /// Overall mean difference (bias).
    public let bias: T

    /// Between-subject variance component of differences.
    public let varianceBetween: T

    /// Within-subject variance component of differences.
    public let varianceWithin: T

    /// Total variance (between + within).
    public let varianceTotal: T

    /// Lower modified limit of agreement.
    public let loaLower: T

    /// Upper modified limit of agreement.
    public let loaUpper: T

    /// Number of subjects.
    public let subjects: Int

    /// Total number of paired observations.
    public let totalObservations: Int

    /// Whether proportional bias was detected (slope of means vs. differences).
    public let proportionalBiasSlope: T

    /// Coefficient of individual agreement (CIA).
    /// Proportion of total variability due to within-subject differences.
    public let coefficientOfIndividualAgreement: T
}

/// Bland-Altman analysis with repeated measures.
///
/// Accounts for within-subject correlation when each subject contributes
/// multiple paired measurements. Uses variance components to compute
/// modified limits of agreement.
///
/// - Parameters:
///   - pairs: Array of subjects, where each subject is an array of (x, y) pairs.
///   - confidence: Confidence level for limits (default 0.95).
/// - Returns: Repeated-measures Bland-Altman result with variance decomposition.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects
///           or any subject has fewer than 1 pair.
public func blandAltmanRepeatedMeasures<T: Real>(
    _ pairs: [[(x: T, y: T)]],
    confidence: T = T(0.95)
) throws -> RepeatedMeasuresBlandAltmanResult<T>
```

## Implementation Strategy

Two approaches, from simpler to more correct:

### Approach A: Method of Moments (ANOVA-based)

Use one-way ANOVA on the differences grouped by subject:
- `SS_between` and `SS_within` from ANOVA on `d_ij` grouped by subject
- Extract variance components: `σ²_within = MS_within`, `σ²_between = (MS_between - MS_within) / k`
- Handles balanced designs exactly, unbalanced approximately

**Pro:** Simple, reuses ANOVA (from ICC proposal). **Con:** Can produce negative variance estimates; need truncation to zero.

### Approach B: REML Estimation

Restricted maximum likelihood for the random intercept model `d_ij = μ + u_i + ε_ij`.

**Pro:** Optimal, handles unbalanced, always non-negative with bounded optimization. **Con:** Requires iterative optimization (Newton-Raphson or EM), significantly more complex.

**Recommendation:** Start with Approach A. It's standard in the literature (Bland & Altman 2007 use it) and adequate for most validation studies. Add REML as a future option if needed.

## File Organization

```
Sources/BusinessMath/Statistics/Descriptors/
  Agreement/
    blandAltmanRepeatedMeasures.swift             — NEW

Tests/BusinessMathTests/Statistics Tests/Descriptor Tests/
  Agreement Tests/
    BlandAltmanRepeatedMeasuresTests.swift         — NEW
```

## Implementation Plan

### Phase 1: Variance Components via ANOVA (RED → GREEN)

1. **RED** — `BlandAltmanRepeatedMeasuresTests`:
   - Single replicate per subject → reduces to standard Bland-Altman result
   - Balanced design (all subjects same m) → verify against manual calculation
   - Known between/within variance ratio
   - All differences identical across subjects → σ²_between = 0
   - All differences identical within each subject → σ²_within = 0
   - Unbalanced design (different m per subject)
   - Single subject → throws `insufficientData`
   - Empty pairs array → throws
2. **GREEN** — Implement using one-way ANOVA on differences grouped by subject
3. Dependencies: `oneWayANOVA` (from ICC proposal), `mean`

### Phase 2: Coefficient of Individual Agreement

1. **RED** — CIA = σ²_within / (σ²_between + σ²_within)
   - All variability between subjects (CIA → 0) → methods agree within subjects
   - All variability within subjects (CIA → 1) → poor individual agreement
2. **GREEN** — Trivial computation from variance components

## Edge Cases

- **Negative variance estimate:** If MS_between < MS_within, σ²_between would be negative. Truncate to zero and note in result (common practice per Bland & Altman).
- **Single replicate per subject:** Degenerates to standard Bland-Altman. Could return standard result or throw — propose: return valid result with `varianceWithin = 0` (no within-subject info).
- **One subject with many replicates:** Can estimate σ²_within but not σ²_between. Throw `insufficientData(required: 2)` for subjects.

## Effort Estimate

| Phase | Estimated Lines | Test Cases | New Dependencies |
|-------|----------------|------------|------------------|
| Variance components | ~60 | ~10 | `oneWayANOVA` (from ICC proposal) |
| CIA + proportional bias | ~20 | ~4 | `slope` (exists) |
| **Total** | **~80** | **~14** | |

Estimated effort: 1 session (assuming one-way ANOVA already exists from ICC work).

## References

- Bland, J.M. & Altman, D.G. (1999). "Measuring agreement in method comparison studies." *Statistical Methods in Medical Research*, 8(2), 135–160.
- Bland, J.M. & Altman, D.G. (2007). "Agreement between methods of measurement with multiple observations per individual." *Journal of Biopharmaceutical Statistics*, 17(4), 571–582.
- Zou, G.Y. (2013). "Confidence interval estimation for the Bland-Altman limits of agreement with multiple observations per individual." *Statistical Methods in Medical Research*, 22(6), 630–642.

## Not In Scope

- REML-based variance component estimation (iterative, complex — defer)
- Heterogeneous within-subject variance (different σ²_within per subject)
- Time-series structure within subjects (autocorrelation of differences)
- Mixed-effects regression on differences (for modeling covariates)
