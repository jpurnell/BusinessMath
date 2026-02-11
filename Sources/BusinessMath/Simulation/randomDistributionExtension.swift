import Numerics

/// Convenience methods for generating random samples from statistical distributions.
extension Double {
	/// Generate a random sample from a normal (Gaussian) distribution.
	/// - Parameters:
	///   - mean: Mean of the distribution (default: 0.0)
	///   - stdDev: Standard deviation (default: 1.0)
	/// - Returns: Random value from Normal(mean, stdDev²)
	public static func randomNormal(mean: Double = 0.0, stdDev: Double = 1.0) -> Double {
		return distributionNormal(mean: mean, stdDev: stdDev)
	}

	/// Generate a random sample from a triangular distribution.
	/// - Parameters:
	///   - low: Minimum value
	///   - high: Maximum value
	///   - base: Mode (most likely value)
	/// - Returns: Random value from Triangular(low, high, base)
	public static func randomTriangular(low: Double, high: Double, base: Double) -> Double {
		return triangularDistribution(low: low, high: high, base: base)
	}

	/// Generate a random sample from a uniform distribution.
	/// - Parameters:
	///   - low: Minimum value (inclusive)
	///   - high: Maximum value (inclusive)
	/// - Returns: Random value uniformly distributed in [low, high]
	public static func randomUniform(low: Double, high: Double) -> Double {
		return distributionUniform(min: low, max: high)
	}

	/// Generate a random sample from an exponential distribution.
	/// - Parameter rate: Rate parameter λ (λ > 0)
	/// - Returns: Random value from Exponential(λ)
	public static func randomExponential(rate: Double) -> Double {
		return distributionExponential(λ: rate)
	}

	/// Generate a random sample from a gamma distribution.
	/// - Parameters:
	///   - r: Shape parameter (integer)
	///   - λ: Rate parameter
	/// - Returns: Random value from Gamma(r, λ)
	public static func randomGamma(r: Int, λ: Double) -> Double {
		return distributionGamma(r: r, λ: λ)
	}

	/// Generate a random sample from a geometric distribution.
	/// - Parameter p: Success probability (0 < p ≤ 1)
	/// - Returns: Random value from Geometric(p)
	public static func randomGeometric(p: Double) -> Double {
		return distributionGeometric(p)
	}

	/// Generate a random sample from a logistic distribution.
	/// - Parameters:
	///   - mean: Location parameter (default: 0)
	///   - stdDev: Scale parameter (default: 1)
	/// - Returns: Random value from Logistic(mean, stdDev)
	public static func randomLogistic(_ mean: Double = 0, _ stdDev: Double = 1) -> Double {
		return distributionLogistic(mean, stdDev)
	}

	/// Generate a random sample from a log-normal distribution.
	/// - Parameters:
	///   - mean: Mean of underlying normal distribution
	///   - stdDev: Standard deviation of underlying normal
	/// - Returns: Random value from LogNormal(mean, stdDev)
	public static func randomLogNormal(mean: Double, stdDev: Double) -> Double {
		return distributionLogNormal(mean: mean, stdDev: stdDev)
	}
}
