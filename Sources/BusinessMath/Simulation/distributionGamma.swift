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

public func distributionGamma<T: Real>(r: Int, λ: T) -> T {
	return (0..<r).map({_ in distributionExponential(λ: λ) }).reduce(T(0), +)
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
