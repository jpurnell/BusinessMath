//
//  distributionGamma.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from a Gamma distribution with shape parameter `r` and rate parameter `λ`.
///
/// The Gamma distribution is a two-parameter family of continuous probability distributions. The parameters are referred to as the shape parameter `r` and the rate parameter `λ`. This function uses the relationship between the Gamma and Exponential distributions to generate a Gamma-distributed random variable.
///
/// - Parameters:
///   - r: The shape parameter of the Gamma distribution, which must be an integer indicating the number of exponential random variables to sum.
///   - λ: The rate parameter (inverse of the scale parameter) of the Gamma distribution.
/// - Returns: A random number generated from the Gamma distribution with shape parameter `r` and rate parameter `λ`.
///
/// - Note: The function generates `r` exponential random variables with rate parameter `λ` and returns their sum. This approaches the Gamma distribution using the definition that a Gamma distribution with integer shape parameter `r` can be constructed from the sum of `r` exponential variables.
///
/// - Example:
///   ```swift
///   let shapeParameter: Int = 3
///   let rateParameter: Double = 2.0
///   let randomValue: Double = distributionGamma(r: shapeParameter, λ: rateParameter)
///   // randomValue will be a random number generated from the Gamma distribution with parameters r = 3 and λ = 2.0

public func distributionGamma<T: Real>(r: Int, λ: T, seeds: [Double]? = nil) -> T {
	if let seeds = seeds {
		// Use provided seeds for deterministic generation
		let requiredSeeds = min(r, seeds.count)
		var sum: T = T(0)
		for i in 0..<requiredSeeds {
			sum += distributionExponential(λ: λ, seed: seeds[i])
		}
		// If not enough seeds, generate remaining randomly
		for _ in requiredSeeds..<r {
			sum += distributionExponential(λ: λ)
		}
		return sum
	} else {
		return (0..<r).map({_ in distributionExponential(λ: λ) }).reduce(T(0), +)
	}
}

/// Generates a random value from a Gamma distribution using Marsaglia and Tsang's method.
///
/// This is a more general and efficient implementation that works for any real-valued shape parameter.
/// Uses Marsaglia and Tsang's method for shape >= 1, and shape transformation for shape < 1.
///
/// - Parameters:
///   - shape: The shape parameter (k > 0)
///   - scale: The scale parameter (θ > 0)
///   - seeds: Optional array of seed values for deterministic generation
///   - seedIndex: Mutable index tracking position in seed array
/// - Returns: A random value from Gamma(shape, scale)
public func gammaVariate<T: Real>(shape: T, scale: T, seeds: [Double]? = nil, seedIndex: inout Int) -> T {
	guard shape > T(0) && scale > T(0) else {
		fatalError("Gamma shape and scale must be positive")
	}

	// Helper to get next seed
	func nextSeed() -> Double {
		if let seeds = seeds, seedIndex < seeds.count {
			let seed = seeds[seedIndex]
			seedIndex += 1
			return seed
		}
		return Double.random(in: 0...1)
	}

	// For shape < 1, use the transformation property
	if shape < T(1) {
		let uSeed = nextSeed()
		let u: T = distributionUniform(min: T(0), max: T(1), uSeed)
		let x = gammaVariate(shape: shape + T(1), scale: scale, seeds: seeds, seedIndex: &seedIndex)
		return x * T.pow(u, T(1) / shape)
	}

	// Marsaglia and Tsang's method for shape >= 1
	let oneThird: T = T(1) / T(3)
	let d = shape - oneThird
	let c = T(1) / T.sqrt(T(9) * d)

	while true {
		var x: T
		var v: T

		// Generate v = (1 + c×Z)³ where Z ~ N(0,1)
		repeat {
			let u1Seed = nextSeed()
			let u2Seed = nextSeed()
			x = distributionNormal(mean: T(0), stdDev: T(1), u1Seed, u2Seed)
			v = T(1) + c * x
		} while v <= T(0)

		v = v * v * v

		// Generate U ~ Uniform(0,1)
		let uSeed = nextSeed()
		let u: T = distributionUniform(min: T(0), max: T(1), uSeed)

		// Acceptance test
		let x2 = x * x
		let x4 = x2 * x2
		let constant: T = T(331) / T(10000)  // 0.0331
		let threshold1 = T(1) - constant * x4
		if u < threshold1 {
			return d * v * scale
		}

		let logU = T.log(u)
		let logV = T.log(v)
		let half: T = T(1) / T(2)
		let term1 = half * x2
		let term2 = d * (T(1) - v + logV)
		let threshold2 = term1 + term2
		if logU < threshold2 {
			return d * v * scale
		}
	}
}

public struct DistributionGamma: DistributionRandom {
	var r: Int
	var λ: Double
	
	public init(r: Int, λ: Double) {
		self.r = r
		self.λ = λ
	}
	
	public func random() -> Double {
		return distributionGamma(r: r, λ: λ)
	}
	
	public func next() -> Double {
		return random()
	}
}
