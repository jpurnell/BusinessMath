public func distributionRayleigh<T: Real>(mean: T) -> T {
	return mean * T.sqrt(T(-2)*T.log(distributionUniform(min: T(0), max: T(1))))
}

public struct DistributionRayleigh: DistributionRandom {
	let mean: Double
	
	public init(mean: Double) {
		self.mean = mean
	}
	
	public func random() -> Double {
		return distributionRayleigh(mean: mean)
	}
	
	public func next() -> Double {
		return random()
	}
}