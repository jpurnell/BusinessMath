import Foundation
import Numerics

/// Probability density function of Student's t-distribution.
///
/// Computes the density at a given point for the t-distribution
/// with the specified degrees of freedom:
///
/// f(t | v) = Gamma((v+1)/2) / (sqrt(v * pi) * Gamma(v/2)) * (1 + t^2/v)^(-(v+1)/2)
///
/// - Parameters:
///   - t: The value at which to evaluate the density.
///   - df: Degrees of freedom (> 0).
/// - Returns: The density f(t | v).
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if `df` <= 0.
public func studentTPDF<T: Real>(t: T, df: Int) throws -> T {
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, ∞)")
	}

	let nu = T(df)

	// Work in log-space to avoid overflow for large df
	let logCoeff = T.logGamma((nu + T(1)) / T(2))
		- T.logGamma(nu / T(2))
		- T.log(nu * T.pi) / T(2)
	let logKernel = -((nu + T(1)) / T(2)) * T.log(T(1) + (t * t) / nu)

	return T.exp(logCoeff + logKernel)
}
