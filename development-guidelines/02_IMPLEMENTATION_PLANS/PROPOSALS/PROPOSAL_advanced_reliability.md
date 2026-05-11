# Proposal: Advanced Agreement and Reliability Statistics

**Date:** 2026-05-11
**Status:** Draft
**Scope:** Six advanced reliability/agreement extensions across `BusinessMath/Statistics/`
**Depends on:**
- `PROPOSAL_icc.md` (ICC, two-way ANOVA — must land first)
- `PROPOSAL_weighted_agreement.md` (weighted variance/covariance/CCC — must land first)
- `PROPOSAL_repeated_measures_agreement.md` (repeated-measures Bland-Altman — must land first)
- `PROPOSAL_distribution_cdfs_and_anova.md` (one-way ANOVA, F-distribution CDF — must land first)
- `PROPOSAL_agreement_statistics.md` (base CCC, Bland-Altman — must land first)

## Problem

The existing and proposed agreement statistics in BusinessMath cover the common cases: balanced ICC, method-of-moments repeated-measures Bland-Altman, unweighted and weighted CCC, and standard Bland-Altman. However, real-world reliability studies regularly encounter conditions that these tools cannot handle:

1. **Missing data** — Raters miss subjects. The current ICC requires a complete rectangular matrix `[[T]]` where every rater rates every subject. In multi-site clinical trials, busy raters, and crowdsourced labeling tasks, some cells are always missing.

2. **Study design optimization** — ICC gives a single reliability number, but researchers need to answer "how many raters do I need for adequate reliability?" Generalizability Theory (G-theory) decomposes variance into multiple facets and predicts reliability for hypothetical designs.

3. **Nested study designs** — The current two-way ANOVA assumes a fully crossed design (every rater rates every subject). In nested designs (each patient seen by different doctors), the ANOVA decomposition is fundamentally different.

4. **Negative variance estimates** — The method-of-moments approach in `blandAltmanRepeatedMeasures` can produce negative between-subject variance estimates when MS_between < MS_within. REML estimation is the standard remedy.

5. **Outlier sensitivity** — Weighted statistics are particularly vulnerable to extreme observations with high weight. Robust alternatives (trimmed and Winsorized weighted statistics) provide resistance to contamination.

6. **Temporal and spatial agreement patterns** — In longitudinal validation, agreement may vary over time or across the measurement range. Kernel-weighted and time-varying agreement statistics capture these dynamics.

### Use Cases

| Scenario | Required Module |
|----------|----------------|
| Multi-site clinical trial with missing rater assignments | ICC with Missing Data |
| Planning a reliability study: "How many raters do I need?" | G-theory D-study |
| Each patient seen by a different set of doctors | Nested ANOVA |
| Validation study with unbalanced repeated measures and negative variance | REML Variance Components |
| Device comparison with outlier readings from sensor glitches | Robust Weighted Statistics |
| Wearable validation over weeks — does agreement degrade? | Kernel/Time-Varying Agreement |

## What Already Exists

| Component | Status | Location | Gap |
|-----------|--------|----------|-----|
| `icc(_:model:agreement:confidence:)` | Implemented | `Agreement/icc.swift` | Requires complete `[[T]]` — no missing data |
| `ICCModel`, `ICCAgreement`, `ICCResult` | Implemented | `Agreement/icc.swift` | — |
| `twoWayANOVA(_:)` | Implemented | `ANOVA/twoWayANOVA.swift` | Crossed design only, no nesting |
| `oneWayANOVA(_:)` | Implemented | `ANOVA/oneWayANOVA.swift` | — |
| `blandAltmanRepeatedMeasures(_:)` | Implemented | `Agreement/blandAltmanRepeatedMeasures.swift` | Method of moments only (can yield negative variance) |
| `weightedVariance(_:weights:_:)` | Implemented | `variance/weightedVariance.swift` | No robust variants (trimmed, Winsorized) |
| `weightedAverage(_:weights:)` | Implemented | `Central Tendency/weightedAverage.swift` | No trimmed variant |
| `weightedCovariance(_:_:weights:_:)` | Implemented | `Covariance/weightedCovariance.swift` | — |
| `weightedCorrelation(_:_:weights:)` | Implemented | `correlation coefficient/weightedCorrelation.swift` | — |
| `concordanceCorrelationCoefficient(_:_:confidence:)` | Implemented | `Agreement/concordanceCorrelationCoefficient.swift` | No kernel/time-varying variant |
| `weightedStandardDeviation(_:weights:_:)` | Implemented | `Dispersion Around the Mean/weightedStandardDeviation.swift` | — |
| `blandAltman(_:_:)` | Implemented | `Agreement/blandAltman.swift` | No kernel/time-varying variant |
| `kendallW(_:)` | Implemented | `Comparison Statistics/kendallW.swift` | Non-parametric inter-rater concordance |
| `friedmanChiSquare(_:)` | Implemented | `Comparison Statistics/friedmanChiSquare.swift` | Non-parametric repeated-measures test |
| `fStatistic(kendallW:items:)` | Implemented | `Comparison Statistics/fStatistic.swift` | F-approximation from W (Legendre 2005) |
| `nemenyiCD(judges:items:alpha:)` | Implemented | `Comparison Statistics/nemenyiCD.swift` | Non-parametric post-hoc pairwise comparisons |
| `spearmansRho(_:vs:)` | Implemented | `Covariance and Correlation/` | Non-parametric rank correlation |
| Nested ANOVA | Missing | — | Required for nested ICC designs |
| REML estimation | Missing | — | Required for optimal variance components |
| G-theory (G-study / D-study) | Missing | — | Required for study design optimization |
| Robust weighted statistics | Missing | — | Required for outlier resistance |
| Kernel-weighted agreement | Missing | — | Required for spatially/temporally varying agreement |

## Phase 5: ICC with Missing Data

### Problem

Current `icc` requires `[[T]]` — a complete n x k matrix. When some rater-subject cells are missing, users must either discard subjects (losing data) or impute values (introducing bias). An EM-based approach estimates variance components directly from incomplete data.

### Model

The random-effects model underlying ICC:

```
x_ij = mu + s_i + r_j + e_ij
```

where:
- `mu` is the grand mean
- `s_i ~ N(0, sigma_s^2)` is the random subject effect
- `r_j ~ N(0, sigma_r^2)` is the random rater effect
- `e_ij ~ N(0, sigma_e^2)` is the residual error
- Not all (i, j) cells are observed

The variance components `(sigma_s^2, sigma_r^2, sigma_e^2)` are estimated via the EM algorithm, and ICC is computed from them:

```
ICC(2,1) absolute = sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)
ICC(3,1) consistency = sigma_s^2 / (sigma_s^2 + sigma_e^2)
ICC(1,1) = sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)
```

### EM Algorithm

Let `theta = (mu, sigma_s^2, sigma_r^2, sigma_e^2)` denote the current parameter estimates.

**Notation:**
- `O` = set of observed (i, j) pairs
- `n_i` = number of raters who rated subject i
- `k_j` = number of subjects rated by rater j
- `N` = total number of observed cells = |O|

**E-step:** Compute the expected sufficient statistics given current `theta`.

For observed cells, the conditional expectations are straightforward because the observed data is known. The key quantities are the posterior expectations of the random effects:

For subject effect `s_i`, given all observed ratings for subject i:

```
E[s_i | x_obs, theta] = (sigma_s^2 / (sigma_s^2 + sigma_e^2 / n_i)) 
                        * (x_bar_i. - mu - r_bar_i.)
```

where:
- `x_bar_i.` = mean of observed ratings for subject i
- `r_bar_i.` = mean of `E[r_j | ...]` for raters j who rated subject i

Similarly, for rater effect `r_j`:

```
E[r_j | x_obs, theta] = (sigma_r^2 / (sigma_r^2 + sigma_e^2 / k_j))
                        * (x_bar_.j - mu - s_bar_.j)
```

where:
- `x_bar_.j` = mean of observed ratings for rater j
- `s_bar_.j` = mean of `E[s_i | ...]` for subjects i rated by rater j

Because `E[s_i]` depends on `E[r_j]` and vice versa, the E-step uses iterative conditional expectations (ICE): alternate updating subject effects and rater effects until convergence (inner loop, typically 5-20 iterations).

**Second moments for variance updates:**

```
E[s_i^2 | x_obs, theta] = E[s_i | ...]^2 + Var[s_i | x_obs, theta]

Var[s_i | x_obs, theta] = 1 / (1/sigma_s^2 + n_i/sigma_e^2)

E[r_j^2 | x_obs, theta] = E[r_j | ...]^2 + Var[r_j | x_obs, theta]

Var[r_j | x_obs, theta] = 1 / (1/sigma_r^2 + k_j/sigma_e^2)
```

**M-step:** Update parameter estimates to maximize expected log-likelihood.

```
mu_new = (1/N) * sum_{(i,j) in O} (x_ij - E[s_i] - E[r_j])

sigma_s_new^2 = (1/n) * sum_{i=1}^{n} E[s_i^2 | x_obs, theta]

sigma_r_new^2 = (1/k) * sum_{j=1}^{k} E[r_j^2 | x_obs, theta]

sigma_e_new^2 = (1/N) * sum_{(i,j) in O} E[(x_ij - mu - s_i - r_j)^2 | ...]
             = (1/N) * sum_{(i,j) in O} [(x_ij - mu_new - E[s_i] - E[r_j])^2
                                         + Var[s_i | ...] + Var[r_j | ...]]
```

**Observed-data log-likelihood** (for convergence monitoring):

```
log L(theta | x_obs) = -(N/2) * log(2*pi) 
                       - (1/2) * sum_{(i,j) in O} log(sigma_s^2 + sigma_r^2 + sigma_e^2)
                       - (1/2) * sum_{(i,j) in O} (x_ij - mu)^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)
```

Note: The exact marginal log-likelihood requires integrating out the correlated random effects, which involves block-diagonal covariance matrices. The formula above is the independence approximation used for convergence monitoring. For a fully correct marginal likelihood, one would need to account for the within-subject and within-rater correlation structure, but the independence approximation is standard practice for EM convergence checks.

**Convergence criterion:**

```
|log L(theta_new) - log L(theta_old)| / |log L(theta_old)| < epsilon
```

Default `epsilon = 1e-8`, maximum iterations = 200.

**Initialization:**

```
mu_0 = grand mean of all observed cells
sigma_s_0^2 = variance of row means (across subjects)
sigma_r_0^2 = variance of column means (across raters)
sigma_e_0^2 = pooled within-cell residual variance (overall variance - sigma_s_0^2 - sigma_r_0^2),
              truncated to max(result, epsilon) to avoid starting at zero
```

### Edge Cases and Numerical Stability

- **Variance component hits zero:** Clamp to `T.ulpOfOne` during iteration to avoid division by zero in posterior variance. After convergence, report zero if the estimate is below a threshold.
- **Completely missing row or column:** A subject with zero raters or a rater with zero subjects contributes no information. Exclude from estimation but count in degrees of freedom.
- **All data present:** Should produce results matching the standard ANOVA-based ICC within numerical tolerance.
- **Single observed cell per subject:** `Var[s_i | ...]` is large; the estimate is dominated by the prior. This is correct behavior.
- **Convergence failure:** If max iterations reached, return the current estimate with a flag indicating non-convergence.

### Proposed API

```swift
/// Result of an ICC computation with missing data.
///
/// Contains variance component estimates from EM estimation in addition
/// to the ICC value and confidence interval.
public struct ICCMissingDataResult<T: Real>: Sendable, Equatable {
    /// The ICC value computed from estimated variance components.
    public let icc: T

    /// Estimated subject variance component (sigma_s^2).
    public let varianceSubjects: T

    /// Estimated rater variance component (sigma_r^2).
    public let varianceRaters: T

    /// Estimated residual variance component (sigma_e^2).
    public let varianceError: T

    /// Estimated grand mean (mu).
    public let grandMean: T

    /// Number of EM iterations to convergence.
    public let iterations: Int

    /// Whether the EM algorithm converged within the iteration limit.
    public let converged: Bool

    /// Final observed-data log-likelihood.
    public let logLikelihood: T

    /// Number of subjects (rows).
    public let subjects: Int

    /// Number of raters (columns).
    public let raters: Int

    /// Number of observed cells.
    public let observedCells: Int
}

/// Intraclass correlation coefficient with missing data.
///
/// Estimates ICC from an incomplete ratings matrix using the EM algorithm
/// for a random-effects model. Missing cells are represented as `nil`.
///
/// The model is:
/// ```
/// x_ij = mu + s_i + r_j + e_ij
/// ```
/// where `s_i ~ N(0, sigma_s^2)`, `r_j ~ N(0, sigma_r^2)`, `e_ij ~ N(0, sigma_e^2)`.
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the rating of subject `i` by rater `j`,
///     or `nil` if that cell is missing. All rows must have the same length.
///   - model: The ICC model type (see ``ICCModel``).
///   - agreement: The agreement type (see ``ICCAgreement``).
///   - maxIterations: Maximum EM iterations (default 200).
///   - tolerance: Relative log-likelihood convergence tolerance (default 1e-8).
/// - Returns: An ``ICCMissingDataResult`` with ICC, variance components, and convergence info.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects with
///   observations, or fewer than 2 raters with observations.
///   `BusinessMathError.mismatchedDimensions` if rows differ in length.
public func icc<T: Real>(
    _ ratings: [[T?]],
    model: ICCModel,
    agreement: ICCAgreement,
    maxIterations: Int = 200,
    tolerance: T = T(1) / T(100_000_000)
) throws -> ICCMissingDataResult<T>
```

---

## Phase 6: Generalizability Theory (G-Studies / D-Studies)

### Problem

ICC answers "how reliable is this measurement?" G-theory answers "why is it reliable (or not), and how can I make it more reliable?" It decomposes total variance into contributions from each facet (subjects, raters, items, occasions) and their interactions, then predicts reliability for hypothetical study designs.

### Theory: Two-Facet Fully Crossed Design (p x r x i)

Consider the simplest multi-facet case: `p` persons rated by `r` raters on `i` items. The observation model is:

```
X_pri = mu + p_p + r_r + i_i + (pr)_pr + (pi)_pi + (ri)_ri + (pri,e)_pri
```

Seven variance components: `sigma_p^2`, `sigma_r^2`, `sigma_i^2`, `sigma_pr^2`, `sigma_pi^2`, `sigma_ri^2`, `sigma_pri,e^2`.

For a balanced design, variance components are extracted from the **Expected Mean Squares (EMS)** table:

| Source | df | MS | E(MS) |
|--------|----|----|-------|
| Persons (p) | n_p - 1 | MS_p | sigma_e^2 + n_i * sigma_pr^2 + n_r * sigma_pi^2 + n_r * n_i * sigma_p^2 |
| Raters (r) | n_r - 1 | MS_r | sigma_e^2 + n_i * sigma_pr^2 + n_p * sigma_ri^2 + n_p * n_i * sigma_r^2 |
| Items (i) | n_i - 1 | MS_i | sigma_e^2 + n_r * sigma_pi^2 + n_p * sigma_ri^2 + n_p * n_r * sigma_i^2 |
| p x r | (n_p-1)(n_r-1) | MS_pr | sigma_e^2 + n_i * sigma_pr^2 |
| p x i | (n_p-1)(n_i-1) | MS_pi | sigma_e^2 + n_r * sigma_pi^2 |
| r x i | (n_r-1)(n_i-1) | MS_ri | sigma_e^2 + n_p * sigma_ri^2 |
| p x r x i (residual) | (n_p-1)(n_r-1)(n_i-1) | MS_e | sigma_e^2 |

**Extracting variance components** (solve EMS equations bottom-up):

```
sigma_e^2   = MS_e
sigma_pr^2  = (MS_pr - MS_e) / n_i
sigma_pi^2  = (MS_pi - MS_e) / n_r
sigma_ri^2  = (MS_ri - MS_e) / n_p
sigma_p^2   = (MS_p - MS_e - n_i * sigma_pr^2 - n_r * sigma_pi^2) / (n_r * n_i)
            = (MS_p - MS_pr - MS_pi + MS_e) / (n_r * n_i)
sigma_r^2   = (MS_r - MS_e - n_i * sigma_pr^2 - n_p * sigma_ri^2) / (n_p * n_i)
            = (MS_r - MS_pr - MS_ri + MS_e) / (n_p * n_i)
sigma_i^2   = (MS_i - MS_e - n_r * sigma_pi^2 - n_p * sigma_ri^2) / (n_p * n_r)
            = (MS_i - MS_pi - MS_ri + MS_e) / (n_p * n_r)
```

Negative estimates are truncated to zero (standard practice in G-theory; see Shavelson & Webb 1991).

### Simpler Case: One-Facet Design (p x r)

For the common one-facet design (subjects x raters), the EMS table simplifies to the familiar two-way ANOVA:

| Source | df | MS | E(MS) |
|--------|----|----|-------|
| Persons (p) | n_p - 1 | MS_p | sigma_e^2 + n_r * sigma_p^2 |
| Raters (r) | n_r - 1 | MS_r | sigma_e^2 + n_p * sigma_r^2 |
| Residual (pr,e) | (n_p-1)(n_r-1) | MS_e | sigma_e^2 |

Extraction:
```
sigma_e^2 = MS_e
sigma_p^2 = (MS_p - MS_e) / n_r
sigma_r^2 = (MS_r - MS_e) / n_p
```

### D-Study: Predicting Reliability for Hypothetical Designs

Given variance components from a G-study, a D-study predicts reliability when facet sizes change.

**Generalizability coefficient** (relative reliability, analogous to ICC consistency):

```
rho^2 = sigma_p^2 / (sigma_p^2 + sigma_delta^2)
```

where `sigma_delta^2` is the relative error variance:

For one-facet: `sigma_delta^2 = sigma_pr,e^2 / n_r'`
For two-facet: `sigma_delta^2 = sigma_pr^2 / n_r' + sigma_pi^2 / n_i' + sigma_pri,e^2 / (n_r' * n_i')`

Here `n_r'` and `n_i'` are the **design** facet sizes (the hypothetical number of raters/items).

**Dependability coefficient** (absolute reliability, analogous to ICC absolute agreement):

```
Phi = sigma_p^2 / (sigma_p^2 + sigma_Delta^2)
```

where `sigma_Delta^2` is the absolute error variance:

For one-facet: `sigma_Delta^2 = sigma_r^2 / n_r' + sigma_pr,e^2 / n_r'`
For two-facet: `sigma_Delta^2 = sigma_r^2 / n_r' + sigma_i^2 / n_i' + sigma_pr^2 / n_r' + sigma_pi^2 / n_i' + sigma_ri^2 / (n_r' * n_i') + sigma_pri,e^2 / (n_r' * n_i')`

### Proposed API

```swift
/// A facet in a generalizability study.
///
/// Each facet represents a source of measurement variation
/// (e.g., raters, items, occasions).
public struct GFacet: Sendable, Hashable {
    /// Human-readable label for this facet (e.g., "raters", "items").
    public let label: String

    /// Number of levels observed for this facet in the G-study.
    public let levels: Int

    /// Creates a facet with the given label and number of levels.
    public init(label: String, levels: Int)
}

/// Variance component from a G-study.
///
/// Represents the estimated variance attributable to a single source
/// (a facet or an interaction between facets).
public struct VarianceComponent<T: Real>: Sendable, Equatable {
    /// Label identifying this source (e.g., "p", "r", "p x r").
    public let source: String

    /// Estimated variance component (non-negative after truncation).
    public let variance: T

    /// Percentage of total variance attributable to this source.
    public let percentOfTotal: T

    /// Degrees of freedom for this source.
    public let df: Int

    /// Mean square for this source.
    public let meanSquare: T
}

/// Result of a generalizability study (G-study).
///
/// Contains variance component estimates for all sources of variation
/// (main effects and interactions) in a fully crossed design.
public struct GStudyResult<T: Real>: Sendable, Equatable {
    /// Variance components for each source (main effects and interactions).
    public let components: [VarianceComponent<T>]

    /// The facets used in this study.
    public let facets: [GFacet]

    /// Total variance (sum of all components).
    public let totalVariance: T

    /// Person (object of measurement) variance component.
    public let variancePersons: T

    /// Number of persons (objects of measurement).
    public let personCount: Int
}

/// Result of a decision study (D-study).
///
/// Predicts reliability for a hypothetical measurement design using
/// variance components from a G-study.
public struct DStudyResult<T: Real>: Sendable, Equatable {
    /// Generalizability coefficient (relative reliability, analogous to ICC consistency).
    public let generalizabilityCoefficient: T

    /// Dependability coefficient (absolute reliability, analogous to ICC absolute agreement).
    public let dependabilityCoefficient: T

    /// Relative error variance (sigma_delta^2).
    public let relativeErrorVariance: T

    /// Absolute error variance (sigma_Delta^2).
    public let absoluteErrorVariance: T

    /// Standard error of measurement (absolute): sqrt(sigma_Delta^2).
    public let standardErrorOfMeasurement: T

    /// The design facet sizes used for this prediction.
    public let designFacets: [String: Int]
}

/// Generalizability study for a one-facet fully crossed design (p x r).
///
/// Decomposes total variance into person, facet, and residual components
/// using two-way ANOVA.
///
/// - Parameters:
///   - data: Matrix where `data[p][r]` is the score of person `p` by rater/condition `r`.
///   - facetLabel: Label for the facet (default "raters").
/// - Returns: A ``GStudyResult`` with variance components.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 persons or 2 facet levels.
///   `BusinessMathError.mismatchedDimensions` if rows differ in length.
public func gStudy<T: Real>(
    _ data: [[T]],
    facetLabel: String = "raters"
) throws -> GStudyResult<T>

/// Generalizability study for a two-facet fully crossed design (p x r x i).
///
/// Decomposes total variance into seven components: three main effects,
/// three two-way interactions, and the residual.
///
/// - Parameters:
///   - data: Three-dimensional array where `data[p][r][i]` is the score
///     of person `p` by rater `r` on item `i`.
///   - facetLabels: Labels for the two facets (default `("raters", "items")`).
/// - Returns: A ``GStudyResult`` with all seven variance components.
/// - Throws: `BusinessMathError.insufficientData` if any dimension has fewer than 2 levels.
///   `BusinessMathError.mismatchedDimensions` if the array is not rectangular.
public func gStudy<T: Real>(
    _ data: [[[T]]],
    facetLabels: (String, String) = ("raters", "items")
) throws -> GStudyResult<T>

/// Decision study: predict reliability for a hypothetical design.
///
/// Given variance components from a G-study, computes the generalizability
/// and dependability coefficients for specified facet sizes.
///
/// For a one-facet design with `n_r'` raters:
/// ```
/// rho^2 = sigma_p^2 / (sigma_p^2 + sigma_pr,e^2 / n_r')
/// Phi   = sigma_p^2 / (sigma_p^2 + sigma_r^2/n_r' + sigma_pr,e^2/n_r')
/// ```
///
/// For a two-facet design with `n_r'` raters and `n_i'` items:
/// ```
/// rho^2 = sigma_p^2 / (sigma_p^2 + sigma_pr^2/n_r' + sigma_pi^2/n_i'
///         + sigma_pri,e^2/(n_r'*n_i'))
/// ```
///
/// - Parameters:
///   - gResult: The G-study result containing variance components.
///   - design: Dictionary mapping facet labels to their hypothetical sizes.
/// - Returns: A ``DStudyResult`` with predicted reliability coefficients.
/// - Throws: `BusinessMathError.invalidInput` if design facets don't match G-study facets.
///   `BusinessMathError.invalidInput` if any design facet size is less than 1.
public func dStudy<T: Real>(
    _ gResult: GStudyResult<T>,
    design: [String: Int]
) throws -> DStudyResult<T>
```

---

## Phase 7: Nested ANOVA

### Problem

The current `twoWayANOVA` assumes a fully **crossed** design where every subject is observed under every condition. In **nested** designs, subgroups are unique to each group:

- Each patient is seen by a different set of doctors (doctors nested within clinics)
- Students nested within classrooms within schools
- Measurements nested within subjects for ICC(1,1) with replication

The ANOVA decomposition is different: there is no interaction term, because the subgroups in one group are different from those in another.

### Theory

For a nested design with `a` groups, `b` subgroups per group, and `n` observations per subgroup (balanced):

```
X_ijk = mu + alpha_i + beta_j(i) + e_ijk
```

where:
- `alpha_i` = effect of group i (i = 1, ..., a)
- `beta_j(i)` = effect of subgroup j nested within group i (j = 1, ..., b)
- `e_ijk` = residual error (k = 1, ..., n)

**Sum of squares decomposition:**

```
SS_total = SS_between_groups + SS_subgroups_within_groups + SS_within_subgroups

SS_between_groups = b * n * sum_i (X_bar_i.. - X_bar_...)^2

SS_subgroups_within = n * sum_i sum_j (X_bar_ij. - X_bar_i..)^2

SS_within_subgroups = sum_i sum_j sum_k (X_ijk - X_bar_ij.)^2
```

**Degrees of freedom:**

```
df_between = a - 1
df_subgroups_within = a * (b - 1)
df_within = a * b * (n - 1)
df_total = a * b * n - 1
```

**Mean squares:**

```
MS_between = SS_between / df_between
MS_subgroups = SS_subgroups_within / df_subgroups_within
MS_within = SS_within / df_within
```

**Expected mean squares (for random effects):**

```
E(MS_between) = sigma_e^2 + n * sigma_beta^2 + b * n * sigma_alpha^2
E(MS_subgroups) = sigma_e^2 + n * sigma_beta^2
E(MS_within) = sigma_e^2
```

**Variance component extraction:**

```
sigma_e^2     = MS_within
sigma_beta^2  = (MS_subgroups - MS_within) / n
sigma_alpha^2 = (MS_between - MS_subgroups) / (b * n)
```

Negative estimates are truncated to zero.

**F-tests:**

```
F_between = MS_between / MS_subgroups    (df: a-1, a*(b-1))
F_subgroups = MS_subgroups / MS_within    (df: a*(b-1), a*b*(n-1))
```

Note: For testing the between-groups effect in a nested design, the denominator is `MS_subgroups` (not `MS_within`), because subgroups are the "units" within each group.

### Unbalanced Nested ANOVA

When subgroups have different numbers of observations (`n_ij`) or groups have different numbers of subgroups (`b_i`), the formulas generalize:

```
SS_within = sum_i sum_j sum_k (X_ijk - X_bar_ij.)^2

SS_subgroups_within = sum_i sum_j n_ij * (X_bar_ij. - X_bar_i..)^2

SS_between = sum_i n_i. * (X_bar_i.. - X_bar_...)^2
```

where `n_i. = sum_j n_ij` is the total observations in group i, and weighted means are used:
```
X_bar_i.. = (sum_j sum_k X_ijk) / n_i.
X_bar_... = (sum_i sum_j sum_k X_ijk) / N
```

For variance components from unbalanced designs, the harmonic mean of subgroup sizes `n_0` replaces `n`:
```
n_0 = (N - sum_i (sum_j n_ij^2) / n_i.) / (sum_i b_i - a)
```

Similarly for `b_0` when groups have different numbers of subgroups.

### Proposed API

```swift
/// Result of a nested analysis of variance.
///
/// Decomposes variation in a hierarchical (nested) design into
/// between-groups, subgroups-within-groups, and within-subgroups components.
public struct NestedANOVAResult<T: Real>: Sendable, Equatable {
    /// Sum of squares between groups.
    public let ssBetweenGroups: T

    /// Sum of squares for subgroups within groups.
    public let ssSubgroupsWithin: T

    /// Sum of squares within subgroups (residual).
    public let ssWithinSubgroups: T

    /// Total sum of squares.
    public let ssTotal: T

    /// Mean square between groups.
    public let msBetweenGroups: T

    /// Mean square for subgroups within groups.
    public let msSubgroupsWithin: T

    /// Mean square within subgroups.
    public let msWithinSubgroups: T

    /// F-statistic for between-groups effect (MS_between / MS_subgroups).
    public let fBetweenGroups: T

    /// p-value for between-groups F-test.
    public let pBetweenGroups: T

    /// F-statistic for subgroups-within-groups effect (MS_subgroups / MS_within).
    public let fSubgroupsWithin: T

    /// p-value for subgroups-within-groups F-test.
    public let pSubgroupsWithin: T

    /// Degrees of freedom for between-groups (a - 1).
    public let dfBetweenGroups: Int

    /// Degrees of freedom for subgroups within groups.
    public let dfSubgroupsWithin: Int

    /// Degrees of freedom within subgroups.
    public let dfWithinSubgroups: Int

    /// Number of groups.
    public let groupCount: Int

    /// Total number of observations.
    public let totalCount: Int

    /// Estimated between-group variance component (sigma_alpha^2), truncated to zero.
    public let varianceBetweenGroups: T

    /// Estimated subgroup-within-group variance component (sigma_beta^2), truncated to zero.
    public let varianceSubgroupsWithin: T

    /// Estimated within-subgroup variance component (sigma_e^2).
    public let varianceWithinSubgroups: T
}

/// Nested (hierarchical) one-way ANOVA.
///
/// For designs where subgroups are nested within groups (e.g., students
/// within classrooms, raters nested within clinics). Unlike crossed designs,
/// different groups contain different subgroups, so there is no interaction term.
///
/// The sum of squares decomposition is:
/// ```
/// SS_total = SS_between_groups + SS_subgroups_within + SS_within_subgroups
/// ```
///
/// - Parameter data: Three-dimensional array where `data[group][subgroup][observation]`.
///   Groups may have different numbers of subgroups, and subgroups may have
///   different numbers of observations (unbalanced design supported).
/// - Returns: A ``NestedANOVAResult`` with SS decomposition, F-tests, and variance components.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups, any group
///   has fewer than 2 subgroups, or any subgroup is empty.
public func nestedANOVA<T: Real>(
    _ data: [[[T]]]
) throws -> NestedANOVAResult<T>
```

---

## Phase 8: REML Variance Components for Repeated Measures

### Problem

The current `blandAltmanRepeatedMeasures` uses method of moments (ANOVA-based variance component extraction):

```swift
// From blandAltmanRepeatedMeasures.swift, line 113-117:
if msBetween > msWithin, k > T.zero {
    varianceBetween = (msBetween - msWithin) / k
} else {
    varianceBetween = T.zero  // truncation
}
```

This truncation discards information and biases the estimate. REML (Restricted Maximum Likelihood) provides:
- Variance estimates that are always non-negative by construction (with bounded optimization)
- Unbiased estimation (unlike ML, REML accounts for the loss of degrees of freedom from estimating fixed effects)
- Optimal estimates for unbalanced designs

### Model

For the repeated-measures Bland-Altman, differences are modeled as:

```
d_ij = mu + u_i + e_ij
```

where:
- `d_ij` = difference for subject i, replicate j
- `mu` = fixed overall bias
- `u_i ~ N(0, sigma_u^2)` = random subject effect
- `e_ij ~ N(0, sigma_e^2)` = residual error
- `m_i` = number of replicates for subject i (may vary)

### The Restricted Log-Likelihood

Let `theta = (sigma_u^2, sigma_e^2)`. For `n` subjects with `m_i` replicates each:

The marginal distribution of `d_i = (d_i1, ..., d_im_i)` is:

```
d_i ~ N(mu * 1_mi, V_i)
```

where `V_i = sigma_u^2 * J_mi + sigma_e^2 * I_mi`

Here `J_mi` is the `m_i x m_i` matrix of all ones and `I_mi` is the identity.

Because V_i has a simple structure (compound symmetry), its inverse and determinant have closed forms:

```
V_i^{-1} = (1/sigma_e^2) * [I_mi - (sigma_u^2 / (sigma_e^2 + m_i * sigma_u^2)) * J_mi]

det(V_i) = sigma_e^{2*(m_i - 1)} * (sigma_e^2 + m_i * sigma_u^2)
```

The **restricted log-likelihood** is:

```
l_R(theta) = -(1/2) * [sum_i (m_i - 1) * log(sigma_e^2) 
             + sum_i log(sigma_e^2 + m_i * sigma_u^2)
             + log(sum_i m_i / (sigma_e^2 + m_i * sigma_u^2))
             + sum_i (1/sigma_e^2) * (sum_j (d_ij - d_bar_i)^2)
             + sum_i m_i * (d_bar_i - mu_hat)^2 / (sigma_e^2 + m_i * sigma_u^2)
             + (N - n) * log(2*pi)]
```

where:
- `N = sum_i m_i` (total observations)
- `d_bar_i = (1/m_i) * sum_j d_ij` (subject mean)
- `mu_hat = [sum_i m_i * d_bar_i / (sigma_e^2 + m_i * sigma_u^2)] / [sum_i m_i / (sigma_e^2 + m_i * sigma_u^2)]` (GLS estimate of mu, evaluated at current theta)

The third term (`log(sum_i ...)`) is the REML correction that distinguishes restricted from full maximum likelihood. It penalizes for estimating the fixed effect `mu`.

### Score Equations (Gradient)

The partial derivatives of the restricted log-likelihood with respect to the variance parameters:

```
dl_R / d(sigma_e^2) = -(1/2) * [sum_i (m_i - 1) / sigma_e^2
                       + sum_i 1 / (sigma_e^2 + m_i * sigma_u^2)
                       - (1/sigma_e^4) * sum_i S_i
                       - sum_i m_i * (d_bar_i - mu_hat)^2 / (sigma_e^2 + m_i * sigma_u^2)^2
                       - partial REML correction / d(sigma_e^2)]
```

where `S_i = sum_j (d_ij - d_bar_i)^2` is the within-subject sum of squares for subject i.

Rather than deriving the full analytic gradient (which is complex due to the REML correction term and the dependence of `mu_hat` on theta), we use **Fisher scoring**, which replaces the observed information matrix with its expected value.

### Fisher Scoring Update

Fisher scoring uses the expected Fisher information, which for the compound symmetry model has a clean form. Define:

```
a_i = sigma_e^2 + m_i * sigma_u^2
```

The expected Fisher information matrix `I(theta)` is:

```
I_11 = (1/2) * [sum_i (m_i - 1) / sigma_e^4 + sum_i 1 / a_i^2]  (for sigma_e^2)
I_22 = (1/2) * sum_i m_i^2 / a_i^2                                 (for sigma_u^2)
I_12 = (1/2) * sum_i m_i / a_i^2                                   (= I_21)
```

The update rule:

```
theta_{t+1} = theta_t + I(theta_t)^{-1} * S(theta_t)
```

where `S(theta_t)` is the score vector (gradient of restricted log-likelihood).

For a 2x2 information matrix, the inverse is:

```
I^{-1} = (1/det) * [[I_22, -I_12], [-I_12, I_11]]
det = I_11 * I_22 - I_12^2
```

**Practical score computation** (avoiding the complex analytic gradient):

The score for `sigma_e^2`:

```
S_1 = -(1/2) * [sum_i (m_i - 1) / sigma_e^2 + sum_i 1/a_i]
     + (1/2) * [(1/sigma_e^4) * sum_i S_i + sum_i m_i * r_i^2 / a_i^2]
```

The score for `sigma_u^2`:

```
S_2 = -(1/2) * sum_i m_i / a_i
     + (1/2) * sum_i m_i^2 * r_i^2 / a_i^2
```

where `r_i = d_bar_i - mu_hat` is the adjusted subject mean residual.

Note: The REML correction to the score is of order `O(1/n)` and is negligible for n >= 10. For small n, a profile likelihood approach can be used instead.

### Convergence and Constraints

- **Convergence criterion:** Relative change in restricted log-likelihood < epsilon (default 1e-8), or absolute change in both variance parameters < 1e-10.
- **Non-negativity:** After each update, clamp `sigma_u^2` to `max(sigma_u^2, 0)` and `sigma_e^2` to `max(sigma_e^2, T.ulpOfOne)`. If Fisher scoring proposes a negative step, halve the step size (step halving, maximum 10 halvings).
- **Maximum iterations:** Default 100 (REML converges faster than EM).
- **Initialization:** Use method-of-moments estimates as starting values (warm start from current ANOVA-based approach).
- **Balanced design:** When all `m_i` are equal, REML and method of moments produce identical results (up to the non-negativity constraint). This serves as a verification test.

### Proposed API

```swift
/// Estimation method for variance components.
///
/// Controls how between-subject and within-subject variance
/// components are estimated in repeated-measures analyses.
public enum VarianceEstimationMethod: Sendable {
    /// Method of moments via one-way ANOVA.
    /// Simple, fast, but can produce negative variance estimates
    /// which are truncated to zero.
    case methodOfMoments

    /// Restricted maximum likelihood.
    /// Iterative, always produces non-negative estimates,
    /// optimal for unbalanced designs.
    case reml
}

/// Result of REML variance component estimation.
///
/// Contains the estimated variance components, convergence information,
/// and the REML estimate of the fixed effect (overall bias).
public struct REMLResult<T: Real>: Sendable, Equatable {
    /// Estimated between-subject variance (sigma_u^2).
    public let varianceBetween: T

    /// Estimated within-subject variance (sigma_e^2).
    public let varianceWithin: T

    /// Total variance (between + within).
    public let varianceTotal: T

    /// REML estimate of the fixed intercept (overall bias mu).
    public let fixedIntercept: T

    /// Number of Fisher scoring iterations.
    public let iterations: Int

    /// Whether the algorithm converged.
    public let converged: Bool

    /// Final restricted log-likelihood value.
    public let restrictedLogLikelihood: T
}

/// REML estimation for a random-intercept model.
///
/// Estimates variance components for the model `y_ij = mu + u_i + e_ij`
/// using restricted maximum likelihood via Fisher scoring.
///
/// - Parameters:
///   - groups: Array of groups, where each group is an array of observations.
///     Groups may have different sizes (unbalanced design supported).
///   - maxIterations: Maximum Fisher scoring iterations (default 100).
///   - tolerance: Relative convergence tolerance for the restricted log-likelihood (default 1e-8).
/// - Returns: A ``REMLResult`` with variance components and convergence info.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups
///   or total observations do not exceed the number of groups.
public func remlVarianceComponents<T: Real>(
    _ groups: [[T]],
    maxIterations: Int = 100,
    tolerance: T = T(1) / T(100_000_000)
) throws -> REMLResult<T>

/// Bland-Altman analysis with repeated measures using REML estimation.
///
/// Like ``blandAltmanRepeatedMeasures(_:)`` but uses REML instead of
/// method of moments for variance component estimation. REML provides
/// non-negative variance estimates and is optimal for unbalanced designs.
///
/// - Parameters:
///   - pairs: Array of subjects, where each subject is an array of (x, y) pairs.
///   - method: Variance estimation method (default `.reml`).
/// - Returns: Repeated-measures Bland-Altman result with variance decomposition.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects,
///           any subject has fewer than 1 pair, or total observations do not
///           exceed the number of subjects.
public func blandAltmanRepeatedMeasures<T: Real>(
    _ pairs: [[(x: T, y: T)]],
    method: VarianceEstimationMethod
) throws -> RepeatedMeasuresBlandAltmanResult<T>
```

---

## Phase 9: Robust Weighted Statistics

### Problem

Weighted statistics are sensitive to outliers, especially when outliers carry high weight. A single contaminated observation with weight 10 and a value 100x the mean can dominate the weighted mean and inflate the weighted variance.

Robust weighted statistics provide resistance to such contamination by:
- **Trimming:** Excluding observations beyond percentile thresholds
- **Winsorizing:** Replacing extreme observations with percentile boundary values
- **Quantifying robustness:** Reporting the breakdown point

### Trimmed Weighted Mean

The alpha-trimmed weighted mean excludes observations below the alpha-th and above the (1-alpha)-th weighted percentiles:

1. Sort observations by value (carrying weights along)
2. Compute cumulative weight proportions: `CW_i = sum(w_1..w_i) / sum(w_all)`
3. Identify the trimming boundaries:
   - Lower boundary: smallest i such that `CW_i >= alpha`
   - Upper boundary: largest i such that `CW_i <= 1 - alpha`
4. Compute weighted mean of the retained observations

For the boundary observations that straddle the trimming threshold, use fractional inclusion: if observation i spans the boundary, include a fraction of its weight proportional to how much of its cumulative weight falls within the trimming range.

**Formal definition:**

```
Let (x_(1), w_(1)), ..., (x_(n), w_(n)) be sorted by x value.
Let W = sum w_i, and F_i = sum_{j<=i} w_j / W.

trimmedWeightedMean(alpha) = sum_{i: alpha < F_i <= 1-alpha} w_i * x_i / sum_{i: alpha < F_i <= 1-alpha} w_i
```

With fractional boundary adjustment for partial inclusion.

### Winsorized Weighted Variance

The alpha-Winsorized weighted variance clips extreme values to the alpha and (1-alpha) weighted percentiles before computing weighted variance:

1. Sort observations by value (carrying weights along)
2. Find the alpha-th weighted percentile `L` and (1-alpha)-th weighted percentile `U`
3. Replace any `x_i < L` with `L`, any `x_i > U` with `U`
4. Compute weighted variance of the clipped values

```
x_i_winsorized = max(L, min(x_i, U))
WinsorizedWeightedVariance = weightedVariance(x_winsorized, weights)
```

### Breakdown Point

The breakdown point of an estimator is the smallest fraction of observations that, if replaced with arbitrary values, can make the estimate arbitrarily large (or small). It measures the maximum contamination an estimator can tolerate.

- Weighted mean: breakdown point = min(w_i) / sum(w_i) — a single observation with the smallest weight can cause breakdown if its value is extreme
- Alpha-trimmed weighted mean: breakdown point = alpha (by construction)
- Median: breakdown point = 0.5 (maximum possible)

For weighted statistics, we compute:

```
effectiveBreakdownPoint = alpha  (for alpha-trimmed estimators)
weightedBreakdownPoint = min(w_i / W, alpha)  (accounting for weight concentration)
```

### Proposed API

```swift
/// Computes the alpha-trimmed weighted mean.
///
/// Excludes observations below the alpha-th and above the (1-alpha)-th
/// weighted percentiles, then computes the weighted mean of the remaining
/// observations. Provides resistance to outliers.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights corresponding to each value.
///   - alpha: Trimming proportion (0 < alpha < 0.5). Default 0.05 (5% each tail).
/// - Returns: The trimmed weighted mean.
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
///   `BusinessMathError.invalidInput` if alpha is not in (0, 0.5), or weights are negative.
///   `BusinessMathError.divisionByZero` if total weight of retained observations is zero.
///   `BusinessMathError.insufficientData` if fewer than 3 values.
public func weightedTrimmedMean<T: Real>(
    _ values: [T], weights: [T], alpha: T = T(5) / T(100)
) throws -> T

/// Computes the alpha-Winsorized weighted variance.
///
/// Clips values below the alpha-th and above the (1-alpha)-th weighted
/// percentiles to those boundary values before computing weighted variance.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights corresponding to each value.
///   - alpha: Winsorizing proportion (0 < alpha < 0.5). Default 0.05.
///   - pop: Sample or population variance (default `.sample`).
/// - Returns: The Winsorized weighted variance.
/// - Throws: Same as ``weightedTrimmedMean``.
public func winsorizedWeightedVariance<T: Real>(
    _ values: [T], weights: [T], alpha: T = T(5) / T(100), _ pop: Population = .sample
) throws -> T

/// Computes the Winsorized weighted standard deviation.
///
/// Square root of ``winsorizedWeightedVariance``.
public func winsorizedWeightedStandardDeviation<T: Real>(
    _ values: [T], weights: [T], alpha: T = T(5) / T(100), _ pop: Population = .sample
) throws -> T

/// Weighted percentile using interpolation.
///
/// Computes the p-th percentile of a weighted dataset using linear
/// interpolation between adjacent order statistics.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights.
///   - p: Percentile in [0, 1].
/// - Returns: The weighted percentile value.
/// - Throws: `BusinessMathError.invalidInput` if p is not in [0, 1].
///   `BusinessMathError.insufficientData` if values is empty.
public func weightedPercentile<T: Real>(
    _ values: [T], weights: [T], p: T
) throws -> T

/// Breakdown point of a weighted estimator.
///
/// Computes the finite-sample breakdown point, which is the smallest
/// fraction of observations (by weight) that can make the estimate
/// arbitrarily bad.
///
/// - Parameters:
///   - weights: Non-negative weights.
///   - trimming: Optional trimming proportion (for trimmed estimators).
/// - Returns: The breakdown point in [0, 0.5].
/// - Throws: `BusinessMathError.divisionByZero` if total weight is zero.
public func weightedBreakdownPoint<T: Real>(
    _ weights: [T], trimming: T? = nil
) throws -> T
```

---

## Phase 10: Kernel-Weighted Agreement and Time-Varying Weights

### Problem

Standard agreement statistics assume stationarity — that agreement is constant across the measurement range and across time. In longitudinal validation studies:

- Agreement may degrade as a device ages or as a sensor drifts
- Agreement may differ at extremes of the measurement range (e.g., SpO2 monitors at low saturation)
- Recent observations may be more relevant for current device performance

Kernel-weighted and time-varying agreement statistics address these patterns.

### Kernel-Weighted CCC

Weight each observation pair by its distance from a target value using a kernel function:

```
w_i = K((m_i - target) / bandwidth)
```

where:
- `m_i = (x_i + y_i) / 2` is the mean of the paired measurement
- `K` is a kernel function
- `bandwidth` controls the smoothing window

**Available kernels:**

```
Gaussian:      K(u) = exp(-u^2 / 2) / sqrt(2*pi)
Epanechnikov:  K(u) = (3/4) * (1 - u^2)    for |u| <= 1, else 0
Uniform:       K(u) = 1/2                    for |u| <= 1, else 0
Triangular:    K(u) = 1 - |u|               for |u| <= 1, else 0
```

Then compute the weighted CCC using the kernel weights:
```
CCC_kernel(target) = weightedCCC(x, y, weights: w)
```

By sweeping `target` across the measurement range, one obtains a **CCC profile** showing how agreement varies with magnitude.

### Exponentially Weighted Agreement

For time-ordered observations, weight by recency:

```
w_i = lambda^(n - i)
```

where `lambda` is the decay factor in (0, 1] and `i` indexes observations from oldest (i=1) to newest (i=n).

- `lambda = 1.0` — all observations equally weighted (standard CCC/B-A)
- `lambda = 0.9` — 10% decay per step
- `lambda = 0.5` — 50% decay per step (aggressive)

The half-life (number of steps for weight to halve) is:

```
half_life = -log(2) / log(lambda)
```

### Rolling (Moving-Window) Agreement

Compute agreement statistics over a sliding window of size `w`:

```
rolling_CCC[t] = CCC(x[t..t+w], y[t..t+w])
rolling_BA[t]  = blandAltman(x[t..t+w], y[t..t+w])
```

This produces a time series of agreement values, enabling detection of trend, drift, or periodic variation in agreement.

### Proposed API

```swift
/// Kernel function for weighting observations by distance.
public enum KernelFunction: Sendable {
    /// Gaussian kernel: K(u) = exp(-u^2/2) / sqrt(2*pi).
    case gaussian
    /// Epanechnikov kernel: K(u) = (3/4)(1 - u^2) for |u| <= 1, else 0.
    case epanechnikov
    /// Uniform (rectangular) kernel: K(u) = 1/2 for |u| <= 1, else 0.
    case uniform
    /// Triangular kernel: K(u) = 1 - |u| for |u| <= 1, else 0.
    case triangular
}

/// Computes kernel weights for paired observations.
///
/// Weights each observation by its distance from a target value using
/// the specified kernel function and bandwidth.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series.
///   - target: The target value to center the kernel on.
///   - bandwidth: The kernel bandwidth (controls smoothing width).
///   - kernel: The kernel function to use (default `.gaussian`).
/// - Returns: Array of non-negative weights for each observation.
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
///   `BusinessMathError.invalidInput` if bandwidth is not positive.
public func kernelWeights<T: Real>(
    _ x: [T], _ y: [T],
    target: T,
    bandwidth: T,
    kernel: KernelFunction = .gaussian
) throws -> [T]

/// Kernel-weighted concordance correlation coefficient.
///
/// Computes a CCC where observations near the target value receive
/// higher weight. This reveals how agreement varies across the
/// measurement range.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series.
///   - target: Center of the kernel window.
///   - bandwidth: Width of the kernel window.
///   - kernel: Kernel function (default `.gaussian`).
///   - confidence: Confidence level (default 0.95).
/// - Returns: `CCCResult` with kernel-weighted CCC and confidence bounds.
/// - Throws: `BusinessMathError.insufficientData` if effective sample size
///   (sum of normalized weights) is less than 3.
public func kernelWeightedCCC<T: Real>(
    _ x: [T], _ y: [T],
    target: T,
    bandwidth: T,
    kernel: KernelFunction = .gaussian,
    confidence: T = T(95) / T(100)
) throws -> CCCResult<T>

/// CCC profile: kernel-weighted CCC at multiple target values.
///
/// Sweeps a kernel across the measurement range and computes the CCC
/// at each target, producing a profile that shows how agreement varies.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series.
///   - targets: Array of target values at which to evaluate the CCC.
///   - bandwidth: Kernel bandwidth.
///   - kernel: Kernel function (default `.gaussian`).
/// - Returns: Array of `(target, cccResult)` tuples.
public func cccProfile<T: Real>(
    _ x: [T], _ y: [T],
    targets: [T],
    bandwidth: T,
    kernel: KernelFunction = .gaussian
) throws -> [(target: T, ccc: CCCResult<T>)]

/// Computes exponentially decaying weights for time-ordered observations.
///
/// More recent observations receive higher weight. The weight for the
/// i-th observation (0-indexed from the oldest) is `lambda^(n - 1 - i)`.
///
/// - Parameters:
///   - count: Number of observations.
///   - lambda: Decay factor in (0, 1]. 1.0 = equal weights, 0.5 = halving per step.
/// - Returns: Array of weights (most recent has weight 1.0).
/// - Throws: `BusinessMathError.invalidInput` if lambda is not in (0, 1].
///   `BusinessMathError.insufficientData` if count < 1.
public func exponentialDecayWeights<T: Real>(
    count: Int,
    lambda: T
) throws -> [T]

/// Exponentially weighted Bland-Altman analysis.
///
/// Applies exponential decay weights to give more influence to recent
/// observations. Useful for detecting drift in agreement over time.
///
/// - Parameters:
///   - x: Time-ordered measurements from method A.
///   - y: Time-ordered measurements from method B.
///   - lambda: Decay factor in (0, 1].
/// - Returns: `BlandAltmanResult` with exponentially weighted statistics.
public func exponentialWeightedBlandAltman<T: Real>(
    _ x: [T], _ y: [T],
    lambda: T
) throws -> BlandAltmanResult<T>

/// Rolling (moving-window) concordance correlation coefficient.
///
/// Computes the CCC over a sliding window, producing a time series
/// of agreement values.
///
/// - Parameters:
///   - x: Time-ordered measurements from method A.
///   - y: Time-ordered measurements from method B.
///   - windowSize: Number of observations per window (must be >= 3).
///   - step: Step size for the window (default 1).
/// - Returns: Array of `(startIndex, cccResult)` tuples.
/// - Throws: `BusinessMathError.insufficientData` if series length < windowSize.
///   `BusinessMathError.invalidInput` if windowSize < 3 or step < 1.
public func rollingCCC<T: Real>(
    _ x: [T], _ y: [T],
    windowSize: Int,
    step: Int = 1
) throws -> [(startIndex: Int, ccc: CCCResult<T>)]

/// Rolling (moving-window) Bland-Altman analysis.
///
/// Computes Bland-Altman statistics over a sliding window.
///
/// - Parameters:
///   - x: Time-ordered measurements from method A.
///   - y: Time-ordered measurements from method B.
///   - windowSize: Number of observations per window (must be >= 2).
///   - step: Step size for the window (default 1).
/// - Returns: Array of `(startIndex, blandAltmanResult)` tuples.
public func rollingBlandAltman<T: Real>(
    _ x: [T], _ y: [T],
    windowSize: Int,
    step: Int = 1
) throws -> [(startIndex: Int, result: BlandAltmanResult<T>)]
```

---

## File Organization

```
Sources/BusinessMath/Statistics/
  ANOVA/
    oneWayANOVA.swift                                    — EXISTS
    twoWayANOVA.swift                                    — EXISTS
    nestedANOVA.swift                                    — NEW (Phase 7)
  Descriptors/
    Agreement/
      blandAltman.swift                                  — EXISTS
      blandAltmanRepeatedMeasures.swift                  — EXISTS (Phase 8 adds method: parameter)
      concordanceCorrelationCoefficient.swift             — EXISTS
      icc.swift                                          — EXISTS
      iccMissingData.swift                               — NEW (Phase 5)
      weightedBlandAltman.swift                          — EXISTS
      weightedConcordanceCorrelation.swift                — EXISTS
      kernelWeights.swift                                — NEW (Phase 10)
      kernelWeightedAgreement.swift                      — NEW (Phase 10)
      rollingAgreement.swift                             — NEW (Phase 10)
      exponentialWeightedAgreement.swift                 — NEW (Phase 10)
    Covariance and Correlation/
      ...                                                — EXISTS
    Dispersion Around the Mean/
      variance/
        weightedVariance.swift                           — EXISTS
        winsorizedWeightedVariance.swift                 — NEW (Phase 9)
      weightedStandardDeviation.swift                    — EXISTS
      winsorizedWeightedStandardDeviation.swift          — NEW (Phase 9)
    Central Tendency/
      weightedAverage.swift                              — EXISTS
      weightedTrimmedMean.swift                          — NEW (Phase 9)
      weightedPercentile.swift                           — NEW (Phase 9)
    Robustness/
      weightedBreakdownPoint.swift                       — NEW (Phase 9)
  Reliability/
    gStudy.swift                                         — NEW (Phase 6)
    dStudy.swift                                         — NEW (Phase 6)
    GStudyResult.swift                                   — NEW (Phase 6)
    DStudyResult.swift                                   — NEW (Phase 6)
    VarianceComponent.swift                              — NEW (Phase 6)
    GFacet.swift                                         — NEW (Phase 6)
  Estimation/
    remlVarianceComponents.swift                         — NEW (Phase 8)
    REMLResult.swift                                     — NEW (Phase 8)
    VarianceEstimationMethod.swift                       — NEW (Phase 8)

Tests/BusinessMathTests/Statistics Tests/
  ANOVA Tests/
    NestedANOVATests.swift                               — NEW (Phase 7)
  Descriptor Tests/
    Agreement Tests/
      ICCMissingDataTests.swift                          — NEW (Phase 5)
      KernelWeightedAgreementTests.swift                 — NEW (Phase 10)
      RollingAgreementTests.swift                        — NEW (Phase 10)
      ExponentialWeightedAgreementTests.swift             — NEW (Phase 10)
    Dispersion Tests/
      WinsorizedWeightedVarianceTests.swift              — NEW (Phase 9)
    Central Tendency Tests/
      WeightedTrimmedMeanTests.swift                     — NEW (Phase 9)
      WeightedPercentileTests.swift                      — NEW (Phase 9)
    Robustness Tests/
      WeightedBreakdownPointTests.swift                  — NEW (Phase 9)
  Reliability Tests/
    GStudyTests.swift                                    — NEW (Phase 6)
    DStudyTests.swift                                    — NEW (Phase 6)
  Estimation Tests/
    REMLVarianceComponentsTests.swift                    — NEW (Phase 8)
    BlandAltmanREMLTests.swift                           — NEW (Phase 8)
```

---

## Implementation Plan

### Phase 5: ICC with Missing Data (EM Algorithm)

**RED:**
1. Complete data (no nils) produces same ICC as standard `icc()` (within tolerance 1e-6)
2. Single missing cell: verify ICC changes smoothly from complete-data value
3. 50% missing data (randomly): converges, ICC in [0, 1]
4. All data for one subject missing: excluded, does not crash
5. All data for one rater missing: excluded, does not crash
6. Perfect agreement with missing data: ICC = 1.0
7. Perfect disagreement: ICC near 0 or negative
8. Convergence flag is `true` for well-conditioned data
9. Non-convergence: adversarial data with maxIterations=2, verify `converged == false`
10. Fewer than 2 subjects with data: throws `insufficientData`
11. Fewer than 2 raters with data: throws `insufficientData`
12. Ragged matrix (rows differ in length): throws `mismatchedDimensions`
13. Cross-validate: known dataset from Shrout & Fleiss with artificially removed cells, compare to R `lme4::lmer` + ICC extraction

**GREEN:** Implement EM with ICE inner loop, Fisher scoring for variance components.

**REFACTOR:** Extract the ICE subroutine as a reusable internal function for Phase 6.

### Phase 6: Generalizability Theory

**RED (G-study, one-facet):**
1. Known two-way ANOVA data: G-study variance components match manual extraction from EMS
2. All raters agree perfectly: sigma_r = 0, sigma_e = 0, rho^2 = 1.0
3. No subject differentiation: sigma_p = 0, rho^2 = 0
4. Variance component percentages sum to 100%
5. Negative raw estimate truncated to zero (construct data where MS_r < MS_e)
6. Fewer than 2 persons or 2 raters: throws `insufficientData`
7. Ragged matrix: throws `mismatchedDimensions`

**RED (G-study, two-facet):**
8. Known three-way ANOVA data with textbook variance components
9. Seven components extracted, all non-negative
10. Percentages sum to 100%
11. Uniform data (all identical): all variances zero except possibly sigma_p
12. Non-rectangular 3D array: throws `mismatchedDimensions`

**RED (D-study):**
13. D-study with same facet sizes as G-study: rho^2 matches ICC(3,1) consistency
14. D-study with same facet sizes: Phi matches ICC(2,1) absolute agreement
15. Doubling n_r reduces relative error variance
16. D-study formula: `rho^2 = sigma_p^2 / (sigma_p^2 + sigma_pr,e^2 / n_r')` for one-facet
17. D-study with n_r' = 1 reproduces original ICC
18. Design facets don't match G-study facets: throws `invalidInput`
19. Design facet size < 1: throws `invalidInput`
20. Two-facet D-study: `rho^2 = sigma_p^2 / (sigma_p^2 + sigma_pr^2/n_r' + sigma_pi^2/n_i' + sigma_pri,e^2/(n_r'*n_i'))`

**GREEN:** Implement three-way ANOVA decomposition for two-facet G-study, reuse `twoWayANOVA` for one-facet.

**REFACTOR:** Generalize EMS table construction for future extension to more facets.

### Phase 7: Nested ANOVA

**RED:**
1. Balanced design with known textbook SS values
2. `SS_total = SS_between + SS_subgroups_within + SS_within`
3. `df_total = df_between + df_subgroups + df_within = a*b*n - 1`
4. All groups identical: SS_between = 0
5. All subgroups within each group identical: SS_subgroups_within = 0
6. All observations identical: all SS = 0
7. Variance components: sigma_e = MS_within, sigma_beta from MS_subgroups, sigma_alpha from MS_between
8. F-tests: F_between uses MS_subgroups as denominator (not MS_within)
9. Unbalanced design: different numbers of observations per subgroup
10. Unbalanced design: different numbers of subgroups per group
11. Fewer than 2 groups: throws `insufficientData`
12. Any group with fewer than 2 subgroups: throws `insufficientData`
13. Any empty subgroup: throws `insufficientData`
14. Negative variance component: truncated to zero, not negative

**GREEN:** Implement the balanced-case first, then extend to unbalanced with harmonic means.

**REFACTOR:** Extract weighted-mean-of-group-sizes calculation for reuse.

### Phase 8: REML Variance Components

**RED (REML core):**
1. Balanced groups: REML matches method-of-moments result (within tolerance 1e-6)
2. Unbalanced groups: REML produces non-negative variance (no truncation needed)
3. Data where method-of-moments would give negative variance: REML gives sigma_u^2 near 0, not negative
4. All within-group variation: sigma_u^2 = 0, sigma_e^2 = within-group variance
5. All between-group variation: sigma_e^2 near 0, sigma_u^2 dominates
6. Convergence within default iterations for well-conditioned data
7. Restricted log-likelihood increases monotonically across iterations
8. Fixed intercept matches GLS estimate
9. Fewer than 2 groups: throws `insufficientData`
10. Single observation per group: no within-group df, throws or degenerates correctly

**RED (B-A with REML):**
11. `blandAltmanRepeatedMeasures(pairs, method: .methodOfMoments)` matches existing behavior
12. `blandAltmanRepeatedMeasures(pairs, method: .reml)` produces non-negative varianceBetween
13. Balanced design: both methods agree within tolerance
14. Unbalanced design with many replicates for one subject: REML adjusts appropriately

**GREEN:** Implement Fisher scoring with step halving. Wire REML into `blandAltmanRepeatedMeasures`.

**REFACTOR:** The existing `blandAltmanRepeatedMeasures` call without `method:` parameter continues to use method of moments (backward compatible).

### Phase 9: Robust Weighted Statistics

**RED (weighted percentile):**
1. Equal weights: matches standard percentile
2. All weight on one observation: that observation's value at all percentiles
3. p=0 returns minimum, p=1 returns maximum
4. p=0.5 with equal weights: matches unweighted median
5. Known manual calculation with unequal weights
6. Empty array: throws `insufficientData`
7. Negative weight: throws `invalidInput`
8. p < 0 or p > 1: throws `invalidInput`

**RED (trimmed weighted mean):**
9. Equal weights, alpha=0: matches weighted mean
10. Equal weights, alpha=0.25: matches standard 25% trimmed mean
11. Extreme outlier with high weight: trimmed mean is not affected
12. alpha=0.5: degenerate (no data left), throws or returns median
13. Known manual calculation
14. alpha <= 0 or alpha >= 0.5: throws `invalidInput`
15. Fewer than 3 values: throws `insufficientData`

**RED (Winsorized weighted variance):**
16. Equal weights, alpha=0: matches weighted variance
17. Extreme outlier: Winsorized variance < unwinsorized variance
18. Known manual calculation
19. alpha=0.25 with known boundary clipping values

**RED (breakdown point):**
20. Equal weights: breakdown point = 1/n
21. One dominant weight: breakdown point = min(non-dominant) / total
22. With trimming alpha: breakdown point = alpha

**GREEN:** Implement weighted percentile first (used by all others), then trimmed mean, then Winsorized variance, then breakdown point.

**REFACTOR:** Ensure weighted percentile uses numerically stable interpolation.

### Phase 10: Kernel-Weighted and Time-Varying Agreement

**RED (kernel weights):**
1. Gaussian kernel at target=0, bandwidth=1: weights follow N(0,1) density
2. Epanechnikov kernel: weights zero outside bandwidth
3. Uniform kernel: constant weights within bandwidth, zero outside
4. Target at data center: highest weights there
5. Target far from all data: all weights near zero (throws `insufficientData` for effective sample size)
6. Bandwidth=0: throws `invalidInput`

**RED (kernel-weighted CCC):**
7. Gaussian kernel at center of range: similar to unweighted CCC
8. Kernel at extremes: CCC differs from center (if agreement varies)
9. Very large bandwidth: converges to unweighted CCC
10. Effective sample size too small: throws `insufficientData`

**RED (CCC profile):**
11. Profile across 10 target values: returns 10 results
12. Profile with very large bandwidth: all CCC values similar
13. Constructed data with range-dependent agreement: profile captures the pattern

**RED (exponential decay weights):**
14. lambda=1.0: all weights equal (1.0)
15. lambda=0.5: weights halve each step
16. lambda=0.9: most recent weight is 1.0, oldest is 0.9^(n-1)
17. lambda=0: throws `invalidInput`
18. lambda > 1: throws `invalidInput`

**RED (exponentially weighted B-A):**
19. lambda=1.0: matches unweighted Bland-Altman
20. lambda=0.5 with drift: bias weighted toward recent observations
21. Known manual calculation

**RED (rolling CCC):**
22. Window = full series length: single result matching unweighted CCC
23. Window = 3 (minimum): produces n-2 results
24. Step = 2: produces ceil((n-3)/2) + 1 results
25. Series shorter than window: throws `insufficientData`
26. Window < 3: throws `invalidInput`

**RED (rolling B-A):**
27. Window = full series: matches unweighted B-A
28. Known drift pattern: rolling bias shows trend
29. Window < 2: throws `invalidInput`

**GREEN:** Implement kernel weight computation, then compose with existing weighted CCC/B-A. Rolling functions iterate over windows.

**REFACTOR:** Consider shared infrastructure for rolling computations (generic rolling window function).

---

## Effort Estimates

| Phase | New Files | Estimated Lines | Test Cases | Session Estimate |
|-------|-----------|----------------|------------|------------------|
| 5: ICC Missing Data | 1 source + 1 test | ~200 | ~13 | 2 sessions |
| 6: G-Theory | 6 source + 2 test | ~300 | ~20 | 2–3 sessions |
| 7: Nested ANOVA | 1 source + 1 test | ~150 | ~14 | 1–2 sessions |
| 8: REML | 3 source + 2 test | ~250 | ~14 | 2 sessions |
| 9: Robust Weighted | 5 source + 4 test | ~200 | ~22 | 1–2 sessions |
| 10: Kernel/Time-Varying | 4 source + 3 test | ~250 | ~29 | 2 sessions |
| **Total** | **20 source + 13 test** | **~1,350** | **~112** | **10–14 sessions** |

---

## Phase Dependencies

```
                 ┌─────────────────────────────────────────┐
                 │       Prerequisites (all EXIST)         │
                 │  ICC, two-way ANOVA, one-way ANOVA,     │
                 │  weighted variance/covariance/CCC,      │
                 │  repeated-measures B-A, base CCC/B-A    │
                 └────────┬──────────┬──────────┬──────────┘
                          │          │          │
                 ┌────────▼───┐ ┌────▼────┐ ┌──▼──────────┐
                 │  Phase 7   │ │ Phase 9 │ │  Phase 10   │
                 │  Nested    │ │ Robust  │ │  Kernel /   │
                 │  ANOVA     │ │ Weighted│ │  Time-Vary  │
                 └────────┬───┘ └─────────┘ └─────────────┘
                          │
              ┌───────────▼───────────┐
              │       Phase 6         │
              │   G-Theory (G/D)      │
              │  (uses nested ANOVA   │
              │   for future nested   │
              │   G-study extension)  │
              └───────────────────────┘
                          │
              ┌───────────▼───────────┐
              │       Phase 8         │
              │   REML Variance       │
              │  Components           │
              └───────────┬───────────┘
                          │
              ┌───────────▼───────────┐
              │       Phase 5         │
              │  ICC Missing Data     │
              │  (reuses REML or EM)  │
              └───────────────────────┘
```

**Parallelizable groups:**
- **Group A (independent):** Phase 7, Phase 9, Phase 10 — all three can proceed in parallel with no interdependence
- **Group B (after Phase 7):** Phase 6 benefits from nested ANOVA for future extensions, but the initial one-facet and two-facet G-study only requires the existing `twoWayANOVA`. Phase 6 can start in parallel with Group A.
- **Group C (after Phase 8):** Phase 5 (ICC with missing data) uses EM, which is conceptually related to REML. Implementing REML first (Phase 8) builds familiarity with iterative variance estimation before tackling the more complex multi-effect EM. However, Phase 5 is self-contained and can be implemented independently if preferred.

**Recommended execution order:** Phase 9 and Phase 10 first (simpler, compositional), then Phase 7 (nested ANOVA), then Phase 6 (G-theory), then Phase 8 (REML), then Phase 5 (ICC missing data).

---

## References

### Phase 5: ICC with Missing Data
- Dempster, A.P., Laird, N.M., & Rubin, D.B. (1977). "Maximum likelihood from incomplete data via the EM algorithm." *Journal of the Royal Statistical Society, Series B*, 39(1), 1–38.
- Shrout, P.E. & Fleiss, J.L. (1979). "Intraclass correlations: Uses in assessing rater reliability." *Psychological Bulletin*, 86(2), 420–428.
- Schafer, J.L. (1997). *Analysis of Incomplete Multivariate Data*. Chapman & Hall/CRC. (Chapter 5: Normal data with a general pattern of missing values.)
- Van Buuren, S. (2018). *Flexible Imputation of Missing Data* (2nd ed.). Chapman & Hall/CRC. (Chapter 2: EM algorithm for mixed-effects models.)

### Phase 6: Generalizability Theory
- Brennan, R.L. (2001). *Generalizability Theory*. Springer-Verlag. (The definitive reference; Chapters 2–4 cover EMS rules, G-studies, and D-studies.)
- Shavelson, R.J. & Webb, N.M. (1991). *Generalizability Theory: A Primer*. Sage Publications. (Accessible introduction; Chapter 3 has the EMS tables used here.)
- Cronbach, L.J., Gleser, G.C., Nanda, H., & Rajaratnam, N. (1972). *The Dependability of Behavioral Measurements*. Wiley. (Original theoretical foundation.)
- Cardinet, J., Johnson, S., & Pini, G. (2010). *Applying Generalizability Theory Using EduG*. Routledge. (Practical computation guide.)

### Phase 7: Nested ANOVA
- Montgomery, D.C. (2017). *Design and Analysis of Experiments* (9th ed.). Wiley. (Chapter 14: Nested and Split-Plot Designs.)
- Sokal, R.R. & Rohlf, F.J. (2012). *Biometry* (4th ed.). W.H. Freeman. (Chapter 10: Nested ANOVA.)
- Searle, S.R., Casella, G., & McCulloch, C.E. (1992). *Variance Components*. Wiley. (Chapter 4: Unbalanced nested designs.)

### Phase 8: REML Variance Components
- Patterson, H.D. & Thompson, R. (1971). "Recovery of inter-block information when block sizes are unequal." *Biometrika*, 58(3), 545–554. (Original REML paper.)
- Harville, D.A. (1977). "Maximum likelihood approaches to variance component estimation and to related problems." *Journal of the American Statistical Association*, 72(358), 320–338. (REML theory and Fisher scoring.)
- Corbeil, R.R. & Searle, S.R. (1976). "Restricted maximum likelihood (REML) estimation of variance components in the mixed model." *Technometrics*, 18(1), 31–38.
- Gilmour, A.R., Thompson, R., & Cullis, B.R. (1995). "Average Information REML: An efficient algorithm for variance parameter estimation in linear mixed models." *Biometrics*, 51(4), 1440–1450. (AI-REML, a modern alternative to Fisher scoring.)

### Phase 9: Robust Weighted Statistics
- Huber, P.J. & Ronchetti, E.M. (2009). *Robust Statistics* (2nd ed.). Wiley. (Chapter 3: Breakdown point theory.)
- Wilcox, R.R. (2017). *Introduction to Robust Estimation and Hypothesis Testing* (4th ed.). Academic Press. (Chapter 3: Trimmed means; Chapter 7: Breakdown point.)
- Hettmansperger, T.P. & McKean, J.W. (2011). *Robust Nonparametric Statistical Methods* (2nd ed.). Chapman & Hall/CRC.
- Ma, Y. & Genton, M.G. (2000). "Highly robust estimation of the autocovariance function." *Journal of Time Series Analysis*, 21(6), 663–684. (Robust weighted statistics.)

### Phase 10: Kernel-Weighted and Time-Varying Agreement
- Silverman, B.W. (1986). *Density Estimation for Statistics and Data Analysis*. Chapman & Hall/CRC. (Chapter 2: Kernel functions and bandwidth selection.)
- Fan, J. & Gijbels, I. (1996). *Local Polynomial Modelling and Its Applications*. Chapman & Hall/CRC. (Kernel regression framework that generalizes to kernel-weighted agreement.)
- Hunter, J.S. (1986). "The exponentially weighted moving average." *Journal of Quality Technology*, 18(4), 203–210. (EWMA theory for time-varying statistics.)
- Carstensen, B. (2010). *Comparing Clinical Measurement Methods: A Practical Guide*. Wiley. (Chapter 5: Varying agreement over the measurement range; Chapter 7: Replicated measurements.)

---

## Not In Scope

- Mixed-effects regression with covariates (e.g., modeling agreement as a function of patient age)
- Multi-level nested ANOVA with more than two levels of nesting
- G-theory for more than two facets (three or more facets require automated EMS rule generation)
- Bayesian variance component estimation (Gibbs sampling for mixed models)
- Heterogeneous within-subject variance models (different sigma_e per subject)
- Automated bandwidth selection for kernel-weighted agreement (e.g., cross-validation)
