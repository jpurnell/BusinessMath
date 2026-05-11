import Foundation
import Numerics

/// Cumulative distribution function of the non-central t-distribution.
///
/// Computes P(T <= t | nu, delta) where delta is the non-centrality parameter.
///
/// Uses the representation T = (Z + delta) / sqrt(V/nu) where Z ~ N(0,1) and V ~ chi^2(nu)
/// are independent. The CDF is computed as:
///
/// P(T <= t) = E_V[ Phi(t * sqrt(V/nu) - delta) ]
///
/// where Phi is the standard normal CDF. This expectation is evaluated by numerical
/// integration over the Gamma(nu/2, 1) distribution of V/2.
///
/// For large degrees of freedom (df > 200), a corrected normal approximation is used.
///
/// - Parameters:
///   - t: Value at which to evaluate (any real number).
///   - df: Degrees of freedom (> 0).
///   - delta: Non-centrality parameter. When delta = 0, equals central t CDF.
/// - Returns: P(T <= t) in [0, 1].
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if df <= 0.
public func nonCentralTCDF<T: Real>(t: T, df: Int, delta: T) throws -> T {
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, inf)")
	}

	// Central case
	if delta == T.zero {
		return try tCDF(t: t, df: df)
	}

	let nu = T(df)

	// Normal approximation for large df
	if df > 200 {
		let correctedMean = delta * (T(1) - T(1) / (T(4) * nu))
		let correctedVariance = T(1) + delta * delta / (T(2) * nu)
		let stdDev = T.sqrt(correctedVariance)
		return normalCDF(x: t, mean: correctedMean, stdDev: stdDev)
	}

	// Numerical integration:
	// P(T <= t) = integral_0^inf Phi(t * sqrt(2w/nu) - delta) * f(w) dw
	// where f(w) = w^{alpha-1} * e^{-w} / Gamma(alpha), alpha = nu/2
	//
	// The Gamma(alpha, 1) density has mode at alpha-1 and mean alpha.
	// We integrate using composite trapezoidal rule over a range covering
	// effectively all of the Gamma density mass.

	let alpha = nu / T(2)
	let sqrtAlpha = T.sqrt(alpha)

	// Integration range: [0, alpha + 10*sqrt(alpha)]
	// This covers well beyond 99.99% of the Gamma distribution mass
	let wMax = alpha + T(10) * sqrtAlpha

	// Use adaptive number of integration points for accuracy
	// More points for larger df (wider gamma distribution)
	let nPoints = 2000
	let dw = wMax / T(nPoints)

	let logGammaAlpha = T.logGamma(alpha)
	let two = T(2)

	var integral = T.zero

	for i in 1..<nPoints {
		let w = T(i) * dw

		// Phi argument: t * sqrt(2*w/nu) - delta
		let sqrtRatio = T.sqrt(two * w / nu)
		let phiArg = t * sqrtRatio - delta
		let phiVal = normalCDF(x: phiArg, mean: T.zero, stdDev: T(1))

		// Gamma(alpha, 1) log-density: (alpha-1)*log(w) - w - logGamma(alpha)
		let logDensity = (alpha - T(1)) * T.log(w) - w - logGammaAlpha
		let density = T.exp(logDensity)

		integral += phiVal * density * dw
	}

	return min(max(integral, T.zero), T(1))
}
