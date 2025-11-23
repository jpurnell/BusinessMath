//
//  distributionExponential.swift
//
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from an Exponential distribution with rate parameter `λ`.
///
/// The Exponential distribution is a continuous probability distribution that describes the time between events in a Poisson process. This function generates a random number from an Exponential distribution using the inverse transform sampling method.
///
/// - Parameters:
///   - λ: The rate parameter of the Exponential distribution.
/// - Returns: A random number generated from the Exponential distribution with rate parameter `λ`.
///
/// - Note: The function computes the random number using the inverse transform sampling method:
///   \[ X = -\frac{1}{\lambda} \
///
public func distributionExponential<T: Real>(λ: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	let u: T
	if let seed = seed {
		u = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		u = distributionUniform()
	}
	return T(-1) * (T(1) / λ) * T.log(1 - u)
}

public struct DistributionExponential: DistributionRandom {
	let λ: Double
	
	public init(_ λ: Double) {
		self.λ = λ
	}
	
	public func random() -> Double {
		distributionExponential(λ: λ)
	}
	
	public func next() -> Double {
		return random()
	}
}
