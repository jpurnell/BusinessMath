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
	let coefficient = T(1) / (stdDev * T.sqrt(2 * .pi))
	
	// Use direct multiplication instead of T.pow() to avoid NaN with negative values
	// See note in logNormalPDF for detailed explanation
	let diff = x - µ
	let exponent = -(diff * diff) / (T(2) * stdDev * stdDev)
	return coefficient * T.exp(exponent)
}

/// Computes the value of the log-normal distribution's probability density function (PDF).
///
/// The log-normal distribution is used in various fields such as finance and environmental science to model data that follows a normal distribution after a logarithmic transformation.
/// This function calculates the probability density at a given point `x` for a log-normal distribution with the specified mean and standard deviation of the underlying normal distribution.
///
/// - Parameters:
///   - x: The value at which to evaluate the probability density function. This must be a positive number.
///   - µ: The mean (average) of the underlying normal distribution. Defaults to `0`.
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

public func logNormalPDF<T: Real>(_ x: T, mean µ: T = T(0), stdDev: T = T(1)) -> T {
	let denominator = T.sqrt(2 * .pi) * stdDev * x
	
	// Note: We use direct multiplication (logDiff * logDiff) instead of T.pow(logDiff, T(2))
	// to square the value. This is because T.pow() with generic Real types can produce NaN
	// when the base is negative (which happens when log(x) < µ, e.g., log(0.01) ≈ -4.605).
	// Direct multiplication is more numerically stable, more efficient, and handles negative
	// values correctly since (-a) * (-a) = a² for all real numbers.
	let logDiff = T.log(x) - µ
	let exponent = -(logDiff * logDiff) / (T(2) * stdDev * stdDev)
	let probAtX = T.exp(exponent) / denominator
	return probAtX
}
