//
//  TrappingStatisticsTests.swift
//  BusinessMath
//
//  Phase 1 of the contaminated-input sweep: `Int(_:)` traps the *process* — for a
//  non-finite value and equally for a finite one above `Int.max` (9.22e18). A trap is
//  worse than a wrong number, because there is no value to inspect and nothing to catch.
//
//  Three sites in Statistics, each fixed at the point the value enters rather than at the
//  conversion. Every suite here pairs the crash case with a clean-data control that passed
//  before the fix and still passes after it: that pairing is what shows the screen is
//  targeted rather than a blanket short-circuit.
//
//  See project/plans/CONTAMINATED_INPUT_CONTRACT.md.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Trapping conversions — experiment sizing")
struct PowerAnalysisTrapTests {

	// MARK: - Clean-data controls

	@Test("Control: a sizable two-mean design still returns 252 per arm")
	func sizableMeanDesignIsUnaffected() throws {
		let design = Experiment<Double>.twoMean(
			baseline: 100.0, standardDeviation: 20.0, minimumDetectableEffect: 5.0
		)
		let perArm = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)

		// The same figure `ExperimentDesignTests` pins against R's `power.t.test`:
		// exact 251.164, rounded up. It must survive the new representability screen.
		#expect(perArm == 252, "Expected 252 per arm, got \(perArm)")
	}

	@Test("Control: a sizable two-proportion design still returns 1565 per arm")
	func sizableProportionDesignIsUnaffected() throws {
		let design = Experiment<Double>.twoProportion(
			baseline: 0.50, minimumDetectableEffect: 0.05
		)
		let perArm = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)

		// R's `power.prop.test(p1 = 0.50, p2 = 0.55, power = 0.80)` reports n = 1564.672.
		#expect(perArm == 1565, "Expected 1565 per arm, got \(perArm)")
	}

	// MARK: - The trap

	@Test("A NaN power is refused by name instead of taking the process down")
	func nanPowerIsRefused() throws {
		let design = Experiment<Double>.twoProportion(
			baseline: 0.50, minimumDetectableEffect: 0.05
		)

		// `nan <= 0` and `nan >= 1` are both false, so the old two-negation validation let
		// this through; `zBeta` became `nan` and `Int(nan)` trapped.
		let thrown = try #require(
			#expect(throws: ExperimentError.self) {
				_ = try design.sampleSizePerArm(power: Double.nan, alpha: 0.05)
			}
		)
		guard case .invalidPower = thrown else {
			Issue.record("Expected .invalidPower, got \(thrown)")
			return
		}
	}

	@Test("A NaN alpha is refused by name instead of poisoning the critical value")
	func nanAlphaIsRefused() throws {
		let design = Experiment<Double>.twoProportion(
			baseline: 0.50, minimumDetectableEffect: 0.05
		)

		let thrown = try #require(
			#expect(throws: ExperimentError.self) {
				_ = try design.sampleSizePerArm(power: 0.80, alpha: Double.nan)
			}
		)
		guard case .invalidAlpha = thrown else {
			Issue.record("Expected .invalidAlpha, got \(thrown)")
			return
		}
	}

	@Test("The infinity sentinel becomes the documented throw, not a trap")
	func infiniteSizeSentinelIsThrown() throws {
		// An effect of 1e-200 squares to exactly zero, so `meanSampleSize` returns its
		// `.infinity` sentinel — "no finite design" — which then reached `Int(_:)`.
		let design = Experiment<Double>.twoMean(
			baseline: 0.0, standardDeviation: 1.0, minimumDetectableEffect: 1e-200
		)

		let thrown = try #require(
			#expect(throws: ExperimentError.self) {
				_ = try design.sampleSizePerArm(power: 0.80, alpha: 0.05)
			}
		)
		guard case .unrepresentableSampleSize = thrown else {
			Issue.record("Expected .unrepresentableSampleSize, got \(thrown)")
			return
		}
	}

	@Test("A finite size larger than Int.max is refused, with no infinity anywhere")
	func finiteButUnrepresentableSizeIsThrown() {
		// This is the case with nothing non-finite in it at all: 1e-10 squares to 1e-20,
		// which is perfectly representable, and the per-arm figure comes out near 1.6e21 —
		// past `Int.max`, which is only 9.22e18.
		let design = Experiment<Double>.twoMean(
			baseline: 0.0, standardDeviation: 1.0, minimumDetectableEffect: 1e-10
		)

		do {
			let perArm = try design.sampleSizePerArm(power: 0.80, alpha: 0.05)
			Issue.record("A design needing ~1.6e21 observations should be refused, got \(perArm)")
		} catch let error as ExperimentError {
			guard case let .unrepresentableSampleSize(figure) = error else {
				Issue.record("Expected .unrepresentableSampleSize, got \(error)")
				return
			}
			// The payload is the unrounded figure, so it can be reported to a user who
			// wants to know how far out of reach the design is.
			#expect(figure.isFinite, "The payload should be the finite figure, got \(figure)")
			#expect(figure > 1e20, "Expected a figure above 1e20, got \(figure)")
		} catch {
			Issue.record("Expected an ExperimentError, got \(error)")
		}
	}
}

@Suite("Trapping conversions — classifier calibration")
struct ClassifierCalibrationTrapTests {

	// MARK: - Clean-data controls

	@Test("Control: exactly representable scores land in the buckets they name")
	func bucketAssignmentIsUnchanged() throws {
		// Binary fractions, so `score * 4` is exact and the slot is not a rounding question:
		// 0.0625 -> 0.25, 0.3125 -> 1.25, 0.5625 -> 2.25, 0.8125 -> 3.25.
		let scores: [Double] = [0.0625, 0.3125, 0.5625, 0.8125]
		let outcomes: [Bool] = [false, false, true, true]
		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))

		let curve = evaluation.calibration(buckets: 4)

		#expect(curve.points.count == 4, "One occupied bucket each, got \(curve.points.count)")
		#expect(curve.points[0].predictedRate.isEqual(to: 0.0625))
		#expect(curve.points[3].predictedRate.isEqual(to: 0.8125))
		#expect(curve.points[0].observedRate.isEqual(to: 0.0))
		#expect(curve.points[3].observedRate.isEqual(to: 1.0))
	}

	@Test("Control: the Brier score of the documented example is unchanged")
	func brierScoreIsUnchanged() throws {
		let scores: [Double] = [0.1, 0.4, 0.35, 0.8, 0.7, 0.2, 0.9, 0.05, 0.6, 0.3]
		let outcomes: [Bool] = [false, false, true, true, true, false, true, false, true, false]
		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))

		let curve = evaluation.calibration(buckets: 10)

		// Squared residuals, in the order above:
		//   0.01 + 0.16 + 0.4225 + 0.04 + 0.09 + 0.04 + 0.01 + 0.0025 + 0.16 + 0.09 = 1.025
		// over ten observations.
		let expected = 1.025 / 10.0
		let gap = abs(curve.brierScore - expected)
		#expect(gap < 1e-12, "Brier \(curve.brierScore) should be \(expected)")

		let observed = curve.points.reduce(0) { $0 + $1.count }
		#expect(observed == 10, "Every observation must fall in some bucket, got \(observed)")
	}

	// MARK: - The trap

	@Test("An unbounded score is clamped into the end buckets rather than trapping")
	func unboundedScoresAreClamped() throws {
		// Raw margins are legitimately unbounded — the initialiser admits any finite score
		// on purpose, because `roc`/`auc` only ever order them. `1e30 * 4` is far past
		// `Int.max`, so `Int(scaled)` trapped before the clamp on the next line ran.
		let scores: [Double] = [1e30, 0.5, -1e30, 0.25]
		let outcomes: [Bool] = [true, false, false, true]
		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))

		let curve = evaluation.calibration(buckets: 4)

		#expect(curve.points.count == 4, "Four distinct buckets, got \(curve.points.count)")
		#expect(curve.points[0].predictedRate.isEqual(to: -1e30),
				"The most negative score belongs in the bottom bucket")
		#expect(curve.points[3].predictedRate.isEqual(to: 1e30),
				"The most positive score belongs in the top bucket")
		let observed = curve.points.reduce(0) { $0 + $1.count }
		#expect(observed == 4, "No observation may be dropped, got \(observed)")
	}

	@Test("A score whose scaled value overflows to infinity still lands in the top bucket")
	func overflowingScaleIsClamped() throws {
		// `1e308 * 10` overflows to `+infinity`, which `Int(_:)` also traps on. The clamp
		// is in `T` now, so the infinity is bounded before any conversion happens.
		let scores: [Double] = [1e308, 0.5]
		let outcomes: [Bool] = [true, false]
		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))

		let curve = evaluation.calibration(buckets: 10)

		#expect(curve.points.count == 2, "Two occupied buckets, got \(curve.points.count)")
		#expect(curve.points[0].predictedRate.isEqual(to: 0.5))
		#expect(curve.points[1].predictedRate.isEqual(to: 1e308))
	}
}

@Suite("Trapping conversions — Poisson quantile")
struct DistributionPoissonTrapTests {

	// MARK: - Clean-data control

	@Test("Control: the median of a rate of 3.5 is still the third count")
	func medianIsUnchanged() throws {
		let arrivals = try #require(DistributionPoisson(lambda: 3.5))

		// Derived from the type's own CDF rather than recalled: the median is the smallest
		// k whose cumulative mass reaches one half.
		let belowMedian = arrivals.cdf(2)
		let atMedian = arrivals.cdf(3)
		#expect(belowMedian < 0.5, "cdf(2) = \(belowMedian) should fall short of one half")
		#expect(atMedian >= 0.5, "cdf(3) = \(atMedian) should reach one half")
		let median = arrivals.quantile(0.5)
		#expect(median == 3, "Got \(median)")
	}

	@Test("Control: a rate of 25 is still constructible and orders its quantiles")
	func ordinaryRateIsUnchanged() throws {
		let arrivals = try #require(DistributionPoisson(lambda: 25.0))

		#expect(arrivals.lambda.isEqual(to: 25.0))
		let low = arrivals.quantile(0.1)
		let high = arrivals.quantile(0.9)
		#expect(low < high, "quantile(0.1) = \(low) should sit below quantile(0.9) = \(high)")
	}

	// MARK: - The trap

	@Test("A rate too large to name a count is refused at construction")
	func unusableRateYieldsNil() {
		// `quantile(_:)` forms `Int(lambda + 10 * sqrt(lambda)) + 40`, which trapped: the
		// caller lost the process rather than getting a `nil` it could branch on.
		#expect(DistributionPoisson(lambda: 1e19) == nil)
		#expect(DistributionPoisson(lambda: 1e300) == nil)
		#expect(DistributionPoisson(lambda: 0x1p54) == nil)
	}

	@Test("The bound is where a Double stops distinguishing consecutive counts")
	func boundaryRateIsAccepted() throws {
		// 2^53 is the last rate that names a distinct integer count, so it is admitted and
		// 2^54 (asserted above) is not. Only construction is exercised here — see the note
		// in the sweep report about the quantile search being O(lambda).
		let atBound = try #require(DistributionPoisson(lambda: 0x1p53))
		#expect(atBound.lambda.isEqual(to: 0x1p53))
	}

	@Test("Control: the existing refusals are untouched")
	func existingRefusalsAreUnchanged() {
		#expect(DistributionPoisson(lambda: -1.0) == nil)
		#expect(DistributionPoisson(lambda: Double.nan) == nil)
		#expect(DistributionPoisson(lambda: Double.infinity) == nil)
	}

	// MARK: - The search that started at zero

	/// The windowed search answers exactly what the definition asks for.
	///
	/// `quantile(p)` is *the smallest k with `cdf(k) >= p`*, so `cdf(_:)` is the oracle and it
	/// is an independent one: it sums from zero through ``poissonCDF(_:µ:)``, while the search
	/// now starts at twelve standard deviations below the mean. Asserting both sides of the
	/// boundary — `cdf(k) >= p` and `cdf(k - 1) < p` — is what makes this an inversion rather
	/// than a coincidence at one point.
	///
	/// A rate of 5000 is chosen because it is the smallest round rate on both sides of the
	/// change: the window starts at 4111, so the skipped head is genuinely being skipped
	/// (below 144 it is not, and the test would pass without exercising anything), and the
	/// whole support is still small enough for the summing CDF to serve as the oracle.
	/// Hoisted out of the `@Test` macro: it expands its argument into generic closures, and an
	/// array literal that type-checks fine as a plain `let` has cost this project a CI run.
	static let probeProbabilities: [Double] = [0.1, 0.5, 0.9]

	@Test("The windowed search inverts the CDF exactly",
		  arguments: DistributionPoissonTrapTests.probeProbabilities)
	func windowedSearchInvertsTheCDF(probability: Double) throws {
		let arrivals = try #require(DistributionPoisson(lambda: 5000.0))

		let k: Int = arrivals.quantile(probability)
		let atK: Double = arrivals.cdf(k)
		let belowK: Double = arrivals.cdf(k - 1)

		#expect(atK >= probability,
				"quantile(\(probability)) = \(k), but cdf(\(k)) = \(atK) does not reach it")
		// One literal, not a concatenation: `Comment` is ExpressibleByStringInterpolation, so it
		// accepts a string *literal* but not a `String` expression such as `"a" + "b"`.
		let predecessor: Int = k - 1
		#expect(belowK < probability,
				"quantile(\(probability)) = \(k) is not the smallest: cdf(\(predecessor)) = \(belowK) already reaches \(probability)")
	}

	/// A rate of ten billion answers, where it used to run ten billion times.
	///
	/// This is the assertion the repair exists for and the shape of it is unusual: the test
	/// *completing* is half of it. The old search ran `for k in 0...ceiling` with the ceiling
	/// just past the mean, so at this rate it evaluated `logGamma` ten billion times — minutes
	/// at best — and at the 1e12 in the sweep report, hours. Every one of those iterations
	/// added an exact `0.0`, because the mass that far below the mean underflows. The search
	/// now spans twenty-two standard deviations around the mean, so the work is O(√λ): about
	/// two million terms here, not ten billion.
	///
	/// The value is checked against the Cornish–Fisher expansion, which is the right oracle at
	/// this rate for the same reason the search is affordable — a Poisson with λ = 1e10 is
	/// normal to within a fraction of a count, its standardised skewness being 1e-5. `z` is
	/// solved for rather than written down, so nothing here is a recalled constant.
	///
	/// The tolerance is 100 counts against a standard deviation of 100,000. It is loose in
	/// absolute terms and very tight relative to every way this could go wrong: a search
	/// starting shallower than about four standard deviations below the mean skips enough mass
	/// to move the answer by more than 300 counts, and a search that failed to reach `p` at all
	/// would return the ceiling, 100,000 counts out.
	@Test("A rate of ten billion is answered from the mean outward")
	func largeRateDoesNotWalkTheWholeSupport() throws {
		let rate = 1e10
		let arrivals = try #require(DistributionPoisson(lambda: rate))
		let deviation: Double = rate.squareRoot()

		let upperDecile: Int = arrivals.quantile(0.9)
		let z: Double = inverseNormalCDF(p: 0.9, mean: 0, stdDev: 1)
		// Cornish–Fisher to the skewness term: λ + z√λ + (z² − 1)/6.
		let shifted: Double = z * deviation
		let skewnessTerm: Double = (z * z - 1) / 6
		let expected: Double = rate + shifted + skewnessTerm
		let error: Double = abs(Double(upperDecile) - expected)
		#expect(error < 100,
				"quantile(0.9) = \(upperDecile) against \(expected), off by \(error)")

		// Monotone across the scale, which a search that returned its ceiling would not be.
		let lowerDecile: Int = arrivals.quantile(0.1)
		let median: Int = arrivals.quantile(0.5)
		#expect(lowerDecile < median, "\(lowerDecile) should sit below \(median)")
		#expect(median < upperDecile, "\(median) should sit below \(upperDecile)")

		// The median of a Poisson lies within one of its mean for a rate this large.
		let medianError: Double = abs(Double(median) - rate)
		#expect(medianError < 100, "the median \(median) is far from the mean \(rate)")
	}

	/// A probability at or above one still answers the documented ceiling, and answers it
	/// without walking the support to find out that the mass never gets there.
	@Test("Certainty answers the documented ceiling")
	func certaintyAnswersTheCeiling() throws {
		let rate = 1e10
		let arrivals = try #require(DistributionPoisson(lambda: rate))
		let deviation: Double = rate.squareRoot()
		let spread: Double = 10.0 * deviation
		let ceiling: Int = Int(rate + spread) + 40

		let atOne: Int = arrivals.quantile(1.0)
		#expect(atOne == ceiling, "got \(atOne) against \(ceiling)")
		let aboveOne: Int = arrivals.quantile(2.0)
		#expect(aboveOne == ceiling, "got \(aboveOne) against \(ceiling)")

		// And the other end is unchanged: at or below zero, and for a NaN, the answer is the
		// support minimum. `Int` has no `nan`, which is documented on the declaration.
		let atZero: Int = arrivals.quantile(0.0)
		#expect(atZero == 0, "got \(atZero)")
		let belowZero: Int = arrivals.quantile(-1.0)
		#expect(belowZero == 0, "got \(belowZero)")
		let contaminated: Int = arrivals.quantile(Double.nan)
		#expect(contaminated == 0, "got \(contaminated)")
	}
}
