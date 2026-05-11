import Foundation
import Numerics

/// Two-tailed p-value from Student's t-distribution.
///
/// Computes P(|T| >= |t|) = 2 * (1 - tCDF(|t|, df)), the probability
/// of observing a test statistic as extreme as or more extreme than `t`
/// under the null hypothesis.
///
/// - Parameters:
///   - t: The observed t-statistic.
///   - df: Degrees of freedom (> 0).
/// - Returns: Two-tailed p-value in [0, 1].
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if `df` <= 0.
public func tPValue<T: Real>(t: T, df: Int) throws -> T {
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, ∞)")
	}

	let cdf = try tCDF(t: abs(t), df: df)
	return T(2) * (T(1) - cdf)
}
