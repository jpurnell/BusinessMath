import Numerics

extension Double {
	static func randomNormal(mean: Double = 0.0, stdDev: Double = 1.0) -> Double {
		return distributionNormal(mean: mean, stdDev: stdDev)
	}
	
	static func randomTriangular(low: Double, high: Double, base: Double) -> Double {
		return triangularDistribution(low: low, high: high, base: base)
	}
	
	static func randomUniform(low: Double, high: Double) -> Double {
		return distributionUniform(min: low, max: high)
	}
	
	static func randomExponential(rate: Double) -> Double {
		return distributionExponential(λ: rate)
	}
	
	static func randomGamma(r: Int, λ: Double) -> Double {
		return distributionGamma(r: r, λ: λ)
	}
	
	static func randomGeometric(p: Double) -> Double {
		return distributionGeometric(p)
	}
	
	static func randomLogistic(_ mean: Double = 0, _ stdDev: Double = 1) -> Double {
		return distributionLogistic(distributionUniform(), mean, stdDev)
	}
	
	static func randomLogNormal(mean: Double, stdDev: Double) -> Double {
		return distributionLogNormal(mean: mean, stdDev: stdDev)
	}
}
