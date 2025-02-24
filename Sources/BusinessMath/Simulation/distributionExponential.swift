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
public func distributionExponential<T: Real>(λ: T) -> T {
	let u: T = distributionUniform()
	return T(-1) * (T(1) / λ) * T.log(1 - u)
}

public struct DistributionExponential: RandomNumberGenerator {
	let λ: Double
	
	public init(_ λ: Double) {
		self.λ = λ
	}
	
	public func random() -> Double {
		distributionExponential(λ: λ)
	}
	
	public func next() -> UInt64 {
		return UInt64(random())
	}
}
