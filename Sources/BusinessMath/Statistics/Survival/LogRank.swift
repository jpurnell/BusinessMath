//
//  LogRank.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The log-rank test: does one group survive longer than another?
///
/// ```swift
/// let control: [Double] = [6, 7, 10, 15]
/// let treated: [Double] = [8, 12, 20, 25]
/// if let test = LogRankTest(firstTimes: control, firstEvents: [true, true, true, false],
///                           secondTimes: treated, secondEvents: [true, true, false, true]) {
///     print(test.statistic, test.pValue)
/// }
/// ```
///
/// ## What it compares, and what it does not
///
/// At each failure time the test asks how many failures fell in the first group against
/// how many the risk sets say should have, if survival were identical. Those differences
/// accumulate; under the null they sum to zero, and the standardised sum is `χ²` on one
/// degree of freedom.
///
/// **It compares whole curves, not any single point.** Two groups can have identical
/// survival at every landmark you might pick and still separate here, and two groups whose
/// curves cross can be strongly different in the middle and indistinguishable to this test
/// — the early and late differences cancel. A crossing pair is exactly where the log-rank
/// is least informative, and looking at the curves is the remedy.
///
/// It also uses no times at all beyond their order, which is what makes it non-parametric
/// and what stops it from saying by how much the groups differ. For that, read the
/// restricted means off ``SurvivalCurve/restrictedMean(horizon:)``.
public struct LogRankTest<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// Observed failures in the first group.
	public let observed: T

	/// Failures the first group would have had under identical survival.
	public let expected: T

	/// The hypergeometric variance of ``observed``, summed over failure times.
	public let variance: T

	/// `(O − E)² / V`, chi-squared on one degree of freedom.
	public let statistic: T

	/// Always one: the test compares two groups.
	public let degreesOfFreedom: Int = 1

	/// The upper-tail probability of ``statistic``.
	public let pValue: T

	/// Runs the test.
	///
	/// - Parameters:
	///   - firstTimes: Durations in the first group.
	///   - firstEvents: `true` for a failure, `false` for right-censoring.
	///   - secondTimes: Durations in the second group.
	///   - secondEvents: As above.
	/// - Returns: `nil` if either group is empty, the lengths disagree, a time is
	///   negative or non-finite, or neither group records a failure — with no failures
	///   anywhere there is nothing to compare.
	public init?(firstTimes: [T], firstEvents: [Bool],
				 secondTimes: [T], secondEvents: [Bool]) {
		guard !firstTimes.isEmpty, !secondTimes.isEmpty else { return nil }
		guard firstTimes.count == firstEvents.count,
			  secondTimes.count == secondEvents.count else { return nil }
		let everyTime = firstTimes + secondTimes
		guard everyTime.allSatisfy({ $0.isFinite && $0 >= T.zero }) else { return nil }
		guard firstEvents.contains(true) || secondEvents.contains(true) else { return nil }

		var failureTimes: [T] = []
		for (time, event) in zip(everyTime, firstEvents + secondEvents) where event {
			if !failureTimes.contains(where: { $0 == time }) { failureTimes.append(time) }
		}
		failureTimes.sort()

		var totalObserved: T = T.zero
		var totalExpected: T = T.zero
		var totalVariance: T = T.zero

		for failure in failureTimes {
			let riskFirst = firstTimes.filter { $0 >= failure }.count
			let riskSecond = secondTimes.filter { $0 >= failure }.count
			let riskTotal = riskFirst + riskSecond
			// One subject at risk cannot inform a comparison, and the variance below
			// divides by `n − 1`.
			guard riskTotal > 1 else { continue }

			var failuresFirst = 0
			for (time, event) in zip(firstTimes, firstEvents) where event && time == failure {
				failuresFirst += 1
			}
			var failuresSecond = 0
			for (time, event) in zip(secondTimes, secondEvents) where event && time == failure {
				failuresSecond += 1
			}
			let failures = failuresFirst + failuresSecond
			guard failures > 0 else { continue }

			let n: T = T(riskTotal)
			let n1: T = T(riskFirst)
			let d: T = T(failures)
			let share: T = n1 / n
			totalObserved += T(failuresFirst)
			totalExpected += d * share

			// The hypergeometric variance, with the finite-population correction
			// (n − d)/(n − 1). At d = n that factor is zero: when everyone still at risk
			// fails at once the split carries no information, and the term correctly
			// contributes nothing.
			let complement: T = 1 - share
			let spread: T = d * share * complement
			let remaining: T = n - d
			let denominator: T = n - 1
			guard denominator > T.zero else { continue }
			let correction: T = remaining / denominator
			totalVariance += spread * correction
		}

		self.observed = totalObserved
		self.expected = totalExpected
		self.variance = totalVariance

		if totalVariance > T.zero {
			let gap: T = totalObserved - totalExpected
			let squared: T = gap * gap
			let chi: T = squared / totalVariance
			self.statistic = chi
			self.pValue = Self.upperTail(chi)
		} else {
			self.statistic = T.zero
			self.pValue = T(1)
		}
	}

	/// `P(χ²₁ > x)`.
	///
	/// One degree of freedom has a closed form — `2(1 − Φ(√x))` — because a `χ²₁` is a
	/// squared standard normal. Using it avoids reaching for the incomplete gamma for
	/// the one case that does not need it.
	///
	/// - Parameter x: The statistic.
	/// - Returns: The upper-tail probability.
	static func upperTail(_ x: T) -> T {
		guard x > T.zero else { return T(1) }
		let root: T = T.sqrt(x)
		let cumulative: T = normalCDF(x: root, mean: T.zero, stdDev: T(1))
		let tail: T = 1 - cumulative
		return 2 * tail
	}
}
