//
//  RobustAnomalyDetectionTests.swift
//  BusinessMathTests
//
//  The z-score detector has one blind spot, and it is not the one the review filed.
//

import Testing
import Foundation
@testable import BusinessMath

/// Three detection rules, and the case that separates them.
///
/// A review filed `ZScoreAnomalyDetector` as computing "a z-score against the series' own
/// mean and standard deviation", so that a single large outlier inflates the deviation
/// enough to hide itself — on `[10, 12, 11, 13, 12, 50, 11, 12]` reporting z = 2.4694
/// against a threshold of 3.0, and missing the 50.
///
/// **Measured against the code, that is refuted.** The baseline is the `windowSize` points
/// *before* the one under test, so a value is never inside the baseline it is judged
/// against, and `flaggedIndices` drops already-flagged points from later windows. On that
/// series the 50 is flagged at every window size from 2 to 5, with z between 37 and 75.
/// Runs of consecutive spikes are caught too.
///
/// **The real hole is the loop bound.** The scan starts at `windowSize`, so the leading
/// `windowSize` points are never examined — invisible themselves, and inflating the
/// standard deviation for everything after them. `leadingSpikeMasksALaterAnomaly` is that
/// case, and it is why the two robust detectors were added.
@Suite("Robust anomaly detection")
struct RobustAnomalyDetectionTests {

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		let periods = (0..<values.count).map { Period.month(year: 2025, month: $0 + 1) }
		return TimeSeries(periods: periods, values: values)
	}

	/// The review's series, and what the z-score detector actually does with it.
	@Test("The rolling z-score catches the review's spike, contrary to the filed claim")
	func theFiledClaimIsRefuted() {
		let data = series([10, 12, 11, 13, 12, 50, 11, 12])
		for window in 2...5 {
			let detector = ZScoreAnomalyDetector<Double>(windowSize: window)
			let found = detector.detect(in: data, threshold: 3.0)
			#expect(found.count == 1, "window \(window) found \(found.count) anomalies")
			let flagged: Double = found.first?.value ?? 0
			#expect(flagged.isEqual(to: 50.0), "window \(window) flagged \(flagged)")
		}
	}

	/// The blind spot that is real, stated as the difference one unexaminable point makes.
	@Test("A spike inside the first window hides a later anomaly entirely")
	func leadingSpikeMasksALaterAnomaly() {
		let detector = ZScoreAnomalyDetector<Double>(windowSize: 4)

		// A clean baseline: the 30 stands out sharply.
		let clean = detector.detect(in: series([12, 11, 13, 12, 30, 12, 11, 12]), threshold: 3.0)
		#expect(clean.count == 1, "clean baseline found \(clean.count)")
		let score: Double = clean.first?.deviationScore ?? 0
		#expect(score > 25.0, "the 30 scored \(score) against a clean baseline")

		// The same 30 and the same threshold. Only the first value changed — and the scan
		// never reaches it, because the first `windowSize` points are baseline only.
		let poisoned = detector.detect(in: series([50, 11, 13, 12, 30, 12, 11, 12]), threshold: 3.0)
		#expect(poisoned.isEmpty,
				"one unexaminable leading value should silence the detector, got \(poisoned.count)")
	}

	/// The robust rules see what the z-score cannot.
	@Test("Both robust detectors flag the leading spike the z-score never examines")
	func robustRulesSeeTheLeadingSpike() {
		let data = series([50, 11, 13, 12, 30, 12, 11, 12])

		let modified = ModifiedZScoreAnomalyDetector<Double>().detect(in: data)
		let modifiedValues: [Double] = modified.map { $0.value }
		#expect(modifiedValues.contains(50.0), "modified z flagged \(modifiedValues)")

		let iqr = IQRAnomalyDetector<Double>().detect(in: data)
		let iqrValues: [Double] = iqr.map { $0.value }
		#expect(iqrValues.contains(50.0), "IQR flagged \(iqrValues)")
	}

	/// The modified z-score of the review's outlier, pinned to its arithmetic.
	///
	/// median = 12, MAD = 1, so M = 0.6745 · |50 - 12| / 1 = 25.631. Computed here rather
	/// than transcribed, so the assertion is the identity and not a copied constant.
	@Test("The modified z-score of the review's 50 is 0.6745 · 38, which is 25.631")
	func modifiedZScoreIsPinned() throws {
		let data = series([10, 12, 11, 13, 12, 50, 11, 12])
		let found = ModifiedZScoreAnomalyDetector<Double>().detect(in: data)

		let spike = try #require(found.first { $0.value.isEqual(to: 50.0) })
		let expected: Double = 0.6745 * 38.0 / 1.0
		#expect(abs(spike.deviationScore - expected) < 1e-12,
				"scored \(spike.deviationScore), expected \(expected)")
		#expect(spike.expectedValue.isEqual(to: 12.0), "median was \(spike.expectedValue)")
	}

	/// Tukey's fence on the same series, pinned to the quartiles that produce it.
	///
	/// Sorted the series is `[10, 11, 11, 12, 12, 12, 13, 50]`, so with the library's
	/// interpolating `quantile` Q1 = 11 and Q3 = 12.25. IQR = 1.25 and the upper fence is
	/// 12.25 + 1.5 · 1.25 = **14.125** — which the 50 clears by a wide margin, and which
	/// no ordinary value comes near.
	@Test("The upper Tukey fence for the review's series is 14.125")
	func tukeyFenceIsPinned() throws {
		let values: [Double] = [10, 12, 11, 13, 12, 50, 11, 12]
		let sorted: [Double] = values.sorted()
		let q1: Double = quantile(sorted: sorted, p: 0.25)
		let q3: Double = quantile(sorted: sorted, p: 0.75)
		let iqr: Double = q3 - q1
		let fence: Double = q3 + 1.5 * iqr

		#expect(q1.isEqual(to: 11.0), "Q1 was \(q1)")
		#expect(q3.isEqual(to: 12.25), "Q3 was \(q3)")
		#expect(fence.isEqual(to: 14.125), "the fence was \(fence)")

		let found = IQRAnomalyDetector<Double>().detect(in: series(values))
		#expect(found.count == 1, "found \(found.map { $0.value })")
		let flagged = try #require(found.first)
		#expect(flagged.value.isEqual(to: 50.0), "flagged \(flagged.value)")
	}

	/// Robustness, stated as the property that defines it.
	///
	/// Move the outlier further away and a mean-based rule follows it — the standard
	/// deviation grows, so the score need not. The median and the MAD do not move at all,
	/// so the score rises without bound. That is the whole difference between the two
	/// families, and it is checkable rather than merely describable.
	@Test("Sending the outlier further out raises its modified z-score without bound")
	func theScaleDoesNotChaseTheOutlier() throws {
		let detector = ModifiedZScoreAnomalyDetector<Double>()

		var previous: Double = 0
		for magnitude in [50.0, 500.0, 5_000.0, 50_000.0] {
			let data = series([10, 12, 11, 13, 12, magnitude, 11, 12])
			let found = detector.detect(in: data)
			let spike = try #require(found.first { $0.value.isEqual(to: magnitude) })
			#expect(spike.deviationScore > previous,
					"at \(magnitude) the score was \(spike.deviationScore), not above \(previous)")
			previous = spike.deviationScore
		}
	}

	/// The degenerate samples each rule refuses, rather than answering badly.
	@Test("A constant series produces no anomalies under either robust rule")
	func degenerateSamplesAreRefused() {
		let flat = series([12, 12, 12, 12, 12, 12, 12, 12])
		#expect(ModifiedZScoreAnomalyDetector<Double>().detect(in: flat).isEmpty,
				"a zero MAD should yield nothing")
		#expect(IQRAnomalyDetector<Double>().detect(in: flat).isEmpty,
				"a zero IQR should yield nothing")

		// Fewer than four points carries no quartile information.
		let tiny = series([1, 100, 2])
		#expect(IQRAnomalyDetector<Double>().detect(in: tiny).isEmpty,
				"three points should yield nothing")
	}
}
