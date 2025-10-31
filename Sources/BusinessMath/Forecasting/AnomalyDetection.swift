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
		guard data.count >= windowSize else {
			return []
		}

		var anomalies: [Anomaly<T>] = []
		let values = data.valuesArray

		// For each point after the initial window
		for i in windowSize..<values.count {
			// Get rolling window
			let windowStart = i - windowSize
			let window = Array(values[windowStart..<i])

			// Calculate statistics
			let mean = window.reduce(T(0), +) / T(window.count)
			let squaredDiffs = window.map { ($0 - mean) * ($0 - mean) }
			let variance = squaredDiffs.reduce(T(0), +) / T(window.count)
			let stddev = T.sqrt(variance)

			// Skip if standard deviation is too small (constant data)
			guard stddev > T(0) else { continue }

			// Calculate z-score
			let value = values[i]
			let zScore = abs((value - mean) / stddev)

			// Check if anomaly
			if zScore > threshold {
				let severity: AnomalySeverity

				if zScore > T(4) {
					severity = .severe
				} else if zScore > T(3) {
					severity = .moderate
				} else {
					severity = .mild
				}

				anomalies.append(Anomaly(
					period: data.periods[i],
					value: value,
					expectedValue: mean,
					deviationScore: zScore,
					severity: severity
				))
			}
		}

		return anomalies
	}
}
