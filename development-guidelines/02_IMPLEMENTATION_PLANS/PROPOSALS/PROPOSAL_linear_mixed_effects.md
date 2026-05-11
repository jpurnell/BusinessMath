# Proposal: Linear Mixed-Effects (LME) Modeling Framework

**Date:** 2026-05-10
**Status:** Draft
**Scope:** New statistical modeling framework in `BusinessMath/Statistics/MixedModels/`
**Depends on:**
- `PROPOSAL_icc.md` (ICC, two-way ANOVA -- must land first)
- `PROPOSAL_distribution_cdfs_and_anova.md` (F-distribution CDF, t-distribution CDF/quantile -- must land first)
- `PROPOSAL_advanced_reliability.md` Phase 8 (REML variance components -- beneficial but not required; this proposal subsumes Phase 8)

## Problem

Linear Mixed-Effects (LME) modeling is the most requested missing capability in the BusinessMath statistics stack. Many real-world analyses involve data with a hierarchical or grouped structure -- repeated measurements on the same subject, students nested within schools, devices tested across patients -- where the independence assumption of ordinary least squares (OLS) is violated.

The core idea is simple: some effects in a model are **fixed** (we want to estimate them), while others are **random** (we want to account for the variability they introduce). The fixed effects capture population-level relationships; the random effects capture group-level deviations from those relationships.

### What Is Currently Impossible

**1. "Does the wearable's accuracy depend on heart rate zone?"**

A Bland-Altman analysis shows overall agreement between a wearable and a reference device. But if we want to know whether agreement *changes* as a function of a covariate (heart rate zone, skin tone, BMI), we need a covariate-adjusted agreement model. This requires fitting:

```
difference_ij = beta_0 + beta_1 * heart_rate_ij + u_i + e_ij
```

where `u_i` is a random intercept for patient `i`. This is a random intercept LME model. Without it, users must either ignore the clustering (invalid standard errors) or stratify and lose power.

**2. "How does student performance grow over time, accounting for school effects?"**

A longitudinal study measures test scores at multiple time points for students in different schools. The growth trajectory varies by student and by school. The model is:

```
score_ijk = beta_0 + beta_1 * time_ij + u_0k + u_1k * time_ij + v_0i + e_ijk
```

where `u_0k, u_1k` are random intercept and slope for school `k`, and `v_0i` is a random intercept for student `i`. This is a two-level random intercept + slope model. OLS cannot fit this at all.

**3. "What is the ICC after adjusting for age and sex?"**

The current `icc()` function computes a marginal ICC -- the proportion of total variance attributable to subjects. But in practice, some of the between-subject variance is explained by covariates. The adjusted ICC from an LME model is:

```
x_ij = beta_0 + beta_1 * age_i + beta_2 * sex_i + u_i + e_ij
ICC_adjusted = sigma_u^2 / (sigma_u^2 + sigma_e^2)
```

This tells us how reliable the measurement is *after* accounting for known sources of variation.

### LME Unifies Existing Capabilities

| Existing/Proposed Capability | LME Equivalence |
|-----|-----|
| Multiple linear regression | LME with no random effects (Z is empty, u is empty) |
| One-way random effects ANOVA | LME with X = [1], one random intercept grouping factor |
| ICC(1,1) | Variance components from one-way random effects LME |
| ICC(2,1) / ICC(3,1) | Variance components from two-way LME |
| Repeated-measures Bland-Altman | LME with differences as response, subject as random intercept |
| REML (Proposal Phase 8) | The estimation method used by LME; Phase 2 of this proposal subsumes Phase 8 |
| Covariate-adjusted ICC | ICC extracted from LME after fitting fixed effects |
| Growth curve analysis | LME with time as fixed + random slope |
| G-theory variance components | Multi-facet LME with crossed random effects |

Building a general LME framework provides all of these as special cases, consolidating what would otherwise be a dozen separate implementations.

## What Already Exists

| Component | Status | Location | Role in LME |
|-----------|--------|----------|-------------|
| `multipleLinearRegression(X:y:)` | Implemented | `Regression/MultipleLinearRegression.swift` | OLS for fixed effects (Phase 2 warm-start) |
| `MatrixBackend` protocol | Implemented | `Regression/MatrixOperations/MatrixBackend.swift` | `multiply`, `solve`, `qrDecomposition` for `[[Double]]` |
| `CPUMatrixBackend` | Implemented | `Regression/MatrixOperations/CPUMatrixBackend.swift` | Pure Swift fallback: multiply, solve (QR), QR decomposition |
| `AccelerateMatrixBackend` | Implemented | `Regression/MatrixOperations/AccelerateMatrixBackend.swift` | BLAS `cblas_dgemm`, LAPACK `dgesv_`, `dgeqrf_`/`dorgqr_` |
| `MetalMatrixBackend` | Implemented | `Regression/MatrixOperations/MetalMatrixBackend.swift` | GPU backend for very large matrices |
| `DenseMatrix<T: Real>` | Implemented | `Regression/MatrixOperations/DenseMatrix.swift` | Generic dense matrix: +, -, scalar*, transpose, multiply, solve (Gaussian elim), identity, diagonal, trace, Frobenius norm |
| `SparseMatrix` | Implemented | `Optimization/SparseMatrix.swift` | CSR-format sparse matrix, matrix-vector multiply |
| `choleskyDecomposition(_:)` | Implemented | `Simulation/CorrelationMatrix.swift` | Cholesky decomposition L such that A = LL' (Double-only) |
| `isPositiveSemiDefinite(_:)` | Implemented | `Simulation/CorrelationMatrix.swift` | PD check via attempted Cholesky |
| `MatrixError` | Implemented | `Simulation/CorrelationMatrix.swift` | `notPositiveDefinite`, `notSquare`, `singularMatrix`, `dimensionMismatch`, etc. |
| `oneWayANOVA(_:)` | Implemented | `ANOVA/oneWayANOVA.swift` | One-way ANOVA decomposition |
| `twoWayANOVA(_:)` | Implemented | `ANOVA/twoWayANOVA.swift` | Two-way ANOVA decomposition |
| `icc(_:model:agreement:confidence:)` | Implemented | `Agreement/icc.swift` | ICC from ANOVA variance components |
| `MultivariateNewtonRaphson` | Implemented | `Optimization/Algorithms/MultivariateNewtonRaphson.swift` | Newton-Raphson with line search and Hessian |
| `MultivariateLBFGS` | Implemented | `Optimization/Algorithms/MultivariateLBFGS.swift` | L-BFGS quasi-Newton optimizer |
| `tCDF(t:df:)`, `tQuantile(p:df:)` | Implemented | `Probability Distribution/T Distribution/` | t-distribution CDF and inverse for p-values and CIs |
| `fCDF(f:df1:df2:)` | Implemented | `Probability Distribution/F Distribution/` | F-distribution CDF for model comparison |
| `chiSquaredCDF(x:df:)` | Implemented | `Probability Distribution/` | Chi-squared CDF for likelihood ratio tests |

### Gap Analysis

The existing infrastructure provides the building blocks but has several gaps:

| Gap | Impact | Resolution |
|-----|--------|------------|
| `choleskyDecomposition` is `Double`-only, not generic | Cannot use with `DenseMatrix<T>` | Phase 1: add generic Cholesky to `DenseMatrix<T>` |
| No `logDeterminant` via Cholesky | REML criterion requires log\|V\| | Phase 1: add to `DenseMatrix<T>` |
| No Cholesky-based `solve` (forward/back substitution) | V^{-1}y via Cholesky is 2x faster than general solve | Phase 1: add to `DenseMatrix<T>` |
| No block-diagonal matrix operations | Random intercept V has block structure; exploiting it is O(sum n_i^3) not O(N^3) | Phase 2: block-diagonal solver |
| `MatrixBackend` is `Double`-only | LME should be generic `<T: Real>` | Phase 1: generic extensions or `DenseMatrix` path |
| No REML estimation | Core of all LME fitting | Phase 2: implement for random intercept |
| No BLUP computation | Predicted random effects u-hat | Phase 2: implement alongside REML |

---

## The Standard Model

The linear mixed-effects model is:

```
y = X * beta + Z * u + epsilon
```

where:
- **y** is the N x 1 response vector (all observations stacked)
- **X** is the N x p fixed-effects design matrix
- **beta** is the p x 1 vector of fixed-effects coefficients
- **Z** is the N x q random-effects design matrix
- **u ~ N(0, G)** is the q x 1 vector of random effects
- **epsilon ~ N(0, R)** is the N x 1 vector of residuals
- **G** is the q x q random-effects variance-covariance matrix
- **R** is the N x N residual variance-covariance matrix

The marginal distribution of y is:

```
y ~ N(X * beta, V)
```

where:

```
V = Z * G * Z' + R
```

This is the key equation. V captures both the random-effects variance (through G) and the residual variance (through R). The structure of G and R is parameterized by a small number of variance parameters theta.

### Fixed-Effects Estimation (GLS)

Given V (or equivalently, given theta), the fixed-effects coefficients are estimated by Generalized Least Squares:

```
beta_hat = (X' * V^{-1} * X)^{-1} * X' * V^{-1} * y
```

This reduces to OLS when V = sigma^2 * I (no random effects).

### Random-Effects Prediction (BLUPs)

The Best Linear Unbiased Predictor of the random effects is:

```
u_hat = G * Z' * V^{-1} * (y - X * beta_hat)
```

These are "shrinkage estimates" -- they pull each group's estimate toward the overall mean, with the degree of shrinkage determined by the ratio of within-group to between-group variance.

### REML Estimation

Restricted Maximum Likelihood (REML) estimates the variance parameters theta by maximizing:

```
l_REML(theta) = -1/2 * [
    (N - p) * log(2*pi)
    + log|V|
    + log|X' * V^{-1} * X|
    + (y - X * beta_hat)' * V^{-1} * (y - X * beta_hat)
]
```

The key terms are:
- `log|V|` -- the log-determinant of the marginal covariance (penalizes large variance)
- `log|X' * V^{-1} * X|` -- the REML correction (accounts for degrees of freedom lost to fixed effects)
- The quadratic form -- the weighted residual sum of squares

REML is preferred over ML because it produces unbiased variance estimates. ML underestimates variance components by a factor of (N - p) / N, analogous to the n vs n-1 bias in sample variance.

### Why Not Just Use ML?

For the same reason we use n-1 in the denominator of sample variance instead of n. ML treats the estimated fixed effects as known constants when computing variance, but they were estimated from the same data. REML integrates out the fixed effects before estimating the variance parameters, removing this bias. The difference matters most when p is not negligible compared to N.

---

## Phase 1: Matrix Infrastructure Extensions

### What Needs to Be Added

The existing `DenseMatrix<T: Real>` has multiplication, transpose, addition, subtraction, scalar multiplication, and Gaussian elimination solve. It lacks Cholesky decomposition, Cholesky-based solve, log-determinant, and matrix inverse -- all essential for the REML criterion.

The existing `choleskyDecomposition(_:)` in `CorrelationMatrix.swift` works for `[[Double]]` but is not integrated with `DenseMatrix<T>`.

### Cholesky Decomposition

For a symmetric positive definite matrix A, the Cholesky decomposition finds a lower triangular matrix L such that A = L * L'.

**Algorithm (Cholesky-Banachiewicz):**

```
For j = 0, 1, ..., n-1:
    L[j][j] = sqrt(A[j][j] - sum_{k=0}^{j-1} L[j][k]^2)
    
    For i = j+1, j+2, ..., n-1:
        L[i][j] = (A[i][j] - sum_{k=0}^{j-1} L[i][k] * L[j][k]) / L[j][j]
```

**Complexity:** O(n^3 / 3), which is half the cost of LU decomposition.

**Numerical guard:** If `A[j][j] - sum < epsilon`, the matrix is not positive definite (or is numerically singular). Throw `MatrixError.notPositiveDefinite`.

### Forward and Back Substitution

Given L from Cholesky, solving Ax = b becomes:
1. **Forward substitution:** Solve L * z = b for z (O(n^2))
2. **Back substitution:** Solve L' * x = z for x (O(n^2))

This is 2x faster than general Gaussian elimination and numerically stable for positive definite systems.

**Forward substitution (L * z = b):**

```
z[0] = b[0] / L[0][0]
For i = 1, ..., n-1:
    z[i] = (b[i] - sum_{k=0}^{i-1} L[i][k] * z[k]) / L[i][i]
```

**Back substitution (L' * x = z):**

```
x[n-1] = z[n-1] / L[n-1][n-1]
For i = n-2, ..., 0:
    x[i] = (z[i] - sum_{k=i+1}^{n-1} L[k][i] * x[k]) / L[i][i]
```

### Log-Determinant via Cholesky

```
log|A| = log|L * L'| = log|L|^2 = 2 * log|L| = 2 * sum_{i=0}^{n-1} log(L[i][i])
```

This is numerically stable (no risk of overflow from computing the determinant directly) and costs only O(n) after the Cholesky is computed.

### Matrix Inverse via Cholesky

```
A^{-1} = (L * L')^{-1} = L'^{-1} * L^{-1}
```

Compute by solving A * X = I column by column using the Cholesky factor. This gives the full inverse in O(n^3 / 3) for the decomposition plus O(n^3) for the n back-solves.

In practice, we should avoid forming the full inverse whenever possible. For the REML criterion, we need:
- `V^{-1} * y` -- solve `V * x = y` via Cholesky (no inverse needed)
- `V^{-1} * X` -- solve `V * W = X` column by column (no inverse needed)
- `X' * V^{-1} * X` -- compute `X' * W` where W = V^{-1} * X
- `log|V|` -- from Cholesky diagonal

The only place the actual inverse is needed is for standard errors of fixed effects, which require `(X' * V^{-1} * X)^{-1}` -- but this is a p x p matrix (small), not the N x N inverse of V.

### Proposed API Extensions to DenseMatrix

```swift
extension DenseMatrix where T: Real {

    /// Cholesky decomposition: A = L * L' where L is lower triangular.
    ///
    /// The matrix must be symmetric and positive definite. The Cholesky
    /// decomposition is unique for positive definite matrices and provides
    /// efficient solving of linear systems, determinant computation, and
    /// matrix inversion.
    ///
    /// - Returns: Lower triangular matrix L such that A = L * L'
    /// - Throws: ``MatrixError/notSquare`` if the matrix is not square.
    ///   ``MatrixError/notPositiveDefinite`` if the matrix is not positive definite.
    /// - Complexity: O(n^3 / 3)
    public func cholesky() throws -> DenseMatrix<T>

    /// Solve A * x = b using the Cholesky decomposition.
    ///
    /// For symmetric positive definite A, this is more efficient and numerically
    /// stable than general Gaussian elimination. The algorithm:
    /// 1. Compute L = cholesky(A)
    /// 2. Forward substitution: solve L * z = b
    /// 3. Back substitution: solve L' * x = z
    ///
    /// - Parameter b: Right-hand side vector (length must equal rows)
    /// - Returns: Solution vector x
    /// - Throws: ``MatrixError/notSquare``, ``MatrixError/notPositiveDefinite``,
    ///   ``MatrixError/dimensionMismatch(expected:actual:)``
    /// - Complexity: O(n^3 / 3) for decomposition + O(n^2) for solve
    public func choleskySolve(_ b: [T]) throws -> [T]

    /// Solve A * X = B for multiple right-hand sides using Cholesky.
    ///
    /// Equivalent to calling ``choleskySolve(_:)`` for each column of B,
    /// but computes the Cholesky decomposition only once.
    ///
    /// - Parameter B: Right-hand side matrix (rows must equal self.rows)
    /// - Returns: Solution matrix X
    /// - Throws: Same as ``choleskySolve(_:)``
    /// - Complexity: O(n^3 / 3) + O(n^2 * k) where k = B.columns
    public func choleskySolve(_ B: DenseMatrix<T>) throws -> DenseMatrix<T>

    /// Log-determinant computed via Cholesky decomposition.
    ///
    /// For a symmetric positive definite matrix A with Cholesky factor L:
    /// ```
    /// log|A| = 2 * sum(log(L[i][i]))
    /// ```
    ///
    /// This is numerically stable (avoids overflow from large determinants)
    /// and efficient (O(n^3/3) for decomposition, O(n) for the sum).
    ///
    /// - Returns: log(|A|) = log(determinant of A)
    /// - Throws: ``MatrixError/notSquare``, ``MatrixError/notPositiveDefinite``
    /// - Complexity: O(n^3 / 3)
    public func logDeterminant() throws -> T

    /// Matrix inverse via Cholesky decomposition.
    ///
    /// For a symmetric positive definite matrix, computes A^{-1} by solving
    /// A * X = I column by column using the Cholesky factor.
    ///
    /// - Note: Prefer ``choleskySolve(_:)`` over forming the explicit inverse
    ///   whenever possible. The inverse is needed only for variance-covariance
    ///   matrices of estimated coefficients, which are typically small (p x p).
    ///
    /// - Returns: The inverse matrix A^{-1}
    /// - Throws: ``MatrixError/notSquare``, ``MatrixError/notPositiveDefinite``
    /// - Complexity: O(n^3)
    public func choleskyInverse() throws -> DenseMatrix<T>
}
```

### Accelerate-Optimized Path

On Apple platforms, the Cholesky decomposition should delegate to LAPACK `dpotrf_` (decompose) and `dpotrs_` (solve) when `T == Double`. This provides significant speedup for N > 100.

```swift
#if canImport(Accelerate)
extension DenseMatrix where T == Double {
    /// Cholesky decomposition using LAPACK dpotrf_.
    internal func choleskyAccelerate() throws -> DenseMatrix<Double>
    
    /// Cholesky solve using LAPACK dpotrs_.
    internal func choleskySolveAccelerate(_ b: [Double]) throws -> [Double]
}
#endif
```

The public API auto-dispatches to Accelerate when available, falling back to pure Swift.

### Effort Estimate

| Component | Lines | Tests |
|-----------|-------|-------|
| Cholesky on `DenseMatrix<T>` | ~60 | ~8 |
| Forward/back substitution (`choleskySolve`) | ~50 | ~6 |
| `logDeterminant` | ~15 | ~3 |
| `choleskyInverse` | ~20 | ~3 |
| Accelerate-optimized path (Double) | ~80 | ~4 |
| Block-diagonal helpers (for Phase 2) | ~60 | ~4 |
| **Total** | **~285** | **~28** |

Estimated sessions: 2-3

---

## Phase 2: Random Intercept Model

The simplest and most common LME model. It covers:
- Covariate-adjusted ICC
- Repeated measures with fixed covariates
- Simple repeated-measures Bland-Altman (subsumes Proposal Phase 8 REML)
- Longitudinal analysis with subject-level variation

### Model

For subject i with n_i observations:

```
y_ij = x_ij' * beta + u_i + e_ij
```

where:
- `y_ij` is observation j of subject i
- `x_ij` is the 1 x p vector of fixed-effects covariates
- `beta` is the p x 1 fixed-effects vector
- `u_i ~ N(0, sigma_u^2)` is the random intercept for subject i
- `e_ij ~ N(0, sigma_e^2)` is the residual error

The random effects design matrix Z is an N x m indicator matrix (m groups), where Z[row, i] = 1 if observation "row" belongs to group i. The random-effects covariance G = sigma_u^2 * I_m.

### Covariance Structure

The marginal covariance of the observation vector for subject i is:

```
V_i = sigma_u^2 * J_{n_i} + sigma_e^2 * I_{n_i}
```

where `J_{n_i}` is the n_i x n_i matrix of all ones and `I_{n_i}` is the identity. This is **compound symmetry**: all observations within a subject have the same variance (`sigma_u^2 + sigma_e^2`) and the same covariance (`sigma_u^2`).

### Closed-Form Inverse and Determinant

Because V_i has compound symmetry, its inverse and determinant have closed forms:

```
V_i^{-1} = (1 / sigma_e^2) * [I_{n_i} - (sigma_u^2 / (sigma_e^2 + n_i * sigma_u^2)) * J_{n_i}]
```

**Derivation:** The Sherman-Morrison-Woodbury formula. V_i = sigma_e^2 * I + sigma_u^2 * 1 * 1', so:

```
V_i^{-1} = (1/sigma_e^2) * I - (1/sigma_e^2) * sigma_u^2 * 1 * 1' * (1/sigma_e^2) / (1 + sigma_u^2 * 1' * (1/sigma_e^2) * I * 1)
         = (1/sigma_e^2) * [I - sigma_u^2 / (sigma_e^2 + n_i * sigma_u^2) * J]
```

**Determinant:**

```
det(V_i) = (sigma_e^2)^{n_i - 1} * (sigma_e^2 + n_i * sigma_u^2)
```

**Log-determinant:**

```
log|V_i| = (n_i - 1) * log(sigma_e^2) + log(sigma_e^2 + n_i * sigma_u^2)
```

Because V is block-diagonal (one block per subject), the total log-determinant is:

```
log|V| = sum_i log|V_i| = sum_i [(n_i - 1) * log(sigma_e^2) + log(sigma_e^2 + n_i * sigma_u^2)]
```

This is O(m) -- the number of subjects -- not O(N^3). This is the key computational advantage of the random intercept model.

### REML Algorithm for Random Intercept

**Parameterization:** Let `theta = (sigma_u^2, sigma_e^2)`. We optimize the profiled REML criterion.

**Step 1: Compute V^{-1} and log|V| for current theta.**

Using the closed forms above, for each subject i:

```
a_i = sigma_e^2 + n_i * sigma_u^2    (within-subject marginal variance contribution)
w_i = sigma_u^2 / a_i                  (shrinkage weight)
```

Then:
```
V_i^{-1} * y_i = (1/sigma_e^2) * (y_i - w_i * sum(y_i) * 1)
```

where `sum(y_i) = sum_j y_ij` is the sum of observations for subject i.

**Step 2: Compute GLS estimate of beta.**

```
beta_hat = (X' * V^{-1} * X)^{-1} * X' * V^{-1} * y
```

Using the block-diagonal structure of V, this reduces to:

```
X' * V^{-1} * X = sum_i X_i' * V_i^{-1} * X_i
X' * V^{-1} * y = sum_i X_i' * V_i^{-1} * y_i
```

Each term is computed using the closed-form V_i^{-1}, so the total cost is O(sum_i n_i * p^2) = O(N * p^2).

**Step 3: Compute the REML criterion.**

```
l_REML(theta) = -1/2 * [
    (N - p) * log(2*pi)
    + log|V|
    + log|X' * V^{-1} * X|
    + r' * V^{-1} * r
]
```

where `r = y - X * beta_hat` is the residual vector.

The quadratic form `r' * V^{-1} * r` decomposes by subject:

```
r' * V^{-1} * r = sum_i r_i' * V_i^{-1} * r_i
                = sum_i [(1/sigma_e^2) * sum_j r_ij^2 - (w_i / sigma_e^2) * (sum_j r_ij)^2]
                = (1/sigma_e^2) * [sum_i sum_j r_ij^2 - sum_i w_i * (sum_j r_ij)^2]
```

**Step 4: Optimize theta.**

The REML criterion is a smooth function of two parameters (sigma_u^2, sigma_e^2). Optimization options:

**Option A: Fisher Scoring (recommended for Phase 2).**

Fisher scoring uses the expected information matrix, which has a clean closed form for compound symmetry. Define:

```
a_i = sigma_e^2 + n_i * sigma_u^2
```

The score vector (gradient of l_REML with respect to theta) is:

```
S_1 = dl/d(sigma_e^2) = -1/2 * [sum_i (n_i - 1)/sigma_e^2 + sum_i 1/a_i
                         - (1/sigma_e^4) * sum_i S_i
                         - sum_i (sum_j r_ij)^2 / a_i^2
                         + REML correction terms]

S_2 = dl/d(sigma_u^2) = -1/2 * [sum_i n_i/a_i
                         - sum_i n_i^2 * (sum_j r_ij / n_i)^2 / a_i^2
                         + REML correction terms]
```

where `S_i = sum_j (r_ij - r_bar_i)^2` is the within-subject residual sum of squares.

The expected Fisher information matrix:

```
I_11 = 1/2 * [sum_i (n_i - 1)/sigma_e^4 + sum_i 1/a_i^2]    (for sigma_e^2)
I_22 = 1/2 * sum_i n_i^2/a_i^2                                 (for sigma_u^2)
I_12 = 1/2 * sum_i n_i/a_i^2                                   (= I_21)
```

Update: `theta_{t+1} = theta_t + I(theta_t)^{-1} * S(theta_t)`

For a 2 x 2 information matrix, the inverse is:

```
I^{-1} = (1/det) * [[I_22, -I_12], [-I_12, I_11]]
det = I_11 * I_22 - I_12^2
```

**Option B: Profile likelihood with 1D optimization.**

For the random intercept model specifically, we can profile out sigma_e^2 analytically. Define the variance ratio `rho = sigma_u^2 / sigma_e^2`. Then the REML criterion is a function of rho alone, and sigma_e^2 has a closed-form MLE for each rho:

```
sigma_e^2(rho) = r' * V(rho)^{-1} * r / (N - p)
```

where `V(rho) = I + rho * Z * Z'`. This reduces the optimization to a 1D problem over rho >= 0, which can be solved by Brent's method or a simple grid search followed by golden section refinement.

We recommend Fisher scoring for Phase 2 because it generalizes to Phases 3 and 4, where profiling becomes more complex. The 1D profile approach should be available as a fallback for difficult convergence cases.

**Step 5: Compute BLUPs.**

```
u_hat_i = sigma_u^2 * 1_i' * V_i^{-1} * r_i
         = sigma_u^2 * (1/sigma_e^2) * (sum_j r_ij - w_i * n_i * sum_j r_ij)
         = (sigma_u^2 / a_i) * sum_j r_ij
         = w_i * n_i * r_bar_i
```

where `r_bar_i = (1/n_i) * sum_j r_ij` is the mean residual for subject i.

This has a beautiful interpretation: the BLUP for subject i is a shrinkage estimate of the group mean residual, pulled toward zero by the factor `w_i * n_i = n_i * sigma_u^2 / (sigma_e^2 + n_i * sigma_u^2)`. Groups with more observations (large n_i) or high between-group variance (large sigma_u^2) are shrunk less.

**Step 6: Convergence.**

- **Criterion:** Relative change in REML log-likelihood: `|l_{t+1} - l_t| / |l_t| < tolerance`
- **Default tolerance:** 1e-8
- **Maximum iterations:** 100
- **Constraint enforcement:** After each update, clamp `sigma_u^2 >= 0` and `sigma_e^2 >= T.ulpOfOne`. If Fisher scoring proposes a step that would make either component negative, halve the step size (up to 10 halvings).
- **Initialization:** Method-of-moments from one-way ANOVA of residuals after OLS fit.

### Proposed API

```swift
/// A grouping factor that assigns each observation to a group.
///
/// Observations within the same group share a random effect.
/// For example, `groups[j] = i` means observation j belongs to group i.
public struct GroupingFactor: Sendable, Equatable {
    /// Group assignments for each observation.
    /// Values are integer group identifiers (0-indexed).
    public let groups: [Int]
    
    /// Number of distinct groups.
    public let groupCount: Int
    
    /// Number of observations in each group.
    public let groupSizes: [Int]
    
    /// Creates a grouping factor from group assignments.
    ///
    /// - Parameter groups: Array mapping each observation to its group (0-indexed).
    /// - Throws: `BusinessMathError.invalidInput` if groups is empty
    ///   or contains negative values.
    public init(_ groups: [Int]) throws
}

/// Specification of a random-intercept linear mixed-effects model.
///
/// The model is: y_ij = x_ij' * beta + u_i + e_ij
/// where u_i ~ N(0, sigma_u^2) and e_ij ~ N(0, sigma_e^2).
public struct RandomInterceptModel<T: Real>: Sendable {
    /// Fixed-effects design matrix X (N x p).
    /// Each row is an observation, each column is a predictor.
    /// An intercept column is added automatically.
    public let fixedEffects: DenseMatrix<T>
    
    /// Response vector y (length N).
    public let response: [T]
    
    /// Grouping factor assigning observations to groups.
    public let grouping: GroupingFactor
}

/// Result of fitting a random-intercept LME model.
public struct RandomInterceptResult<T: Real>: Sendable, Equatable {
    /// Fixed-effects coefficients (beta), including intercept at index 0.
    public let beta: [T]
    
    /// Standard errors of fixed-effects coefficients.
    public let standardErrors: [T]
    
    /// t-statistics for fixed effects (beta / SE).
    public let tStatistics: [T]
    
    /// p-values for fixed effects (two-tailed t-test).
    /// Degrees of freedom approximated by Satterthwaite method.
    public let pValues: [T]
    
    /// Confidence intervals for fixed effects.
    public let confidenceIntervals: [(lower: T, upper: T)]
    
    /// Random-effects variance component (sigma_u^2).
    public let varianceRandom: T
    
    /// Residual variance component (sigma_e^2).
    public let varianceResidual: T
    
    /// Total variance (sigma_u^2 + sigma_e^2).
    public let varianceTotal: T
    
    /// Intraclass correlation coefficient: sigma_u^2 / (sigma_u^2 + sigma_e^2).
    public let icc: T
    
    /// REML log-likelihood at convergence.
    public let remlLogLikelihood: T
    
    /// ML log-likelihood at convergence (for AIC/BIC computation).
    public let mlLogLikelihood: T
    
    /// AIC = -2 * logLik_ML + 2 * k (where k = number of parameters).
    public let aic: T
    
    /// BIC = -2 * logLik_ML + k * log(N).
    public let bic: T
    
    /// Predicted random effects (BLUPs) for each group.
    /// u_hat[i] is the estimated random intercept for group i.
    public let randomEffects: [T]
    
    /// Conditional standard deviations of the random effects.
    /// Measures the uncertainty in each BLUP estimate.
    public let randomEffectsSE: [T]
    
    /// Residuals: y - X * beta_hat - Z * u_hat (conditional residuals).
    public let residuals: [T]
    
    /// Marginal residuals: y - X * beta_hat (fixed-effects residuals only).
    public let marginalResiduals: [T]
    
    /// Fitted values: X * beta_hat + Z * u_hat (conditional fitted values).
    public let fittedValues: [T]
    
    /// Number of observations.
    public let observations: Int
    
    /// Number of groups.
    public let groups: Int
    
    /// Number of fixed-effects parameters (including intercept).
    public let fixedEffectsCount: Int
    
    /// Number of Fisher scoring iterations to convergence.
    public let iterations: Int
    
    /// Whether the algorithm converged within the iteration limit.
    public let converged: Bool
}

/// Fit a random-intercept linear mixed-effects model via REML.
///
/// Estimates fixed effects (beta) and variance components (sigma_u^2, sigma_e^2)
/// for the model:
/// ```
/// y_ij = x_ij' * beta + u_i + e_ij
/// ```
/// where u_i ~ N(0, sigma_u^2) and e_ij ~ N(0, sigma_e^2).
///
/// The algorithm:
/// 1. Initialize variance components from method-of-moments (one-way ANOVA).
/// 2. Iterate Fisher scoring on the profiled REML criterion.
/// 3. At each step, compute GLS estimates of beta given current variance components.
/// 4. After convergence, compute BLUPs, standard errors, and diagnostics.
///
/// ## Example: Covariate-Adjusted ICC
///
/// ```swift
/// // Patients measured repeatedly; adjust for age
/// let X = try DenseMatrix(patients.map { [$0.age] })
/// let y = patients.flatMap { $0.measurements }
/// let groups = try GroupingFactor(patients.flatMap { p in
///     Array(repeating: p.id, count: p.measurements.count)
/// })
///
/// let model = RandomInterceptModel(
///     fixedEffects: X, response: y, grouping: groups
/// )
/// let result = try fitRandomIntercept(model)
/// print("Adjusted ICC: \(result.icc)")
/// ```
///
/// - Parameters:
///   - model: The random intercept model specification.
///   - maxIterations: Maximum Fisher scoring iterations (default 100).
///   - tolerance: Relative convergence tolerance for REML log-likelihood (default 1e-8).
///   - confidenceLevel: Confidence level for fixed-effects intervals (default 0.95).
/// - Returns: A ``RandomInterceptResult`` with all estimates and diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups,
///   or total observations do not exceed the number of fixed-effects parameters.
///   `BusinessMathError.mismatchedDimensions` if X rows != y length != groups length.
///   `MatrixError.singularMatrix` if X'V^{-1}X is singular.
public func fitRandomIntercept<T: Real>(
    _ model: RandomInterceptModel<T>,
    maxIterations: Int = 100,
    tolerance: T = T(1) / T(100_000_000),
    confidenceLevel: T = T(95) / T(100)
) throws -> RandomInterceptResult<T>
```

### Effort Estimate

| Component | Lines | Tests |
|-----------|-------|-------|
| `GroupingFactor` | ~30 | ~5 |
| `RandomInterceptModel`, `RandomInterceptResult` | ~60 | -- |
| Block-diagonal V^{-1} and log\|V\| | ~40 | ~5 |
| GLS beta estimation | ~30 | ~3 |
| REML criterion evaluation | ~40 | ~4 |
| Fisher scoring iteration | ~60 | ~5 |
| BLUP computation | ~20 | ~3 |
| Standard errors and p-values | ~30 | ~3 |
| Integration (fitRandomIntercept) | ~40 | ~5 |
| **Total** | **~350** | **~33** |

Estimated sessions: 2-3

### Test Plan

**Correctness:**
1. No covariates (X = [1]): ICC matches `icc(_:model:.oneWayRandom:agreement:.absolute)` within 1e-6
2. Balanced design: REML matches method-of-moments from one-way ANOVA within 1e-6
3. Unbalanced design: REML produces non-negative sigma_u^2 even when MoM would be negative
4. Perfect agreement (all observations equal within groups): sigma_e^2 near 0
5. No group effect (all observations from same distribution): sigma_u^2 near 0, ICC near 0
6. Known dataset: cross-validate against R `lme4::lmer()` for beta, sigma_u^2, sigma_e^2, BLUPs (tolerance 1e-4)
7. Single fixed covariate (age): adjusted ICC < marginal ICC when age explains between-subject variance

**Convergence:**
8. Converges within 20 iterations for well-conditioned data
9. REML log-likelihood increases monotonically across iterations
10. Non-convergence: adversarial data with maxIterations=2, verify `converged == false`

**Edge cases:**
11. Fewer than 2 groups: throws `insufficientData`
12. Single observation per group: degenerate (no within-group df), sigma_e^2 estimated from total residual
13. Group sizes of 1 and 100: unbalanced case, BLUPs for size-1 groups shrunk heavily toward zero
14. Dimension mismatch (X rows != y length): throws `mismatchedDimensions`

**Diagnostics:**
15. Residuals sum to approximately zero
16. Conditional residuals (y - X*beta - Z*u_hat) have smaller variance than marginal residuals (y - X*beta)
17. AIC and BIC are finite and computable

---

## Phase 3: Random Intercept + Slope Model

### Model

Extends Phase 2 to allow the effect of a time-like covariate to vary by group:

```
y_ij = x_ij' * beta + u_0i + u_1i * t_ij + e_ij
```

where:

```
(u_0i, u_1i)' ~ N(0, G)    with G = [[sigma_0^2, sigma_01],
                                       [sigma_01,  sigma_1^2]]
```

This captures:
- **Random intercept** (sigma_0^2): groups start at different baselines
- **Random slope** (sigma_1^2): groups change at different rates
- **Covariance** (sigma_01): whether groups that start high also change faster (or slower)

### Covariance Structure

The random-effects design matrix for subject i is:

```
Z_i = [1  t_i1]
      [1  t_i2]
      [... ...]
      [1  t_{in_i}]
```

The marginal covariance for subject i is:

```
V_i = Z_i * G * Z_i' + sigma_e^2 * I_{n_i}
```

This is no longer compound symmetry -- V_i has a more complex structure where the (j, k) element is:

```
V_i[j,k] = sigma_0^2 + sigma_01 * (t_ij + t_ik) + sigma_1^2 * t_ij * t_ik + sigma_e^2 * delta_{jk}
```

### Cholesky Parameterization of G

G must be positive definite. Rather than optimizing sigma_0^2, sigma_01, sigma_1^2 directly (which may yield non-PD G), we parameterize via the Cholesky factor:

```
G = L * L'    where L = [[l_11, 0   ],
                          [l_21, l_22]]
```

So:
```
sigma_0^2 = l_11^2
sigma_01  = l_21 * l_11
sigma_1^2 = l_21^2 + l_22^2
```

The REML criterion is then optimized over (l_11, l_21, l_22, sigma_e^2) with the constraint l_11 > 0, l_22 > 0, sigma_e^2 > 0. This is an unconstrained optimization if we reparameterize as (log(l_11), l_21, log(l_22), log(sigma_e^2)).

### REML with General Per-Subject V_i

For Phase 3, V_i is no longer compound symmetry, so we lose the closed-form inverse. However, V_i is only n_i x n_i (typically 3-20 observations per subject), so a per-subject Cholesky decomposition is cheap:

```
For each subject i:
    Compute V_i = Z_i * G * Z_i' + sigma_e^2 * I
    Compute L_i = cholesky(V_i)                          O(n_i^3)
    Compute log|V_i| = 2 * sum(log(diag(L_i)))           O(n_i)
    Solve V_i^{-1} * y_i via forward/back substitution    O(n_i^2)
    Solve V_i^{-1} * X_i via forward/back substitution    O(n_i^2 * p)
```

Total cost: O(sum_i n_i^3 + N * p^2), which is much cheaper than the naive O(N^3).

### Optimization

With 4 parameters (3 Cholesky elements + sigma_e^2), Fisher scoring or L-BFGS-B are both viable. We recommend:

1. **Fisher scoring** for the first implementation (consistent with Phase 2)
2. **L-BFGS** as a fallback via the existing `MultivariateLBFGS` optimizer

The gradient can be computed analytically or via finite differences. For Phase 3, finite differences over 4 parameters are cheap and avoid error-prone analytic gradient derivation. Analytic gradients can be added as a performance optimization later.

### Proposed API

```swift
/// Specification of the random-effects structure.
public struct RandomEffectsStructure<T: Real>: Sendable {
    /// Column indices in the fixed-effects design matrix that also appear
    /// as random effects. For a random intercept model, this is [].
    /// For a random intercept + slope on column 1, this is [1].
    /// The intercept (column 0 after prepending) is always included as random.
    public let randomSlopeColumns: [Int]
}

/// Specification of a random intercept + slope LME model.
///
/// The model is: y_ij = x_ij' * beta + z_ij' * u_i + e_ij
/// where u_i ~ N(0, G), G is a q x q covariance matrix,
/// and z_ij is the random-effects design vector for observation j of group i.
public struct RandomSlopeModel<T: Real>: Sendable {
    /// Fixed-effects design matrix X (N x p, without intercept -- added automatically).
    public let fixedEffects: DenseMatrix<T>
    
    /// Response vector y (length N).
    public let response: [T]
    
    /// Grouping factor.
    public let grouping: GroupingFactor
    
    /// Random-effects structure (which fixed effects also have random components).
    public let randomEffects: RandomEffectsStructure<T>
}

/// Result of fitting a random intercept + slope LME model.
public struct RandomSlopeResult<T: Real>: Sendable, Equatable {
    /// Fixed-effects coefficients (beta), including intercept.
    public let beta: [T]
    
    /// Standard errors of fixed effects.
    public let standardErrors: [T]
    
    /// t-statistics for fixed effects.
    public let tStatistics: [T]
    
    /// p-values for fixed effects.
    public let pValues: [T]
    
    /// Confidence intervals for fixed effects.
    public let confidenceIntervals: [(lower: T, upper: T)]
    
    /// Random-effects covariance matrix G (q x q).
    public let covarianceRandom: DenseMatrix<T>
    
    /// Residual variance (sigma_e^2).
    public let varianceResidual: T
    
    /// Correlation between random intercept and random slope.
    public let randomCorrelation: T
    
    /// REML and ML log-likelihoods.
    public let remlLogLikelihood: T
    public let mlLogLikelihood: T
    
    /// AIC and BIC.
    public let aic: T
    public let bic: T
    
    /// Predicted random effects for each group (m x q matrix).
    /// Row i contains the BLUPs (u_hat_0i, u_hat_1i, ...) for group i.
    public let randomEffects: DenseMatrix<T>
    
    /// Residuals and fitted values.
    public let residuals: [T]
    public let fittedValues: [T]
    
    /// Convergence information.
    public let iterations: Int
    public let converged: Bool
    
    /// Number of random-effects parameters per group (q).
    public let randomEffectsPerGroup: Int
}

/// Fit a random intercept + slope LME model via REML.
///
/// ## Example: Growth Curve
///
/// ```swift
/// // Students tested at times 0, 1, 2, 3
/// let X = try DenseMatrix(observations.map { [$0.time, $0.isFemale ? 1.0 : 0.0] })
/// let y = observations.map { $0.score }
/// let groups = try GroupingFactor(observations.map { $0.studentId })
///
/// let model = RandomSlopeModel(
///     fixedEffects: X, response: y, grouping: groups,
///     randomEffects: RandomEffectsStructure(randomSlopeColumns: [0])  // time
/// )
/// let result = try fitRandomSlope(model)
/// // result.beta[1] = average growth rate
/// // result.covarianceRandom[1,1] = variance in growth rates across students
/// ```
public func fitRandomSlope<T: Real>(
    _ model: RandomSlopeModel<T>,
    maxIterations: Int = 200,
    tolerance: T = T(1) / T(100_000_000),
    confidenceLevel: T = T(95) / T(100)
) throws -> RandomSlopeResult<T>
```

### Effort Estimate

| Component | Lines | Tests |
|-----------|-------|-------|
| `RandomEffectsStructure`, `RandomSlopeModel`, `RandomSlopeResult` | ~70 | -- |
| Per-subject V_i construction | ~30 | ~3 |
| Per-subject Cholesky solve | ~20 | ~2 |
| Cholesky parameterization of G | ~30 | ~4 |
| REML criterion with general V_i | ~50 | ~4 |
| Fisher scoring / L-BFGS optimization | ~50 | ~4 |
| BLUP computation for q > 1 | ~25 | ~3 |
| Integration (fitRandomSlope) | ~40 | ~4 |
| **Total** | **~315** | **~24** |

Estimated sessions: 2-3

### Test Plan

1. Random intercept only (no slope columns): matches Phase 2 results exactly
2. Known growth curve data: cross-validate beta, G, BLUPs against R `lme4::lmer(score ~ time + (1 + time | student))`
3. Uncorrelated random effects: estimated correlation near zero for simulated data with sigma_01 = 0
4. Positive random correlation: students who start high grow faster
5. Negative random correlation: students who start high grow slower
6. Cholesky parameterization: G is always positive semi-definite by construction
7. Single observation per group: degenerate random slope, should fall back gracefully
8. Convergence: REML log-likelihood increases monotonically

---

## Phase 4: General LME

### Model

Arbitrary fixed-effects matrix X, arbitrary random-effects matrix Z, arbitrary grouping structure (including crossed random effects and multiple grouping factors).

```
y = X * beta + Z_1 * u_1 + Z_2 * u_2 + ... + epsilon
```

where each `u_k ~ N(0, G_k)` corresponds to a different grouping factor.

### Crossed vs. Nested Random Effects

- **Nested:** Students within schools. Each student belongs to exactly one school.
- **Crossed:** Subjects crossed with items. Each subject sees every item.

The distinction matters computationally:
- Nested: Z has block structure, V is block-diagonal (efficient)
- Crossed: V is NOT block-diagonal; it is dense or has complex sparsity (expensive)

### The lme4 Algorithm (Bates et al. 2015)

The state-of-the-art approach, used by R's `lme4::lmer()`:

**1. Profile out beta and sigma^2.**

The REML criterion can be written as:

```
l_REML(theta) = -1/2 * [
    (N - p) * log(2*pi)
    + (N - p) * log(sigma_hat^2(theta))
    + log|L_theta|^2
    + log|R_X|^2
    + (N - p)
]
```

where:
- theta parameterizes G (via Cholesky factor of G/sigma^2)
- L_theta is the Cholesky factor of a sparse matrix derived from Z and theta
- R_X is from the sparse QR of a weighted design matrix
- sigma_hat^2(theta) is the profiled residual variance

This profiled criterion depends only on theta (the relative covariance parameters), not on beta or sigma^2.

**2. Optimize over theta.**

lme4 uses BOBYQA (derivative-free bounded optimization). For our library, we can use:
- Newton-Raphson with finite-difference gradients (existing `MultivariateNewtonRaphson`)
- L-BFGS (existing `MultivariateLBFGS`)
- A simple Nelder-Mead implementation as derivative-free fallback

**3. Recover beta and sigma^2.**

Given theta_hat, solve the mixed-model equations:

```
[X'R^{-1}X     X'R^{-1}Z     ] [beta_hat] = [X'R^{-1}y]
[Z'R^{-1}X     Z'R^{-1}Z + G^{-1}] [u_hat  ]   [Z'R^{-1}y]
```

These are Henderson's mixed-model equations. For R = sigma^2 * I, they simplify to:

```
[X'X     X'Z        ] [beta_hat] = [X'y]
[Z'X     Z'Z + G^{-1}/sigma^2] [u_hat  ]   [Z'y]
```

### Sparse Matrix Considerations

For crossed random effects with many levels, the coefficient matrix of Henderson's equations is large but sparse. The existing `SparseMatrix` (CSR format) can be extended with:
- Sparse Cholesky decomposition (AMD ordering for fill-reduction)
- Sparse triangular solve

This is a significant engineering effort. Phase 4 should support nested random effects with dense per-block computations initially, with sparse support as a Phase 4b extension.

### Proposed API

```swift
/// A random-effects term in a general LME model.
///
/// Each term specifies a grouping factor and the random-effects
/// design matrix for that grouping factor.
public struct RandomEffectsTerm<T: Real>: Sendable {
    /// The grouping factor for this random effect.
    public let grouping: GroupingFactor
    
    /// Column indices from the fixed-effects matrix that have
    /// random components under this grouping factor.
    /// An empty array means random intercept only.
    public let randomColumns: [Int]
    
    /// Human-readable label (e.g., "subject", "school").
    public let label: String
}

/// General linear mixed-effects model specification.
public struct LMEModel<T: Real>: Sendable {
    /// Fixed-effects design matrix (N x p, without intercept).
    public let fixedEffects: DenseMatrix<T>
    
    /// Response vector (length N).
    public let response: [T]
    
    /// Random-effects terms (one or more grouping factors).
    public let randomEffects: [RandomEffectsTerm<T>]
}

/// Result of fitting a general LME model.
public struct LMEResult<T: Real>: Sendable {
    /// Fixed-effects coefficients.
    public let beta: [T]
    
    /// Standard errors of fixed effects.
    public let standardErrors: [T]
    
    /// t-statistics for fixed effects.
    public let tStatistics: [T]
    
    /// p-values for fixed effects (Satterthwaite df approximation).
    public let pValues: [T]
    
    /// Confidence intervals for fixed effects.
    public let confidenceIntervals: [(lower: T, upper: T)]
    
    /// Variance components for each random-effects term.
    /// For term k with q_k random effects per group, this is the q_k x q_k G_k matrix.
    public let varianceComponents: [DenseMatrix<T>]
    
    /// Residual variance (sigma_e^2).
    public let varianceResidual: T
    
    /// REML and ML log-likelihoods.
    public let remlLogLikelihood: T
    public let mlLogLikelihood: T
    
    /// AIC and BIC.
    public let aic: T
    public let bic: T
    
    /// Predicted random effects (BLUPs) for each term.
    /// randomEffectsBLUPs[k][i] is the BLUP vector for group i under term k.
    public let randomEffectsBLUPs: [[[T]]]
    
    /// Residuals and fitted values.
    public let residuals: [T]
    public let fittedValues: [T]
    
    /// Convergence information.
    public let iterations: Int
    public let converged: Bool
}

/// Fit a general linear mixed-effects model via REML.
///
/// Supports multiple random-effects terms (nested or crossed grouping factors)
/// with arbitrary random-effects structure per term.
///
/// ## Example: Students Nested in Schools
///
/// ```swift
/// let X = try DenseMatrix(data.map { [$0.time, $0.ses] })
/// let y = data.map { $0.score }
///
/// let model = LMEModel(
///     fixedEffects: X, response: y,
///     randomEffects: [
///         RandomEffectsTerm(
///             grouping: try GroupingFactor(data.map { $0.schoolId }),
///             randomColumns: [0],  // random slope on time
///             label: "school"
///         ),
///         RandomEffectsTerm(
///             grouping: try GroupingFactor(data.map { $0.studentId }),
///             randomColumns: [],  // random intercept only
///             label: "student"
///         )
///     ]
/// )
/// let result = try fitLME(model)
/// ```
public func fitLME<T: Real>(
    _ model: LMEModel<T>,
    maxIterations: Int = 200,
    tolerance: T = T(1) / T(100_000_000),
    confidenceLevel: T = T(95) / T(100)
) throws -> LMEResult<T>
```

### Effort Estimate

| Component | Lines | Tests |
|-----------|-------|-------|
| `RandomEffectsTerm`, `LMEModel`, `LMEResult` | ~80 | -- |
| Henderson's mixed-model equations | ~60 | ~5 |
| General REML criterion (profiled) | ~80 | ~5 |
| Optimization wrapper (Fisher scoring + L-BFGS fallback) | ~60 | ~4 |
| Multiple grouping factors | ~50 | ~5 |
| Integration (fitLME) | ~50 | ~5 |
| **Total** | **~380** | **~24** |

Estimated sessions: 3-4

---

## Phase 5: Model Diagnostics and Inference

### Residual Diagnostics

```swift
/// Diagnostic plots data for an LME model.
public struct LMEDiagnostics<T: Real>: Sendable {
    /// Conditional residuals (y - X*beta_hat - Z*u_hat).
    public let conditionalResiduals: [T]
    
    /// Marginal residuals (y - X*beta_hat).
    public let marginalResiduals: [T]
    
    /// Standardized conditional residuals (Pearson residuals).
    public let standardizedResiduals: [T]
    
    /// Fitted values (X*beta_hat + Z*u_hat).
    public let fittedValues: [T]
    
    /// QQ-plot data: sorted standardized residuals vs theoretical quantiles.
    public let qqPlotData: [(theoretical: T, observed: T)]
    
    /// Residuals vs fitted values (for heteroscedasticity detection).
    public let residualVsFitted: [(fitted: T, residual: T)]
}
```

### Likelihood Ratio Test

For comparing nested models (e.g., random intercept vs. random intercept + slope):

```
LRT = -2 * (l_reduced - l_full)
```

Under H0 (reduced model is correct), LRT approximately follows a chi-squared distribution. However, when testing whether a variance component is zero (boundary of parameter space), the null distribution is a mixture of chi-squared distributions.

```swift
/// Likelihood ratio test comparing two nested LME models.
///
/// The full model must contain all the random effects of the reduced model
/// plus additional ones. The test statistic is:
/// ```
/// LRT = -2 * (logLik_reduced - logLik_full)
/// ```
///
/// - Warning: When testing variance components at the boundary (H0: sigma^2 = 0),
///   the p-value from a standard chi-squared is conservative.
///   The correct null distribution is a 50:50 mixture of chi^2(0) and chi^2(1)
///   for a single variance component, or more complex mixtures for multiple components.
///
/// - Parameters:
///   - reduced: The simpler (reduced) model result.
///   - full: The more complex (full) model result.
/// - Returns: Test statistic, degrees of freedom, and p-value.
public func likelihoodRatioTest<T: Real>(
    reduced: LMEResult<T>,
    full: LMEResult<T>
) throws -> (statistic: T, df: Int, pValue: T)
```

### Satterthwaite Degrees of Freedom

In OLS, degrees of freedom for t-tests are simply N - p. In LME, the effective degrees of freedom for each fixed effect depend on the variance components and the design structure. The Satterthwaite approximation computes:

```
df_j = 2 * (Var(beta_hat_j))^2 / Var(Var(beta_hat_j))
```

where the variance of the variance is estimated from the second derivatives of the REML criterion. This is the default in R's `lmerTest::lmer()` and SAS PROC MIXED.

### Information Criteria

```
AIC = -2 * logLik_ML + 2 * k
BIC = -2 * logLik_ML + k * log(N)
```

where k is the total number of parameters (p fixed + number of theta parameters + 1 for sigma^2).

For comparing models with different fixed effects, use ML (not REML) log-likelihood. For comparing models with different random effects, either ML or REML is acceptable.

### Effort Estimate

| Component | Lines | Tests |
|-----------|-------|-------|
| `LMEDiagnostics` computation | ~50 | ~5 |
| Likelihood ratio test | ~30 | ~5 |
| Satterthwaite df approximation | ~60 | ~5 |
| Model comparison (AIC/BIC) | ~20 | ~3 |
| Prediction intervals | ~30 | ~3 |
| **Total** | **~190** | **~21** |

Estimated sessions: 1-2

---

## Phase 6: Specialized Applications

### Covariate-Adjusted Bland-Altman

Fit an LME model with differences as response, covariates as fixed effects, and subjects as random intercepts. Extract:
- **Adjusted bias:** Fixed-effects prediction at covariate values of interest
- **Adjusted limits of agreement:** +/- 1.96 * sqrt(sigma_u^2 + sigma_e^2) evaluated at specific covariate values
- **Covariate-dependent limits:** If the model includes interaction terms or non-linear covariate effects

```swift
/// Covariate-adjusted Bland-Altman analysis using LME.
///
/// Fits the model: d_ij = beta_0 + beta_1 * cov_ij + u_i + e_ij
/// where d_ij = x_ij - y_ij is the difference and cov_ij is the covariate.
///
/// - Parameters:
///   - x: Measurements from method A (grouped by subject).
///   - y: Measurements from method B (grouped by subject).
///   - covariates: Covariate matrix (N x k), same ordering as x/y.
///   - groups: Subject grouping.
/// - Returns: Model result plus convenience properties for agreement analysis.
public func covariateAdjustedBlandAltman<T: Real>(
    x: [T], y: [T],
    covariates: DenseMatrix<T>,
    groups: GroupingFactor
) throws -> CovariateAdjustedAgreementResult<T>
```

### Growth Curve Analysis

A convenience wrapper around the random slope model for longitudinal data:

```swift
/// Fit a growth curve model.
///
/// Convenience wrapper for: score ~ time + covariates + (1 + time | group)
///
/// - Parameters:
///   - time: Time points for each observation.
///   - response: Outcome values.
///   - covariates: Optional fixed-effects covariates.
///   - groups: Grouping factor (e.g., students, patients).
/// - Returns: Growth curve result with group-level trajectories.
public func fitGrowthCurve<T: Real>(
    time: [T],
    response: [T],
    covariates: DenseMatrix<T>?,
    groups: GroupingFactor
) throws -> GrowthCurveResult<T>
```

### Covariate-Adjusted ICC

Extract ICC from an LME model after adjusting for fixed effects:

```swift
/// Compute the adjusted ICC from a random-intercept LME result.
///
/// The adjusted ICC is sigma_u^2 / (sigma_u^2 + sigma_e^2) from the LME model
/// that includes fixed-effects covariates. This measures reliability after
/// accounting for known sources of between-subject variation.
///
/// - Parameter result: A fitted random-intercept LME result.
/// - Returns: The adjusted ICC value.
public func adjustedICC<T: Real>(_ result: RandomInterceptResult<T>) -> T {
    return result.icc  // Already computed in the result
}
```

### Effort Estimate

| Component | Lines | Tests |
|-----------|-------|-------|
| `covariateAdjustedBlandAltman` | ~40 | ~5 |
| `fitGrowthCurve` | ~30 | ~4 |
| Convenience types (`CovariateAdjustedAgreementResult`, `GrowthCurveResult`) | ~50 | -- |
| **Total** | **~120** | **~9** |

Estimated sessions: 1

---

## Effort Estimates Summary

| Phase | New Lines | Tests | Sessions | Delivers |
|-------|-----------|-------|----------|----------|
| 1: Matrix Infrastructure | ~285 | ~28 | 2-3 | Cholesky on DenseMatrix, log-determinant, Cholesky solve |
| 2: Random Intercept | ~350 | ~33 | 2-3 | Covariate-adjusted ICC, simple repeated measures, REML |
| 3: Random Intercept + Slope | ~315 | ~24 | 2-3 | Growth curves, time-varying effects |
| 4: General LME | ~380 | ~24 | 3-4 | Multiple grouping factors, nested/crossed random effects |
| 5: Diagnostics | ~190 | ~21 | 1-2 | LRT, Satterthwaite df, AIC/BIC, residual analysis |
| 6: Applications | ~120 | ~9 | 1 | Convenience wrappers for agreement and growth |
| **Total** | **~1,640** | **~139** | **12-16** | |

---

## Architecture Decisions

### 1. Matrix Type Strategy

**Decision:** Extend `DenseMatrix<T: Real>` with Cholesky decomposition and related operations. Do not create a new matrix type.

**Rationale:**
- `DenseMatrix<T>` already exists with transpose, multiply, add, subtract, scalar multiply, solve, identity, diagonal, trace, and Frobenius norm.
- Adding Cholesky, log-determinant, and Cholesky-based solve to `DenseMatrix<T>` is natural and avoids type proliferation.
- The existing `choleskyDecomposition(_:)` in `CorrelationMatrix.swift` works on `[[Double]]`; the new implementation on `DenseMatrix<T>` generalizes this to any `Real` type.
- For the `MatrixBackend` protocol (Double-only), the Accelerate-optimized path can be accessed internally when `T == Double`.

### 2. Optimization Strategy

**Decision:** Fisher scoring for Phases 2-3; L-BFGS (via existing `MultivariateLBFGS`) as fallback for Phase 4.

**Rationale:**
- Fisher scoring is the standard for REML optimization. It converges quadratically near the optimum and uses the expected information matrix, which is easier to derive than the observed Hessian.
- For the random intercept model (Phase 2), the Fisher information has a clean 2x2 closed form, making Fisher scoring trivial.
- For the random intercept + slope (Phase 3), the Fisher information is 4x4 and still manageable.
- For the general case (Phase 4), the number of theta parameters can be large. L-BFGS avoids forming the full Hessian while still achieving superlinear convergence.
- The existing `MultivariateNewtonRaphson` and `MultivariateLBFGS` can be reused directly, passing the REML criterion as the objective function.

### 3. Sparse Matrices

**Decision:** Phase 4 initially supports nested random effects with dense per-block computations. Sparse Cholesky for crossed random effects is deferred to Phase 4b.

**Rationale:**
- Nested random effects produce block-diagonal V matrices, which can be handled efficiently by iterating over subjects (same approach as Phases 2-3).
- Crossed random effects produce non-block-diagonal structures that require sparse Cholesky (AMD ordering, supernodal factorization). This is a significant engineering effort comparable to implementing half of CHOLMOD.
- The existing `SparseMatrix` has CSR storage and matrix-vector multiply, but no sparse Cholesky. Adding it is a separate proposal.
- Most practical LME applications (clinical trials, longitudinal studies, device validation) use nested designs. Crossed designs (item response theory, psychometrics) are important but less common in the BusinessMath user base.

### 4. Degrees of Freedom Approximation

**Decision:** Satterthwaite approximation (not Kenward-Roger).

**Rationale:**
- Satterthwaite is simpler to implement (requires only the variance-covariance matrix of the fixed effects and its gradient with respect to theta).
- Kenward-Roger provides a small-sample correction by adjusting both the degrees of freedom AND the variance estimate, but requires third derivatives of the REML criterion.
- For most practical sample sizes (N > 30), Satterthwaite and Kenward-Roger give very similar results.
- If Kenward-Roger is needed later, it can be added as an option without changing the API.

### 5. Generic vs. Double-Only

**Decision:** All public types are generic `<T: Real>`. Internal computation uses `DenseMatrix<T>` for correctness, with Accelerate-optimized paths when `T == Double`.

**Rationale:**
- Consistent with the library's convention (all statistics functions are generic).
- `DenseMatrix<T>` already supports generics.
- The Accelerate optimization is important for performance but is an internal detail.

---

## Phase Dependencies

```
                           ┌──────────────────┐
                           │   Prerequisites   │
                           │   (all EXIST)     │
                           │   DenseMatrix<T>  │
                           │   choleskyDecomp  │
                           │   MatrixBackend   │
                           │   ICC, ANOVA      │
                           │   tCDF, fCDF      │
                           │   Newton-Raphson  │
                           │   L-BFGS          │
                           └────────┬─────────┘
                                    │
                           ┌────────▼─────────┐
                           │    Phase 1        │
                           │    Matrix Infra   │
                           │    (Cholesky on   │
                           │     DenseMatrix)  │
                           └────────┬─────────┘
                                    │
                           ┌────────▼─────────┐
                           │    Phase 2        │
                           │    Random         │
                           │    Intercept      │
                           │    (REML, BLUP)   │
                           └────────┬─────────┘
                                    │
                      ┌─────────────┼─────────────┐
                      │             │             │
             ┌────────▼───┐ ┌──────▼──────┐ ┌────▼────────┐
             │  Phase 3   │ │  Phase 5    │ │  Phase 6    │
             │  Random    │ │  Diagnostics│ │  Applications│
             │  Slope     │ │  (can start │ │  (can start  │
             │            │ │   after P2) │ │   after P2)  │
             └────────┬───┘ └─────────────┘ └─────────────┘
                      │
             ┌────────▼───┐
             │  Phase 4   │
             │  General   │
             │  LME       │
             └────────────┘
```

**Parallelizable work:**
- **After Phase 2:** Phases 3, 5, and 6 can all proceed in parallel. Phase 5 (diagnostics) only needs the result types from Phase 2. Phase 6 (applications) wraps Phase 2 functionality.
- **Phase 4 depends on Phase 3** because it generalizes the per-subject Cholesky approach to arbitrary random-effects structures.
- **Phase 1 is sequential:** Must complete before any model fitting.

**Recommended execution order:** Phase 1 then Phase 2 (sequential), then Phase 3 + Phase 5 + Phase 6 (parallel), then Phase 4.

---

## Interaction with Existing Proposals

### Subsumes PROPOSAL_advanced_reliability.md Phase 8

Phase 8 of the advanced reliability proposal specifies REML variance components for repeated-measures Bland-Altman with compound symmetry. Phase 2 of this proposal provides the same capability as a special case (X = [1], one random intercept, compound symmetry V).

If Phase 8 lands first, Phase 2 of this proposal should reuse the `REMLResult` type and `VarianceEstimationMethod` enum, wrapping them in the LME API.

If this proposal lands first, Phase 8 becomes a convenience wrapper:

```swift
public func remlVarianceComponents<T: Real>(_ groups: [[T]], ...) throws -> REMLResult<T> {
    // Construct a random intercept model with X = [1]
    // and fit via fitRandomIntercept
}
```

### Relationship to PROPOSAL_icc.md

ICC is a special case of the random intercept LME with no fixed-effects covariates beyond the intercept. The existing `icc()` function uses ANOVA-based variance components, which is equivalent to method-of-moments estimation. Phase 2 provides REML-based ICC, which:
- Is optimal for unbalanced designs
- Never produces negative variance estimates
- Allows covariate adjustment

The existing `icc()` function should remain as-is (it is faster for balanced designs). A new `adjustedICC` function in Phase 6 provides the LME-based version.

### Relationship to PROPOSAL_advanced_reliability.md Phase 5

Phase 5 proposes ICC with missing data via the EM algorithm. An alternative approach is to fit an LME model to the incomplete data, since LME naturally handles unbalanced designs (observations missing at random are simply absent from the model). This is exactly how R's `lme4` handles missing data.

If both proposals are implemented, the EM approach (Phase 5 of advanced reliability) and the LME approach (this proposal) should produce equivalent results. The LME approach is more general (supports covariates) while the EM approach may be faster for the specific ICC-with-missing-data problem.

---

## Risks

### Numerical Stability

**Risk:** Cholesky decomposition on near-singular G matrices (when a variance component approaches zero) can fail or produce inaccurate results.

**Mitigation:** Use the Cholesky parameterization throughout (optimize over log of Cholesky diagonal elements). This ensures G is always positive semi-definite by construction. When a Cholesky diagonal element approaches zero, the corresponding variance component is effectively zero -- report this in the result.

### Performance

**Risk:** Pure-Swift matrix operations for N > 10,000 may be slow without Accelerate.

**Mitigation:**
1. Phase 2 (random intercept) uses the closed-form V_i^{-1}, avoiding any N x N matrix operations entirely. Cost is O(N * p^2), which is fast even for large N.
2. Phase 3 (random slope) uses per-subject n_i x n_i Cholesky, where n_i is typically 3-20. This is fast even in pure Swift.
3. Phase 4 (general) for nested designs also uses per-subject blocks. Only crossed designs with many levels require large matrix operations.
4. Accelerate-optimized paths for `Double` provide hardware-accelerated BLAS/LAPACK.

### Scope Creep

**Risk:** LME is a deep rabbit hole. Generalized LME (GLMM), nonlinear mixed effects, spatial correlation structures, and Bayesian estimation are all natural extensions that could delay delivery.

**Mitigation:** Each phase delivers standalone, usable functionality. The "Not In Scope" section below is a hard boundary. Phase 4 should resist the temptation to support every possible random-effects structure -- nested designs with block-diagonal V cover the vast majority of use cases.

### Convergence Difficulties

**Risk:** Fisher scoring may fail to converge for some datasets (near-singular information matrix, boundary solutions where sigma_u^2 = 0).

**Mitigation:**
1. Step halving when Fisher scoring proposes a step that would make any variance component negative.
2. Fallback to L-BFGS with box constraints when Fisher scoring fails.
3. Multiple initializations: try method-of-moments initialization, and if that fails, try a grid of starting values for the variance ratio.
4. Report `converged = false` in the result when maximum iterations are reached, rather than throwing an error.

---

## File Organization

```
Sources/BusinessMath/Statistics/
  MixedModels/
    Matrix/
      DenseMatrixCholesky.swift              -- NEW (Phase 1): Cholesky, solve, logDet, inverse
      BlockDiagonalOperations.swift          -- NEW (Phase 1): block-diagonal V operations
    Types/
      GroupingFactor.swift                   -- NEW (Phase 2): group assignments
      RandomInterceptModel.swift             -- NEW (Phase 2): model specification
      RandomInterceptResult.swift            -- NEW (Phase 2): result type
      RandomSlopeModel.swift                 -- NEW (Phase 3): model specification
      RandomSlopeResult.swift                -- NEW (Phase 3): result type
      LMEModel.swift                         -- NEW (Phase 4): general model specification
      LMEResult.swift                        -- NEW (Phase 4): general result type
      LMEDiagnostics.swift                   -- NEW (Phase 5): diagnostic data
      RandomEffectsStructure.swift           -- NEW (Phase 3): random-effects specification
      RandomEffectsTerm.swift                -- NEW (Phase 4): general random-effects term
    Fitting/
      fitRandomIntercept.swift               -- NEW (Phase 2): REML estimation
      fitRandomSlope.swift                   -- NEW (Phase 3): REML estimation
      fitLME.swift                           -- NEW (Phase 4): general REML estimation
      FisherScoring.swift                    -- NEW (Phase 2): Fisher scoring algorithm
      REMLCriterion.swift                    -- NEW (Phase 2): REML log-likelihood evaluation
    Diagnostics/
      LMEDiagnosticsComputation.swift        -- NEW (Phase 5): residuals, QQ data
      LikelihoodRatioTest.swift              -- NEW (Phase 5): model comparison
      SatterthwaiteDf.swift                  -- NEW (Phase 5): df approximation
    Applications/
      CovariateAdjustedBlandAltman.swift     -- NEW (Phase 6): agreement modeling
      GrowthCurve.swift                      -- NEW (Phase 6): longitudinal analysis
      AdjustedICC.swift                      -- NEW (Phase 6): covariate-adjusted ICC

Tests/BusinessMathTests/Statistics Tests/
  MixedModels Tests/
    DenseMatrixCholeskyTests.swift            -- NEW (Phase 1)
    GroupingFactorTests.swift                 -- NEW (Phase 2)
    RandomInterceptTests.swift               -- NEW (Phase 2)
    RandomSlopeTests.swift                   -- NEW (Phase 3)
    GeneralLMETests.swift                    -- NEW (Phase 4)
    LMEDiagnosticsTests.swift                -- NEW (Phase 5)
    LikelihoodRatioTestTests.swift           -- NEW (Phase 5)
    SatterthwaiteDfTests.swift               -- NEW (Phase 5)
    CovariateAdjustedBlandAltmanTests.swift  -- NEW (Phase 6)
    GrowthCurveTests.swift                   -- NEW (Phase 6)
```

---

## Not In Scope

- **Generalized LME (GLMM):** Non-normal responses (Poisson, binomial, negative binomial). Requires iterative reweighted least squares (IRLS) or Laplace approximation. This is a separate, equally large project.
- **Nonlinear mixed effects (NLME):** Nonlinear mean function with random parameters. Requires linearization (conditional or marginal) and is domain-specific (pharmacokinetics, growth models).
- **Spatial/temporal correlation structures in R:** AR(1), exponential, Gaussian, or Matern correlation for the residual covariance R. The current proposal assumes R = sigma_e^2 * I (independent residuals within subjects, after accounting for random effects).
- **Penalized/regularized mixed models:** LASSO or ridge penalties on fixed effects. Would require specialized optimization (coordinate descent) that is incompatible with the Fisher scoring approach.
- **Bayesian mixed models:** MCMC (Gibbs sampling) or variational inference for mixed models. Conceptually different framework with its own proposal.
- **Crossed random effects with sparse Cholesky:** Deferred to Phase 4b. Phase 4 supports crossed designs via dense Henderson's equations (viable for moderate numbers of levels).
- **Multivariate responses:** Multiple response variables with correlated random effects. Requires Kronecker product structures.
- **Heterogeneous residual variance:** Different sigma_e^2 for different groups or covariate levels. Would require additional variance parameters and more complex optimization.

---

## References

- Bates, D., Machler, M., Bolker, B., & Walker, S. (2015). "Fitting Linear Mixed-Effects Models Using lme4." *Journal of Statistical Software*, 67(1), 1-48. DOI: 10.18637/jss.v067.i01. [The definitive reference for the profiled REML algorithm and Cholesky parameterization.]
- Pinheiro, J.C. & Bates, D.M. (2000). *Mixed-Effects Models in S and S-PLUS*. Springer. [Comprehensive treatment of LME theory and algorithms, including Fisher scoring and Newton-Raphson for REML.]
- McCulloch, C.E., Searle, S.R., & Neuhaus, J.M. (2008). *Generalized, Linear, and Mixed Models* (2nd ed.). Wiley. [Textbook covering the mathematical foundations of mixed models.]
- Harville, D.A. (1977). "Maximum likelihood approaches to variance component estimation and to related problems." *Journal of the American Statistical Association*, 72(358), 320-338. [Original REML paper with Fisher scoring derivation.]
- Henderson, C.R. (1984). *Applications of Linear Models in Animal Breeding*. University of Guelph. [Origin of Henderson's mixed-model equations and BLUP theory.]
- Kenward, M.G. & Roger, J.H. (1997). "Small sample inference for fixed effects from restricted maximum likelihood." *Biometrics*, 53(3), 983-997. [Kenward-Roger degrees of freedom approximation.]
- Satterthwaite, F.E. (1946). "An approximate distribution of estimates of variance components." *Biometrics Bulletin*, 2(6), 110-114. [Satterthwaite degrees of freedom approximation.]
- Patterson, H.D. & Thompson, R. (1971). "Recovery of inter-block information when block sizes are unequal." *Biometrika*, 58(3), 545-554. [Original REML paper.]
- Laird, N.M. & Ware, J.H. (1982). "Random-effects models for longitudinal data." *Biometrics*, 38(4), 963-974. [Foundation paper for LME in longitudinal studies.]
- Verbeke, G. & Molenberghs, G. (2000). *Linear Mixed Models for Longitudinal Data*. Springer. [Practical guide to LME with clinical examples.]
