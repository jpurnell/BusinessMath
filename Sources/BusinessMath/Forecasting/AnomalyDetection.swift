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
