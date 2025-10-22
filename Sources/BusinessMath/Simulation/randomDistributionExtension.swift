import Numerics

extension Double {
	public static func randomNormal(mean: Double = 0.0, stdDev: Double = 1.0) -> Double {
		return distributionNormal(mean: mean, stdDev: stdDev)
	}
	
	public static func randomTriangular(low: Double, high: Double, base: Double) -> Double {
		return triangularDistribution(low: low, high: high, base: base)
	}
	
	public static func randomUniform(low: Double, high: Double) -> Double {
		return distributionUniform(min: low, max: high)
	}
	
	public static func randomExponential(rate: Double) -> Double {
		return distributionExponential(λ: rate)
	}
	
	public static func randomGamma(r: Int, λ: Double) -> Double {
		return distributionGamma(r: r, λ: λ)
	}
	
	public static func randomGeometric(p: Double) -> Double {
		return distributionGeometric(p)
	}
	
	public static func randomLogistic(_ mean: Double = 0, _ stdDev: Double = 1) -> Double {
		return distributionLogistic(mean, stdDev)
	}
	
	public static func randomLogNormal(mean: Double, stdDev: Double) -> Double {
		return distributionLogNormal(mean: mean, stdDev: stdDev)
	}
}
