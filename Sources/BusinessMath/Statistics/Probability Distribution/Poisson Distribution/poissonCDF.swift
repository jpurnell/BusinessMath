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
	// Convert that floor to an `Int` to index the sum. `Real` gives no numeric
	// conversion to `Int`, so this counts *up to* the floor and stops there.
	//
	// The old cap of 10_000 was a silent truncation: for a rate above it the sum simply
	// stopped and returned a number smaller than the true probability, with nothing to
	// say so. The loop now runs to the floor, and terminates on the mass instead — see
	// below — so the bound is a property of the distribution rather than a constant.
	var n = 0
	while T(n) < floored { n += 1 }

	// Each term as exp(k·ln µ − µ − ln Γ(k+1)), for the reason given on `poisson(_:µ:)`:
	// the previous form divided by `Int` factorial and trapped for any k above 20.
	//
	// A recurrence — p₀ = exp(−µ), pₖ = pₖ₋₁·µ/k — would be cheaper, but p₀ underflows
	// to zero for µ beyond about 745, which would silently return 0 for every argument.
	// Evaluating each term in log space costs a `logGamma` per term and cannot underflow
	// until the term genuinely is negligible.
	let logRate: T = T.log(µ)
	var total: T = T(0)
	for k in 0...n {
		let count: T = T(k)
		let logNumerator: T = count * logRate
		let logTerm: T = logNumerator - µ - T.logGamma(count + T(1))
		total += T.exp(logTerm)
		// Past the mean the terms fall away geometrically. Once the accumulated mass is
		// 1 to within representable precision, every remaining term is below the ulp of
		// the total and adding them changes nothing.
		if total >= T(1) { return T(1) }
	}
	return T.minimum(total, T(1))
}
