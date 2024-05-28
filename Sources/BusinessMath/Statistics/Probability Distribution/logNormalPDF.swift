//
//  logNormalPDF.swift
//  
//
//  Created by Justin Purnell on 2/2/24.
//

import Foundation
import Numerics

	/// Computes the value of the Gaussian (normal) distribution's probability density function (PDF).
	///
	/// The Gaussian distribution is widely used in statistics and represents the distribution of many kinds of random variables.
	/// This function calculates the probability density at a given point `x` for a normal distribution with the specified mean and standard deviation.
	///
	/// - Parameters:
	///   - x: The value at which to evaluate the probability density function.
	///   - µ: The mean (average) of the Gaussian distribution. Defaults to `0`.
	///   - stdDev: The standard deviation of the Gaussian distribution. Defaults to `1`.
	/// - Returns: The value of the probability density function at `x`.
	///
	/// - Note: The function follows the formula:
	///   \[ f(x) = \frac{1}{\text{stdDev} \sqrt{2 \pi}} \exp\left(-\frac{(x - \mu)^2}{2 \cdot \text{stdDev}^2}\right) \]
	///   where `π` is approximately 3.14159.

func g<T: Real>(_ x: T, mean µ: T = T(0), stdDev: T = T(1)) -> T {
	let e = T(1) / (stdDev * T.sqrt(2 * .pi))
	let f = T.exp( (T(-1) / T(2)) * T.pow((x - µ), T(2))) / T.pow(stdDev, T(2))
	return e * f
}

/// Computes the value of the log-normal distribution's probability density function (PDF).
///
/// The log-normal distribution is used in various fields such as finance and environmental science to model data that follows a normal distribution after a logarithmic transformation.
/// This function calculates the probability density at a given point `x` for a log-normal distribution with the specified mean and standard deviation of the underlying normal distribution.
///
/// - Parameters:
///   - x: The value at which to evaluate the probability density function. This must be a positive number.
///   - mean: The mean (average) of the underlying normal distribution. Defaults to `0`.
///   - stdDev: The standard deviation of the underlying normal distribution. Defaults to `1`.
/// - Returns: The value of the log-normal probability density function at `x`.
///
/// - Note: The function follows the formula for the log-normal PDF:
///   \[ f(x; \mu, \sigma) = \frac{1}{x \sigma \sqrt{2 \pi}} \exp\left(-\frac{(\ln x - \mu)^2}{2 \sigma^2}\right) \]
///   where `x` must be positive, `µ` is the mean of the underlying normal distribution, and `σ` is the standard deviation of the underlying normal distribution.
///
/// - Example:
///   ```swift
///   let result = logNormalPDF(1.0, mean: 0.0, stdDev: 1.0)
///   // result should be the probability density of x = 1 for the log-normal distribution with mean 0 and stdDev 1
///   ```

func logNormalPDF<T: Real>(_ x: T, mean µ: T = T(0), stdDev: T = T(1)) -> T {
	let denominator = T.sqrt(2 * .pi) * stdDev * x
	let exponent = -T.pow((T.log(x) - µ), T(2)) / (T(2) * T.pow(stdDev, T(2)))
	let probAtX = T.exp(exponent) / denominator
	return probAtX
}
