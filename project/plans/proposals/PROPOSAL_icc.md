# Proposal: Intraclass Correlation Coefficient (ICC)

**Date:** 2026-05-10
**Status:** Draft
**Scope:** New reliability/agreement metric in `BusinessMath/Statistics/Descriptors/Agreement/`
**Depends on:** `PROPOSAL_distribution_cdfs_and_anova.md` (must land first — provides `fCDF`, `fQuantile`, `oneWayANOVA`)

## Problem

The Intraclass Correlation Coefficient (ICC) measures reliability — how consistently a set of raters (or instruments) rank subjects. It's distinct from Lin's CCC:

| Statistic | Question it answers |
|-----------|-------------------|
| Pearson r | Do two series move together linearly? |
| Lin's CCC | Do two methods produce the same values? |
| ICC | Do multiple raters rank subjects consistently? |

ICC is the standard metric for inter-rater reliability in psychology, medicine (imaging reads, clinical scoring), and industrial QC. There are 10 ICC forms (Shrout & Fleiss 1979, McGraw & Wong 1996) but the three most common are:

- **ICC(1,1)** — Each subject rated by a different random subset of raters (one-way random)
- **ICC(2,1)** — Each subject rated by the same raters, raters are random sample (two-way random, absolute agreement)
- **ICC(3,1)** — Each subject rated by the same raters, raters are fixed (two-way mixed, consistency)

## What Already Exists

| Component | Status | Gap |
|-----------|--------|-----|
| `varianceS` / `varianceP` | ✅ Exists | — |
| `mean` | ✅ Exists | — |
| F-distribution sampling | ✅ `distributionF` | — |
| F-CDF | ⚠️ Private, approximate | Needs public, accurate version |
| One-way ANOVA (SS_B, SS_W, MS_B, MS_W) | ❌ Missing | **Required prerequisite** |
| Two-way ANOVA (SS_subjects, SS_raters, SS_error) | ❌ Missing | Required for ICC(2,1) and ICC(3,1) |

## Proposed Implementation

### Prerequisites (from `PROPOSAL_distribution_cdfs_and_anova.md`)

The following are provided by the foundational distributions proposal and available when this work begins:

- `fCDF(f:df1:df2:)` — exact F-distribution CDF
- `fQuantile(p:df1:df2:)` — inverse F-CDF (for confidence intervals)
- `oneWayANOVA(_:)` → `OneWayANOVAResult<T>` — one-way decomposition with F and p-value

This proposal adds the **two-way ANOVA** (needed for ICC(2,1) and ICC(3,1)) and the ICC itself.

### Two-Way ANOVA (without replication)

```swift
/// Two-way ANOVA result (subjects × raters, no replication).
public struct TwoWayANOVAResult<T: Real>: Sendable, Equatable {
    public let ssSubjects: T
    public let ssRaters: T
    public let ssError: T
    public let ssTotal: T
    public let msSubjects: T
    public let msRaters: T
    public let msError: T
    public let dfSubjects: Int
    public let dfRaters: Int
    public let dfError: Int
}

/// Two-way ANOVA without replication (n subjects × k raters).
/// Input: matrix[i][j] = rating of subject i by rater j.
public func twoWayANOVA<T: Real>(_ ratings: [[T]]) throws -> TwoWayANOVAResult<T>
```

### ICC Functions

```swift
/// ICC model types per Shrout & Fleiss (1979).
public enum ICCModel: Sendable {
    /// One-way random: each subject rated by different raters.
    case oneWayRandom
    /// Two-way random: same raters rate all subjects, raters are random sample.
    case twoWayRandom
    /// Two-way mixed: same raters rate all subjects, raters are fixed.
    case twoWayMixed
}

/// ICC agreement type.
public enum ICCAgreement: Sendable {
    /// Absolute agreement: systematic differences between raters matter.
    case absolute
    /// Consistency: only relative ranking matters, not absolute level.
    case consistency
}

/// ICC result.
public struct ICCResult<T: Real>: Sendable, Equatable {
    /// The ICC value in [0, 1] (can be negative for poor reliability).
    public let icc: T
    /// Lower bound of confidence interval.
    public let lowerBound: T
    /// Upper bound of confidence interval.
    public let upperBound: T
    /// F-statistic for testing ICC > 0.
    public let fStatistic: T
    /// Degrees of freedom (numerator, denominator).
    public let df: (Int, Int)
    /// Number of subjects.
    public let subjects: Int
    /// Number of raters.
    public let raters: Int
}

/// Intraclass Correlation Coefficient.
///
/// - Parameters:
///   - ratings: Matrix where ratings[i][j] = rating of subject i by rater j.
///   - model: The ICC model (one-way random, two-way random, two-way mixed).
///   - agreement: Whether to measure absolute agreement or consistency.
///   - confidence: Confidence level for interval (default 0.95).
/// - Returns: `ICCResult` with ICC value, CI, and test statistics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects or 2 raters.
public func icc<T: Real>(
    _ ratings: [[T]],
    model: ICCModel = .twoWayMixed,
    agreement: ICCAgreement = .absolute,
    confidence: T = T(0.95)
) throws -> ICCResult<T>
```

### ICC Formulas

Given two-way ANOVA components (n subjects, k raters):

```
ICC(1,1) = (MSr - MSw) / (MSr + (k-1)×MSw)
    where MSr = MS_subjects (one-way), MSw = MS_within (one-way)

ICC(2,1) absolute = (MSr - MSe) / (MSr + (k-1)×MSe + k×(MSc - MSe)/n)
    where MSr = MS_subjects, MSc = MS_raters, MSe = MS_error (two-way)

ICC(3,1) consistency = (MSr - MSe) / (MSr + (k-1)×MSe)
    where MSr = MS_subjects, MSe = MS_error (two-way)
```

CI uses F-distribution quantiles (requires public `fCDF` and inverse F).

## File Organization

```
Sources/BusinessMath/Statistics/
  ANOVA/                                          — NEW directory
    oneWayANOVA.swift
    twoWayANOVA.swift
  Descriptors/Agreement/
    icc.swift                                     — ICC function + result struct
    ICCModel.swift                                — Enums

Tests/BusinessMathTests/Statistics Tests/
  ANOVA Tests/
    OneWayANOVATests.swift
    TwoWayANOVATests.swift
  Descriptor Tests/Agreement Tests/
    ICCTests.swift
```

## Implementation Plan

### Phase 1: Two-Way ANOVA (without replication)

1. **RED** — `TwoWayANOVATests`:
   - Balanced design with known textbook values
   - Verify `ssTotal = ssSubjects + ssRaters + ssError`
   - Verify `dfSubjects + dfRaters + dfError = n×k - 1`
   - All raters agree perfectly → ssError = 0
   - All subjects identical → ssSubjects = 0
   - Single subject or single rater → throws `insufficientData`
   - Ragged matrix (unequal row lengths) → throws `mismatchedDimensions`
2. **GREEN** — Implement two-way decomposition
3. Dependencies: `mean` (exists)

### Phase 2: ICC

1. **RED** — `ICCTests`:
   - ICC(1,1): verify against published Shrout & Fleiss (1979) Table 4 values
   - ICC(2,1) absolute: perfect agreement → ICC = 1.0
   - ICC(3,1) consistency: systematic rater offset doesn't affect consistency ICC
   - ICC(2,1) vs ICC(3,1): absolute < consistency when rater bias exists
   - Known dataset: cross-validate against R `irr::icc()` or SPSS output
   - CI width decreases with more subjects
   - Single rater → throws (need k ≥ 2)
   - Single subject → throws (need n ≥ 2)
   - All ratings identical → ICC = 1.0 (or degenerate — handle gracefully)
2. **GREEN** — Implement all forms using two-way ANOVA + `fQuantile` for CIs
3. Dependencies: `twoWayANOVA` (Phase 1), `oneWayANOVA` (from distributions proposal), `fQuantile` (from distributions proposal)

## Effort Estimate

| Phase | Estimated Lines | Test Cases | New Dependencies |
|-------|----------------|------------|------------------|
| Two-Way ANOVA | ~70 | ~10 | `mean` (exists) |
| ICC (all forms + CI) | ~100 | ~15 | `twoWayANOVA`, `oneWayANOVA`, `fQuantile` |
| **Total** | **~170** | **~25** | |

Estimated effort: 1–2 sessions (assuming `PROPOSAL_distribution_cdfs_and_anova.md` has landed).

## References

- Shrout, P.E. & Fleiss, J.L. (1979). "Intraclass correlations: Uses in assessing rater reliability." *Psychological Bulletin*, 86(2), 420��428.
- McGraw, K.O. & Wong, S.P. (1996). "Forming inferences about some intraclass correlation coefficients." *Psychological Methods*, 1(1), 30–46.
- Koo, T.K. & Li, M.Y. (2016). "A guideline of selecting and reporting intraclass correlation coefficients for reliability research." *Journal of Chiropractic Medicine*, 15(2), 155–163.

## Not In Scope

- ICC for agreement with missing data (requires EM or REML estimation)
- Generalizability theory (G-studies / D-studies) — fundamentally different framework
- ICC with more than one measurement per subject-rater cell (needs nested ANOVA)
