//
//  distributionGeometric.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics


// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from a geometric distribution with success probability `p`.
///
/// The geometric distribution models the number of trials needed to get the first success in a sequence of independent Bernoulli trials.
/// It is a discrete probability distribution with parameter `p`, where `p` is the probability of success on each trial.
///
/// - Parameters:
///   - p: The probability of success on each trial. It should be a value between 0 and 1.
///   - seeds: Optional array of uniform random seeds for deterministic generation (default: nil)
/// - Returns: A random number generated from the geometric distribution with success probability `p`.
///
/// - Note: The function generates random numbers using a uniform random number generator to simulate Bernoulli trials until the first success occurs.
///         Make sure to seed the random number generator appropriately when using `distributionUniform()`.
///
/// - Example:
///   ```swift
///   let probabilityOfSuccess: Double = 0.5
///   let randomValue: Double = distributionGeometric(probabilityOfSuccess)
///   // randomValue will be a random number generated from the geometric distribution with parameter p = 0.5
public func distributionGeometric<T: Real>(_ p: T, seeds: [Double]? = nil) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard p > T(0), p <= T(1), !p.isNaN, p.isFinite else { return T.nan }

	// Special case: p = 1 means always succeed on first trial
	if p == T(1) { return T(1) }

	// Use inverse transform method (O(1), no iteration needed)
	// X = ceil(ln(U) / ln(1-p)) where U ~ Uniform(0,1)
	let u: T
	if let seeds = seeds, !seeds.isEmpty {
		u = distributionUniform(min: T(0), max: T(1), seeds[0])
	} else {
		u = distributionUniform()
	}

	// Avoid log(0) by using 1-U which has same distribution as U
	let oneMinusP = T(1) - p
	let logOneMinusP = T.log(oneMinusP)

	// Prevent division by zero for p very close to 1
	guard logOneMinusP < T(0) else { return T(1) }

	// ceil(ln(1-U) / ln(1-p)) but use ln(U) since U and 1-U have same distribution
	let result = T.log(u) / logOneMinusP
	return T(max(1, Int(result.rounded(.up))))
}

/// A geometric distribution generator for modeling number of trials until first success.
///
/// The geometric distribution models scenarios like: number of coin flips until heads,
/// number of attempts until success, or waiting time in discrete trials.
public struct DistributionGeometric: DistributionRandom {
	let p: Double

	/// Creates a geometric distribution generator.
	/// - Parameter probabilityOfSuccess: Success probability per trial (0 < p ≤ 1)
	public init(_ probabilityOfSuccess: Double) {
		self.p = probabilityOfSuccess
	}

	/// Generates a random value from the geometric distribution.
	/// - Returns: A random positive integer (as Double) representing number of trials
	public func random() -> Double {
		distributionGeometric(p)
	}

	/// Generates the next random value from the geometric distribution.
	/// - Returns: A random positive integer (as Double) representing number of trials
	public func next() -> Double {
		return random()
	}
}



