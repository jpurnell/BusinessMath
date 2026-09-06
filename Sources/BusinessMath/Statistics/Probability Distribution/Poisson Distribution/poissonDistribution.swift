//
//  poissonDistribution.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Poisson Distribution: Measures the probability of a random event happening over some interval of some time or space. Assumes two things: 1) Probability of the occurence is constant for any two intervals of time or space. 2) The occurence of the even in any interval is independent of the occurence in any other interval
/// Computes the Poisson probability for a given event.
///
/// The Poisson distribution expresses the probability of a given number of events occurring in a fixed interval of time or space, if these events occur with a constant mean rate and are independent of the time since the last event.
///
/// - Parameters:
///     - x: The number of successes that result from the experiment (non-negative).
///     - µ: The mean number of successes that occur in a specified region.
///
/// - Returns: The Poisson probability of observing exactly `x` occurrences in the interval.
///
/// - Precondition: `x` must be a non-negative integer and `µ` has to be a non-negative value.
/// - Complexity: O(1). Evaluated in log space, so no factorial is formed.
///
/// ## Why log space
///
/// This was `pow(µ, x) * exp(-µ) / x.factorial()`, which **trapped the process** for any
/// `x` above 20: `Int.factorial()` returns an `Int` and 21! exceeds `Int64.max`. A rate of
/// 25 arrivals is ordinary, so the crash was reachable from ordinary input — and a trap is
/// worse than a wrong number, because there is no value to inspect and nothing to catch.
/// `pow(µ, x)` overflowed to infinity on the same inputs for its own reasons.
///
/// The identity used instead is
///
/// ```
/// P(X = k) = exp(k·ln µ − µ − ln Γ(k+1))
/// ```
///
/// which forms no large intermediate at all: every term stays within a few hundred in
/// magnitude for any `k` and `µ` a `Double` can represent. `ln Γ(k+1)` is the log factorial.
///
///    let x = 5
///    let µ = 3.5
///    let result = poisson(x, µ: µ)
///    print(result)
///
/// Use this function when you need to model the number of times an event happened in a time interval.

public func poisson<T: Real>(_ x: Int, µ: T) -> T {
	// Below the support. Not an error: the mass there is zero.
	guard x >= 0 else { return T(0) }
	// A negative rate is not a Poisson. Say so, rather than letting `log` say it.
	guard µ >= T(0) else { return T.nan }
	// The degenerate case. All the mass sits at zero, and `log(0)` must not be reached.
	guard µ > T(0) else { return x == 0 ? T(1) : T(0) }

	let count: T = T(x)
	let logRate: T = count * T.log(µ)
	let logFactorial: T = T.logGamma(count + T(1))
	let logProbability: T = logRate - µ - logFactorial
	return T.exp(logProbability)
}
