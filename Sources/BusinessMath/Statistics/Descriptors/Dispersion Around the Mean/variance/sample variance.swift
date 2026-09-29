//
//  sample variance.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// When we are working with a subset (sample) of the total number of observations, we use the
/// sum of squared average differences, but divide it by one fewer than the number of
/// observations. That is the unbiased estimator at every sample size; there is no small-sample
/// variant of it. The t-distribution governs the sampling distribution of the *mean* — which is
/// what makes confidence intervals and test statistics wider for small samples — and does not
/// change this point estimate. A `varianceTDist` that claimed otherwise was removed in 3.0.0.
///
///
/// Computes the sample variance for a given set of values.
///
/// The sample variance is a measure of the dispersion of a set of data points. It is calculated as the sum of squared differences from the mean divided by the number of degrees of freedom.
///
/// - Parameters:
///	- values: An array of values for which the sample variance is to be calculated.
///
/// - Returns: The sample variance of the given dataset.
///
/// - Note:
///   - This function uses the formula `s^2 = Σ((x - μ)^2) / (n - 1)`, where `n` is the number of data points and `μ` is the mean of the dataset.
///   - The function `sumOfSquaredAvgDiff(_:)` is assumed to be defined elsewhere, which computes the sum of squared differences from the mean.
///
/// - Requires:
///   - Implementation of the `sumOfSquaredAvgDiff(_:)` function to compute the necessary sum of squared differences.
///
/// - Example:
///   ```swift
///   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let sampleVariance = varianceS(data)
///   print("Sample variance of the data: \(sampleVariance)")
///   ```
///
/// - Important:
///   - Fewer than two values has **no sample variance**, and the function answers `nan` rather
///     than a number. The divisor is `n - 1`, so one observation asks for `0/0` and an empty
///     array for `0/0` as well; neither is zero dispersion, which is what a `0` would claim.
///     Measured consequence of the old `0`: `stdDevS([x])` was `0`, so any t-statistic dividing
///     by it came back `±infinity` — infinitely significant evidence from a single observation.
///     `varianceP` already behaves this way for an empty array (it divides by `count`), and a
///     *population* of one genuinely does have zero variance, which is why the two differ.
///   - Equivalent of Excel VAR(xx:xx), which reports `#DIV/0!` for the same inputs.
///
public func varianceS<T: Real>(_ values: [T]) -> T {
	// `n - 1` degrees of freedom means one observation leaves none. Returning `0` here read as
	// "these values do not vary" — the confident, unremarkable answer — for a sample that
	// cannot be dispersed at all. See the `- Important:` note above for the measured effect.
	guard values.count > 1 else {
		return T.nan
	}
	let degreesOfFreedom = values.count - 1
	return sumOfSquaredAvgDiff(values)/T(degreesOfFreedom)
}
