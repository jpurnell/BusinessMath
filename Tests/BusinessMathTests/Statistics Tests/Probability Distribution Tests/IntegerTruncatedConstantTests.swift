//
//  IntegerTruncatedConstantTests.swift
//  BusinessMath
//
//  Pins the constants that `T(Int(...))` had silently truncated.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Every function here computed a fractional constant by converting to `Int` first,
/// so the constant collapsed — to 1 where 1.06 was meant, and to 0 where 0.05 and
/// (n - k)/(n - 1) were meant. The constants are pinned to their intended values, and
/// each test also states the value the truncated spelling produced, so a regression
/// to the old idiom fails rather than quietly returning the old number again.
@Suite("Integer-truncated constants")
struct IntegerTruncatedConstantTests {

	// MARK: - Fisher's 1.06

	/// The standard error of the Fisher z-transform of a *rank* correlation is
	/// `sqrt(1.06 / (n - 3))` (Fieller, Hartley & Pearson 1957), so the z statistic is
	/// `z · sqrt((n - 3) / 1.06)`. Written as `T(Int(106) / 100)` the divisor was `T(1)`,
	/// which is the standard error of the *Pearson* z-transform — a different statistic.
	@Test("zScore(fisherR:items:) divides by 1.06, not by 1")
	func fisherRZScoreUsesTheRankCorrectionFactor() {
		// Pre-fix: sqrt(7 - 3) · 0.68 = 2 · 0.68 = 1.36 exactly.
		let truncated = Double(7 - 3).squareRoot() * 0.68
		#expect(abs(truncated - 1.36) < 1e-15)

		let z = zScore(fisherR: 0.68, items: 7)
		#expect(abs(z - 1.3209487728058793) < 1e-12)
		// 1.36 against 1.3209…: a 2.96% gap, far outside any rounding argument.
		#expect(abs(z - truncated) > 1e-6)

		// The whole effect is the constant, so the ratio is 1/sqrt(1.06) at every n and r.
		let expectedRatio = 1.0 / 1.06.squareRoot()
		for (r, n) in [(0.68, 7), (0.5, 30), (0.9, 103)] {
			let value = zScore(fisherR: r, items: n)
			let old = Double(n - 3).squareRoot() * r
			#expect(abs(value / old - expectedRatio) < 1e-12)
		}
		#expect(abs(expectedRatio - 0.9712858623572641) < 1e-15)
	}

	/// `zScore(rho:items:)` already carried the repaired spelling. Once `fisherR` matches,
	/// the two agree exactly — which is the point, since one is defined as the other
	/// applied to `fisher(rho)`. Before the fix they disagreed by 2.96%.
	@Test("zScore(rho:) and zScore(fisherR:) agree once both use 1.06")
	func rhoAndFisherRZScoresAgree() throws {
		for (rho, n) in [(0.68, 7), (0.42, 25), (-0.3, 50)] {
			let viaRho = try zScore(rho: rho, items: n)
			let viaFisher = zScore(fisherR: try fisher(rho), items: n)
			#expect(abs(viaRho - viaFisher) < 1e-14)
		}
	}

	/// `correlationBreakpoint` inverts the same statistic, so dropping the 1.06 made every
	/// breakpoint too small — it understated the correlation needed to clear the threshold.
	@Test("correlationBreakpoint divides by 1.06, not by 1")
	func correlationBreakpointUsesTheRankCorrectionFactor() {
		// n = 100 at 95%: the truncated constant gave 0.16547395781714794.
		let value = correlationBreakpoint(100, probability: 0.95)
		#expect(abs(value - 0.17027211388345986) < 1e-12)
		#expect(value > 0.1655, "the breakpoint must not fall back to the 1.0-divisor value")

		// Larger samples still need smaller correlations, and higher confidence still needs
		// larger ones — the fix scales the curve, it does not reshape it.
		#expect(correlationBreakpoint(1000, probability: 0.95) < value)
		#expect(correlationBreakpoint(100, probability: 0.99) > value)

		#expect(abs(correlationBreakpoint(1000, probability: 0.95) - 0.05358169805593157) < 1e-12)
		#expect(abs(correlationBreakpoint(100, probability: 0.99) - 0.23850445902151188) < 1e-12)
	}

	// MARK: - The 5% finite-population threshold

	/// `T(Int(5) / Int(100))` was 0 and `T(x.count / population)` was 0, so the test read
	/// `0 >= 0`: the finite-population branch had never run. It is reachable now, and it is on
	/// the side the textbook puts it — the correction applies when the sample is a large
	/// fraction of the population, not a small one.
	@Test("correctedStdErr reaches its finite-population branch")
	func correctedStandardErrorReachesTheCorrectionBranch() {
		let x: [Double] = (1...10).map { Double($0) }   // 10% of 100, above the threshold
		let uncorrected = standardError(x)
		let corrected = correctedStdErr(x, population: 100)

		// Pre-fix this returned `uncorrected` unchanged, for every input ever passed.
		#expect(corrected < uncorrected)
		#expect(abs(uncorrected - 0.9574271077563381) < 1e-12)
		#expect(abs(corrected - 0.9128709291752769) < 1e-12)

		// sqrt((N - n)/(N - 1)) = sqrt(90/99). Pre-fix that quotient was Int division and
		// evaluated to 0, so this branch would have returned exactly zero had it run.
		#expect(abs(corrected / uncorrected - (90.0 / 99.0).squareRoot()) < 1e-12)
		#expect(corrected > 0.0)
	}

	/// The threshold is a real 0.05 now, and the branches are the way round every textbook
	/// has them — which is also the way round `standardErrorProbabilistic` in the same
	/// directory already had them. The two functions used to disagree with each other.
	@Test("correctedStdErr corrects above 5%, not below")
	func correctedStandardErrorThresholdIsFivePercent() {
		let belowThreshold: [Double] = [1.0, 2.0, 3.0, 4.0]     // 4% of 100
		#expect(correctedStdErr(belowThreshold, population: 100).isEqual(to: standardError(belowThreshold)))

		let atThreshold: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]   // exactly 5%, so still no correction
		#expect(correctedStdErr(atThreshold, population: 100).isEqual(to: standardError(atThreshold)))

		let justAbove: [Double] = (1...6).map { Double($0) }    // 6% of 100
		#expect(correctedStdErr(justAbove, population: 100) < standardError(justAbove))

		let farBelow: [Double] = [1.0, 2.0, 3.0]                // 0.3% of 1000
		#expect(correctedStdErr(farBelow, population: 1000).isEqual(to: standardError(farBelow)))

		// A census-sized sample is where the correction earns its keep: 50 of 100 shrinks the
		// standard error by 29%, from 2.0615528128088303.
		let half: [Double] = (1...50).map { Double($0) }
		#expect(abs(correctedStdErr(half, population: 100) - 1.4650817883192209) < 1e-12)
	}

	/// `standardErrorProbabilistic`'s threshold had already been repaired; the quotient
	/// inside its correction factor had not, and `T((total - n)/(total - 1))` is Int
	/// division. The branch returned `base · sqrt(0)` — exactly zero — for every n > 1.
	@Test("standardErrorProbabilistic no longer returns zero above the threshold")
	func standardErrorProbabilisticCorrectionIsNotZero() {
		let base = standardErrorProbabilistic(0.5, observations: 10)
		#expect(abs(base - 0.15811388300841897) < 1e-15)

		let corrected = standardErrorProbabilistic(0.5, observation: 10, totalObservations: 100)
		#expect(corrected > 0.0, "the finite-population branch returned exactly zero")
		#expect(abs(corrected - 0.15075567228888181) < 1e-12)
		#expect(abs(corrected / base - (90.0 / 99.0).squareRoot()) < 1e-12)

		// A census-sized sample: 50 of 100.
		#expect(abs(standardErrorProbabilistic(0.5, observation: 50, totalObservations: 100) - 0.050251890762960605) < 1e-12)

		// Below the threshold the correction is skipped, and always was.
		#expect(standardErrorProbabilistic(0.5, observation: 2, totalObservations: 100)
				.isEqual(to: standardErrorProbabilistic(0.5, observations: 2)))
	}
}
