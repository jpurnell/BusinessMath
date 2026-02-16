//
//  logNormalCDF.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/5/26.
//

import Foundation
import Numerics

/// Computes the cumulative distribution function (CDF) of the log-normal distribution.
///
/// The log-normal CDF gives the probability P(X ≤ x) where X follows a log-normal
/// distribution with underlying normal parameters μ (mean) and σ (standard deviation).
///
/// The log-normal distribution is commonly used in finance to model:
/// - Stock prices (Black-Scholes model)
/// - Asset returns (always positive)
/// - Project completion times
/// - Insurance claim sizes
///
/// ## Mathematical Foundation
///
/// If X ~ LogNormal(μ, σ), then ln(X) ~ Normal(μ, σ).
///
/// Therefore:
/// ```
/// P(X ≤ x) = P(ln(X) ≤ ln(x)) = Φ((ln(x) - μ) / σ)
/// ```
/// where Φ is the standard normal CDF.
///
/// ## Key Properties
///
/// - **Domain**: x > 0 (lognormal is only defined for positive values)
/// - **Range**: [0, 1]
/// - **Median**: P(X ≤ e^μ) = 0.5
/// - **Monotonicity**: CDF increases as x increases
///
/// ## Parameters
///
/// - Parameter x: The value at which to evaluate the CDF. Must be positive (x > 0).
///   For x ≤ 0, the function returns 0.
/// - Parameter μ: The mean (μ) of the underlying normal distribution. Defaults to 0.
///   This is NOT the mean of the lognormal distribution itself.
/// - Parameter σ: The standard deviation (σ) of the underlying normal distribution.
///   Defaults to 1. Must be positive (σ > 0).
///
/// ## Returns
///
/// The probability that a log-normally distributed random variable is less than or equal to x.
/// Returns a value in [0, 1].
///
/// ## Examples
///
/// ### Basic Usage
/// ```swift
/// // Standard lognormal: LogNormal(0, 1)
/// let prob = logNormalCDF(1.0, mean: 0.0, stdDev: 1.0)
/// // prob = 0.5 (median of standard lognormal is 1.0)
/// ```
///
/// ### Stock Price Probability (Black-Scholes)
/// ```swift
/// // What's the probability a $100 stock ends below $90 in 1 year?
/// // Assume 10% drift, 20% volatility
/// let S0 = 100.0
/// let drift = 0.10
/// let vol = 0.20
/// let T = 1.0
///
/// // Under risk-neutral pricing: ln(S_T) ~ Normal(ln(S0) + (μ - σ²/2)T, σ√T)
/// let logMean = log(S0) + (drift - 0.5 * vol * vol) * T
/// let logStdDev = vol * sqrt(T)
///
/// let probBelow90 = logNormalCDF(90.0, mean: logMean, stdDev: logStdDev)
/// // probBelow90 ≈ 0.177 (17.7% chance)
/// ```
///
/// ### Value at Risk (VaR)
/// ```swift
/// // Find 5th percentile of portfolio value
/// // If portfolio follows LogNormal(0, 1)
/// // Solve: logNormalCDF(x, 0, 1) = 0.05
/// // x ≈ 0.222 (VaR at 5% level)
/// ```
///
/// ## Implementation Notes
///
/// This function leverages the relationship between lognormal and normal distributions:
/// - Transform x → ln(x)
/// - Standardize: z = (ln(x) - μ) / σ
/// - Use existing `normalCDF()` for final calculation
///
/// This approach is:
/// - **Efficient**: Single logarithm + normalCDF call
/// - **Accurate**: Inherits accuracy of normalCDF (error < 10^-15)
/// - **Numerically stable**: No cancellation or overflow issues
///
/// ## Related Functions
///
/// - ``logNormalPDF(_:mean:stdDev:)`` - Probability density function
/// - ``distributionLogNormal(mean:stdDev:_:_:)`` - Random sampling
/// - ``normalCDF(x:mean:stdDev:)`` - Normal CDF (used internally)
///
/// ## See Also
///
/// - [Log-normal distribution (Wikipedia)](https://en.wikipedia.org/wiki/Log-normal_distribution)
/// - Black-Scholes option pricing model
/// - Value at Risk (VaR) calculations
///
public func logNormalCDF<T: Real>(_ x: T, mean μ: T = T(0), stdDev σ: T = T(1)) -> T {
	// Lognormal is only defined for positive x
	// P(X ≤ 0) = 0 for lognormal distribution
	guard x > T.zero else {
		return T.zero
	}

	// Key transformation: If X ~ LogNormal(μ, σ), then ln(X) ~ Normal(μ, σ)
	// Therefore: P(X ≤ x) = P(ln(X) ≤ ln(x)) = Φ((ln(x) - μ) / σ)
	//
	// where Φ is the standard normal CDF

	// Step 1: Transform to log space
	let logX = T.log(x)

	// Step 2: Standardize to z-score
	let z = (logX - μ) / σ

	// Step 3: Use standard normal CDF
	// normalCDF with mean=0, stdDev=1 gives Φ(z)
	return normalCDF(x: z, mean: T.zero, stdDev: T(1))
}
