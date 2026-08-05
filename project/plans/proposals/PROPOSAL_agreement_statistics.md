# Proposal: Agreement Statistics Module

**Date:** 2026-05-10
**Status:** Draft
**Scope:** New agreement metrics in `BusinessMath/Statistics/Descriptors/`
**Depends on:** None (self-contained). Phases 4–5 can optionally benefit from `PROPOSAL_distribution_cdfs_and_anova.md` for exact small-sample CIs, but the normal approximation is sufficient for n ≥ 25.

## Problem

BusinessMath has correlation (`correlationCoefficient`), error metrics (`mape`, `mae`, `rmse`), and regression — but no dedicated **agreement statistics** for comparing two measurement methods against each other. Correlation tells you if two series move together; agreement tells you if they actually produce the same values.

This distinction matters in clinical validation (e.g., comparing a wearable device against a reference instrument), sensor fusion, forecasting model comparison, and any domain where two methods measure the same quantity and you need to know if they're interchangeable.

### Motivating Use Case

The Narbis biofeedback app needs to compare Apple Watch HRV measurements against a chest-strap reference device. The standard validation methodology (Bonneval et al. 2025, Lambe et al. 2026) uses Bland-Altman analysis and Lin's CCC — neither of which exists in BusinessMath today.

## What Already Exists

| Function | File | Notes |
|----------|------|-------|
| `correlationCoefficient(_:_:_:)` | `Covariance and Correlation/` | Pearson's r — measures linear association, not agreement |
| `mape(_:_:)` | `Error Metrics/mape.swift` | Already implemented as ratio (not percentage). Excludes zero actuals. |
| `mae(_:_:)` | `Error Metrics/mae.swift` | Mean Absolute Error |
| `rmse(_:_:)` | `Error Metrics/rmse.swift` | Root Mean Squared Error |
| `covariance(_:_:_:)` | `Covariance and Correlation/` | Sample/population covariance |
| `standardDeviation` variants | `Dispersion Around the Mean/` | SD with sample/population |

Lin's CCC builds on top of `correlationCoefficient` and `standardDeviation` — both already available.

## Proposed Functions

### 1. Lin's Concordance Correlation Coefficient (CCC)

**What it measures:** How closely paired observations fall to the 45° identity line (not just any regression line). Combines precision (Pearson r) and accuracy (bias correction factor Cb). A pair of measurements can have r = 0.99 but CCC = 0.5 if there's a systematic offset.

**Formula:**
```
CCC = (2 × r × Sx × Sy) / (Sx² + Sy² + (μx - μy)²)

Where:
  r  = Pearson correlation coefficient
  Sx = standard deviation of x
  Sy = standard deviation of y
  μx = mean of x
  μy = mean of y
```

Equivalently: `CCC = r × Cb` where `Cb = 2 / (v + 1/v + u²)`, `v = Sx/Sy`, `u = (μx - μy) / √(Sx × Sy)`.

**Range:** [-1, 1]. CCC = 1 means perfect agreement. CCC = 0 means no agreement. CCC = -1 means perfect inverse agreement.

**API:**
```swift
/// Result of a concordance correlation coefficient analysis.
public struct CCCResult<T: Real>: Sendable, Equatable {
    /// Lin's concordance correlation coefficient in [-1, 1].
    public let ccc: T

    /// Pearson correlation coefficient (precision component).
    public let pearsonR: T

    /// Bias correction factor Cb (accuracy component). CCC = r × Cb.
    public let biasCorrection: T

    /// Lower bound of the confidence interval.
    public let lowerBound: T

    /// Upper bound of the confidence interval.
    public let upperBound: T

    /// Confidence level used (default 0.95).
    public let confidence: T

    /// Number of paired observations.
    public let count: Int
}

/// Lin's concordance correlation coefficient with confidence interval.
///
/// Measures agreement between two measurement methods by evaluating
/// how closely paired observations fall to the 45° identity line.
/// Unlike Pearson's r, CCC penalizes systematic bias between methods.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - confidence: Confidence level for the interval (default 0.95).
/// - Returns: `CCCResult` containing CCC, decomposition, and confidence bounds.
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
///           `BusinessMathError.insufficientData` if fewer than 2 observations.
///           `BusinessMathError.divisionByZero` if either series has zero variance.
public func concordanceCorrelationCoefficient<T: Real>(
    _ x: [T], _ y: [T], confidence: T = T(0.95)
) throws -> CCCResult<T>
```

Short alias:
```swift
public func linsCCC<T: Real>(_ x: [T], _ y: [T], confidence: T = T(0.95)) throws -> CCCResult<T>
```

**Reference:** Lin, L.I. (1989). "A concordance correlation coefficient to evaluate reproducibility." *Biometrics*, 45(1), 255–268.

### 2. Bland-Altman Analysis

**What it measures:** The agreement between two measurement methods by analyzing the distribution of their differences. The mean difference (bias) shows systematic offset; the limits of agreement (LoA = bias ± 1.96 × SD) show the range within which 95% of differences fall.

**Formula:**
```
differences[i] = x[i] - y[i]
bias = mean(differences)
sd   = standardDeviation(differences, .sample)
loaLower = bias - 1.96 × sd
loaUpper = bias + 1.96 × sd
```

**API:**
```swift
/// Result of a Bland-Altman agreement analysis.
public struct BlandAltmanResult<T: Real>: Sendable, Equatable {
    /// Mean difference (x - y). Positive = x reads higher than y.
    public let bias: T

    /// Standard deviation of the differences.
    public let standardDeviation: T

    /// Lower 95% limit of agreement (bias - 1.96 × SD).
    public let loaLower: T

    /// Upper 95% limit of agreement (bias + 1.96 × SD).
    public let loaUpper: T

    /// Slope of differences regressed on means.
    /// Non-zero indicates proportional bias (disagreement scales with magnitude).
    public let proportionalBiasSlope: T

    /// R² of the proportional bias regression (differences ~ means).
    public let proportionalBiasRSquared: T

    /// Number of paired observations.
    public let count: Int
}

/// Bland-Altman analysis of agreement between two measurement methods.
///
/// Computes the mean difference (bias) and 95% limits of agreement
/// between paired measurements from two methods.
///
/// - Parameters:
///   - x: Measurements from method A.
///   - y: Measurements from method B (same length as x).
/// - Returns: Bias, standard deviation of differences, and limits of agreement.
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
///           `BusinessMathError.insufficientData` if fewer than 2 observations.
public func blandAltman<T: Real>(
    _ x: [T], _ y: [T]
) throws -> BlandAltmanResult<T>
```

**Reference:** Bland, J.M. & Altman, D.G. (1986). "Statistical methods for assessing agreement between two methods of clinical measurement." *The Lancet*, 327(8476), 307–310.

### 3. N-N Interval Differences (Successive Differences)

**What it measures:** The absolute differences between consecutive values in a series. In HRV analysis these are called N-N intervals (normal-to-normal successive differences). Comparing N-N series between devices reveals whether a device preserves beat-to-beat variability or smooths it away.

This is a general-purpose operation — computing `|series[i] - series[i-1]|` — useful beyond HRV.

**API:**
```swift
/// Compute the absolute successive differences of a series.
///
/// Returns an array of `|values[i] - values[i-1]|` for i in 1..<count.
/// The result has length `values.count - 1`.
///
/// - Parameter values: Input series.
/// - Returns: Absolute successive differences.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values.
public func successiveDifferences<T: Real>(_ values: [T]) throws -> [T]
```

This keeps MAPE and Bland-Altman composable: `mape(successiveDifferences(strap), successiveDifferences(watch))` gives N-N MAPE directly.

## File Organization

```
Sources/BusinessMath/Statistics/Descriptors/
  Agreement/
    concordanceCorrelationCoefficient.swift   — Lin's CCC
    blandAltman.swift                         — Bland-Altman analysis + result struct
    successiveDifferences.swift               — |x[i] - x[i-1]| helper

Tests/BusinessMathTests/Statistics Tests/Descriptor Tests/
  Agreement Tests/
    ConcordanceCorrelationCoefficientTests.swift
    BlandAltmanTests.swift
    SuccessiveDifferencesTests.swift
```

Follows the existing `Descriptors/` subdirectory pattern (cf. `Error Metrics/`, `Covariance and Correlation/`).

## Implementation Plan

### Phase 1: Successive Differences (RED → GREEN)

1. **RED** — `SuccessiveDifferencesTests`:
   - `[1, 3, 2, 5]` → `[2, 1, 3]`
   - Single element → throws `insufficientData`
   - Empty array → throws `insufficientData`
   - Constant series → all zeros
   - Negative values → correct absolute differences
2. **GREEN** — Implement `successiveDifferences`
3. Trivial function, no dependencies

### Phase 2: Bland-Altman (RED → GREEN)

1. **RED** — `BlandAltmanTests`:
   - Identical arrays → bias 0, SD 0, LoA (0, 0)
   - Known offset `y = x + 5` → bias -5, SD 0
   - Known dataset with manual calculation → verify bias, SD, LoA to precision
   - Reference values from Bland & Altman (1986) Table 1 if available
   - Mismatched lengths → throws
   - Single pair → throws `insufficientData`
2. **GREEN** — Implement `blandAltman` using existing `mean` and `standardDeviationS`
3. Dependencies: `mean`, `standardDeviationS` (both exist)

### Phase 3: Lin's CCC (RED → GREEN)

1. **RED** — `ConcordanceCorrelationCoefficientTests`:
   - Identical arrays → CCC = 1.0
   - Perfect negative → CCC = -1.0
   - Known offset (high r, low CCC) → verify CCC < r
   - Known scaling (y = 2x) → CCC < 1 despite r = 1
   - Independent random → CCC ≈ 0
   - Textbook example with known CCC value
   - Mismatched lengths → throws
   - Fewer than 2 → throws `insufficientData`
   - Constant x or y → throws `divisionByZero` (zero SD)
2. **GREEN** — Implement using existing `correlationCoefficient`, `mean`, `standardDeviation`
3. Dependencies: all exist in BusinessMath already

### Phase 4: CCC Confidence Intervals (RED → GREEN)

**Theory:** Apply Fisher's z-transform to CCC, compute a normal-approximation CI in z-space, then back-transform via `tanh`.

```
z = atanh(CCC)
SE_z ≈ √( (1 - r²) × CCC² / ((1 - CCC²) × r² × (n - 2)) + 2 × CCC³ × (1 - CCC) × u² / (r × (1 - CCC²)²) + CCC⁴ × u⁴ / (2 × r² × (1 - CCC²)²) )
```

For the large-sample approximation (n ≥ 25), the simplified form is often sufficient:
```
SE_z ≈ 1 / √(n - 2)
```

CI in z-space: `z ± zScore(ci) × SE_z`
CI for CCC: `(tanh(z_lower), tanh(z_upper))`

1. **RED** — `CCCConfidenceIntervalTests`:
   - Perfect agreement (CCC=1) → bounds clamp to 1.0 (atanh saturates)
   - Known dataset (n=30) → verify CI contains true CCC
   - Wider CI at 99% vs 95% for same data
   - Small n (n=5) produces wider CI than large n (n=100)
   - Cross-validate: CI computed manually vs. function output
   - Verify CI is symmetric in z-space (asymmetric in CCC-space)
2. **GREEN** — Integrate into `CCCResult`, using `atanh`, `tanh`, `zScore(ci:)`
3. Dependencies: `atanh`/`tanh` (Real protocol), `zScore(ci:)` (exists)

### Phase 5: Proportional Bias Detection (RED → GREEN)

**Theory:** Regress the Bland-Altman differences `d[i] = x[i] - y[i]` on the means `m[i] = (x[i] + y[i]) / 2`. A statistically significant slope indicates that the disagreement between methods changes with the magnitude of the measurement — i.e., the methods diverge more at higher (or lower) values.

```
slope = regression_slope(means, differences)
r² = rSquared(means, differences)
```

1. **RED** — `ProportionalBiasTests`:
   - Constant offset (y = x + 5) → slope ≈ 0 (uniform bias, not proportional)
   - Proportional relationship (y = 1.1x) → slope ≈ -0.1/(1 + 0.5×0.1) ≈ non-zero
   - Perfect agreement → slope = 0, R² = 0 (or NaN for zero variance)
   - Known dataset with manual slope calculation
   - Verify slope sign: if x reads progressively higher at larger magnitudes → positive slope
2. **GREEN** — Compute means array, call existing `slope(_:_:)` and `rSquared(_:_:)`
3. Dependencies: `slope` (exists), `rSquared` (exists)

## Test References

Each test should cite its expected values:

| Metric | Reference Source |
|--------|----------------|
| Lin's CCC | Lin (1989) Table 1; or cross-validate: compute Pearson r and Cb separately, verify CCC = r × Cb |
| CCC CI | Lin (1989) SE formula; cross-validate symmetry in z-space |
| Bland-Altman | Bland & Altman (1986); or manual computation on small dataset |
| Proportional bias | Manual regression on small dataset; known-proportional synthetic data |
| MAPE (existing) | Already tested |
| Successive diffs | Manual computation (trivial) |

## Edge Cases

- **Zero standard deviation:** If one series is constant, Pearson r is undefined. Lin's CCC should throw `divisionByZero` (consistent with `correlationCoefficient` behavior).
- **Single pair:** Bland-Altman needs SD of differences, which requires n ≥ 2. Throw `insufficientData(required: 2, ...)`.
- **Large bias:** CCC correctly approaches 0 as bias increases, even if r stays high. This is the key property that distinguishes it from Pearson.
- **MAPE with zero actuals:** Already handled by existing `mape` — zeros excluded from denominator.

## Not In Scope (Separate Proposals)

- Bland-Altman with repeated measures — requires mixed-effects model infrastructure (see `PROPOSAL_repeated_measures_agreement.md`)
- Weighted CCC — requires weighted variance/correlation primitives (see `PROPOSAL_weighted_agreement.md`)
- Intraclass Correlation Coefficient (ICC) — ANOVA-based reliability statistic (see `PROPOSAL_icc.md`)
