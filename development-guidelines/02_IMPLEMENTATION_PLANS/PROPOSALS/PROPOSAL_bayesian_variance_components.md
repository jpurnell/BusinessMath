# Proposal: Bayesian Variance Component Estimation via Gibbs Sampling

**Date:** 2026-05-10
**Status:** Draft
**Scope:** New Bayesian estimation module in `BusinessMath/Statistics/Estimation/`
**Depends on:**
- `PROPOSAL_icc.md` (ICC infrastructure, `ICCModel` enum, two-way ANOVA — must land first)
- `PROPOSAL_advanced_reliability.md` Phase 8 (REML variance components — useful comparison point, not strictly required)

## Problem

The library currently estimates variance components via method of moments (ANOVA-based, in `icc.swift`) and will soon support REML (Phase 8 of `PROPOSAL_advanced_reliability.md`) and EM (Phase 5). Both are frequentist point estimators that produce a single "best guess" and a confidence interval. Bayesian estimation via Gibbs sampling provides the full posterior distribution over variance components, which is especially valuable in four situations:

1. **Small sample sizes (n < 20 subjects):** Frequentist confidence intervals for ICC rely on F-distribution approximations that degrade with few subjects. Bayesian credible intervals remain valid because they are derived from the exact posterior, not from asymptotic theory.

2. **Probability statements about reliability:** Clinicians and regulators want answers to questions like "What is the probability that ICC exceeds the 0.75 threshold for good reliability?" Bayesian inference answers this directly: `P(ICC > 0.75 | data) = 0.92`. Frequentist confidence intervals do not answer this question.

3. **Incorporating prior information:** A pilot study with 5 subjects and 3 raters provides useful information that is wasted by frequentist methods. Bayesian priors can formally incorporate this knowledge, shrinking estimates toward plausible values when data is sparse.

4. **Negative variance estimates:** The method-of-moments estimator can produce negative variance components (truncated to zero, discarding information). With proper priors, Bayesian posteriors are naturally non-negative — the prior forces the sampler to respect the constraint that variances cannot be negative.

### Use Cases

| Scenario | Why Bayesian? |
|----------|---------------|
| Pilot reliability study with 8 subjects, 2 raters | Frequentist CI is too wide to be useful; Bayesian posterior with informative prior from literature is narrower |
| FDA submission requiring P(ICC > 0.75) > 0.90 | Direct probability statement from posterior; frequentist CI cannot provide this |
| Method comparison where ANOVA gives negative sigma_r^2 | Bayesian posterior concentrates near zero without artificial truncation |
| Multi-site study combining pilot data with main study | Prior from pilot site, posterior from main site |
| Sensitivity analysis: how much does the prior matter? | Run with vague vs informative priors, compare posteriors |

## What Already Exists

| Component | Status | Location | Gap |
|-----------|--------|----------|-----|
| `distributionNormal(mean:stdDev:)` | Exists | `Simulation/distributionNormal.swift` | — |
| `distributionNormal(mean:variance:)` | Exists | `Simulation/distributionNormal.swift` | — |
| `gammaVariate(shape:scale:seeds:seedIndex:)` | Exists | `Simulation/distributionGamma.swift` | Real-valued shape via Marsaglia-Tsang |
| `distributionGamma(r:lambda:)` | Exists | `Simulation/distributionGamma.swift` | Integer shape only |
| Inverse-Gamma sampler | Missing | — | **Required** — core of Gibbs sampler |
| `ICCModel` enum | Exists | `Agreement/icc.swift` | — |
| `icc(_:model:agreement:confidence:)` | Exists | `Agreement/icc.swift` | Frequentist only |
| `twoWayANOVA(_:)` | Exists | `ANOVA/twoWayANOVA.swift` | — |
| `mean(_:)`, `varianceS(_:)` | Exists | Various | — |
| REML variance components | Planned | Phase 8 of advanced reliability | Comparison point for validation |

## The Model

For the two-way random effects model underlying ICC:

```
x_ij = mu + s_i + r_j + e_ij

s_i ~ N(0, sigma_s^2)    [random subject effect, i = 1, ..., n]
r_j ~ N(0, sigma_r^2)    [random rater effect, j = 1, ..., k]
e_ij ~ N(0, sigma_e^2)   [residual error]
```

where:
- `x_ij` is the rating of subject `i` by rater `j`
- `mu` is the grand mean
- `n` is the number of subjects, `k` is the number of raters
- `N = n * k` is the total number of observations (balanced design)

The goal is to estimate the posterior distributions of `(mu, sigma_s^2, sigma_r^2, sigma_e^2)` given the observed data, and then derive the posterior distribution of ICC from the variance components.

## Prior Specification

### Conjugate Priors (Default)

Conjugate priors yield closed-form full conditional distributions, making the Gibbs sampler straightforward:

- **Grand mean:** `mu ~ N(mu_0, tau^2)` — vague default: `mu_0 = 0`, `tau^2 = 10^6`
- **Subject variance:** `sigma_s^2 ~ Inverse-Gamma(a_s, b_s)` — vague default: `a_s = 0.001`, `b_s = 0.001`
- **Rater variance:** `sigma_r^2 ~ Inverse-Gamma(a_r, b_r)` — vague default: `a_r = 0.001`, `b_r = 0.001`
- **Error variance:** `sigma_e^2 ~ Inverse-Gamma(a_e, b_e)` — vague default: `a_e = 0.001`, `b_e = 0.001`

The Inverse-Gamma(a, b) distribution has:
- Mean = `b / (a - 1)` for `a > 1`
- Mode = `b / (a + 1)`
- Variance = `b^2 / ((a - 1)^2 * (a - 2))` for `a > 2`

### Caution on Vague Priors (Gelman 2006)

The `Inverse-Gamma(epsilon, epsilon)` prior for small `epsilon` is a common default but can be problematic:

- When the true variance component is near zero, the posterior is sensitive to the choice of `epsilon`. Values of `a_s = b_s = 0.001` versus `a_s = b_s = 0.01` can yield meaningfully different posteriors for small variance components.
- The prior density piles up near zero, which can pull the posterior toward zero even when the data supports a small but positive variance.
- Gelman (2006) recommends the **half-Cauchy** prior on the standard deviation `sigma ~ half-Cauchy(0, A)` as a more principled weakly informative prior. However, this breaks conjugacy and requires a Metropolis-Hastings step within Gibbs, substantially increasing implementation complexity.

**This proposal implements conjugate Inverse-Gamma priors.** The half-Cauchy alternative is documented as a future extension (see "Not In Scope"). Users concerned about prior sensitivity should run the sampler with multiple prior settings and compare posteriors — the API supports this directly.

### Informative Priors from Pilot Data

For informative priors, the user specifies `(shape, scale)` parameters derived from a prior study. Given a pilot estimate `sigma_hat^2` and a measure of confidence `strength`:

```
shape = strength / 2
scale = strength * sigma_hat^2 / 2
```

This parameterization ensures the prior mode is at `sigma_hat^2` when `strength > 2`, and the prior becomes more concentrated as `strength` increases. A strength of 10 corresponds roughly to 10 prior observations worth of information.

## Gibbs Sampler: Full Conditional Distributions

The Gibbs sampler iterates through the following six full conditional distributions. At each iteration, every parameter is updated in sequence, conditioning on the current values of all other parameters.

### mu | rest

```
mu | s, r, sigma_e^2, data ~ N(mu_post, sigma_post^2)

where:
  sigma_post^2 = 1 / (N / sigma_e^2 + 1 / tau^2)
  mu_post = sigma_post^2 * (sum_{i,j} (x_ij - s_i - r_j) / sigma_e^2 + mu_0 / tau^2)
  N = n * k (total observations)
```

**Derivation:** The likelihood contribution from all observations involves `(x_ij - mu - s_i - r_j)^2 / sigma_e^2`. Combining with the normal prior on `mu` and completing the square yields a normal posterior.

### s_i | rest (for each subject i = 1, ..., n)

```
s_i | mu, r, sigma_s^2, sigma_e^2, data ~ N(s_post_i, v_post_i)

where:
  v_post_i = 1 / (k / sigma_e^2 + 1 / sigma_s^2)
  s_post_i = v_post_i * sum_j (x_ij - mu - r_j) / sigma_e^2
```

**Derivation:** The prior on `s_i` is `N(0, sigma_s^2)`. The likelihood contributes `k` observations for subject `i`, each with precision `1 / sigma_e^2`. The posterior precision is the sum of the prior precision and the data precision.

### r_j | rest (for each rater j = 1, ..., k)

```
r_j | mu, s, sigma_r^2, sigma_e^2, data ~ N(r_post_j, v_post_j)

where:
  v_post_j = 1 / (n / sigma_e^2 + 1 / sigma_r^2)
  r_post_j = v_post_j * sum_i (x_ij - mu - s_i) / sigma_e^2
```

**Derivation:** Symmetric to the subject effect derivation, with `n` observations per rater.

### sigma_s^2 | rest

```
sigma_s^2 | s ~ Inverse-Gamma(a_s + n/2, b_s + sum_i s_i^2 / 2)
```

**Derivation:** The conjugate update for the variance of `n` normal observations with known mean zero. The shape increases by `n/2` (half the number of subject effects), and the scale increases by `sum s_i^2 / 2` (half the sum of squared effects).

### sigma_r^2 | rest

```
sigma_r^2 | r ~ Inverse-Gamma(a_r + k/2, b_r + sum_j r_j^2 / 2)
```

### sigma_e^2 | rest

```
sigma_e^2 | mu, s, r, data ~ Inverse-Gamma(a_e + N/2, b_e + sum_{i,j} (x_ij - mu - s_i - r_j)^2 / 2)
```

**Derivation:** The conjugate update for the variance of `N = n * k` residuals. The shape increases by `N/2` and the scale increases by half the residual sum of squares.

### Sampling from Inverse-Gamma

The Inverse-Gamma distribution is not available as a primitive sampler in the library. However, it has a simple relationship to the Gamma distribution:

```
If X ~ Gamma(shape: a, scale: 1/b), then 1/X ~ Inverse-Gamma(a, b).
```

**Implementation:** Sample `g = gammaVariate(shape: a_post, scale: 1/b_post)`, then return `sigma^2 = 1 / g`.

This uses the existing `gammaVariate(shape:scale:seeds:seedIndex:)` function, which supports real-valued shape parameters via Marsaglia and Tsang's method.

## ICC from Posterior Samples

At each Gibbs iteration `t` (after burn-in), compute the ICC from the current variance component samples:

```
ICC(1,1)_t = sigma_s^2_t / (sigma_s^2_t + sigma_r^2_t + sigma_e^2_t)

ICC(2,1)_t = sigma_s^2_t / (sigma_s^2_t + sigma_r^2_t/k + sigma_e^2_t/k)
             [absolute agreement, averaged over k raters]

ICC(3,1)_t = sigma_s^2_t / (sigma_s^2_t + sigma_e^2_t)
             [consistency — rater variance excluded]
```

The posterior distribution of ICC is the empirical distribution of these samples. From this distribution, extract:

- **Posterior mean:** `mean(iccSamples)`
- **Posterior median:** `median(iccSamples)`
- **95% credible interval:** 2.5th and 97.5th percentiles of `iccSamples`
- **Probability above threshold:** `count(iccSamples > threshold) / count(iccSamples)`

## Convergence Diagnostics

### Burn-In

Discard the first `B` iterations to allow the chain to reach its stationary distribution. Default: `B = iterations / 2`. The sampler starts from a data-driven initialization (ANOVA-based variance components), so convergence is typically rapid — often within 100-500 iterations.

### Thinning

Keep every `t`-th iteration to reduce autocorrelation in the stored samples. Default: `t = 1` (no thinning). Thinning is generally unnecessary with modern storage capacity and is included only for users who need it. The effective sample size is a better diagnostic than thinning.

### R-hat (Gelman-Rubin Diagnostic)

Run `M >= 2` independent chains from dispersed starting values. For each parameter, compare within-chain variance to between-chain variance:

```
B = (n / (M - 1)) * sum_m (theta_bar_m - theta_bar)^2   [between-chain variance]
W = (1 / M) * sum_m s_m^2                                 [within-chain variance]

var_hat = ((n - 1) / n) * W + (1 / n) * B                 [pooled variance estimate]

R_hat = sqrt(var_hat / W)
```

where `n` is the number of post-burn-in samples per chain, `theta_bar_m` is the mean of chain `m`, `theta_bar` is the grand mean, and `s_m^2` is the variance of chain `m`.

**Interpretation:** `R_hat < 1.1` indicates convergence. Values above 1.1 suggest the chains have not mixed and more iterations are needed.

### Effective Sample Size (ESS)

The effective sample size accounts for autocorrelation within a chain:

```
ESS = M * n / (1 + 2 * sum_{k=1}^{K} rho_k)
```

where `rho_k` is the lag-`k` autocorrelation and `K` is chosen such that `rho_K` is negligible (e.g., first negative autocorrelation). An ESS of at least 400 is recommended for reliable posterior summaries.

## Proposed API

### Prior Configuration

```swift
/// Prior specification for a variance component.
///
/// Parameterizes an Inverse-Gamma(shape, scale) prior on a variance parameter.
/// The Inverse-Gamma is conjugate to the normal likelihood, yielding closed-form
/// full conditional distributions in the Gibbs sampler.
public struct VariancePrior<T: Real>: Sendable, Equatable {
    /// Shape parameter for the Inverse-Gamma prior (a > 0).
    public let shape: T
    /// Scale parameter for the Inverse-Gamma prior (b > 0).
    public let scale: T

    /// Vague (non-informative) prior: Inverse-Gamma(0.001, 0.001).
    ///
    /// Suitable when no prior information is available. Note that this prior
    /// can be sensitive for small variance components (see Gelman 2006).
    public static var vague: VariancePrior { ... }

    /// Informative prior calibrated from a previous study.
    ///
    /// - Parameters:
    ///   - expectedVariance: The prior point estimate of the variance (e.g., from a pilot study).
    ///   - strength: Controls how concentrated the prior is around the expected variance.
    ///     Higher values mean stronger prior influence. A strength of 10 corresponds
    ///     roughly to 10 observations worth of prior information.
    /// - Returns: A `VariancePrior` with mode at approximately `expectedVariance`.
    ///
    /// The parameterization is:
    /// ```
    /// shape = strength / 2
    /// scale = strength * expectedVariance / 2
    /// ```
    public static func informative(expectedVariance: T, strength: T) -> VariancePrior { ... }
}
```

### Sampler Configuration

```swift
/// Configuration for the Gibbs sampler.
///
/// Controls the number of iterations, burn-in period, thinning, number of
/// chains (for R-hat computation), and random seed for reproducibility.
public struct GibbsConfig<T: Real>: Sendable, Equatable {
    /// Total number of iterations per chain (including burn-in). Default: 10,000.
    public let iterations: Int
    /// Number of burn-in iterations to discard. Default: iterations / 2.
    public let burnIn: Int
    /// Thinning interval: keep every n-th post-burn-in sample. Default: 1 (no thinning).
    public let thinning: Int
    /// Number of independent chains to run (for R-hat). Default: 2.
    public let chains: Int
    /// Random seed for reproducibility. Default: nil (non-deterministic).
    public let seed: UInt64?

    /// Default configuration: 10,000 iterations, 5,000 burn-in, no thinning, 2 chains.
    public static var `default`: GibbsConfig { ... }
}
```

### Result Type

```swift
/// Result of Bayesian variance component estimation via Gibbs sampling.
///
/// Contains posterior samples for all variance components and derived ICC values,
/// along with summary statistics and convergence diagnostics.
public struct BayesianICCResult<T: Real>: Sendable, Equatable {
    // MARK: - Posterior Samples

    /// Posterior samples of the subject variance component (sigma_s^2).
    public let sigmaSubjectsSamples: [T]
    /// Posterior samples of the rater variance component (sigma_r^2).
    public let sigmaRatersSamples: [T]
    /// Posterior samples of the error variance component (sigma_e^2).
    public let sigmaErrorSamples: [T]
    /// Posterior samples of ICC (computed from variance component samples).
    public let iccSamples: [T]

    // MARK: - Summary Statistics

    /// Posterior mean of ICC.
    public let iccMean: T
    /// Posterior median of ICC.
    public let iccMedian: T
    /// 95% highest posterior density credible interval for ICC.
    public let iccCredibleInterval: (lower: T, upper: T)

    /// Posterior mean of the subject variance component.
    public let sigmaSubjectsMean: T
    /// Posterior mean of the rater variance component.
    public let sigmaRatersMean: T
    /// Posterior mean of the error variance component.
    public let sigmaErrorMean: T

    // MARK: - Convergence Diagnostics

    /// Gelman-Rubin R-hat for ICC (nil if only one chain was run).
    public let rHat: T?
    /// Effective sample size for the ICC chain.
    public let effectiveSampleSize: Int

    // MARK: - Methods

    /// Posterior probability that ICC exceeds a threshold.
    ///
    /// - Parameter threshold: The ICC value to compare against (e.g., 0.75 for "good" reliability).
    /// - Returns: The proportion of posterior samples above the threshold, in [0, 1].
    public func probabilityAbove(_ threshold: T) -> T
}
```

### Main Entry Point

```swift
/// Bayesian ICC estimation via Gibbs sampling.
///
/// Estimates the posterior distributions of variance components and ICC from a balanced
/// ratings matrix using a Gibbs sampler with conjugate Inverse-Gamma priors.
///
/// The model is:
/// ```
/// x_ij = mu + s_i + r_j + e_ij
/// s_i ~ N(0, sigma_s^2),  r_j ~ N(0, sigma_r^2),  e_ij ~ N(0, sigma_e^2)
/// ```
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the rating of subject `i` by rater `j`.
///     Must be balanced (all rows the same length, no missing values).
///   - model: The ICC model type (`.oneWayRandom`, `.twoWayRandom`, `.twoWayMixed`).
///   - priors: Prior distributions for the three variance components. Defaults to vague priors.
///   - config: Gibbs sampler configuration (iterations, burn-in, thinning, chains, seed).
/// - Returns: A ``BayesianICCResult`` with posterior samples, summary statistics, and diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects or 2 raters.
///   `BusinessMathError.mismatchedDimensions` if rows differ in length.
///   `BusinessMathError.invalidInput` if prior parameters are non-positive.
public func bayesianICC<T: Real>(
    _ ratings: [[T]],
    model: ICCModel,
    priors: (subjects: VariancePrior<T>, raters: VariancePrior<T>, error: VariancePrior<T>)? = nil,
    config: GibbsConfig<T> = .default
) throws -> BayesianICCResult<T>
```

## File Organization

```
Sources/BusinessMath/Statistics/
  Estimation/
    bayesianICC.swift                          — NEW: Gibbs sampler + main function
    BayesianICCResult.swift                    — NEW: result type
    VariancePrior.swift                        — NEW: prior specification
    GibbsConfig.swift                          — NEW: sampler configuration
    convergenceDiagnostics.swift               — NEW: R-hat and ESS

  Simulation/
    distributionGamma.swift                    — EXISTS (gammaVariate used for Inverse-Gamma)
    distributionNormal.swift                   — EXISTS (used for mu, s_i, r_j)
    sampleInverseGamma.swift                   — NEW: Inverse-Gamma sampler via Gamma reciprocal

  Descriptors/Agreement/
    icc.swift                                  — EXISTS (ICCModel enum, frequentist ICC)

Tests/BusinessMathTests/Statistics Tests/
  Estimation Tests/
    BayesianICCTests.swift                     — NEW: end-to-end sampler tests
    InverseGammaSamplerTests.swift             — NEW: distribution validation
    ConvergenceDiagnosticsTests.swift          — NEW: R-hat and ESS tests
```

## Implementation Plan

### Phase 1: Inverse-Gamma Sampler (~30 lines)

Implement `sampleInverseGamma(shape:scale:)` using the existing `gammaVariate` function.

**RED:**
1. For `Inverse-Gamma(shape: 3, scale: 2)`, sample 50,000 values and verify:
   - Sample mean is within 5% of theoretical mean `b / (a - 1) = 2 / 2 = 1.0`
   - Sample variance is within 15% of theoretical variance `b^2 / ((a-1)^2 * (a-2)) = 4 / (4 * 1) = 1.0`
2. All samples are positive (no negative or zero values)
3. Shape or scale <= 0 throws `invalidInput`
4. For `shape = 100, scale = 100`: posterior is concentrated near `scale / (shape - 1) = 100/99 ~ 1.01` (verify sample std dev is small)

**GREEN:** Sample `g = gammaVariate(shape: a, scale: 1/b)`, return `1 / g`.

**Dependencies:** `gammaVariate` (exists in `distributionGamma.swift`)

### Phase 2: Gibbs Sampler for Two-Way Random Model (~120 lines)

The main iteration loop implementing all six full conditional distributions.

**RED:**
1. **Known dataset convergence:** Use Shrout & Fleiss (1979) Table 4 data. Verify posterior means of variance components converge to within 10% of the ANOVA-based estimates (for vague priors, Bayesian and frequentist estimates should agree asymptotically).
2. **Perfect agreement:** All subjects get identical ratings from all raters. Posterior of `sigma_r^2` and `sigma_e^2` should concentrate near zero. ICC posterior mean should be near 1.0.
3. **No reliability:** Random noise with no subject differentiation. ICC posterior mean should be near 0.
4. **Reproducibility:** Same seed produces identical posterior samples.
5. **Different seeds:** Different seeds produce different samples (but similar summary statistics).
6. **Input validation:** Fewer than 2 subjects or 2 raters throws `insufficientData`.
7. **Input validation:** Ragged matrix throws `mismatchedDimensions`.
8. **Initialization:** Sampler starts from ANOVA-based estimates (not arbitrary values).

**GREEN:** Implement the Gibbs loop:
1. Initialize `mu`, `s`, `r`, `sigma_s^2`, `sigma_r^2`, `sigma_e^2` from ANOVA decomposition
2. For each iteration:
   a. Sample `mu | rest` from Normal
   b. Sample each `s_i | rest` from Normal
   c. Sample each `r_j | rest` from Normal
   d. Sample `sigma_s^2 | rest` from Inverse-Gamma
   e. Sample `sigma_r^2 | rest` from Inverse-Gamma
   f. Sample `sigma_e^2 | rest` from Inverse-Gamma
3. After burn-in, store (thinned) samples

**Dependencies:** Phase 1, `distributionNormal` (exists), `twoWayANOVA` (exists)

### Phase 3: ICC Posterior Computation (~40 lines)

At each stored iteration, compute ICC from variance samples and derive summary statistics.

**RED:**
1. **Posterior mean:** For a large dataset (n=50, k=10), Bayesian ICC posterior mean is within 0.02 of frequentist ICC point estimate (with vague priors).
2. **Credible interval:** 95% credible interval contains the frequentist point estimate.
3. **Probability above threshold:** For data with ICC ~ 0.85, verify `probabilityAbove(0.75) > 0.90`.
4. **Probability above threshold:** For data with ICC ~ 0.50, verify `probabilityAbove(0.75) < 0.10`.
5. **ICC model types:** `ICC(1,1)`, `ICC(2,1)`, and `ICC(3,1)` produce distinct posterior distributions when rater variance is non-zero.
6. **Consistency vs absolute:** `ICC(3,1)` posterior is stochastically larger than `ICC(2,1)` posterior when rater variance is positive (because consistency ICC excludes rater variance from the denominator).

**GREEN:** Compute ICC at each iteration from stored variance samples. Compute mean, median, and percentile-based credible interval from the ICC sample array.

**Dependencies:** Phase 2, `mean` (exists)

### Phase 4: Convergence Diagnostics (~60 lines)

R-hat from multiple chains and effective sample size via autocorrelation.

**RED:**
1. **Convergent chains:** Two chains from different starting values on a well-identified model produce `R_hat < 1.05`.
2. **Non-convergent chains:** Two chains with 10 iterations each (too few to converge) produce `R_hat > 1.1`.
3. **ESS:** For an uncorrelated sequence, `ESS ~ n` (close to the actual number of samples).
4. **ESS:** For a highly autocorrelated sequence (e.g., AR(1) with rho = 0.95), `ESS << n`.
5. **Single chain:** `R_hat` is nil when only one chain is run.
6. **ESS lower bound:** ESS is always at least 1 and at most the number of samples.

**GREEN:** Implement R-hat using the split-chain estimator (Gelman et al., 2013, Section 11.4) and ESS using the initial monotone sequence estimator for autocorrelation.

**Dependencies:** `mean` (exists), `varianceS` (exists)

### Phase 5: Missing Data Extension (~40 lines)

Extend the Gibbs sampler to handle incomplete (unbalanced) rating matrices.

**RED:**
1. **No missing data:** Results with `[[T]]` input match results from `[[T?]]` input where all values are present, within tolerance.
2. **Single missing cell:** Posterior means shift smoothly from the complete-data case.
3. **50% missing at random:** Sampler converges, ICC is in [0, 1], credible interval is wider than the complete-data case.
4. **All data missing for one subject:** Subject is excluded from estimation. No crash.
5. **All data missing for one rater:** Rater is excluded from estimation. No crash.
6. **Fewer than 2 subjects with observed data:** Throws `insufficientData`.
7. **Ragged matrix (rows differ in length):** Throws `mismatchedDimensions`.

**GREEN:** In the full conditional distributions, sum only over observed `(i, j)` pairs. For `s_i | rest`, the precision `k / sigma_e^2` becomes `k_i / sigma_e^2` where `k_i` is the number of raters who observed subject `i`. Similarly for `r_j`. The Gibbs sampler naturally handles missingness because each parameter is updated conditional on the current values of all others — missing data cells do not contribute to the sufficient statistics.

**Dependencies:** Phase 2

**API extension:**

```swift
/// Bayesian ICC estimation with missing data via Gibbs sampling.
///
/// Accepts an incomplete ratings matrix where missing cells are `nil`.
/// The Gibbs sampler handles missing data by conditioning only on
/// observed values in each full conditional distribution.
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the rating or `nil` if missing.
///   - model: The ICC model type.
///   - priors: Prior distributions for variance components. Defaults to vague priors.
///   - config: Gibbs sampler configuration.
/// - Returns: A ``BayesianICCResult`` with posterior samples and diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects or
///   2 raters have observations.
public func bayesianICC<T: Real>(
    _ ratings: [[T?]],
    model: ICCModel,
    priors: (subjects: VariancePrior<T>, raters: VariancePrior<T>, error: VariancePrior<T>)? = nil,
    config: GibbsConfig<T> = .default
) throws -> BayesianICCResult<T>
```

## Edge Cases

| Case | Behavior |
|------|----------|
| Very small variance component (true sigma_s^2 near 0) | Posterior concentrates near zero. With Inverse-Gamma(epsilon, epsilon) prior, the posterior is proper but may have a mode at zero. The ICC posterior concentrates near 0. |
| Perfect agreement (all raters give identical ratings per subject) | sigma_r^2 and sigma_e^2 posteriors concentrate near zero. ICC posterior concentrates near 1.0. The Inverse-Gamma posterior shape increases substantially, pushing the mode toward zero. |
| Single rater per subject (confounded effects) | sigma_r^2 and sigma_e^2 cannot be separated. The Gibbs sampler will exhibit high autocorrelation and poor mixing between these two components. R-hat will be elevated. ESS will be low. **Document this limitation.** |
| All subjects identical (no between-subject variance) | sigma_s^2 posterior concentrates near zero. ICC near 0 regardless of rater/error variance. |
| Large number of iterations with small data | Memory concern: 10,000 iterations x 4 parameters = 40,000 stored values. For `Double`, this is ~320 KB — negligible. |
| Non-positive prior parameters | Throw `BusinessMathError.invalidInput` at the start, before any sampling. |

## Effort Estimates

| Phase | New Files | Estimated Lines | Test Cases | Session Estimate |
|-------|-----------|----------------|------------|------------------|
| 1: Inverse-Gamma Sampler | 1 source + 1 test | ~30 | ~4 | 0.5 session |
| 2: Gibbs Sampler | 1 source | ~120 | ~8 | 1 session |
| 3: ICC Posterior | 1 source | ~40 | ~6 | 0.5 session |
| 4: Convergence Diagnostics | 1 source + 1 test | ~60 | ~6 | 0.5 session |
| 5: Missing Data Extension | (extends Phase 2) | ~40 | ~7 | 0.5 session |
| **Total** | **5 source + 3 test** | **~290** | **~31** | **2-3 sessions** |

## Phase Dependencies

```
                 ┌──────────────────────────┐
                 │     Prerequisites         │
                 │  gammaVariate (exists)     │
                 │  distributionNormal (exists)│
                 │  ICCModel enum (exists)    │
                 │  twoWayANOVA (exists)      │
                 └─────────┬────────────────┘
                           │
                 ┌─────────▼────────────────┐
                 │  Phase 1: Inverse-Gamma   │
                 │  Sampler                  │
                 └─────────┬────────────────┘
                           │
                 ┌─────────▼────────────────┐
                 │  Phase 2: Gibbs Sampler   │
                 │  (core loop)              │
                 └──┬──────────────────┬────┘
                    │                  │
          ┌─────────▼──────┐  ┌───────▼──────────┐
          │  Phase 3: ICC  │  │  Phase 5: Missing │
          │  Posterior      │  │  Data Extension   │
          └────────────────┘  └──────────────────┘
                    │
          ┌─────────▼──────────────────┐
          │  Phase 4: Convergence      │
          │  Diagnostics (R-hat, ESS)  │
          └────────────────────────────┘
```

Phases 3 and 5 can proceed in parallel after Phase 2. Phase 4 requires Phase 3 (needs the ICC sample array to test diagnostics on).

## Relationship to Other Proposals

This proposal complements three frequentist estimation approaches in the library:

| Approach | Proposal | Strengths | Limitations |
|----------|----------|-----------|-------------|
| Method of moments (ANOVA) | `PROPOSAL_icc.md` | Fast, closed-form, no iteration | Can produce negative variances; CIs unreliable for small n |
| EM algorithm | `PROPOSAL_advanced_reliability.md` Phase 5 | Handles missing data; point estimates | No uncertainty quantification beyond point estimate |
| REML | `PROPOSAL_advanced_reliability.md` Phase 8 | Optimal for unbalanced designs; non-negative | Still a point estimator; CIs require bootstrap or Wald approximation |
| **Bayesian (Gibbs)** | **This proposal** | Full posterior; probability statements; incorporates priors; naturally non-negative | Computationally expensive; requires prior specification; convergence must be verified |

Users should choose based on their needs:
- **Quick reliability check:** Use frequentist ICC (fast, no configuration)
- **Missing data:** Use EM or Bayesian
- **Small samples or probability statements:** Use Bayesian
- **Regulatory submission requiring P(ICC > threshold):** Use Bayesian

## References

- Gelman, A. (2006). "Prior distributions for variance parameters in hierarchical models." *Bayesian Analysis*, 1(3), 515-534. (Critique of Inverse-Gamma priors; half-Cauchy recommendation.)
- Gelman, A., Carlin, J.B., Stern, H.S., Dunson, D.B., Vehtari, A., & Rubin, D.B. (2013). *Bayesian Data Analysis* (3rd ed.). Chapman & Hall/CRC. (Chapter 5: Hierarchical models; Chapter 11: Gibbs sampling and convergence diagnostics.)
- Shoukri, M.M. (2010). *Measures of Interobserver Agreement and Reliability* (2nd ed.). Chapman & Hall/CRC. (Chapter 7: Bayesian methods for ICC.)
- Muller, R. & Buttner, P. (1994). "A critical discussion of intraclass correlation coefficients." *Statistics in Medicine*, 13(23-24), 2465-2476.
- Shrout, P.E. & Fleiss, J.L. (1979). "Intraclass correlations: Uses in assessing rater reliability." *Psychological Bulletin*, 86(2), 420-428.
- Marsaglia, G. & Tsang, W.W. (2000). "A simple method for generating gamma variables." *ACM Transactions on Mathematical Software*, 26(3), 363-372. (The `gammaVariate` implementation used for Inverse-Gamma sampling.)

## Not In Scope

- **Half-Cauchy priors on standard deviations** — Requires a Metropolis-Hastings step within Gibbs, breaking the fully conjugate structure. More robust for small variance components (Gelman 2006), but substantially increases implementation complexity. Candidate for a future extension.
- **Multivariate variance components** — Matrix-valued variance components (e.g., for multivariate ICC) require Wishart/Inverse-Wishart distributions and matrix sampling. A separate proposal.
- **Hamiltonian Monte Carlo (HMC)** — More efficient sampling for high-dimensional or poorly mixing posteriors, but requires gradient computation and substantially more complex tuning (step size, leapfrog steps, mass matrix). Overkill for the 6-parameter model here.
- **JAGS/Stan integration** — External probabilistic programming tool interfaces. Out of scope for a self-contained Swift library.
- **Bayesian model comparison (DIC, WAIC, LOO-CV)** — Useful for comparing ICC models but orthogonal to variance component estimation. Could be a separate proposal.
- **Generalized linear mixed models** — Bayesian estimation for non-normal outcomes (binary, ordinal, count data). A major extension beyond the normal-theory ICC model.
