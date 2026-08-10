//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

/// Computes the cumulative distribution function (CDF) of the Poisson distribution.
///
/// The Poisson distribution is commonly used to model the number of events occurring within a fixed interval of time or space.
/// This function calculates the cumulative probability that the number of events will be less than or equal to a given value.
///
/// - Parameters:
///   - x: The number of occurrences for which the CDF is to be calculated. This must be a non-negative number.
///   - µ: The average number of occurrences in the given interval (mean of the Poisson distribution). This must be a non-negative number.
/// - Returns: The cumulative probability `P(X ≤ x)` where `X` is a Poisson random variable.
///
/// - Note: The function sums the probabilities for values from `0` to `floor(x)` to obtain the cumulative distribution function. It uses the
///   exponential function and the power function to calculate each term in the sum and the factorial function to normalize the probability.
///
/// - Note: A degenerate Poisson (`µ = 0`) is the point mass at zero, so the CDF is `1` for every `k ≥ 0`. That case is written out rather than
///   summed, because the general term evaluates `pow(0, 0)`, which is `NaN` here rather than the `1` the limit requires.
public func poissonCDF<T: Real>(_ x: T, µ: T) -> T {
	guard x >= 0 else { return T(0) }
	// A negative or NaN rate is not a Poisson; the sum would evaluate pow(negative, k),
	// which is already NaN, so say so directly rather than by accident.
	guard µ >= 0 else { return T.nan }
	// The degenerate distribution: all of the mass sits at zero, so the CDF is 1
	// everywhere on the support. Taken before the sum can reach pow(0, 0).
	guard µ > 0 else { return T(1) }
	// floor(x), the real one. This used to count up while `counter < x`, which
	// overshoots by one at every exact integer: for x = 3 the loop ran to counter = 3,
	// stopped, and took `floorInt - 1` = 2, so the sum ran k = 0...2 and the function
	// returned P(X ≤ 2). Non-integer arguments were unaffected, which is why a test on
	// any half-integer grid passed. `Real` refines `FloatingPoint`, so `.rounded(.down)`
	// is available for every conforming type.
	let floored = x.rounded(.down)
	// Convert that floor to an `Int` for the factorial. `Real` gives no numeric
	// conversion to `Int`, so this counts *up to* the floor and stops there. The cap
	// bounds the work; the Poisson CDF is 1 to within double precision long before it.
	var n = 0
	while T(n) < floored && n < 10_000 {
		n += 1
	}
	return T.exp(-1 * µ) * (0...n).map({T.pow(µ, T($0)) / T($0.factorial())}).reduce(T(0), +)
}
