//
//  SampleVarianceContractTests.swift
//  BusinessMath
//
//  Sample variance has `n - 1` degrees of freedom, so a sample of fewer than two observations
//  has none, and `0/0` is not zero dispersion. The old `guard values.count > 1 else { return
//  T(0) }` answered `0` — "these values do not vary" — for a sample that cannot be dispersed
//  at all, and the consequence was not confined to the reported number: `stdDevS([x])` was `0`,
//  so any t-statistic dividing by it came back `±infinity`, which reads as infinitely
//  significant evidence from a single observation.
//
//  The population functions deliberately differ and are pinned here too, because the difference
//  is the point rather than an oversight: a *population* of one genuinely does have zero
//  variance, while a *sample* of one cannot estimate the population's.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Sample variance refuses what it cannot estimate")
struct SampleVarianceContractTests {

	// MARK: - The defect

	@Test("varianceS of an empty sample is not zero dispersion")
	func varianceSOfEmptyIsNaN() {
		let result = varianceS([Double]())
		#expect(result.isNaN, "an empty sample has no variance; got \(result)")
	}

	@Test("varianceS of one observation is not zero dispersion")
	func varianceSOfSingletonIsNaN() {
		// n - 1 == 0, so the divisor is zero and the numerator is zero: 0/0.
		let result = varianceS([42.0])
		#expect(result.isNaN, "one observation leaves no degrees of freedom; got \(result)")
	}

	@Test("stdDevS inherits the refusal, since it is the square root of varianceS")
	func stdDevSInheritsTheRefusal() {
		let result = stdDevS([42.0])
		#expect(result.isNaN, "got \(result)")
	}

	@Test("A t-statistic over one observation is unanswerable, not infinitely significant")
	func tStatisticIsNoLongerInfinite() {
		// The measured consequence of the old `0`. With `stdDevS == 0` this ratio was
		// `±infinity`; a caller comparing it against a critical value read it as significant
		// at every level.
		let sample: [Double] = [42.0]
		let spread = stdDevS(sample)
		let tStatistic = (sample[0] - 40.0) / spread
		#expect(tStatistic.isNaN, "got \(tStatistic)")
		#expect(!tStatistic.isInfinite)
	}

	// MARK: - The dispatchers inherit it

	@Test("variance(_:_:) defaults to the sample estimator and inherits the refusal")
	func varianceDispatcherInherits() {
		let result = variance([42.0])
		#expect(result.isNaN, "got \(result)")
	}

	@Test("stdDev(_:_:) defaults to the sample estimator and inherits the refusal")
	func stdDevDispatcherInherits() {
		let result = stdDev([42.0])
		#expect(result.isNaN, "got \(result)")
	}

	// MARK: - Controls: what must NOT change

	@Test("A population of one genuinely has zero variance")
	func populationOfOneIsZero() {
		// Deliberately different from the sample case. Every member of the population is
		// observed, and they do not differ from their own mean.
		let result = varianceP([42.0])
		#expect(result.isEqual(to: 0.0), "got \(result)")
	}

	@Test("An empty population is still unanswerable")
	func populationOfNoneIsNaN() {
		// `varianceP` divides by `count`, so this was already 0/0 and already `nan`.
		let result = varianceP([Double]())
		#expect(result.isNaN, "got \(result)")
	}

	@Test("Two observations still produce the ordinary sample variance")
	func twoObservationsAreUnchanged() {
		// mean 3; squared deviations 1 and 1; sum 2; divided by n - 1 == 1.
		let result = varianceS([2.0, 4.0])
		#expect(result.isEqual(to: 2.0), "got \(result)")
		let spread = stdDevS([2.0, 4.0])
		let expectedSpread: Double = 2.0.squareRoot()
		#expect(spread.isEqual(to: expectedSpread), "got \(spread)")
	}

	@Test("A larger clean sample is unchanged")
	func largerSampleIsUnchanged() {
		// mean 5; squared deviations 16, 4, 0, 4, 16; sum 40; divided by n - 1 == 4.
		let result = varianceS([1.0, 3.0, 5.0, 7.0, 9.0])
		#expect(result.isEqual(to: 10.0), "got \(result)")
	}
}
