//
//  ExperimentDesignTests.swift
//  BusinessMath
//
//  RED phase for v2.7.0 — see project/plans/upcoming/v2.7.0_SCOPE.md §5.
//
//  Reference truth is R's `power.prop.test` and `power.t.test`. Every expected
//  value below was computed from the same normal-approximation formulas R uses
//  and is reproducible there; none is asserted from memory.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Experiment Design — Two-Proportion Power")
struct TwoProportionPowerTests {

	// MARK: - Golden path, against R's power.prop.test

	@Test("R: power.prop.test(p1=.50, p2=.55, power=.80) -> 1565 per arm")
	func sizingMatchesRForFiftyToFiftyFive() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let n = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)

		#expect(n == 1565, "Expected 1565 per arm (R gives n = 1564.672, rounded up), got \(n)")
	}

	@Test("R: power.prop.test(p1=.05, p2=.06, power=.80) -> 8158 per arm")
	func sizingMatchesRForLowBaseRate() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.05, minimumDetectableEffect: 0.01)
		let n = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)

		#expect(n == 8158, "Expected 8158 per arm (R gives n = 8157.731), got \(n)")
	}

	@Test("R: power.prop.test(p1=.10, p2=.12, power=.90) -> 5142 per arm")
	func sizingMatchesRAtNinetyPercentPower() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.10, minimumDetectableEffect: 0.02)
		let n = try design.sampleSizePerArm(power: 0.90, alpha: 0.05, tails: .two)

		#expect(n == 5142, "Expected 5142 per arm (R gives n = 5141.306), got \(n)")
	}

	// MARK: - The defect this release exists to fix

	@Test("The corrected sizing is ~4.07x the legacy Cochran survey formula")
	func correctedSizingExceedsLegacyByTheDocumentedFactor() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let corrected = Double(try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two))

		// The legacy function, pinned at its current behaviour so this release
		// cannot change it by accident before 3.0.0 deletes it.
		let legacy = sampleSize(ci: 0.95, proportion: 0.5, n: 1_000_000_000.0, error: 0.05)

		#expect(abs(legacy - 384.145735) < 1e-4,
			"Legacy sampleSize should still return 384.146; got \(legacy)")
		#expect(abs(corrected / legacy - 4.0731) < 0.001,
			"Correction factor should be ~4.073x; got \(corrected / legacy)")
	}

	// MARK: - Round-trip

	@Test("Round-trip: sizing for 80% power then measuring power at that n returns 80%")
	func powerRoundTripsThroughSampleSize() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let n = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		let achieved = try design.achievedPower(perArm: n, alpha: 0.05, tails: .two)

		#expect(abs(achieved - 0.800082) < 1e-5,
			"Achieved power at n=\(n) should be 0.800082, got \(achieved)")
	}

	@Test("Round-trip: minimum detectable effect recovers the design's own MDE")
	func minimumDetectableEffectRoundTrips() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let n = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		let mde = try design.minimumDetectableEffect(perArm: n, power: 0.80, alpha: 0.05)

		#expect(abs(mde - 0.05) < 1e-3, "MDE should round-trip to 0.05, got \(mde)")
	}

	// MARK: - Properties

	@Test("Identity: one-sided at alpha equals two-sided at 2*alpha")
	func oneSidedEqualsTwoSidedAtDoubleAlpha() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let oneSided = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .one)
		let twoSided = try design.sampleSizePerArm(power: 0.80, alpha: 0.10, tails: .two)

		#expect(oneSided == twoSided,
			"One-sided at 0.05 (\(oneSided)) should equal two-sided at 0.10 (\(twoSided))")
	}

	@Test("Monotone: a smaller effect requires a larger sample")
	func smallerEffectRequiresLargerSample() throws {
		let large = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.10)
		let small = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.02)

		let nLarge = try large.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		let nSmall = try small.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)

		#expect(nSmall > nLarge, "Detecting 0.02 (\(nSmall)) must need more than 0.10 (\(nLarge))")
	}

	@Test("Monotone: more power requires a larger sample; a looser alpha requires less")
	func powerAndAlphaMoveSampleSizeInOppositeDirections() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)

		let atEighty = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		let atNinety = try design.sampleSizePerArm(power: 0.90, alpha: 0.05, tails: .two)
		let looseAlpha = try design.sampleSizePerArm(power: 0.80, alpha: 0.10, tails: .two)

		#expect(atNinety > atEighty, "90% power (\(atNinety)) must exceed 80% (\(atEighty))")
		#expect(looseAlpha < atEighty, "alpha=0.10 (\(looseAlpha)) must be below alpha=0.05 (\(atEighty))")
	}

	// MARK: - Refusals

	@Test("Refuses a power of zero or one — neither has a finite sample size")
	func refusesDegeneratePower() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)

		#expect(throws: ExperimentError.self) {
			_ = try design.sampleSizePerArm(power: 0.0, alpha: 0.05, tails: .two)
		}
		#expect(throws: ExperimentError.self) {
			_ = try design.sampleSizePerArm(power: 1.0, alpha: 0.05, tails: .two)
		}
	}

	@Test("Refuses an alpha outside (0, 1)")
	func refusesAlphaOutsideUnitInterval() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)

		#expect(throws: ExperimentError.self) {
			_ = try design.sampleSizePerArm(power: 0.80, alpha: 0.0, tails: .two)
		}
		#expect(throws: ExperimentError.self) {
			_ = try design.sampleSizePerArm(power: 0.80, alpha: 1.0, tails: .two)
		}
	}

	@Test("Refuses a non-positive minimum detectable effect")
	func refusesNonPositiveEffect() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.0)

		#expect(throws: ExperimentError.self) {
			_ = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		}
	}

	@Test("Refuses a baseline outside [0, 1], and an MDE that pushes the arm past 1")
	func refusesImpossibleProportions() throws {
		let badBaseline = Experiment<Double>.twoProportion(baseline: 1.5, minimumDetectableEffect: 0.05)
		#expect(throws: ExperimentError.self) {
			_ = try badBaseline.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		}

		let overshoots = Experiment<Double>.twoProportion(baseline: 0.98, minimumDetectableEffect: 0.05)
		#expect(throws: ExperimentError.self) {
			_ = try overshoots.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		}
	}
}

@Suite("Experiment Design — Two-Mean Power")
struct TwoMeanPowerTests {

	@Test("Normal approximation: delta=5, sd=20, power=.80 -> 252 per arm")
	func sizingMatchesNormalApproximation() throws {
		let design = Experiment<Double>.twoMean(
			baseline: 100.0, standardDeviation: 20.0, minimumDetectableEffect: 5.0
		)
		let n = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)

		#expect(n == 252, "Expected 252 per arm (exact 251.164, rounded up), got \(n)")
	}

	@Test("Refuses a non-positive standard deviation")
	func refusesNonPositiveStandardDeviation() throws {
		let design = Experiment<Double>.twoMean(
			baseline: 100.0, standardDeviation: 0.0, minimumDetectableEffect: 5.0
		)
		#expect(throws: ExperimentError.self) {
			_ = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
		}
	}
}

@Suite("Experiment Analysis")
struct ExperimentAnalysisTests {

	/// 1,565 per arm — the sizing the design called for — with 782 and 861 conversions.
	private var observed: ArmResults<Double> {
		ArmResults(controlObservations: 1565, controlConversions: 782,
				   treatmentObservations: 1565, treatmentConversions: 861)
	}

	@Test("Reports absolute and relative lift with a 95% interval")
	func reportsLiftAndInterval() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let result = try design.analyze(observed, alpha: 0.05)

		#expect(abs(result.absoluteLift - 0.0504792332) < 1e-9,
			"Absolute lift should be 0.05048, got \(result.absoluteLift)")
		#expect(abs(result.relativeLift - 0.1010230179) < 1e-9,
			"Relative lift should be 0.10102, got \(result.relativeLift)")
		#expect(abs(result.interval.lowerBound - 0.0155346039) < 1e-9,
			"CI lower bound should be 0.01553, got \(result.interval.lowerBound)")
		#expect(abs(result.interval.upperBound - 0.0854238625) < 1e-9,
			"CI upper bound should be 0.08542, got \(result.interval.upperBound)")
	}

	@Test("Reports a true two-sided p-value")
	func reportsTrueTwoSidedPValue() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let result = try design.analyze(observed, alpha: 0.05)

		#expect(abs(result.pValue - 0.0046364398) < 1e-9,
			"Two-sided p should be 0.004636, got \(result.pValue)")
	}

	/// The legacy `pValue` does not return a p-value. It returns `normSDist(|z|)`,
	/// which is `1 - oneSidedP`, and because the code takes `abs(z)` the result is
	/// always at least 0.5 — so the `p < 0.05` test its own documentation prescribes
	/// can never be true. Pinned here so 2.7.0 cannot change it by accident, and so
	/// the defect is asserted rather than described.
	@Test("Legacy pValue returns the complement, not a p-value — pinned")
	func legacyPValueReturnsTheComplementOfAOneSidedP() throws {
		// The library's own documented usage example: 120/1000 against 145/1000.
		let legacy: Double = pValue(obsA: 1000, convA: 120, obsB: 1000, convB: 145)

		#expect(abs(legacy - 0.950526) < 1e-5,
			"Legacy pValue returns normSDist(|z|) = 0.950526, got \(legacy)")
		#expect(legacy >= 0.5,
			"Legacy pValue can never fall below 0.5, so `p < 0.05` never fires")

		// What that example should report, and what `analyze` will.
		let trueTwoSided = 2.0 * (1.0 - legacy)
		#expect(abs(trueTwoSided - 0.098948) < 1e-5,
			"The true two-sided p for that example is 0.098948, not the 0.043 the doc claims")
	}

	@Test("Property: the interval contains the point estimate")
	func intervalContainsPointEstimate() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let result = try design.analyze(observed, alpha: 0.05)

		#expect(result.interval.contains(result.absoluteLift),
			"Interval \(result.interval) must contain \(result.absoluteLift)")
	}

	@Test("Property: the interval excludes zero exactly when p is below alpha")
	func intervalExcludesZeroIffSignificant() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)

		let significant = try design.analyze(observed, alpha: 0.05)
		#expect(significant.pValue < 0.05)
		#expect(!significant.interval.contains(0.0),
			"A significant result's interval must exclude zero: \(significant.interval)")

		// Same rates, a twentieth of the sample: the effect survives, the evidence does not.
		let underpowered = ArmResults<Double>(
			controlObservations: 78, controlConversions: 39,
			treatmentObservations: 78, treatmentConversions: 43
		)
		let notSignificant = try design.analyze(underpowered, alpha: 0.05)
		#expect(notSignificant.pValue > 0.05)
		#expect(notSignificant.interval.contains(0.0),
			"A non-significant result's interval must contain zero: \(notSignificant.interval)")
	}

	@Test("Refuses an arm with no observations")
	func refusesEmptyArm() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let empty = ArmResults<Double>(
			controlObservations: 0, controlConversions: 0,
			treatmentObservations: 100, treatmentConversions: 10
		)

		#expect(throws: ExperimentError.self) {
			_ = try design.analyze(empty, alpha: 0.05)
		}
	}

	@Test("Refuses conversions exceeding observations")
	func refusesImpossibleConversionCount() throws {
		let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
		let impossible = ArmResults<Double>(
			controlObservations: 100, controlConversions: 150,
			treatmentObservations: 100, treatmentConversions: 10
		)

		#expect(throws: ExperimentError.self) {
			_ = try design.analyze(impossible, alpha: 0.05)
		}
	}
}
