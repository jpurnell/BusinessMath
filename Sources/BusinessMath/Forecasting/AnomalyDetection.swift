//
//  AnomalyDetection.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - AnomalySeverity

/// The severity level of an anomaly.
public enum AnomalySeverity: String, Sendable {
	/// Mild anomaly (2-3 standard deviations).
	case mild

	/// Moderate anomaly (3-4 standard deviations).
	case moderate

	/// Severe anomaly (>4 standard deviations).
	case severe
}

// MARK: - Anomaly

/// Represents a detected anomaly in a time series.
public struct Anomaly<T: Real & Sendable & Codable>: Sendable {
	/// The period when the anomaly occurred.
	public let period: Period

	/// The actual value at this period.
	public let value: T

	/// The expected value (based on rolling statistics).
	public let expectedValue: T

	/// The deviation score (number of standard deviations from mean).
	public let deviationScore: T

	/// The severity classification of the anomaly.
	public let severity: AnomalySeverity

	/// Creates an anomaly.
	///
	/// - Parameters:
	///   - period: The period when the anomaly occurred.
	///   - value: The actual value.
	///   - expectedValue: The expected value.
	///   - deviationScore: The z-score.
	///   - severity: The severity level.
	public init(
		period: Period,
		value: T,
		expectedValue: T,
		deviationScore: T,
		severity: AnomalySeverity
	) {
		self.period = period
		self.value = value
		self.expectedValue = expectedValue
		self.deviationScore = deviationScore
		self.severity = severity
	}

	var description: String {
		let df = ISO8601DateFormatter()
		return "\(df.string(from: period.date)): \(value) |\t\(expectedValue) |\tz=\(deviationScore) |\t\(severity.rawValue.capitalized)"
	}
}

// MARK: - ZScoreAnomalyDetector

/// Detects anomalies using the z-score method.
///
/// `ZScoreAnomalyDetector` identifies values that deviate significantly from
/// the mean within a rolling window. It uses z-scores (standard deviations)
/// to quantify how unusual a value is.
///
/// ## Usage
///
/// ```swift
/// let timeSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
/// let detector = ZScoreAnomalyDetector<Double>(windowSize: 30)
/// let anomalies = detector.detect(in: timeSeries, threshold: 3.0)
///
/// for anomaly in anomalies {
///     print("\(anomaly.period): \(anomaly.value) (z=\(anomaly.deviationScore))")
/// }
/// ```
///
/// ## Method
///
/// For each point in the time series:
/// 1. Calculate mean and standard deviation of the rolling window
/// 2. Compute z-score: z = (value - mean) / stddev
/// 3. If |z| > threshold, flag as anomaly
/// 4. Classify severity based on z-score magnitude
///
/// The window is the `windowSize` points **before** the one under test, so a value is
/// never part of the baseline it is measured against, and points already flagged are
/// dropped from later baselines. Between them those two properties handle the textbook
/// self-masking case: a lone spike, and even a run of consecutive spikes, is caught.
///
/// ## The limitation: the first `windowSize` points
///
/// The scan starts at index `windowSize`, because nothing earlier has a full baseline. So
/// **the leading `windowSize` points are never examined**, and an anomaly among them is
/// invisible *and* inflates the standard deviation every later point is judged against.
///
/// Measured, on a threshold of 3.0 and a window of 4:
///
/// ```swift
/// // A clean baseline. The 30 is flagged, with z = 25.46.
/// [12, 11, 13, 12, 30, 12, 11, 12]
///
/// // The same 30, the same threshold. One leading value changed — and it is a value the
/// // scan never reaches. Nothing at all is flagged.
/// [50, 11, 13, 12, 30, 12, 11, 12]
/// ```
///
/// A standard deviation is the wrong tool against contamination, because a single extreme
/// value moves it far enough to hide behind. When the level is stable and the risk is a
/// contaminated baseline, reach for ``ModifiedZScoreAnomalyDetector`` or
/// ``IQRAnomalyDetector`` instead: both rest on order statistics, which a handful of
/// extreme values barely move, and both examine every point including the first.
///
/// Keep this detector when the level genuinely moves — a trailing window tracks a drifting
/// series, and a whole-sample rule will call the drift itself an anomaly.
public struct ZScoreAnomalyDetector<T: Real & Sendable & Codable> {
	
		// MARK: - Properties
	
		/// The size of the rolling window for calculating statistics.
	public let windowSize: Int
	
		// MARK: - Initialization
	
		/// Creates a z-score anomaly detector.
		///
		/// - Parameter windowSize: Number of periods to include in rolling window.
	public init(windowSize: Int) {
		self.windowSize = windowSize
	}
	
		// MARK: - Detection
	
		/// Detects anomalies in a time series.
		///
		/// - Parameters:
		///   - data: The time series to analyze.
		///   - threshold: The z-score threshold (e.g., 3.0 for ±3 standard deviations).
		/// - Returns: An array of detected anomalies.

	public func detect(in data: TimeSeries<T>, threshold: T) -> [Anomaly<T>] {
			guard data.count >= windowSize else { return [] }

			var anomalies: [Anomaly<T>] = []
			let values = data.valuesArray

			// Track indices of previously flagged anomalies to exclude from the baseline window
			var flaggedIndices = Set<Int>()

			for i in windowSize..<values.count {
					let start = i - windowSize

					// Compute mean over the window excluding prior anomalies
					var sum: T = .zero
					var n: Int = 0
					for j in start..<i {
							if flaggedIndices.contains(j) { continue }
							sum += values[j]
							n += 1
					}
					if n == 0 { continue } // no usable baseline
					let countT = T(n)
					let mean = sum / countT

					// Compute variance over the same filtered window
					var sumSq: T = .zero
					for j in start..<i {
							if flaggedIndices.contains(j) { continue }
							let d = values[j] - mean
							sumSq += d * d
					}
					let variance = sumSq / countT
					let stddev = T.sqrt(variance)

					let value = values[i]

					var zScore: T = .zero
					var severity: AnomalySeverity? = nil

					let three: T = 3
					let four: T = 4

					if stddev == .zero {
							// Flat baseline: use a finite fallback scale so that z-scores are comparable and monotonic
							if value != mean {
									let diff = abs(value - mean)
									let rel: T = T(1) / T(100)   // 1% of the baseline level
									let absEps: T = 1   // at least 1 unit to avoid exploding z near zero mean
									let fallbackScale = max(abs(mean) * rel, absEps)
									zScore = diff / fallbackScale

									if zScore > threshold {
											if zScore > four {
													severity = .severe
											} else if zScore > three {
													severity = .moderate
											} else {
													severity = .mild
											}
									}
							}
					} else {
							let diff = abs(value - mean)
							zScore = diff / stddev

							if zScore > threshold {
									if zScore > four {
											severity = .severe
									} else if zScore > three {
											severity = .moderate
									} else {
											severity = .mild
									}
							}
					}

					if let sev = severity {
							anomalies.append(Anomaly(
									period: data.periods[i],
									value: value,
									expectedValue: mean,
									deviationScore: zScore,
									severity: sev
							))
							flaggedIndices.insert(i) // exclude this point from future baselines
					}
			}

			return anomalies
	}
}

// MARK: - ModifiedZScoreAnomalyDetector

/// Detects anomalies using the modified z-score, which contamination cannot hide behind.
///
/// Where ``ZScoreAnomalyDetector`` measures against a mean and a standard deviation, this
/// measures against a **median** and a **median absolute deviation**. Both are order
/// statistics: moving one observation to infinity moves the median by at most one position
/// and the MAD hardly at all, so an outlier cannot inflate the scale it is then judged
/// against. A mean and a standard deviation have no such protection — one extreme value
/// drags both toward itself, which is how a spike comes to look ordinary.
///
/// ## Method
///
/// For every point in the series — including the first, which the rolling z-score never
/// reaches:
///
/// ```
/// M = 0.6745 · |x - median| / MAD
/// ```
///
/// The constant is Φ⁻¹(0.75). It rescales the MAD so that, for normally distributed data,
/// `M` is on the same footing as an ordinary z-score — which is what makes a threshold
/// borrowed from one usable on the other. Iglewicz and Hoaglin's recommended threshold is
/// **3.5**, and that is the default here.
///
/// ## Example
///
/// ```swift
/// let months = (1...8).map { Period.month(year: 2025, month: $0) }
/// let series = TimeSeries(periods: months, values: [10, 12, 11, 13, 12, 50, 11, 12])
/// let detector = ModifiedZScoreAnomalyDetector<Double>()
/// let anomalies = detector.detect(in: series)
/// // The 50 scores M = 25.63 against a threshold of 3.5.
/// ```
///
/// ## When not to use it
///
/// The baseline is the whole sample, so a series with a genuine trend or level shift will
/// report the far end of the trend as anomalous. For a moving level, ``ZScoreAnomalyDetector``
/// and its trailing window is the right tool.
public struct ModifiedZScoreAnomalyDetector<T: Real & Sendable & Codable> {

	/// The default threshold, from Iglewicz and Hoaglin: 3.5.
	public static var defaultThreshold: T { T(7) / T(2) }

	/// Creates a modified z-score detector.
	public init() {}

	/// Detects anomalies in a time series.
	///
	/// - Parameters:
	///   - data: The time series to analyse.
	///   - threshold: The modified z-score above which a point is an anomaly.
	///     Defaults to 3.5.
	/// - Returns: The detected anomalies, in period order. Empty when the series is
	///   empty, or when more than half its values are identical — see below.
	public func detect(in data: TimeSeries<T>, threshold: T? = nil) -> [Anomaly<T>] {
		let cutoff: T = threshold ?? Self.defaultThreshold
		let values = data.valuesArray
		guard !values.isEmpty else { return [] }

		let centre: T = median(values)
		let deviations: [T] = values.map { abs($0 - centre) }
		let scale: T = median(deviations)

		// A MAD of zero means more than half the sample sits on a single value. The ratio
		// is then 0/0 for that value and x/0 for every other, so the rule has nothing to
		// say and says nothing, rather than reporting every distinct value as infinitely
		// anomalous. `ZScoreAnomalyDetector`'s fallback scale is not borrowed here: it is
		// a proportion of the *mean*, which is the quantity this detector exists to avoid.
		guard scale > T.zero else { return [] }

		let consistency: T = T(6745) / T(10_000)   // Φ⁻¹(0.75)
		let three: T = 3
		let four: T = 4

		var anomalies: [Anomaly<T>] = []
		for (index, value) in values.enumerated() {
			let deviation: T = abs(value - centre)
			let scaled: T = consistency * deviation
			let score: T = scaled / scale
			guard score > cutoff else { continue }

			let severity: AnomalySeverity
			if score > four {
				severity = .severe
			} else if score > three {
				severity = .moderate
			} else {
				severity = .mild
			}

			anomalies.append(Anomaly(
				period: data.periods[index],
				value: value,
				expectedValue: centre,
				deviationScore: score,
				severity: severity
			))
		}
		return anomalies
	}
}

// MARK: - IQRAnomalyDetector

/// Detects anomalies with Tukey's fences, the rule behind a box plot's whiskers.
///
/// A point is an anomaly when it falls outside `[Q1 - k·IQR, Q3 + k·IQR]`. Like
/// ``ModifiedZScoreAnomalyDetector`` this rests on order statistics, so contamination
/// cannot manufacture the scale that hides it — but it makes no assumption of symmetry,
/// which the modified z-score's single centre does. On a skewed series the fences sit at
/// different distances above and below, where a median-based score treats both tails alike.
///
/// ## Method
///
/// Quartiles come from ``quantile(sorted:p:)``, which interpolates at `p·(n-1)` — the same
/// definition Excel's `PERCENTILE.INC` uses. `k` defaults to **1.5**, Tukey's value: for
/// normally distributed data it places about 0.7% of observations outside the fences.
/// Use 3.0 for "far out" points only.
///
/// ## Example
///
/// ```swift
/// let months = (1...8).map { Period.month(year: 2025, month: $0) }
/// let series = TimeSeries(periods: months, values: [10, 12, 11, 13, 12, 50, 11, 12])
/// let detector = IQRAnomalyDetector<Double>()
/// let anomalies = detector.detect(in: series)
/// // Q1 = 11, Q3 = 12.25, IQR = 1.25, so the upper fence is 14.125 and the 50 is outside it.
/// ```
///
/// ## When not to use it
///
/// As with the modified z-score, the quartiles describe the whole sample, so a trending
/// series will report its own extremes. Reach for ``ZScoreAnomalyDetector`` when the level
/// moves.
public struct IQRAnomalyDetector<T: Real & Sendable & Codable & BinaryFloatingPoint> {

	/// Tukey's multiplier: 1.5.
	public static var defaultMultiplier: T { T(3) / T(2) }

	/// Creates an interquartile-range detector.
	public init() {}

	/// Detects anomalies in a time series.
	///
	/// - Parameters:
	///   - data: The time series to analyse.
	///   - multiplier: The fence multiplier `k`. Defaults to 1.5.
	/// - Returns: The detected anomalies, in period order. Empty for a series of fewer
	///   than four points, where quartiles carry no information.
	public func detect(in data: TimeSeries<T>, multiplier: T? = nil) -> [Anomaly<T>] {
		let k: T = multiplier ?? Self.defaultMultiplier
		let values = data.valuesArray
		guard values.count >= 4 else { return [] }

		let sorted: [T] = values.sorted()
		let quarter: T = T(1) / T(4)
		let threeQuarters: T = T(3) / T(4)
		let q1: T = quantile(sorted: sorted, p: quarter)
		let q3: T = quantile(sorted: sorted, p: threeQuarters)
		let iqr: T = q3 - q1

		let lowerFence: T = q1 - k * iqr
		let upperFence: T = q3 + k * iqr
		let centre: T = median(values)

		// A zero IQR means the middle half of the sample is a single value, so the fences
		// collapse onto it and every distinct observation lies outside. That is a
		// degenerate sample rather than a series of anomalies, and the score below would
		// divide by zero besides.
		guard iqr > T.zero else { return [] }

		let three: T = 3
		let four: T = 4

		var anomalies: [Anomaly<T>] = []
		for (index, value) in values.enumerated() {
			guard value < lowerFence || value > upperFence else { continue }

			// How many IQRs past the nearer fence the point sits, so the score is
			// comparable across series of different scale and reads like the z-scores the
			// other detectors report.
			let excess: T = value > upperFence ? value - upperFence : lowerFence - value
			let score: T = excess / iqr

			let severity: AnomalySeverity
			if score > four {
				severity = .severe
			} else if score > three {
				severity = .moderate
			} else {
				severity = .mild
			}

			anomalies.append(Anomaly(
				period: data.periods[index],
				value: value,
				expectedValue: centre,
				deviationScore: score,
				severity: severity
			))
		}
		return anomalies
	}
}
